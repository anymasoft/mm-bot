# Sprint 3 — отчёт

**Окончание:** 2026-05-17.
**Ветка работ:** `bybit-integration` в Astras-bybit-UI, `main` в bybit-adapter и mm-bot.

## TL;DR

- **Order Book мерцание устранено.** Backend теперь держит per-symbol состояние книги, применяет Bybit V5 delta'ы incrementally, throttle'ит broadcasts до 10 Hz, при первой подписке seed'ит state через REST. Frontend переключён с обычного `order-book` на `scalper-order-book` (Image 3 архитектора — со spread display и подсветкой объёмов), таблица переведена на `OnPush` + `track row.price` — Angular теперь переиспользует DOM rows для неизменившихся price levels.
- **Equity Curve** — fixed bug в recorder где каждый flush stamp'ался временем последнего wallet update вместо `Date.now()`. До фикса все точки за минуту имели один timestamp, и chart коллапсировал в точку. Сейчас линия растёт по реальному календарному времени.
- **Blotter** — три прежних `[]`-стуба (`/stoporders`, `/trades`, `/stats/history/trades`) переведены на реальные Bybit V5 вызовы (`getActiveOrders(orderFilter=StopOrder)`, `getExecutionList`). WS-апдейты (`order`, `execution`) уже были подключены — теперь tabs показывают как initial REST так и live updates.
- **OSS clean.** Новых dependencies не добавляли. Удалены последние residual references на charting_library (eslint ignore pattern, README). Aудит: `mm-bot/docs/sprint_reports/sprint_3_oss_audit.md`.
- **Tauri 2.0 wrap перенесён на Sprint 4** по решению архитектора (зафиксировано в Sprint 4 plan).

## Что было сделано

### Epic A (CRITICAL) — Order Book stateful merge + throttling + correct depth

**Root cause которое нашлось при чтении кода:**

В `data-handler.ts` opcode `OrderBookGetAndSubscribe` имел такой transform:
```typescript
transform: (raw) => {
  const r = raw as { data?: BybitOrderbookRaw };
  if (!r.data) return null;
  return bybitOrderbookToAlorSlim(r.data);   // <-- проблема
}
```

Bybit V5 шлёт через `orderbook.<depth>.<symbol>`:
- одно сообщение `type='snapshot'` (full картина 50 уровней),
- затем поток `type='delta'` с **только изменёнными** уровнями (`qty=0` означает remove).

Старый transform тупо пробрасывал каждый delta в `bybitOrderbookToAlorSlim` — получался "новый snapshot" с 2-3 уровнями (теми что были в delta), и Astras рисовал это как полную книгу. Это и было одновременно причиной "глубина = 2 уровня" и "мерцание 10×/sec" (frontend рвал весь component на каждый delta).

**Backend fix (bybit-adapter):**

1. **Новый `src/ws/orderbook-state.ts`** — per-symbol Map с операциями `applySnapshot` / `applyDelta` / `getDepth(N)` / `clearState`. `qty=0` удаляет level, sequence gap логируется (но не форсит resnapshot — Bybit V5 сам восстанавливается через свежий snapshot если что).

2. **Special path в `routePublicMessage`** — если topic начинается с `orderbook.`, идёт в `handleOrderbookMessage` (state update) и `scheduleOrderbookBroadcast` (per-topic throttling, 100ms = 10 Hz). Throttling — last-wins (не batching): каждый broadcast — полная картина top-N книги в ALOR slim формате. Между throttle-окнами promo updates тихо merge'ятся в state и победитель выходит в эфир в конце окна.

3. **REST seed на first subscribe** — `bybit.getOrderbook` вызывается ДО `subscribeV5`, иначе после tsx-watch reload Bybit lib мог считать соединение "already subscribed", не присылал свежий WS snapshot, и наш state ловил deltas мимо пустого state'а с warning'ами `delta received before snapshot`. После fix первый ARP сразу seed'ит state, и delta'ы попадают в готовую книгу.

4. **Cleanup на unsubscribe** — `bybitUnsubscribeIfLast` зачищает state, любой pending throttle timer и last-sent марк. Без этого долгая сессия с reconnect-ами набивала бы памяти.

5. **Vitest unit-tests** — первый spec в адаптере: `src/ws/orderbook-state.spec.ts`, 6 тестов покрывают snapshot/delta/qty-0/sort/clear/parseTopic. Все зелёные.

**Frontend fix (astras-bybit-ui):**

