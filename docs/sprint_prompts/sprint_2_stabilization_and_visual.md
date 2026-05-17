# Sprint 2: Стабилизация Sprint 1 — реальный visual control над торговлей

## Контекст для Claude Code

Sprint 1 завершён частично: bybit-adapter и astras-bybit-ui подключены, REST endpoints работают, форма ордера функционирует, ticker отображает Ask. **НО** есть критичные blocking issues, которые не дают пользователю реально "видеть торговлю глазами":

1. **WebSocket pong timeouts** в Bybit connections каждые ~30 секунд (из логов adapter) — это сносит все live данные
2. **Нет графика** — пользователь не видит движения цены
3. **Нет стакана** (Order Book widget) — пользователь не видит куда упадёт его ордер
4. **Bid пустой** в ticker (только Ask)
5. **Цена в форме ордера = 0** — не подставляется текущая рыночная
6. **Crypto-first layout отсутствует** — дашборд оптимизирован под MOEX (FORTS, акции), не под крипту

Цель Sprint 2: **превратить технически работающий MVP в реальный инструмент visual trading**. По итогу — пользователь открывает Astras, видит график BTCUSDT с свечами, стакан с уровнями, размещает лимитный ордер кликом по уровню стакана, видит свой ордер в стакане как horizontal line на графике, видит изменение баланса при fill.

## КРИТИЧНОЕ ПРАВИЛО ПРОЕКТА: 100% Open Source

**Это hard constraint, зафиксированный в project memory.** Любая рекомендация инструментов / библиотек / сервисов проходит через этот фильтр первым:

- ✅ **ALLOWED:** OSI-approved licenses (MIT, Apache-2.0, BSD, GPL, LGPL, AGPL, MPL) без оговорок типа Commons Clause
- ❌ **BLOCKED:** proprietary, freemium, "free for non-commercial", "free with application", trial-period, SaaS-locked, anything requiring approval from third party

**Это включает в себя `TradingView Charting Library`** (proprietary, требует application — НЕ используем).

**Lightweight Charts от того же TradingView — это другой продукт, Apache-2.0 OSS, доступен через `npm install lightweight-charts` без application — используем.**

Если возникает соблазн "ну это же бесплатно для personal use" — это НЕ OSS, выкидываем без обсуждения.

## Архитектурные решения от архитектора (RESOLVED)

| # | Вопрос | Решение |
|---|--------|---------|
| 1 | Layout: UserSettings vs JSON | **JSON в repo** (`src/assets/dashboards/crypto-default.json` или аналог), версионируется в git |
| 2 | Demo vs Testnet | **Demo** (остаёмся, реальные рыночные данные + виртуальные деньги) |
| 3 | Charting library | **Только Lightweight Charts (Apache-2.0)** — уже в deps Astras. Indicators реализуем через `technicalindicators` (MIT, npm). TradingView Charting Library НЕ используем (proprietary). |
| 4 | Order amend semantics | **Bybit native `POST /v5/order/amend`** (priority preservation), cancel+new только как fallback с warning |
| 5 | Hyperion vs direct REST | **Direct REST + memory cache в adapter** (полный список instruments при старте, TTL 1 час) |

## Hotfix предсопроводительный (до Sprint 2 главных задач)

Три безопасные правки которые делаются первым коммитом перед основной работой Sprint 2:

### Hotfix 1: Bid в ticker

В `bybit-adapter/src/translators/ticker.ts` (точный путь может отличаться):

Добавить в маппинг Bybit V5 ticker response → ALOR quote:
- `bid1Price` (Bybit) → `bid` (ALOR)
- `bid1Size` (Bybit) → `bidVolume` (ALOR)

После hotfix ticker в UI должен показывать и Bid и Ask.

### Hotfix 2: Default instrument BTCUSDT

В `astras-bybit-ui` найти где задаётся startup default symbol (вероятно в dashboard config или auth response). Сделать так чтобы при первом входе пользователя BTCUSDT был автоматически выбран в Watchlist + во всех виджетах которые требуют instrument selection.

### Hotfix 3: Диагностика chart data flow

