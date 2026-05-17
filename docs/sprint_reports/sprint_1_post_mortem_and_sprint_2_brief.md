# Sprint 1 Post-Mortem + Sprint 2 Brief: От MVP к полноценному терминалу

**Дата:** 2026-05-17
**Аудитория:** архитектор Opus, для проектирования Sprint 2
**Состояние:** Sprint 1 завершён по объёму, но **UX-достаточности до «полноценного торгового терминала» не хватает**. Этот отчёт фиксирует пройденное, текущие ограничения и предлагает структуру Sprint 2.

---

## 0. TL;DR для Opus

End-to-end запуск работает: одна команда `npm run dev` в `C:\BUFFER\mm-bot\` поднимает adapter на 3000 и Astras UI на 4200, оба в одном терминале PyCharm. Astras авторизуется через mock JWT, видит портфель `bybit_demo (UNITED)` с балансом $887K на Bybit Demo, светлая тема включена принудительно, WS-подключения стабильны, виджеты больше не крашатся.

**Но пользователь видит почти пустой дашборд:** не отображается стакан, нет свечного графика, форма ордера без bid'а и без stack-привязки, нет кривой equity, нет «полнокровного» blotter'а с активными ордерами. Корни — четыре класса проблем:

1. **Layout-долг**: дефолтный дашборд унаследован от upstream Astras и рассчитан на MOEX-фондовый рынок, а не на крипту. Многие нужные виджеты (`order-book`, `tech-chart`, `news`) либо не на главном дашборде, либо рендерятся, но без данных.
2. **Неполные WS-маппинги**: light-chart не получает свечи; bid в ticker'е пуст; нет push-обновлений по replace/amend ордерам.
3. **Hyperion-долг**: GraphQL backend Astras (используется виджетами «Карта рынка», «Тенденции рынка», «Инфо о бумаге», «Облигации», «Поиск инструмента») у нас сейчас отвечает корректным «пусто» — но не настоящими данными. Это требует отдельного GraphQL proxy слоя.
4. **Equity curve отсутствует**: Bybit не отдаёт исторический balance, а Astras виджет «Динамика по договору» ждёт временной ряд. Нужно писать собственный recorder.

Sprint 2 должен сфокусироваться на **(1) и (2)** — это даёт «потрогать» полный цикл ордера. **(3)** и **(4)** можно вынести в Sprint 3.

---

## 1. Что сделано в Sprint 1 (полная сводка)

### 1.1 bybit-adapter — Node.js/Fastify прокси (порт 3000)

Репозиторий: <https://github.com/anymasoft/bybit-adapter>

**Стек:** Fastify 4 + TypeScript + `tiagosiebler/bybit-api` (REST+WS клиент к Bybit V5) + Zod + pino. Tsx watch для dev-hot-reload.

**REST endpoints (эмулируют ALOR API):**

| Категория | Endpoints | Источник Bybit |
|---|---|---|
| Auth | `POST /auth/actions/refresh` (выпускает mock JWT с `clientid`/`sub`/`portfolios`/`exp`), `DELETE /auth/actions/refresh/:rt` | — (mock) |
| Instruments | `GET /md/v2/Securities`, `GET /md/v2/Securities/:ex/:sym`, `.../availableBoards`, `.../quotes` | `/v5/market/instruments-info`, `/v5/market/tickers` |
| History (свечи) | `GET /md/v2/history` | `/v5/market/kline` |
| Orderbook snapshot | `GET /md/v2/orderbooks/:ex/:sym` | `/v5/market/orderbook` |
| Portfolio | `GET /md/v2/Clients/:ex/:portfolio/summary`, `.../positions`, `.../orders`, `.../all` | `/v5/account/wallet-balance`, `/v5/position/list`, `/v5/order/realtime` |
| Orders | `POST /commandapi/warptrans/{FX1,TRADE}/v2/.../orders/{limit,market}`, DELETE | `/v5/order/create`, `/v5/order/cancel` |
| UserSettings | `GET/PUT/DELETE /identity/v5/UserSettings` (in-memory) | — (in-memory) |
| Stubs | `/api/releases`, `/hyperion` (GraphQL), `/news/graphql`, `/instruments/v1/TreeMap`, `/cmsapi/*`, `/md/v2/time`, `/eslogs`, `/astras/rates/actions/getNewRequest`, `/commandapi/api/orderGroups`, `/client/v2.0/.../dynamics`, `/md/v2/Clients/:ex/:portfolio/{stoporders,trades}`, `/md/v2/stats/:ex/:portfolio/*` | — |
| Health | `GET /health` | — |

**WebSocket (порт 3000, два endpoint'а):**

- `/ws` — **data feed**: Astras-стиль envelope `{opcode, guid, token, code, instrumentGroup, ...}`. Поддерживает opcodes:
  - `OrderBookGetAndSubscribe` (тема Bybit `orderbook.50.{symbol}` → ALOR snapshot+delta)
  - `BarsGetAndSubscribe` (тема `kline.{interval}.{symbol}`)
  - `QuotesSubscribe` (тема `tickers.{symbol}`)
  - `AllTradesSubscribe` (тема `publicTrade.{symbol}`)
  - `PositionsGetAndSubscribeV2`, `OrdersGetAndSubscribeV2`, `TradesGetAndSubscribeV2`, `SummariesGetAndSubscribeV2` (private темы `position`, `order`, `execution`, `wallet`)
  - `StopOrdersGetAndSubscribeV2`, `RisksGetAndSubscribeV2` (stub'ы — отдают пусто)
  - `unsubscribe` — корректно снимает подписку и декрементит refcount
  - `ping`/`pong` — keepalive
- `/cws` — **command channel**: те же envelope'ы, но opcodes:
  - `submit:Limit`, `submit:Market` → `/v5/order/create`
  - `delete:Limit`, `delete:Market`, `delete:StopMarket`, `delete:StopLimit` → `/v5/order/cancel` (с автоматическим lookup символа, если Astras не прислал)
  - `ping`, `authorize` (lifecycle, ack)

**WS-устойчивость:**

- `subscription-registry.ts`: один Astras-клиент держит много `guid`-keyed подписок через один socket; multiplex по `clientId+guid`; refcount по Bybit-теме (категория+topic) — Bybit-сторона действительно (un)subscribe'ится только когда счётчик достиг 0/1.
- На `socket.close` — `closeAllSubscriptionsForClient` возвращает orphaned subs (refcount → 0); вызывается `bybitUnsubscribeIfLast` для каждой, иначе на reconnect Astras Bybit отвергает дубль-subscribe с rejected promise (что раньше валило процесс).
- Все subscribe/unsubscribe обёрнуты в try/catch + `Promise.resolve(p).catch(...)`.
- Last-resort: `process.on('unhandledRejection', warn-only)` в `index.ts`.

**Конфигурация:**

- `bybit-adapter/.env` берёт ключи из `MM_BOT_BYBIT_DEMO_API_KEY` / `MM_BOT_BYBIT_DEMO_API_SECRET` (sync с `mm-bot/.env`)
- `caseSensitive: false` в Fastify — Astras местами пишет `/md/v2/Clients/...` с заглавной, местами с маленькой буквы
- CORS открыт на `http://localhost:4200`

### 1.2 astras-bybit-ui — Angular 21 fork (порт 4200)

Репозиторий: <https://github.com/anymasoft/astras-bybit-ui>, ветка `bybit-integration`, upstream `alor-broker/Astras-Trading-UI`.

**Что переделано:**

- `environment.ts`: все `*Url` указывают на `http://localhost:3000` (REST + WS).
- `src/main.ts` до bootstrap'а делает pre-seed `localStorage['sso'] = {refreshToken, jwt}` для обхода SSO redirect, и форсирует `localStorage['last-theme'] = 'default'`.
- **Светлая тема — в трёх местах**, иначе Astras возвращался в `dark`:
  - `src/app/shared/services/theme.service.ts:36,51,97` — fallback и ColorsMap default
  - `src/app/shared/utils/terminal-settings-helper.ts:28` — `designSettings.theme = ThemeType.default`
  - `src/app/modules/terminal-settings/components/general-settings-form/general-settings-form.component.ts:95` — form control default
  - **Прим.:** `darkThemeColorsMap$` на строке 47 theme.service.ts оставлен как `ThemeType.dark` — это правильно (он используется для загрузки `dark.css`, не как default).
- Husky pre-commit: lint + 820 unit-тестов + prod build (~60s, проходит).
- Прочих изменений в исходниках Astras практически нет — авторитетная переработка только настроек среды и тем, плюс корректное использование adapter'а на API-слое.

### 1.3 Запуск одной командой

Корневой `package.json` (mm-bot/):

```json
{
  "scripts": {
    "predev": "kill-port 3000 4200 || exit 0",
    "dev": "concurrently --names adapter,astras --prefix-colors green,cyan --kill-others-on-fail \"npm --prefix bybit-adapter run dev\" \"pnpm --dir astras-bybit-ui start\""
  },
  "devDependencies": { "concurrently": "^9.1.0", "kill-port": "^2.0.1" }
}
```

- Никаких отдельных PowerShell-окон — пользователь работает в терминале PyCharm.
- `predev` через `kill-port` чистит 3000 и 4200, чтобы не натыкаться на EADDRINUSE после хард-выхода.
- `--kill-others-on-fail` — если adapter упал, Astras-процесс гасится за компанию.

### 1.4 Post-Sprint-1 stability фиксы (сделаны после первого скрина пользователя)

**Коммит `c6331a9`** (bybit-adapter):
- Case-insensitive Fastify routing (`/Clients/` vs `/clients/`)
- Stubs для не-Bybit endpoints (releases, hyperion, treemap, cms, eslogs, time, dynamics, orderGroups, stoporders, trades, stats)
- WS robustness: orphaned subscription cleanup, ping/authorize handlers, unhandledRejection safety net

**Коммит `0ea97c45`** (astras-bybit-ui):
- Light-theme defaults в trех дополнительных местах (см. 1.2)

**Коммит `faa58e3`** (bybit-adapter, сегодняшний):
- `/hyperion` и `/news/graphql` теперь **парсят входящий GraphQL-запрос**, определяют root-поле (`instruments` / `bonds` / `news` / etc.), проверяют наличие `nodes`/`totalCount`/`pageInfo` в селекшене и возвращают валидный пустой connection-шейп `{nodes: [], totalCount: 0, pageInfo: {...}}` для коллекций или `null` для одиночных запросов. Это убрало бесконечный цикл крашей `MarketTrendsComponent` (`Cannot read properties of undefined (reading 'displayItems')`) — тысячи стектрейсов в минуту, которые тянули за собой всю change-detection.
- `/astras/rates/actions/getNewRequest` stub (FX rates poller).

---

## 2. Текущее состояние UI (по свежему скрину)

Скрин: **«Домашний» дашборд**, портфель `FORTS bybit_demo`, светлая тема.

### 2.1 Что работает

| Что | Статус | Деталь |
|---|---|---|
| Светлая тема | ✅ | Body `rgb(232,237,244)`, `last-theme=default` |
| Шапка | ✅ | Логотип A, «Виджеты», «+ Заявка», селектор портфеля `FORTS bybit_demo`, три таба дашбордов |
| Auth | ✅ | JWT с `portfolios: "bybit_demo"`, refresh на `/auth/actions/refresh` работает |
| Селектор портфеля | ✅ | Видит `bybit_demo` |
| Dashboard tabs | ✅ | «Домашний», «Торговля», «Лёгкий дашборд» переключаются |
| Ticker Ask | ✅ | `Ask: 78 217,1` — live WS `tickers.BTCUSDT` |
| Blotter | ✅ | Рендерит вкладки О портфеле / Заявки / Стопы / Позиции / Сделки / История сделок / Уведомления; «Сделок сегодня не было» — корректное пусто |
| Market Trends (Тенденции рынка) | ✅ (рендерится) | Показывает «Нет данных» (это правильно после fix Hyperion) |
| All-instruments (Карта рынка) | ✅ (рендерится) | Пустая (Hyperion → пусто) |
| WS reconnect | ✅ | В логах видны «cleaned subscriptions on disconnect» + «removed: 5» на дисконнекте и чистое восстановление подписок на новом соединении |

### 2.2 Что не работает / отсутствует

| Что | Где видно | Корневая причина |
|---|---|---|
| **Стакан (order-book)** | На дашборде «Домашний» нет такого виджета | Layout — не положен на главный дашборд; виджет в системе есть, в default-dashboards-config.json даже включён в другие табы (`Торговля`, `Лёгкий дашборд`), но реально не отрисовывается даже там |
| **Свечной график (light-chart)** | Левый верхний угол: пустая область, только иконка волнистой линии | WS `BarsGetAndSubscribe` либо не вызывается на этом виджете (no instrument link?), либо ticker→bars data flow не работает |
| **Свечной график (tech-chart)** | Не виден на «Домашнем» | Не на этом табе; нужен проверить рендер на «Торговля» |
| **Bid пустой** в форме ордера | Центр сверху: `Bid:` без числа, `Ask: 78 217,1` есть | `bybitTickerToAlor` — посмотреть, отдаёт ли `bid1Price` |
| **Цена в форме ордера = 0** | Поле «Цена» в форме лимитного ордера | Order form не привязана к стакану (без стакана нет источника clickable-цены) — а ручной ввод 0 не пройдёт validation |
| **«Карта рынка» (all-instruments)** пустая | Правый верхний угол | Hyperion GraphQL — у нас stub, real proxy нет |
| **«Тенденции рынка»** пустая | Правый нижний угол | Hyperion GraphQL — то же |
| **«Динамика по договору #BYBIT-DEMO»** пустой график | Левый нижний угол | `/dynamics` отдаёт `{portfolioValues: []}`, потому что Bybit не даёт исторический balance |
| **News widget** | Не виден на «Домашнем» | Не положен на этот таб (есть на «Торговле»); хоть и стабнут news/graphql, real данных нет |
| **Replace/Amend ордера** | Не тестировался | В command-handler.ts нет `update:Limit` opcode — Astras его шлёт при «передвинуть ордер», у нас не поддержано |
| **Stop-orders** | Стоп-приказы на blotter'е | `delete:StopLimit`/`StopMarket` есть, но **submit стоп-ордера** не реализован |

### 2.3 Из логов adapter'а на текущей сессии

```
[adapter] data WS client connected            ← Astras /ws
[adapter] command WS client connected         ← Astras /cws
[adapter] Subscribing to topics: tickers.BTCUSDT   ← QuotesSubscribe
[adapter] Subscribing to topics: order, position, wallet, execution  ← private
[adapter] cleaned subscriptions on disconnect, removed: 5            ← reconnect
[adapter] command WS client connected ...                            ← re-auth
```

**Чего нет в логах adapter'а** — и это диагностически важно:
- Нет `Subscribing to topics: kline.{interval}.BTCUSDT` ← **light-chart не подписывается на bars**
- Нет `Subscribing to topics: orderbook.50.BTCUSDT` ← **на дашборде нет активного order-book виджета**
- Нет `Subscribing to topics: publicTrade.BTCUSDT` ← all-trades виджета на дашборде нет

То есть **либо widget'ы не на дашборде, либо инструмент в них не выбран** (instrument link broken).

---

## 3. Корневые причины, объяснённые отдельно

### 3.1 Layout-долг (главное)

Дефолтный `astras-bybit-ui/src/assets/default-dashboards-config.json` унаследован от upstream Astras и оптимизирован под фондовый рынок MOEX: на главном дашборде стоят `light-chart`, `order-submit`, `treemap`, `portfolio-charts`, `blotter`, `market-trends`. Половина (treemap, market-trends, portfolio-charts) специфична для русского фондового рынка и без Hyperion/dynamics просто пуста. На другие табы заброшен стакан, tech-chart, news.

Для крипто-трейдинга нужен другой layout «Домашний» — например:

```
+---------------------+-------------------------+----------------+
|   tech-chart        |   instrument-info       |  order-book    |
|   (BTCUSDT, 5m)     |   (BTCUSDT)             |  (depth 50)    |
+---------------------+-------------------------+----------------+
|   order-submit      |   blotter (orders/      |  all-trades    |
|   (BTCUSDT)         |    positions/trades)    |  (BTCUSDT)     |
+---------------------+-------------------------+----------------+
|   portfolio-summary (wallet) + portfolio-charts (equity curve)  |
+-----------------------------------------------------------------+
```

Все эти виджеты в системе есть, но конфигурация в JSON не отражает crypto-кейс.

### 3.2 WS bars dataflow (для light-chart)

`light-chart` (Lightweight Charts) предполагает:
1. На init: REST `/md/v2/history?symbol=BTCUSDT&exchange=MOEX&tf=60&from=X&to=Y` → массив свечей
2. На live: WS `BarsGetAndSubscribe` с тем же символом и таймфреймом → инкрементальные обновления

В наших логах нет следов `BarsGetAndSubscribe`. Гипотезы:
- Виджет не получил selected instrument (Astras при первом запуске не имеет «активной бумаги» в widgetSettings, ждёт клика пользователя на инструмент). Раньше на MOEX был instrument-select с предзагруженным `SBER` или `IMOEX`. У нас селект пустой.
- Или сам виджет рендерится без instrumentKey, не подписывается, и просто молчит.

**Лекарство для Sprint 2:** дефолтный selected instrument = `BTCUSDT (linear)`, проставить в default-dashboards-config.json или в `instrument-select` widget defaults.

### 3.3 Bid в ticker'е

Bybit `/v5/market/tickers` отдаёт `bid1Price`, `ask1Price`, `lastPrice`, etc. WS `tickers.SYMBOL` — то же самое. Если в `bybitTickerToAlor` маппинг неполный, Astras видит только Ask. Файл: [src/bybit/transforms.ts](https://github.com/anymasoft/bybit-adapter/blob/main/src/bybit/transforms.ts). Нужен grep по `bid` / `bid_price`. Это 5-минутный фикс.

### 3.4 Hyperion GraphQL

Список виджетов, которые ходят на `/hyperion` (см. `astras-bybit-ui/src/app/.../queryForSchema<>`):

| Виджет | Использует |
|---|---|
| `all-instruments` (Карта рынка) | `instruments` connection |
| `market-trends` (Тенденции рынка) | `instruments` (filtered) |
| `bond-screener` | `bonds` connection |
| `info/stock-info`, `info/bond-info`, `info/derivative-info`, `info/common-info` | одиночные `instrument(symbol, exchange)` |
| `instruments/search-instrument-store` | `instruments` (search) |
| `nearest-trading-session` | `tradingSchedule` |

Это **значительный объём GraphQL surface'а**. ALOR-side это бэкенд под названием Hyperion с собственной схемой. На Bybit нет аналога. Варианты:
1. **Реализовать GraphQL-resolver слой в bybit-adapter** (Apollo Server + наши resolver'ы поверх Bybit REST). Сложно — нужно повторить ALOR-схему достаточно близко, чтобы Zod-валидация прошла.
2. **Подменить виджеты собственными** — переписать `all-instruments`, `market-trends` под прямой REST `/v5/market/instruments-info`.
3. **Не делать в Sprint 2**: оставить stub'ы, виджеты пустые. Фокус на тех виджетах, что реально нужны для трейдинга (chart, order-book, blotter, order-submit, wallet).

Рекомендую **вариант 3** для Sprint 2, **вариант 1** для Sprint 3.

### 3.5 Equity curve

Bybit отдаёт текущий `wallet-balance`, но НЕ исторические снимки. Чтобы Astras-виджет `portfolio-charts` («Динамика по договору») показал кривую, нужен self-recording: adapter каждые N секунд снимает баланс, кладёт в SQLite/локальный файл, отдаёт по `/client/v2.0/agreements/.../dynamics` массивом точек `{date, value}`. Это **отдельная подсистема** в adapter'е — ~150 строк кода + миграция. Sprint 3 candidate.

---

## 4. Что нужно увидеть пользователю (acceptance criteria)

Цитата пользователя:
> «я хочу увидеть реальные графики и потрогать реальный процесс трейдинга: операции с ордерами, выставление/передвижение/снятие/исполнение, увидеть депозит, увидеть график изменения депозита — в общем увидеть полноценный торговый терминал со всем функционалом»

Разложение:

| Требование | Что должно работать end-to-end |
|---|---|
| Реальные графики | `tech-chart` (TradingView, BTCUSDT, 5m/15m/1h/1d switchable) + `light-chart` (preview) — с историей и live updates |
| Стакан | `order-book` виджет, depth 50, bid/ask колонки, live updates, **клик по цене → подставляется в форму ордера** |
| Выставление ордера | Form open → ввод цены/qty → «Купить» → Bybit получает order → blotter «Заявки» показывает NEW |
| Передвижение (replace) | В blotter'е «Заявки» drag/edit цены/qty → adapter `update:Limit` → Bybit amend → blotter обновляется |
| Снятие (cancel) | Кнопка X на ряду заявки → adapter `delete:Limit` → Bybit cancel → ряд исчезает |
| Исполнение | Bybit fill → WS `execution` → blotter «Сделки» показывает trade, blotter «Позиции» обновляется, wallet balance меняется |
| Депозит | `portfolio-summary` виджет: показывает Equity / Available / Margin / UPnL живьём (есть, нужно убедиться в data flow) |
| График изменения депозита | `portfolio-charts` («Динамика по договору») с реальной кривой — требует equity recorder |
| Полноценный layout | Дашборд «Домашний» переделан под крипто-кейс, все виджеты на месте, с предзаполненным `BTCUSDT (linear)` |

---

## 5. Предложение Sprint 2 (для Opus — материал для промпта)

**Цель Sprint 2:** «пользователь видит полный цикл одного ордера на BTCUSDT, от выставления до исполнения, в полноценном крипто-дашборде».

### 5.1 Эпики

**Эпик A — Crypto-first layout** (без этого все остальные правки не видны)
- Создать новый `default-dashboards-config.json` для дашборда «Домашний», ориентированный на крипту: tech-chart + order-book + order-submit + blotter + portfolio-summary + portfolio-charts
- Дефолтный selected instrument = `BTCUSDT (linear)`, простанавливается через instrument-select или в initial widget settings
- Удалить или скрыть MOEX-специфичные виджеты (treemap, market-trends, news) с главного таба
- Acceptance: при первом открытии страницы — все ключевые виджеты с данными, без необходимости что-то кликать

**Эпик B — Light-chart / Tech-chart data flow**
- Найти, почему light-chart не делает `BarsGetAndSubscribe` (instrument link broken? пустой widgetSettings.instrumentKey?)
- Проверить REST `/md/v2/history` шейп — ALOR ждёт массив `[{open, high, low, close, volume, time}]`; убедиться что `bybitKlineToAlorBar` корректен
- Tech-chart использует TradingView Charting Library (не Lightweight) — он мог затребовать datafeed-протокол; проверить, что наш `/md/v2/history` отвечает на параметры `from`/`to`/`resolution` правильно
- Acceptance: оба графика рендерят свечи BTCUSDT за последние 24 часа, и тикают в реальном времени

**Эпик C — Order book**
- Положить виджет на дашборд (см. эпик A)
- Проверить, что `OrderBookGetAndSubscribe` доставляет snapshot + delta правильной структуры (`bids: [[price, qty], ...]`, `asks: [...]`)
- Реализовать click-to-fill: клик по цене стакана → копия в форму ордера (это уже встроено в Astras, должно заработать само если виджеты на одном дашборде с одинаковым instrumentKey)
- Acceptance: видна глубина 50, числа обновляются live, клик по уровню заполняет форму ордера

**Эпик D — Bid в ticker'е**
- Найти `bybitTickerToAlor` в adapter'е (`src/bybit/transforms.ts`)
- Добавить мап `bid1Price → bid` и `ask1Price → ask` если их сейчас нет
- Acceptance: в форме ордера видны оба числа Bid/Ask

**Эпик E — Order lifecycle complete**
- Реализовать `update:Limit` opcode в cws (`POST /v5/order/amend`)
- Astras присылает `{opcode: "update:Limit", guid, orderId, quantity, price}` — adapter маппит на amend
- Реализовать `submit:StopLimit`, `submit:StopMarket` (через Bybit `/v5/order/create` с `triggerPrice` + `triggerBy`)
- Проверить WS `order` стрим: NEW → PARTIALLY_FILLED → FILLED события доходят до Astras blotter'а
- Проверить WS `execution` стрим: индивидуальные trade'ы попадают в «Сделки» вкладку
- Acceptance: можно открыть → подвинуть → закрыть лимитку, видя каждое изменение в blotter'е

**Эпик F — Portfolio data live**
- Убедиться, что WS `wallet` обновляет equity/available margin в `portfolio-summary` после fill ордера
- Убедиться, что WS `position` обновляет open positions
- (опционально, если останется время) — Equity curve recorder: в adapter'е cron каждые 60s снимает balance, пишет в SQLite, отдаёт по `/dynamics`. Если не успеваем — оставить пустой график со скелетоном.

### 5.2 Что **не** делаем в Sprint 2

- Hyperion GraphQL real proxy — оставляем stubs (виджеты Карта рынка / Тенденции / Инфо пустые)
- News feed — оставляем пустой
- Mobile dashboard — не трогаем
- Tauri 2.0 desktop wrapper — Sprint 4

### 5.3 Definition of Done

1. `npm run dev` → открыть http://localhost:4200 → видеть дашборд «Домашний» с tech-chart (live свечи), order-book (live глубина), order-submit (с Bid и Ask), blotter (orders/positions/trades таб'ы)
2. Выставить лимитную заявку BTCUSDT через форму → видеть её в blotter «Заявки» со статусом NEW
3. Подвинуть заявку (edit цены) → видеть обновлённую цену в blotter
4. Отменить заявку → ряд исчезает
5. Выставить маркет-ордер → видеть fill в «Сделках», открытая позиция в «Позициях», изменение баланса в portfolio-summary
6. Светлая тема сохраняется
7. Adapter переживает 10+ Astras-reconnect'ов без unhandled rejection
8. Husky pre-commit в astras-bybit-ui проходит (820 тестов)
9. Скриншот дашборда коммитится в `docs/sprint_reports/sprint_2_screenshot.png`

### 5.4 Sprint 3 candidates (на потом)

- Hyperion GraphQL resolver слой → реальные данные для Карта рынка / Тенденции / Инфо
- News feed (CryptoPanic / CoinGecko)
- Equity curve recorder + Динамика по договору
- Multi-instrument support (ETH, SOL и т.д.) — Astras работает с одним выбранным инструментом за раз, но instrument-select widget должен корректно искать в Bybit symbols list
- Push-уведомления при fill ордера
- Hotkeys для скоростного трейдинга

### 5.5 Sprint 4 candidates

- Tauri 2.0 desktop wrapper (есть в memory под `project_ui_stack`)
- CI/CD (GitHub Actions), Docker, helm
- Audit log всех операций adapter'а в SQLite
- Robust reconnect: backoff, queue, replay missed events

---

## 6. Открытые вопросы для Opus

1. **Где жить custom default-dashboards-config?** Если редактировать `astras-bybit-ui/src/assets/default-dashboards-config.json` напрямую — это конфликтует с upstream merges. Альтернатива: оверрайд в adapter'е через `/identity/v5/UserSettings` (написать туда дефолтную конфигурацию дашбордов для нового пользователя). Что выбрать?

2. **Реальное демо или Testnet?** Сейчас работаем с Bybit Demo (`MM_BOT_BYBIT_ENV=demo`). На Demo есть лимиты на orderbook depth (?) и нет некоторых WS-тем. Стоит ли в Sprint 2 переехать на Testnet или оставаться на Demo?

3. **Что считать «реальный график»?** Light-chart (Lightweight Charts) — это TradingView preview, минимальный. Tech-chart — это полноценный TradingView Chart Library с индикаторами. Какой из них приоритет?

4. **Replace/Amend семантика.** Astras при «передвинуть ордер» может слать `update:Limit` или может слать `delete + submit` под капотом. Нужно посмотреть, что именно Astras делает в этом сценарии — возможно достаточно `delete + submit`, и `update` не нужен.

5. **Hyperion vs. direct REST.** Часть виджетов (`instruments search` в шапке) — критичны для UX (как искать BTCUSDT, если не знаешь точное имя). Их вынести с GraphQL на прямой REST в Sprint 2, или подождать Sprint 3 с полным GraphQL proxy?

---

## 7. Артефакты / ссылки

- **bybit-adapter repo:** https://github.com/anymasoft/bybit-adapter
  - Последний релевантный коммит: `faa58e3 Make Hyperion/news GraphQL stubs return valid empty shapes`
- **astras-bybit-ui repo:** https://github.com/anymasoft/astras-bybit-ui (ветка `bybit-integration`)
  - Последний коммит: `0ea97c45 Light-theme defaults in 3 more places`
- **mm-bot wrapper repo:** https://github.com/anymasoft/mm-bot (root с `package.json` для one-command launch)
- **Скриншоты:**
  - `screenshots/2026-05-17_dashboard_after_hyperion_fix.png` — текущее состояние (TODO: положить пользователю)
  - `screenshots/2026-05-17_logs_console.txt` — логи браузера (есть как `Логи браузера.txt` в корне)
- **Запуск:** `cd C:\BUFFER\mm-bot && npm run dev` → http://localhost:4200
- **Auth для дебага:** localStorage уже preseed'ится `main.ts`, никаких ручных шагов не нужно
- **Sprint 1 предыдущий отчёт:** [docs/sprint_reports/sprint_1_report.md](./sprint_1_report.md) (изначальный MVP)

---

## 8. Что я (Sonnet) могу сделать БЕЗ архитектора

Если Opus решит, что Sprint 2 готовится отдельно (через дополнительное проектирование), а у меня есть свободное время, могу **сразу** взяться за:

1. **Эпик D (Bid в ticker'е)** — 5 минут, конкретный fix в одном файле
2. **Эпик A part 1 (default instrument)** — проставить `BTCUSDT` как default selected instrument в новый user, через user-settings broker или в initial-state дашборда
3. **Эпик B диагностика** — почему light-chart не делает BarsGetAndSubscribe. Воспроизвести через Claude_Preview MCP, поймать в network.

Это «безопасные» правки, которые не пересекаются с архитектурными решениями Sprint 2.

Жду решения архитектора.