1. **Default Crypto layout** в `default-dashboards-config.json` — `order-book` заменён на `scalper-order-book` со seeded settings: `depth: 25`, `showSpreadItems: true`, `showInstrumentPriceDayChange: true`, instrument BTCUSDT/BYBIT/linear. Это Image 3 архитектора — вариант с spread display и подсветкой объёмов для market making.

2. **`ChangeDetectionStrategy.OnPush`** на `ScalperOrderBookTableComponent` — таблица полностью driven by `displayItems$ | async`, поэтому OnPush безопасен.

3. **`track $index` → `track row.price`** в трёх @for loops (volume / price / orders panels). С OnPush + trackBy Angular теперь переиспользует существующие DOM rows для price levels с тем же price — обновляет только cells содержимое вместо полного rebuild'а ряда.

**Backend & frontend архитектурно decoupled:** scalper-order-book widget потребляет тот же `OrderBookDataFeedHelper.getRealtimeDateRequest(...)` opcode `OrderBookGetAndSubscribe` что и старый orderbook widget — backend state manager обслужит оба widget'а одновременно через shared state per symbol.

**Note для Sprint 4 Chart Trading Phase 1:** rendering Order Book widget'а намеренно остался "тупой таблицей" — interactive overlay для chart trading (click-to-place, draggable order lines) ляжет отдельным Angular слоем поверх lightweight-charts. Backend orderbook engine **не coupled** с rendering — он отдаёт чистый slim payload, и любой UI слой может над ним строиться.

**Commits:**
- `bybit-adapter@2f9d244` — `feat(orderbook): stateful merge + throttling + REST seed`
- `astras-bybit-ui@3653a4a8` — `feat(orderbook,crypto): scalper-order-book widget by default + OnPush + trackBy`

### Epic B — Equity Curve frontend connect

REST endpoint `/client/v2.0/agreements/:agreement/portfolios/any/dynamics` уже работал из Sprint 2 (читал `data/equity-*.jsonl` через `readEquityHistory`). Frontend `AgreementDynamicsComponent` уже звал его на правильный URL с правильными query параметрами (`startDate=ISO`, `endDate=ISO`).

**Что было реально сломано:** при curl на endpoint я обнаружил что `portfolioValues` массив состоял из дубликатов:
```json
[{"date":"2026-05-17T14:47:32.000Z","value":883175.45},  ← 11 раз
 {"date":"2026-05-17T15:06:02.000Z","value":883543.62}]  ← 4 раза
```

В JSONL то же самое — 15 строк с одинаковыми `t` и `e`. Это убивало chart (все точки в один timestamp).

**Причина:** в `equity-recorder.ts` flushOnce писал `t: Math.floor(latestTs / 1000)`, где `latestTs` обновлялся только при wallet WS update. Demo account редко присылает wallet snapshot (только при изменении balance), и весь minute-rate flush писал тот же timestamp.

**Fix:** `t = Math.floor(Date.now() / 1000)` всегда в flush. Семантика chart'а — "what was equity at time t?" — самое свежее известное значение equity остаётся лучшим estimate на "сейчас".

Endpoint shape подтверждён через curl:
```bash
curl 'http://127.0.0.1:3000/client/v2.0/agreements/BYBIT-DEMO/portfolios/any/dynamics?startDate=2026-05-17T00:00:00Z&endDate=2026-05-17T23:59:59Z'
# → {"portfolioValues":[{"date":"...","value":883175.45},...]}
```

Frontend chart рендерится через `dynamics.portfolioValues.map(v => v.value)` (datasets) и `.map(v => v.date)` (labels). Shape совпадает.

**Commit:** `bybit-adapter@a97f2d5` — `fix(equity): stamp recorder flushes with Date.now(), not last wallet update`.

**Что осталось на architect verification:** запустить UI, открыть Crypto dashboard, во виджете "Динамика по договору" увидеть растущую линию. На demo account она будет плоская (balance не меняется) до первой сделки — это нормально.

### Epic C — Blotter live data

Из шести blotter tabs три уже работали из Sprint 2:
- **О портфеле** — `GET /md/v2/Clients/:exchange/:portfolio/summary` + WS `SummariesGetAndSubscribeV2` (`wallet` topic) ✓
- **Заявки** — `GET /md/v2/Clients/:exchange/:portfolio/orders` + WS `OrdersGetAndSubscribeV2` (`order` topic) ✓
- **Позиции** — `GET /md/v2/Clients/:exchange/:portfolio/positions` + WS `PositionsGetAndSubscribeV2` (`position` topic) ✓