Открыть Astras в Chrome DevTools → Network tab → отфильтровать WS, проверить какие subscribe messages отправляет frontend при открытии chart widget, какие данные получает в ответ. Записать findings в `mm-bot/docs/sprint_reports/sprint_2_chart_diagnostics.md` — это будет основа для Epic B (Charts) в основной части Sprint 2.

**Hotfix коммитится отдельным commit перед основной работой Sprint 2**, чтобы можно было откатить независимо.

## Epic 0 (CRITICAL): WebSocket stability в bybit-adapter

### Проблема

В логах adapter регулярно видно:
```
'Pong timeout - closing socket to reconnect',
{ category: 'bybit-ws', wsKey: 'v5Private', reason: 'Pong timeout' }
```

Это происходит для **обоих** WS connections (private и public) каждые ~30 секунд. Frontend получает прерывистые данные → нет live updates → UI выглядит сломанным.

### Решение

1. Открыть `bybit-adapter/src/bybit/ws-public.ts` и `ws-private.ts`
2. Проверить настройки `WSClient` из `bybit-api` библиотеки (это MIT-licensed OSS пакет — OK)
3. Явно установить `pingInterval` в 15000-18000ms (по умолчанию может быть 25000ms что близко к Bybit's 20s pong timeout — нужен запас)
4. Опционально установить `pongTimeout` в 10000ms (даём время на network roundtrip)

Пример (точный синтаксис проверить в docs `bybit-api`):
```typescript
const ws = new WebsocketClient({
  market: 'v5',
  testnet: false,
  demoTrading: true,
  pingInterval: 15000,  // ping every 15s, Bybit requires <20s
  pongTimeout: 10000,   // wait 10s for pong response
});
```

### Acceptance

После hotfix WS — в логах adapter **НЕТ** строк `Pong timeout - closing socket` в течение 1 часа непрерывной работы. Frontend получает непрерывные ticker updates без gaps.

## Epic A: Crypto-first дашборд layout

### Проблема

Текущий default layout от ALOR оптимизирован под MOEX (FORTS, акции, новости РФ). На скриншоте видно много пустого пространства, нет стакана и графика на видимом дашборде, "Карта рынка" виджет существует но пустой, "Тенденции рынка" — нет данных.

### Решение

Создать новый default dashboard для криптовалют. Точное расположение JSON-файлов с layout зависит от структуры Astras — найти существующие dashboard configs и создать новый по их шаблону.

**Layout proposal** (logical):

```
┌─────────────────────────────────────────────────────────────┐
│  Header: BTCUSDT Ticker + Account Selector (bybit_demo)    │
├──────────────────────────┬──────────────────────────────────┤
│                          │                                  │
│      Chart               │      Order Book (DOM)            │
│      BTCUSDT             │      BTCUSDT                     │
│      (50% width)         │      (25% width)                 │
│      (60% height)        │      (60% height)                │
│                          │                                  │
├──────────────────────────┤      Order Form                  │
│                          │      (Limit/Market/Stop)         │
│      Equity Curve        │      (25% width)                 │
│      (50% width)         │      (60% height)                │
│      (40% height)        │                                  │
├──────────────────────────┴──────────────────────────────────┤
│                                                              │
│         Blotter (Orders / Positions / Trades / History)     │
│         (100% width, 40% height)                            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

Конкретные widget IDs и dimensions проверить через существующие dashboard configs Astras. Tab name: "Crypto" или "Криптовалюты".

### Acceptance

- При первом запуске Astras default tab = новый Crypto dashboard
- Chart BTCUSDT занимает левую верхнюю четверть, виден с свечами
- Order Book BTCUSDT занимает правый верхний угол, видны bids/asks live
- Order Form под Order Book, видны кнопки Купить/Продать
- Equity Curve слева снизу (пока может быть пустой если equity recorder не готов)
- Blotter снизу полная ширина
- Старый ALOR dashboard "Домашний" остаётся доступным через переключатель табов (не удалять)

## Epic B: Chart с live данными на Lightweight Charts (Apache-2.0)

### Контекст и стек

`Lightweight Charts` (Apache-2.0, npm пакет `lightweight-charts`) — единственный charting backend в этом проекте. Это OSS библиотека от TradingView, **не путать** с их proprietary `TradingView Charting Library`. Lightweight Charts уже в deps `astras-bybit-ui`.

Indicators реализуем через **`technicalindicators`** (MIT license, npm пакет `technicalindicators`) — 100+ готовых индикаторов на TypeScript.

### Чек реальной charting инфраструктуры в Astras

Перед началом работы — проверить какой chart widget в Astras сейчас реально работает:

```bash
cd astras-bybit-ui
grep -r "lightweight-charts" src/ --include="*.ts"
grep -r "tech-chart" src/ --include="*.ts"
grep -r "light-chart" src/ --include="*.ts"
grep -r "tradingview" src/ --include="*.ts" -i
grep -r "charting_library" src/ --include="*.ts" -i
```

Astras имеет несколько chart widget'ов в разных feature modules. Найти ту что использует **lightweight-charts**, и работать с ней. Если есть widget использующий external proprietary TradingView Charting Library — этот widget мы **НЕ используем** (отключить, удалить или скрыть).

### Datafeed реализация

В `bybit-adapter` реализовать:

1. **Historical klines REST endpoint** (для initial chart load):
   - ALOR endpoint: `GET /md/v2/history` (точный path проверить в audit'е Sprint 1)
   - Маппинг на Bybit V5: `GET /v5/market/kline`
   - Параметры: symbol, interval (1m/5m/15m/1h/4h/1d), start, end, limit
   - Translator: Bybit kline array → ALOR bar format

2. **Live klines WS subscription**:
   - ALOR opcode: `BarsGetAndSubscribe` (точный имя проверить в audit'е)
   - Bybit V5 WS topic: `kline.<interval>.<symbol>`
   - При получении update — translate и broadcast frontend через WS

### Indicators implementation

В `astras-bybit-ui` после установки `technicalindicators`:

```bash
cd astras-bybit-ui
pnpm add technicalindicators
```

**Перед установкой проверить license:**
```bash
npm view technicalindicators license
# Должно вернуть "MIT" — OK
```

Реализовать minimum 5 индикаторов через `technicalindicators`:
- **SMA** (Simple Moving Average) — period 20
- **EMA** (Exponential Moving Average) — period 50
- **BB** (Bollinger Bands) — period 20, stdDev 2
- **RSI** (Relative Strength Index) — period 14
- **ATR** (Average True Range) — period 14 — **критично для Avellaneda-Stoikov визуализации**

Каждый indicator рассчитывается из тех же kline данных что и chart, рендерится через Lightweight Charts API:
- SMA/EMA/BB — line series поверх candles
- RSI — separate panel под price chart
- ATR — separate panel или text label

Документация `technicalindicators`: https://github.com/anandanand84/technicalindicators (MIT)

Примеры использования простые:
```typescript
import { SMA, RSI, BollingerBands, ATR } from 'technicalindicators';

const closes = klines.map(k => k.close);
const smaValues = SMA.calculate({ period: 20, values: closes });
```

### Multi-timeframe support

Switch между 1m, 5m, 15m, 1h, 4h, 1d через UI. Каждое переключение — новый history fetch + новая WS subscription с другим interval.

### Acceptance

- Открыв Astras, в Chart виджете для BTCUSDT видны свечи (минимум 100 баров)
- При смене timeframe (1m → 5m → 15m → 1h) график перерисовывается
- Последняя свеча обновляется в реальном времени (текущая цена меняется визуально)
- Минимум 5 индикаторов работают: SMA, EMA, BB, RSI, ATR
- Индикаторы переключаются через UI (toggle on/off)
- Chart использует **только** `lightweight-charts`, **не** `TradingView Charting Library` — это проверяемо: в `astras-bybit-ui/package.json` нет `@tradingview/charting_library`, нет ссылок на их CDN в `index.html` или `angular.json`

## Epic C: Order Book на дашборде + click-to-fill

### Проблема

Нет видимого Order Book widget на скриншоте. Это самое критичное для market making — без стакана нельзя понять где размещать ордер.

### Решение

**Шаг 1: Order Book widget существует в Astras** (`scalper-order-book` модуль или похожий). Проверить:
- Какой WS subscription он использует (вероятно `OrderBookGetAndSubscribe` или аналог)
- Какой формат ожидает

**Шаг 2: Adapter implementation**

Реализовать в `bybit-adapter`:
- WS `OrderBookGetAndSubscribe` маппинг на Bybit V5 WS `orderbook.<depth>.<symbol>` (depth=50)
- Translator Bybit OB updates → ALOR format
- Корректная обработка snapshot vs delta updates (Bybit V5 шлёт snapshot первым, потом delta)

**Шаг 3: Click-to-fill**

В Astras Order Book widget уже есть фича "click на price level → подставить в Order Form". Это standard функционал для scalper-order-book module. Нужно убедиться что:
- Клик по bid цене → заполняет price в Order Form, side = Sell (продажа в bid)
- Клик по ask цене → заполняет price в Order Form, side = Buy (покупка в ask)
- Quantity подставляется из текущего значения формы (или default 0.001 BTC)

Это уже implemented в frontend, важно только чтобы adapter правильно поставлял данные.

### Acceptance

- Order Book widget виден на crypto dashboard, показывает live стакан BTCUSDT
- Snapshot + delta updates работают (стакан "дышит" в реальном времени)
- Глубина минимум 25 уровней с каждой стороны
- Total volume и cumulative sum корректные
- Click по цене в стакане → автозаполнение в Order Form
- Свой размещённый ордер visually подсвечивается в стакане (Astras обычно делает highlight своих заявок)

## Epic D: Auto-fill цены в Order Form

### Проблема

На скриншоте Order Form показывает цену = 0. Это означает что при выборе инструмента или открытии формы текущая цена не подставляется автоматически.

### Решение

В `astras-bybit-ui` найти Order Form component. Логика должна быть:
- При смене instrument → подписаться на его ticker
- При получении первого ticker update → если price field пустой/0 → подставить best ask (для Buy) или best bid (для Sell)
- При смене side (Buy/Sell) → обновить price на соответствующий side (только если пользователь не вводил вручную)

Этот функционал может уже быть в Astras но broken из-за того что ticker от Bybit неполный (см. Hotfix 1).

### Acceptance

- При открытии Order Form → цена автоматически = Ask для Buy, Bid для Sell
- Цена обновляется при смене side
- Если пользователь начал вводить цену вручную → автообновление отключается
- Кол-во лотов default = минимально допустимое для BTCUSDT (например 0.001 BTC)

## Epic E: Order lifecycle полный

### Проблема

В Sprint 1 был только place + cancel. Не было amend/replace, не было stop orders, не было proper fill notifications.

### Решение

**Place order** (уже работает, проверить):
- Limit ✓
- Market — добавить если не было
- Stop-loss и Take-profit — добавить mapping на Bybit `triggerPrice` + `stopOrderType`

**Amend / Replace order:**
- Adapter принимает ALOR replace request
- Маппит в Bybit V5 `POST /v5/order/amend`
- Если Bybit Amend отказывает (например change > allowed) — fallback на cancel + new + warning в logs
- Frontend в Working Orders таблице → правый клик → Modify → меняем price → подтверждение → новая цена через amend

**Cancel order** (уже работает, проверить):
- Single cancel ✓
- Cancel all (одной кнопкой все ордера по символу или вообще все)

**Fill notifications:**
- WS subscription на executions (private feed)
- При fill → trigger event в frontend → blotter "Сделки" tab обновляется → optional toast notification

### Acceptance

- Limit + Market + Stop ордера размещаются через UI
- Existing limit order можно изменить (move/resize) через UI
- В стакане visually видно что ордер перемещается (если amend сохраняет priority)
- При fill — сделка появляется в blotter "Сделки" tab в реальном времени
- При fill — баланс в Account Manager обновляется (через wallet WS feed)

## Epic F: Live данные портфеля + (опционально) Equity Recorder

### Проблема

На скриншоте "Динамика по договору #BYBIT-DEMO" пустой график. Это equity curve которая должна показывать изменение баланса со временем.

### Решение

**Шаг 1: Live portfolio data**

Реализовать в `bybit-adapter`:
- WS subscription на Bybit `wallet` topic (private feed)
- При получении wallet update → broadcast frontend через `SummariesGetAndSubscribe` (или аналог в ALOR format)
- Frontend Account Manager обновляет баланс / equity / available margin в реальном времени

**Шаг 2: Equity Recorder (опционально)**

Astras frontend ожидает historical equity data для графика. У Bybit нет native endpoint "equity history" — нужно строить самим.

Опция простая: каждые 60 секунд adapter снимает snapshot total equity (из wallet WS) и записывает в локальный SQLite файл `bybit-adapter/data/equity.db`. ALOR endpoint для equity history маппится на чтение из этой DB.

Этот module — **опциональный** для Sprint 2, можно сделать в Sprint 3 если не хватает времени. Главное чтобы live balance работал.

SQLite через `better-sqlite3` (MIT licensed npm пакет — OK для OSS constraint). Перед установкой:
```bash
npm view better-sqlite3 license
# Должно вернуть "MIT" — OK
```

### Acceptance

- В Account Manager баланс / available / used margin обновляются в реальном времени
- При размещении ордера → used margin увеличивается
- При отмене → возвращается
- При fill → реализованная P&L обновляется
- (Опционально) Equity curve показывает динамику последних 24 часов

## Что НЕ делаем в Sprint 2

- Hyperion full proxy (используем только direct REST + cache, остальное stubs)
- News widget (нет equivalent в Bybit, оставим заглушку)
- Mobile / responsive layout
- Tauri desktop wrap (Sprint 3 после стабилизации web версии)
- Multi-account support (Sprint 5+)
- ALOR fallback для MOEX торговли (dormant, не trogamem)
- Hummingbot integration (Sprint 4-5)
- Backtest module
- Authentication production-grade (Sprint 3-4)
- **TradingView Charting Library в любой форме** (proprietary, нарушает OSS constraint)
- **Любые non-OSS dependencies** — если возникнет искушение `npm install` чего-то не OSS — записать в open questions, не ставить

## Definition of Done для Sprint 2

Acceptance criteria для финального коммита:

1. **WS stability**: 1 час непрерывной работы без `Pong timeout` в логах adapter
2. **Hotfixes**: Bid в ticker есть, default instrument BTCUSDT, chart data flow продиагностирован
3. **Layout**: Открыв Astras default tab = Crypto dashboard с правильной структурой widgets
4. **Chart**: BTCUSDT свечи на `lightweight-charts`, обновляются live, минимум 3 timeframes работают, 5 indicators реализованы через `technicalindicators`
5. **Order Book**: live стакан BTCUSDT с глубиной 25+, click-to-fill работает
6. **Order Form**: автозаполнение цены, все order types (limit/market/stop) работают
7. **Order lifecycle**: place, amend (preserve priority), cancel, fill notifications работают
8. **Portfolio**: balance/margin обновляются в реальном времени при ордерах и fills
9. **Скриншоты**: minimum 8 скриншотов нового layout с разными сценариями в `mm-bot/screenshots/sprint_2_*`
10. **OSS compliance audit**: в `astras-bybit-ui/package.json` и `bybit-adapter/package.json` все зависимости — OSI-approved licenses. Никаких `@tradingview/charting_library`, никаких proprietary chart libraries. Записать audit в `mm-bot/docs/sprint_reports/sprint_2_oss_audit.md` со списком всех new dependencies и их лицензий.

    Формат audit'а:
    ```markdown
    | Package | Version | License | Where added | OK? |
    |---------|---------|---------|-------------|-----|
    | technicalindicators | 3.x | MIT | astras-bybit-ui | ✅ |
    | better-sqlite3 | 11.x | MIT | bybit-adapter | ✅ |
    | ... | ... | ... | ... | ... |
    ```
11. **Все три репо** на GitHub обновлены, отчёт `sprint_2_report.md` создан

## Расчётный timeline

10-15 рабочих дней full-time. Возможные ускорения:
- Lightweight Charts проще proprietary TradingView lib — меньше API surface, быстрее освоить
- `technicalindicators` имеет ready-to-use API — каждый indicator implementation 10-30 строк
- Если scalper-order-book module Astras tested — click-to-fill готовый

Возможные тормоза:
- WS pong timeout фикс может оказаться сложнее чем кажется (например проблема в network между WSL и Windows)
- Если в Astras нет ready widget на lightweight-charts — придётся писать с нуля
- Order amend семантика может расходиться между ALOR и Bybit больше чем ожидаем

## Workflow

1. Прочитать этот промпт целиком
2. Положить копию в `mm-bot/docs/sprint_prompts/sprint_2_stabilization_and_visual.md`
3. Сначала Hotfixes (отдельный commit "Sprint 2 hotfixes")
4. Потом Epic 0 (WS stability) — критично
5. Epic A, B, C, D, E, F в любом порядке но **A (layout) и B (chart) должны идти параллельно** — без layout chart негде показать
6. После каждого Epic — micro commit с описанием в conventional commits style
7. По завершении всех Epic — OSS audit (Definition of Done #10)
8. Финальный sprint_2_report.md
9. Push во все три репо
10. URLs последних коммитов в чат архитектору

## Замечания для Claude Code

1. **WS pong fix — приоритет №1.** Без него остальные эпики не имеют смысла, потому что данные обрываются.

2. **100% OSS constraint — фильтр первого порядка.** Перед `npm install` любого нового пакета — проверить license:
   ```bash
   npm view <package> license
   ```
   Если ответ:
   - MIT / Apache-2.0 / BSD / ISC / MPL / GPL / LGPL — OK
   - "SEE LICENSE IN ..." — прочитать вручную, если OSS — OK
   - "UNLICENSED" / "Custom" / "Commercial" — НЕ ставить, искать альтернативу
   - "Commons Clause" в условиях — НЕ ставить
   
   Записать каждую новую зависимость с её license в sprint_2_oss_audit.md.

3. **Не пытайся переписать всё с нуля.** Astras уже имеет 36 feature-модулей. Большинство фичей будут работать с минимальными изменениями в backend (adapter). Концентрация — на backend mapping, не на frontend refactoring.

4. **MOEX-specific код не удалять.** Просто скрыть из default UI / отключить через config. Dormant функционал для будущего ALOR подключения.

5. **Скриншоты обязательны.** После каждого Epic — скриншот результата. Это primary способ архитектора оценить прогресс.

6. **WebSocket multiplexing.** Если в Sprint 1 это было упрощено — сейчас должно работать корректно, потому что без него Order Book + Chart + Ticker одновременно не будут работать.

7. **TypeScript types для translators.** Все ALOR contracts должны быть TypeScript интерфейсами в `bybit-adapter/src/alor/types.ts`. Никаких `any`.

8. **Если найдёшь endpoint которого нет в adapter но нужен frontend** — реализовать с минимальной заглушкой или TODO comment. Записать в sprint_2_report.md.

9. **Tests** — минимум для критичных translators (orderbook, ticker, candles, order). Не нужно 100% coverage, фокус на correctness mapping.

10. **Не запускать Hummingbot.** Он установлен в WSL, но мы его не используем до Sprint 4-5.

11. **Если в Astras найдётся chart widget на proprietary TradingView Charting Library** — отключить, не использовать. Работать только с widget'ами на Lightweight Charts. Если ни одного widget на Lightweight Charts нет — создать новый minimal widget в `astras-bybit-ui` с нуля используя `lightweight-charts` npm пакет.

12. **Никаких "временных решений" с proprietary libs.** Если упрёшься в любую функциональность которая в Astras сделана через proprietary компонент — НЕ использовать proprietary как stopgap. Лучше disabled widget со stub, чем working widget на proprietary стеке.

## Открытые вопросы которые могут возникнуть

Если возникнут вопросы которые не покрыты этим промптом — записать в `sprint_2_report.md` секцию "Открытые вопросы" с конкретикой что нужно решить. Не пытаться решить самостоятельно архитектурные вопросы — записать и продолжить с тем что можно сделать.

Особенно записать если:
- Любая зависимость, которую хочется поставить, имеет non-OSS license
- В Astras найден функционал привязанный к proprietary TradingView Charting Library
- ALOR API контракт оказался слишком сложным для прямой трансляции в Bybit V5
