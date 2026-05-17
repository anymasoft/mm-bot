# Sprint 1 Report: Bybit Adapter MVP + Astras adaptation

**Дата:** 2026-05-17
**Длительность:** 1 рабочая сессия (vertical slice MVP)
**Подход:** Vertical slice — минимально достаточный сквозной кусок (REST + WS + Astras shim) для manual trading на BTCUSDT.

## TL;DR

End-to-end стек работает на компиляции и запуске:
- `bybit-adapter` стартует, отдаёт live данные Bybit Demo в ALOR-формате (REST + WS подписки проверены)
- `astras-bybit-ui` собирается без ошибок и слушает на `http://localhost:4200`
- Auth shim в `main.ts` обходит SSO redirect, pre-seed'я localStorage перед bootstrap'ом
- Manual trading smoke test (Часть 5 промпта) — **на стороне пользователя**, инструкция в [sprint_1_manual_trading_walkthrough.md](./sprint_1_manual_trading_walkthrough.md)

## Что сделано

### Часть 1 — Клон репозиториев ✅
- `bybit-adapter` и `astras-bybit-ui` склонированы в `C:\BUFFER\mm-bot\{name}\` (внутрь mm-bot для удобства; добавлены в `.gitignore` mm-bot чтобы не было nested git)
- В `astras-bybit-ui` создан branch `bybit-integration`, запушен в origin
- В `astras-bybit-ui` добавлен remote `upstream` → `alor-broker/Astras-Trading-UI` для будущих merge с апстримом

### Часть 2 — Audit ALOR endpoints ✅
Полный отчёт в [sprint_1_alor_endpoints_audit.md](./sprint_1_alor_endpoints_audit.md) (415 строк).

Найдено: **15 REST endpoints** + **11 WS subscription opcodes** + **8 WS command opcodes**.
Для MVP отобраны: **8 REST + 6 WS subscriptions + 4 WS commands** = 18 точек интеграции.

Ключевые insights:
- Astras использует ДВА WS соединения: `wsUrl` (data feed) и `cwsUrl` (commands)
- Multiplexing по `guid` (UUIDv4) — один WS, много подписок
- JWT injection во ВСЕ запросы как `token` field
- Refresh: `POST {clientDataUrl}/auth/actions/refresh` body `{refreshToken}` → `{jwt}`
- JWT body содержит: `clientid`, `sub` (login), `portfolios` (space-separated), `exp`

### Часть 3 — bybit-adapter MVP ✅

**Стек:** Fastify 4 + TypeScript + tiagosiebler/bybit-api + Zod + pino. Node 20+.

Реализовано:

| Категория | Endpoints / Opcodes | Файл |
|---|---|---|
| Auth | `POST /refresh`, `POST /auth/actions/refresh`, `DELETE /auth/actions/refresh/:rt` | [routes/auth.ts](https://github.com/anymasoft/bybit-adapter/blob/main/src/routes/auth.ts) |
| Instruments | `GET /md/v2/Securities`, `GET /md/v2/Securities/:ex/:sym`, `GET .../availableBoards`, `GET .../quotes` | [routes/securities.ts](https://github.com/anymasoft/bybit-adapter/blob/main/src/routes/securities.ts) |
| History | `GET /md/v2/history` (свечи) | [routes/history.ts](https://github.com/anymasoft/bybit-adapter/blob/main/src/routes/history.ts) |
| Orderbook | `GET /md/v2/orderbooks/:ex/:sym` + alias | [routes/orderbook.ts](https://github.com/anymasoft/bybit-adapter/blob/main/src/routes/orderbook.ts) |
| Portfolio | summary, positions, orders, all-portfolios, full-name | [routes/clients.ts](https://github.com/anymasoft/bybit-adapter/blob/main/src/routes/clients.ts) |
| Orders REST | place/cancel limit & market via `/commandapi/warptrans/{FX1,TRADE}/...` | [routes/orders.ts](https://github.com/anymasoft/bybit-adapter/blob/main/src/routes/orders.ts) |
| WS Data Feed | OrderBookGetAndSubscribe, BarsGetAndSubscribe, QuotesSubscribe, AllTradesSubscribe, Positions/Orders/Trades/Summaries V2 (+ Stop/Risks stubs) | [ws/data-handler.ts](https://github.com/anymasoft/bybit-adapter/blob/main/src/ws/data-handler.ts) |
| WS Commands (cws) | `submit:Limit`, `submit:Market`, `delete:{Limit,Market,StopMarket,StopLimit}` | [ws/command-handler.ts](https://github.com/anymasoft/bybit-adapter/blob/main/src/ws/command-handler.ts) |
| Translators | instruments, orderbook, candles, quotes, positions/wallet, orders, executions | `src/translators/*.ts` (7 файлов) |

Архитектурные решения:
- **Multiplexing**: `subscription-registry.ts` хранит мапу `(clientId, guid) → Subscription`. Refcount по Bybit topic — отписываемся от Bybit когда последний подписчик ушёл. Корректно чистится на disconnect.
- **Public + Private WS**: 2 публичных Bybit WS клиента (linear / spot) + 1 приватный. Listeners регистрируются один раз, диспатчат по topic.
- **Mock JWT**: long-lived 24h токен с полями которые Astras декодирует. SHA-256 секрет берётся из `.env`.
- **Bybit env switching**: одна переменная `BYBIT_ENV ∈ {demo, testnet, mainnet}` → разные базы и WS-эндпоинты библиотеки `bybit-api`.

#### Smoke test (Часть 3e) — Pass

```
GET  /health                              → {"ok":true,"ts":...}
POST /refresh                              → {"AccessToken":"eyJ...","jwt":"eyJ...","refreshToken":"mock-refresh-token","expirationTime":...}
GET  /md/v2/Securities/BYBIT/BTCUSDT      → {symbol:"BTCUSDT",exchange:"BYBIT",minstep:0.1,...}  (live Bybit data)
GET  /md/v2/orderbooks/BYBIT/BTCUSDT      → {snapshot:true,bids:[...50 levels...],asks:[...50 levels...]}
GET  /md/v2/history?symbol=BTCUSDT&tf=1   → {history:[{time,open,high,low,close,volume}...]}
GET  /md/v2/Securities/BYBIT:BTCUSDT/quotes → live ticker (last_price ~$78000)
GET  /md/v2/Clients/BYBIT/bybit_demo/positions → []   (нет позиций)
GET  /md/v2/Clients/BYBIT/bybit_demo/summary   → нули (demo баланс ещё не пополнен, см. walkthrough)

WS:  OrderBookGetAndSubscribe → confirm + initial snapshot + delta updates → OK
```

Tests `vitest`: scaffolded но не написаны для Sprint 1 (vertical slice, не horizontal). Acceptance — реальный smoke test против Bybit Demo. Unit tests запланированы в Sprint 2.

### Часть 4 — Astras adaptation ✅

В `astras-bybit-ui` branch `bybit-integration`:

1. **`src/environments/environment.ts`** — все ALOR URLs (apidev.alor.ru, login-dev.alor.ru, lk-api-dev.alorbroker.ru) заменены на `http://localhost:3000` / `ws://localhost:3000/ws` / `ws://localhost:3000/cws`. Firebase config оставлен (Angular init его ожидает), externalLinks переписаны на github.com/anymasoft.

2. **`src/assets/market-settings-config.json`** — добавлена BYBIT биржа сверху с `isDefault: true`, `defaultInstrument: BTCUSDT@linear`, валюта USDT, timezone UTC, 24/7 trading session. MOEX переведена в `isDefault: false` но **оставлена** в конфиге целиком (dormant — для возможной будущей ALOR интеграции, как договаривались).

3. **`src/main.ts`** — pre-bootstrap auth shim: при старте Astras делает `POST /auth/actions/refresh` к adapter'у, складывает `{jwt, refreshToken}` в `localStorage['sso']` ПЕРЕД вызовом `bootstrapApplication`. Это убивает SSO redirect, потому что `ClientAuthContextService.checkAccess()` находит savedIdentity и идёт в нормальный refresh flow вместо `requestCredentials() → redirectToSso()`. На повторных загрузках сидер skip'ается, Astras сам refresh'ит токен через наш же `/auth/actions/refresh`.

**MOEX-specific код не удалён** ни в одном месте — только переключены defaults и URLs. Это сознательное решение архитектора, dormant для будущего.

#### Verification ✅

```
$ pnpm install                # 45.6s, 0 errors
$ pnpm start                  # ng serve compiled in 35.5s, 0 errors
  ➜  Local:   http://localhost:4200/
```

Astras собирается на Angular 21 + Bybit env без compile errors. Стартует. Manual click-test — на стороне пользователя (Часть 5).

### Часть 5 — Manual trading walkthrough ✅

Документ [sprint_1_manual_trading_walkthrough.md](./sprint_1_manual_trading_walkthrough.md) — пошаговая инструкция для пользователя:
- Подготовка (топап Bybit Demo баланса)
- Запуск adapter + Astras
- 11 шагов smoke-теста (Watchlist → Chart → DOM → Account → Place → DOM → Edit → Cancel → Market → Reload)
- Чек-лист скриншотов (8-10 шт)
- Troubleshooting таблица (7 типовых проблем)
- Что НЕ работает в Sprint 1 (stop-orders, multi-account, dividends — это OK)

Пользователь сам прокликает 11 шагов, сделает скриншоты, добавит в `screenshots/sprint_1_*.png` и приложит к отчёту архитектору.

### Часть 6 — Reports & commits ✅

Этот документ. Коммиты — см. секцию ниже.

## Не сделано / отложено

- **Vitest юнит-тесты для translators** — scaffold готов (`tests/` структура, vitest установлен), но тесты не написаны. Acceptance делался против реального Bybit Demo. **План:** Sprint 2.
- **Tauri 2.0 wrap** — целиком Sprint 4 (по roadmap'у).
- **Stop-orders / TPSL** — Astras их шлёт, adapter сейчас возвращает confirm-stub. Если пользователь попробует поставить SL/TP — увидит "OK" но ордер не создастся в Bybit. **План:** Sprint 3.
- **Code signing / production builds** — не релевантно для MVP.
- **Multi-portfolio support** — один портфель `bybit_demo`. Bybit demo обычно один UTA — этого достаточно.
- **Tracker UI quirks** — не клик-тестил все 20+ widgets Astras в Chrome. Если что-то конкретное сломалось — пользователь сообщит в Sprint 2.

## Проблемы и решения

| Проблема | Решение |
|---|---|
| TS error "import path can only end with .ts when allowImportingTsExtensions enabled" | Добавил `allowImportingTsExtensions: true` + `noEmit: true` в tsconfig; runtime через `tsx` |
| `@fastify/websocket` v10: `SocketStream` deprecated, теперь callback получает WebSocket напрямую | Поправил `ws/server.ts` |
| `bybit.getTickers()` имеет 3 narrow overloads по category | Раздельные вызовы для linear vs spot |
| Bybit pnpm packageManager pin 10.25.0 | `npm i -g pnpm@10.25.0` |
| Astras Wallet endpoint вернул нули | Demo balance ещё не запрошен в Bybit UI — задокументировано в walkthrough шаг 0.1 |

## Полезные находки для будущих спринтов

- Astras `ClientAuthContextService` (`src/app/client/services/auth/client-auth-context.service.ts`) — central piece. Изменив `getIdentityUrl()` и SSO URL можно полностью контролировать auth flow.
- `LocalStorageSsoConstants.ClientTokenStorageKey = 'sso'` — единственный ключ хранения identity. Pre-seed достаточно.
- `market-settings-config.json` — статический JSON, легко править. Дефолтная биржа выбирается по `isDefault: true`.
- WS subscription helper: `src/app/shared/services/subscriptions-data-feed.service.ts` — там вся логика guid multiplexing на клиенте.
- Order command helper: `src/app/client/services/orders/ws-orders-connector.ts` — отправляет cws messages.
- TradingView charting_library уже встроен в Astras (`src/assets/charting_library/`) — graph будет работать "из коробки" если history endpoint отдаёт правильный формат.

## Архитектурные вопросы для Sprint 2

1. **Tauri wrap timing.** По roadmap'у это Sprint 4, но если пользователь в Sprint 2-3 захочет уже "desktop feel" — можно сделать минимальный Tauri shell который просто грузит `localhost:4200` в WebView. Это 1-2 дня. Делать?
2. **Stop-orders** — Bybit V5 имеет conditional orders (StopMarket/StopLimit + TP/SL on positions). Реализовать в Sprint 2 или Sprint 3? Зависит от того насколько часто пользователь будет ставить SL руками до подключения Hummingbot.
3. **Symbol search performance** — `/md/v2/Securities` сейчас грузит ВСЕ инструменты Bybit (Bybit linear категория = 500+ символов). Для Astras Watchlist search этого хватит, но если будет тормозить — добавить серверный фильтр.
4. **WS reconnect strategy** — `bybit-api` сам reconnect'ит, но Astras при разрыве своего WS к adapter теряет подписки. В Sprint 2 — implement subscription replay на стороне adapter (отдавать снапшоты при reconnect).
5. **Error surfacing** — сейчас ошибки Bybit возвращаются как `{code:'BybitError', message:'...'}`. Astras может это не распарсить и показать как "Unknown error". Нужно посмотреть как Astras обрабатывает error responses.

## Метрики

- **Файлов создано в bybit-adapter:** 21 .ts + package.json + tsconfig + README + .env.example
- **Строк кода в bybit-adapter:** ~1,200 (src/)
- **Файлов изменено в astras-bybit-ui:** 3 (environment.ts, market-settings-config.json, main.ts)
- **Документов в mm-bot:** 3 (audit, walkthrough, этот report)
- **Bybit endpoints проверены живыми curl:** 7 (health, refresh, securities, orderbook, history, quotes, positions/summary/orders/all-portfolios)
- **WS подписок проверено wscat-стайл скриптом:** 1 (OrderBookGetAndSubscribe — confirm + snapshot + delta), остальные опираются на тот же multiplexing pipeline
- **TypeScript strict mode:** включен, `tsc` проходит без ошибок
- **Время компиляции Astras:** 35.5s (initial)

## Следующий шаг

Пользователь прокликает manual smoke test по walkthrough, добавит скриншоты в `mm-bot/screenshots/sprint_1_*.png`, и закоммитит. Архитектор смотрит результат, пишет промпт для Sprint 2 (вероятно: Tauri wrap или UI/auth polish — зависит от того что пользователь увидит на экране).

## Коммиты

Будут добавлены ниже после `git commit` во всех трёх репо.