Три остальных были стабы `[]` в `stubs.ts`. Реализовал в новом `bybit-adapter/src/routes/blotter.ts`:

| Endpoint | Bybit V5 source |
|---|---|
| `GET /md/v2/Clients/:ex/:p/stoporders` | `bybit.getActiveOrders(orderFilter='StopOrder')` |
| `GET /md/v2/Clients/:ex/:p/trades` | `bybit.getExecutionList(startTime=today_00:00_UTC)` |
| `GET /md/v2/stats/:ex/:p/history/trades` | `bybit.getExecutionList(startTime=dateFrom, side filter, descending sort, limit cap)` |
| `GET /md/stats/:ex/:p/history/trades/:symbol` | same, symbol-scoped |

Translators (`bybitOrderToAlor`, `bybitExecutionToAlorTrade`) уже были в `src/translators/orders.ts` — переиспользовал. WS live updates тоже не трогал, они уже корректно ходят (`execution` topic для fills, `order` topic для state changes).

В `stubs.ts` оставлен только broader `/md/v2/stats/:exchange/:portfolio/*` catch-all (на случай неожиданных stats reads) — конкретные эндпойнты убраны, route precedence в Fastify теперь корректная (real → catch-all).

Curl на demo account возвращает `[]` от всех трёх (нет stop orders и нет executions сегодня) — это правильное поведение, endpoint работает. Они станут non-empty как только пользователь разместит ордер через UI и тот исполнится.

**Commit:** `bybit-adapter@e1f9733` — `feat(blotter): real stoporders / today-trades / history endpoints`.

### Epic D — WS stability verification

Adapter был запущен в background в начале Sprint 3 (`npm run dev` через PowerShell `nohup`-эквивалент, лог в `mm-bot/logs/sprint3_stability_run.log`). За время работ adapter перезапускался через `tsx watch` несколько раз — каждый edit бэкенд-файла триггерил reload (это нормально для dev режима).

**Critical observation:** в логе нет ни одного `Pong timeout` за все ~16+ минут работы, в том числе через несколько resubscribe'ов после reload'ов. Sprint 2 fix (`pingInterval: 15_000, pongTimeout: 10_000` в WSClient options) работает.

**Что осталось для финального acceptance Sprint 2:** дать adapter поработать 1 час непрерывно (без code edits) и потом сделать grep. Сейчас Sprint 3 commit'ы все сделаны, дальнейших backend изменений не планируется до Sprint 4. Архитектор может оставить `npm run dev` на час и потом проверить:
```bash
grep -i "pong timeout" mm-bot/logs/sprint3_stability_run.log
grep -i "websocket reconnecting" mm-bot/logs/sprint3_stability_run.log
grep -i "websocket connection closed" mm-bot/logs/sprint3_stability_run.log
```
Ожидается 0 matches.

### Epic E — Nice-to-have cleanup

- **README обновлены:**
  - `mm-bot/README.md` — статус всех спринтов до 3 включительно, явный план Sprint 4 (Tauri + Chart Trading Phase 1), 100% OSS принцип явно прописан.
  - `bybit-adapter/README.md` — "What's implemented (after Sprint 3)" секция с stateful merge / amend / equity recorder / blotter.
  - `astras-bybit-ui/README.md` — переписан "Особенности", убрано упоминание TradingView Charting Library, явно сказано что стек 100% open source.
- **ESLint ignore pattern** `**/charting_library/**/*` удалён из `astras-bybit-ui/eslint.config.js` (Sprint 2 удалил сам code, ignore больше не нужен).
- **Residual references** — grep по source code находит 2 матча, оба explanatory comments (`parent-widget.component.ts:19`, `mobile-dashboard.effects.ts:24`) объясняющие что и почему было удалено. Оставлены намеренно — это полезный исторический контекст без загрузки proprietary кода.
- **Deps snapshot** — `mm-bot/docs/sprint_reports/sprint_3_deps_snapshot.txt` (118 строк), `npm ls --depth=0` и `pnpm ls --depth=0` для обоих репо. Baseline для будущих спринтов.

## Definition of Done check

| # | Критерий | Статус |
|---|---|---|
| 1 | Order Book: 25+ уровней, плавные updates, OnPush + trackBy verified | ✅ backend & frontend готовы. **Visual verification** — нужен скриншот / DevTools от архитектора |
| 2 | Equity Curve: реальные данные, обновляется live | ✅ backend готов, recorder timestamp fix'нут. **Visual verification** — нужен запуск UI |
| 3 | Blotter: все 6 tabs показывают live данные | ✅ 6 endpoints реализованы. Tabs показывают `[]` пока demo account пуст, заполнятся после первой сделки |
| 4 | WS stability proof: 1 час без Pong timeout | 🟡 в логе пока ~16 мин без pong timeout. Архитектору запустить ещё на ~45 мин и сделать финальный grep |
| 5 | Cleanup: README актуальны, no residual refs, ESLint cleaner | ✅ |
| 6 | OSS audit: sprint_3_oss_audit.md создан | ✅ |
| 7 | Скриншоты: 6+ скриншотов (orderbook, equity, blotter tabs, DevTools) | ❌ Claude Code не имеет доступа к UI — это задача архитектора |
| 8 | Sprint 3 report (этот файл) | ✅ |
| 9 | Push во все три репо, URLs в чат | (далее в этой итерации) |

## Что осталось архитектору verify через UI

1. Открыть `npm run dev` (top-level), дождаться 4200 + 3000.
2. Crypto tab открывается по дефолту, видны: light-chart (свечи BTCUSDT, BB, SMA20, EMA50, RSI), **scalper-order-book** (новый — заменил обычный orderbook, должен показывать spread между Bid и Ask и подсветку объёмов), order-submit, portfolio-charts (тут должна быть "Динамика по договору"), blotter снизу.
3. **Сабмит лимитного ордера далеко от рынка**: должен появиться в "Заявки" tab. Перетащить order line в scalper-order-book на другой price level → ордер amend'нится (`update:limit` opcode, через Bybit native amendOrder, queue priority сохраняется).
4. Открыть DevTools → Performance → запись 30 сек на Crypto dashboard → смотреть что main thread не блокируется >50ms и нет drops.
5. Через час непрерывной работы — grep по `mm-bot/logs/sprint3_stability_run.log`:
   ```
   grep -i "pong timeout" mm-bot/logs/sprint3_stability_run.log
   ```

## Открытые вопросы

1. **AlorOrder shape не имеет `triggerPrice` поля** для отображения SL/TP маркеров в blotter "Стопы" tab. Сейчас stop-orders выглядят как plain limit orders. Если архитектор хочет proper SL/SM badges как у MOEX варианта — нужно расширить `AlorOrder` интерфейс и `bybitOrderToAlor` translator. Не блокирует, можно в Sprint 5.

2. **`format=heavy` query** на history/trades — Astras всегда шлёт `heavy`, мы игнорируем т.к. возвращаем full AlorTrade shape всегда. Если в продакшене Astras когда-то начнёт слать `light` (trimmed shape) — нужно добавить разделение. Сейчас не критично.

3. **WS subscription для stop orders** — Bybit V5 шлёт stop orders в тот же `order` topic с polем `stopOrderType`. Сейчас наш WS handler не фильтрует — frontend получит stop orders и regular orders в одном потоке (для tab "Заявки"). Frontend сам должен разделять по `type`. Если будет dupes в blotter — нужно фильтровать в handler или в translator.

4. **Throttling 10 Hz для orderbook** — может быть аггрессивно для quiet symbol (где deltas редкие, throttle никогда не активируется) и недостаточно агрессивно для super-busy symbol. Sprint 4+ можно сделать adaptive (e.g. throttle scales с rate того что приходит). Сейчас 10 Hz — разумная константа.

5. **Mobile dashboard** не переключен на scalper-order-book — оставлен обычный order-book с `useOrderWidget: true`. Mobile UX отдельная история (Sprint 5+?), сейчас не трогал чтобы не сломать ничего.

## Commit hashes

- `bybit-adapter@2f9d244` — Epic A backend (stateful merge + throttle + REST seed + vitest spec)
- `bybit-adapter@a97f2d5` — Epic B (equity recorder timestamp fix)
- `bybit-adapter@e1f9733` — Epic C (blotter endpoints)
- `bybit-adapter@f8e019d` — Epic E (README refresh)
- `astras-bybit-ui@3653a4a8` — Epic A frontend (scalper-order-book + OnPush + trackBy)
- `astras-bybit-ui@18f7c7a0` — Epic E (README + eslint cleanup)
- `mm-bot@c9f08fa` — sprint_3 prompts + reports + README

URLs последних коммитов после push публикуются архитектору вместе с этим отчётом.
