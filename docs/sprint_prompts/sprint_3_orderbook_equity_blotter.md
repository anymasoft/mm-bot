# Sprint 3: Order Book стабилизация + Equity Curve + Blotter integration

## Контекст для Claude Code

Sprint 2 завершён успешно. Все три репо обновлены, OSS audit pass, 1550 файлов proprietary TradingView Charting Library вычищены, 3 критичных бага из Sprint 1 найдены и исправлены (TIMEFRAME_MAP, ticker delta merge, lowercase order opcodes). График BTCUSDT с 5 индикаторами работает, Bid и Ask видны, default Crypto layout.

**Главная проблема, обнаруженная пользователем при ручной верификации UI:** Order Book мерцает — полностью перерисовывается 10 раз в секунду вместо incremental update только изменённых уровней. Кроме того глубина стакана = 2-3 уровня вместо 25+ (нужно для market making).

**Архитектор зафиксировал следующие решения по open questions Sprint 2:**

| # | Вопрос | Решение |
|---|--------|---------|
| 1 | Удалять Trading (legacy) dashboard | **Нет, оставить как dormant** — для будущего ALOR/MOEX подключения. Просто hidden в Crypto-first UX. |
| 2 | Equity recorder retention | **90 дней rolling**, потом старые в archive файл. JSONL формат остаётся. |
| 3 | Order book stateful merge | **Обязательно** — это и есть причина мерцания. Детали в Epic A. |
| 4 | better-sqlite3 для equity | **Не сейчас**, JSONL fine. SQLite в Sprint 5+ когда понадобятся queries. |
| 5 | Tech-chart final cleanup | **Да** — Nice-to-have в этом спринте. |

## Цель Sprint 3

После Sprint 3 пользователь открывает Astras и видит:
- Order Book BTCUSDT с **25+ уровнями глубины с каждой стороны**, обновляется **плавно без мерцания** — меняются только конкретные ячейки, не вся таблица
- Equity Curve "Динамика по договору" показывает реальные данные за последние 24 часа (из equity recorder JSONL)
- Blotter снизу дашборда показывает live данные на табах: Заявки (Open Orders), Позиции (Positions), Сделки (Recent Fills), История сделок (Trade History)
- Adapter работает 1 час непрерывно без `Pong timeout` в логах — это финальное подтверждение Sprint 2 Epic 0

Это **прямое продолжение Sprint 2** — устранение последних UX gaps перед тем, как двигаться к Hummingbot integration (Sprint 5) и Tauri wrap (Sprint 4).

## 100% Open Source Constraint

Project memory hard constraint остаётся в силе. Перед `npm install` любого нового пакета — `npm view <package> license`. Allowed: MIT, Apache-2.0, BSD, ISC, MPL, GPL, LGPL. Blocked: anything proprietary, freemium, "free for non-commercial", trial-period, Commons Clause.

Записывать каждую новую зависимость в `mm-bot/docs/sprint_reports/sprint_3_oss_audit.md`.

## Workflow

1. Прочитать этот промпт целиком
2. Положить копию в `mm-bot/docs/sprint_prompts/sprint_3_orderbook_equity_blotter.md`
3. Epic A — критично, идёт первым (мерцающий стакан — главный UX baker)
4. Epic B — Equity Curve, параллельно с A (backend готов, нужен только frontend connect)
5. Epic C — Blotter integration, параллельно с A/B
6. Epic D — WS stability верификация (1 час continuous run + grep логов)
7. Epic E — Nice-to-have cleanup
8. После каждого Epic — micro commit с описанием в conventional commits style
9. По завершении всех Epic — OSS audit + sprint_3_report.md
10. Push во все три репо
11. URLs последних коммитов в чат архитектору

## Epic A (CRITICAL): Order Book stateful merge + throttling + correct depth

### Проблема (root cause analysis)

Bybit V5 WS topic `orderbook.<depth>.<symbol>` шлёт два типа сообщений:
- **Snapshot** (type=`snapshot`) — первое сообщение, full картина стакана
- **Delta** (type=`delta`) — последующие сообщения, **только изменённые уровни** (qty=0 означает удалить уровень)

Текущая проблема в adapter:
1. **Либо** adapter не делает stateful merge — отдаёт frontend каждый delta как новый "snapshot" с 2-3 уровнями (теми что пришли в delta), отсюда truncated depth = 2-3 уровня на скриншотах
2. **Либо** adapter мерджит, но отдаёт frontend full snapshot после каждого delta — frontend перерисовывает весь component → 10x/sec мерцание

Нужно решить **обе** проблемы.

### Решение

**Backend (bybit-adapter):**

В `bybit-adapter/src/ws/` создать (или модифицировать) `orderbook-state.ts`:

```typescript
interface OrderbookLevel {
  price: number;
  size: number;
}

interface OrderbookState {
  symbol: string;
  bids: Map<string, OrderbookLevel>;  // price-keyed для O(1) update
  asks: Map<string, OrderbookLevel>;
  lastUpdateTime: number;
  sequenceNumber: number;
}

class OrderbookStateManager {
  private states: Map<string, OrderbookState> = new Map();
  
  // Применить snapshot — полная замена состояния
  applySnapshot(symbol: string, snapshot: BybitOrderbookSnapshot): OrderbookState {
    const state: OrderbookState = {
      symbol,
      bids: new Map(snapshot.bids.map(([p, s]) => [p, { price: +p, size: +s }])),
      asks: new Map(snapshot.asks.map(([p, s]) => [p, { price: +p, size: +s }])),
      lastUpdateTime: Date.now(),
      sequenceNumber: snapshot.seq,
    };
    this.states.set(symbol, state);
    return state;
  }
  
  // Применить delta — incremental update
  applyDelta(symbol: string, delta: BybitOrderbookDelta): OrderbookState | null {
    const state = this.states.get(symbol);
    if (!state) {
      logger.warn({symbol}, 'delta received before snapshot, ignoring');
      return null;
    }
    
    // Bybit V5 delta semantics: qty=0 means remove level, otherwise replace
    for (const [price, size] of delta.bids) {
      if (+size === 0) state.bids.delete(price);
      else state.bids.set(price, { price: +price, size: +size });
    }
    for (const [price, size] of delta.asks) {
      if (+size === 0) state.asks.delete(price);
      else state.asks.set(price, { price: +price, size: +size });
    }
    
    state.lastUpdateTime = Date.now();
    state.sequenceNumber = delta.seq;
    return state;
  }
  
  // Получить top N levels отсортированных
  getDepth(symbol: string, depth: number = 50): {bids: OrderbookLevel[], asks: OrderbookLevel[]} | null {
    const state = this.states.get(symbol);
    if (!state) return null;
    
    const bids = Array.from(state.bids.values())
      .sort((a, b) => b.price - a.price)  // descending для bids
      .slice(0, depth);
    const asks = Array.from(state.asks.values())
      .sort((a, b) => a.price - b.price)  // ascending для asks
      .slice(0, depth);
    
    return { bids, asks };
  }
}
```

**Throttling layer:** в `data-handler.ts` где обрабатываются orderbook updates:

```typescript
// Per-symbol throttle config
const ORDERBOOK_THROTTLE_MS = 100;  // max 10 updates/sec per symbol
const orderbookLastSent: Map<string, number> = new Map();
const orderbookPending: Map<string, NodeJS.Timeout> = new Map();

function broadcastOrderbookUpdate(symbol: string, state: OrderbookState, subscribers: Subscriber[]) {
  const now = Date.now();
  const lastSent = orderbookLastSent.get(symbol) || 0;
  const timeSinceLast = now - lastSent;
  
  if (timeSinceLast >= ORDERBOOK_THROTTLE_MS) {
    // Сразу отправляем
    sendToSubscribers(symbol, state, subscribers);
    orderbookLastSent.set(symbol, now);
  } else {
    // Откладываем — uniqe timer per symbol
    if (!orderbookPending.has(symbol)) {
      const delay = ORDERBOOK_THROTTLE_MS - timeSinceLast;
      const timer = setTimeout(() => {
        const currentState = stateManager.getDepth(symbol, 50);
        sendToSubscribers(symbol, currentState, subscribers);
        orderbookLastSent.set(symbol, Date.now());
        orderbookPending.delete(symbol);
      }, delay);
      orderbookPending.set(symbol, timer);
    }
    // Если timer уже стоит — просто пропускаем, state обновится к моменту отправки
  }
}
```

**Subscription depth:** в `ws-public.ts` при подписке на orderbook — использовать **depth=50** (Bybit V5 поддерживает 1/50/200/500 для linear perps). depth=50 — хороший баланс между точностью и нагрузкой.

```typescript
ws.subscribeV5([`orderbook.50.${symbol}`], 'linear');
```

**ALOR format output:** frontend Astras ожидает full snapshot в каждом WS message (нужно проверить точную семантику в audit Sprint 1 doc). Если так — после каждого delta + state update adapter отправляет **getDepth(symbol, 50)** результат в ALOR формат. Frontend получает обновлённую картинку с правильной глубиной.

**Frontend (astras-bybit-ui):**

Найти Order Book widget component (вероятно в `src/app/features/scalper-order-book/` или подобном модуле). Применить Angular optimization:

1. **OnPush change detection** на component:
```typescript
@Component({
  // ...
  changeDetection: ChangeDetectionStrategy.OnPush
})
```

2. **trackBy function** для `*ngFor` строк стакана:
```typescript
trackByPrice(index: number, level: OrderbookLevel): number {
  return level.price;  // price stable — Angular reuse существующие DOM ноды
}
```

В template:
```html
<tr *ngFor="let level of bids; trackBy: trackByPrice">
  <td>{{ level.size }}</td>
  <td>{{ level.price }}</td>
</tr>
```

Это **критично** — без trackBy Angular делает diff по object identity, а каждый new object от WS = new identity = full re-render. С trackBy по price — Angular переиспользует ноды для уровней с тем же price и обновляет только cells содержимое.

3. **Object pooling для level objects** (опционально, если OnPush+trackBy недостаточно). Вместо создания new objects на каждый update — поддерживать pool и менять properties existing objects.

### Acceptance

- Order Book widget BTCUSDT показывает 25+ уровней с каждой стороны
- Updates плавные — конкретные ячейки меняются, **вся таблица не перерисовывается**
- Можно визуально проследить как уровень добавился/удалился — без мерцания
- В Chrome DevTools Performance tab при 30-секундной записи — нет drops, no main thread blocking >50ms
- Sequence number от Bybit инкрементальный, no gaps (если gap — adapter должен реcнапшот через REST GET /v5/market/orderbook)

## Epic B: Equity Curve frontend connect

### Проблема

Equity recorder в adapter работает (Sprint 2 Epic F), JSONL файл `bybit-adapter/data/equity.jsonl` создаётся. Но frontend widget "Динамика по договору #BYBIT-DEMO" пустой — нет connection с этим backend.

### Решение

**Шаг 1: Проверить эндпоинт adapter**

Должен быть REST endpoint типа `GET /md/v2/Clients/{exchange}/{portfolio}/dynamics` (или эквивалент в ALOR формате — точное имя проверить в audit'е Sprint 1). Этот endpoint возвращает массив `[{timestamp, equity}, ...]` для chart rendering.

Если в Sprint 2 уже был добавлен `/dynamics` endpoint (упоминается в отчёте) — verify работает корректно, возвращает данные за последние 24 часа.

**Шаг 2: Найти frontend компонент equity chart**

В `astras-bybit-ui` найти widget "Динамика по договору" (обычно `portfolio-charts` или `equity-chart` module). Проверить какой endpoint он вызывает при init.

**Шаг 3: Connect**

Если endpoint в adapter возвращает данные в правильном ALOR формате, и frontend делает запрос на правильный URL — chart должен сам отрисоваться.

Возможные проблемы:
- URL не совпадает (ALOR использует один путь, adapter expose другой) — fix в routes
- Format не совпадает (frontend ожидает `{value, time}`, adapter шлёт `{equity, timestamp}`) — fix в translator
- Timezone issues — equity recorder в UTC, frontend в local — proper conversion

**Шаг 4: Default range**

Frontend по умолчанию запрашивает: 1H, 1M, 6M, 1Y, All. Для нашего use case минимум должен работать **1H и 1M** (короткие диапазоны), потому что equity recorder только начал собирать данные. Длинные диапазоны (6M, 1Y) могут возвращать пустые массивы или single point — это OK для now.

### Acceptance

- Widget "Динамика по договору" показывает equity curve реальные данные
- Минимум 1H range работает
- Линия обновляется при новых snapshots (каждые 60s)
- При торговле (place order → fill → balance change) — equity отражается на графике

## Epic C: Blotter с live данными

### Проблема

На скриншотах Sprint 2 нижняя половина дашборда содержит widget с табами: "О портфеле", "Заявки", "Стопы", "Позиции", "Сделки", "История сделок", "Уведомления". Но они пустые — нет данных, хотя ордера в Bybit testnet могут быть размещены, позиции открыты, сделки совершены.

### Решение

Каждый tab требует:
- REST endpoint в adapter (для initial load)
- WS subscription в adapter (для live updates)
- Translator Bybit → ALOR format
- Frontend компонент уже существует в Astras — нужно убедиться что он подписывается правильно

### Конкретные tabs

**Заявки (Working Orders):**
- REST: `GET /md/v2/Clients/{exchange}/{portfolio}/orders?status=working` — Bybit `GET /v5/order/realtime?openOnly=true`
- WS: `OrdersGetAndSubscribeV2` — Bybit private WS topic `order`
- Показывать: orderId, side, price, qty, filled, status, time

**Стопы (Stop Orders):**
- REST: filter из orders где `stopOrderType != null` — Bybit `GET /v5/order/realtime?orderFilter=StopOrder`
- WS: тот же `order` private topic, filter по stopOrderType
- Показывать: orderId, trigger price, side, qty, status

**Позиции (Positions):**
- REST: `GET /md/v2/Clients/{exchange}/{portfolio}/positions` — Bybit `GET /v5/position/list`
- WS: `PositionsGetAndSubscribeV2` — Bybit private WS topic `position`
- Показывать: symbol, side, qty, avg entry, current price, unrealized PnL, margin

**Сделки (Recent Fills):**
- REST: `GET /md/v2/Clients/{exchange}/{portfolio}/trades?from=<today_start>` — Bybit `GET /v5/execution/list`
- WS: `TradesGetAndSubscribeV2` — Bybit private WS topic `execution`
- Показывать: symbol, side, price, qty, fee, time, realized PnL

**История сделок (Trade History):**
- Same as Сделки но с другим time range (last 7 days)
- REST: `GET /md/v2/Clients/{exchange}/{portfolio}/trades?from=<7d_ago>` — Bybit `GET /v5/execution/list` with date params

**О портфеле (Portfolio Summary):**
- Already works (Account Manager subscription `wallet` topic)
- Показывает balance, equity, margin
- Только нужно убедиться что summary endpoint возвращает full data

### Implementation strategy

1. Найти в `astras-bybit-ui` существующие компоненты для каждого таба
2. Проверить какие WS subscriptions они шлют при активации tab
3. Проверить какие REST endpoints вызываются при initial load
4. В adapter implement отсутствующие endpoints + WS handlers
5. Убедиться translators работают корректно

### Acceptance

- Размещаю лимитный ордер через UI → он появляется в "Заявки" tab в реальном времени
- Размещаю stop order → в "Стопы" tab
- Открываю позицию → в "Позиции" tab с unrealized PnL
- Ордер исполняется → в "Сделки" tab появляется fill, позиция обновляется в "Позиции"
- Сегодняшние сделки видны в "Сделки", старше суток — в "История сделок"
- Tab "Уведомления" — может оставаться пустым (нет business logic для notifications), или показывать список fills как notifications

## Epic D: WS stability final verification

### Цель

Подтвердить что Sprint 2 Epic 0 fix действительно решил pong timeout проблему. Это финальный проверочный шаг — не должно быть `Pong timeout` в логах за 1 час непрерывной работы.

### Шаги

1. Запустить `npm run dev` (top-level)
2. Дать поработать **1 час** непрерывно (можно фоном пока работаем над другими эпиками)
3. После 1 часа — grep по логам:
   ```bash
   grep -i "pong timeout" logs/adapter.log
   grep -i "websocket reconnecting" logs/adapter.log
   grep -i "websocket connection closed" logs/adapter.log
   ```
4. Если хоть один match — есть проблема, записать в Sprint 3 report, требуется retry с другим pingInterval

5. Если 0 matches за 1 час непрерывной работы — Epic 0 Sprint 2 закрывается окончательно

### Acceptance

- 0 строк `Pong timeout` в логах за 1 час continuous run
- 0 строк `Websocket reconnecting` за тот же период
- Скриншот grep'а в `mm-bot/screenshots/sprint_3_ws_stability_proof.png` или скопировать вывод в sprint_3_report.md

## Epic E: Nice-to-have cleanup

### E.1: README updates

Во всех трёх репо проверить README.md:
- `mm-bot/README.md` — описание актуального стека (lightweight-charts + technicalindicators, no Quantower, no TradingView Charting Library)
- `bybit-adapter/README.md` — описание endpoints, WS subscriptions, инструкции запуска, OSS deps list
- `astras-bybit-ui/README.md` — заметить про bybit-integration branch, отличия от upstream alor-broker

### E.2: ESLint pass

В обоих TypeScript проектах (adapter и astras-ui) запустить:
```bash
# adapter
cd bybit-adapter && npm run lint

# astras-bybit-ui
cd astras-bybit-ui && pnpm lint
```

Исправить очевидные warnings (unused imports, дубликаты). Не трогать legacy warnings от ALOR upstream — это вне нашего scope.

### E.3: References cleanup

Поискать и удалить любые residual references на удалённый tech-chart module и TradingView Charting Library:
```bash
cd astras-bybit-ui
grep -r "tech-chart\|charting_library\|InitialSettingsMap\|@tradingview/charting_library" --include="*.ts" --include="*.json" --include="*.md"
```

Если найдётся — удалить. Если уже всё чисто — записать в report что cleanup verified.

### E.4: Dependencies audit

```bash
cd astras-bybit-ui && npm ls --depth=0 > deps.txt
cd ../bybit-adapter && npm ls --depth=0 >> ../mm-bot/docs/sprint_reports/sprint_3_deps_snapshot.txt
```

В sprint_3_oss_audit.md финальная таблица **всех** dependencies (не только новых) с лицензиями. Цель — снимок текущего OSS состояния проекта.

### Acceptance

- README актуальны в трёх репо
- ESLint warnings уменьшены
- 0 references на tech-chart / charting_library / TradingView Charting Library
- sprint_3_deps_snapshot.txt создан с полным списком dependencies

## Что НЕ делаем в Sprint 3

- **Tauri 2.0 wrap** — перенесено в Sprint 4
- **Hummingbot integration** — Sprint 5
- **Production authentication** (real API key validation, encrypted storage) — Sprint 4
- **Backtest module** — Sprint 6
- **MOEX/ALOR подключение** — dormant, не trogamem
- **Multi-account support** — Sprint 5+
- **Cleanup Trading (legacy) dashboard** — оставляем dormant
- **Mobile responsive** — после desktop полностью стабилен

## Definition of Done для Sprint 3

1. **Order Book**: 25+ уровней depth, плавные updates без мерцания, OnPush + trackBy verified в DevTools Performance
2. **Equity Curve**: реальные данные из equity recorder отображаются в "Динамика по договору" widget, обновляются live
3. **Blotter**: все 6 табов (О портфеле / Заявки / Стопы / Позиции / Сделки / История сделок) показывают live данные
4. **WS stability proof**: 1 час continuous run без Pong timeout — verified via grep + screenshot
5. **Cleanup**: README актуальны, no residual tech-chart references, ESLint warnings reduced
6. **OSS audit**: sprint_3_oss_audit.md создан, full deps snapshot
7. **Скриншоты**: минимум 6 скриншотов — Order Book live (с heatmap эффектом, видно diff'ы), Equity Curve с данными, каждый Blotter tab, Performance tab DevTools
8. **Sprint 3 report**: sprint_3_report.md с описанием всего сделанного, проблем, открытых вопросов
9. **Push во все три репо**, URLs последних коммитов в чат архитектору

## Расчётный timeline

7-10 рабочих дней full-time. Возможные ускорения:
- Order Book stateful merge — может быть готов за 2 дня если adapter архитектура поддерживает state stores из коробки
- Blotter endpoints — если scaffolding из Sprint 2 переиспользуется, добавить по 1 эндпойнту в день
- WS stability — пассивный мониторинг, не блокирует другую работу

Возможные тормоза:
- Frontend Angular OnPush может потребовать дополнительных правок в parent components (cascade re-render)
- Equity curve может не подцепляться из-за format mismatch — придётся откатить адаптер endpoint
- Blotter может иметь скрытые dependencies на ALOR-specific логику

## Замечания для Claude Code

1. **Order Book мерцание — Epic A — приоритет №1.** Это main UX blocker. Все остальное может ждать.

2. **OnPush change detection требует осторожности.** Если component уже использует OnChanges или мутирует input — OnPush ломает. Перед migration — тщательно прочитать существующий код component'а.

3. **trackBy функция обязательна для real-time tables.** Без неё Angular делает full DOM re-create. С ней — переиспользует existing ноды.

4. **Sequence numbers Bybit V5.** Каждый orderbook update имеет `u` (update id) и `seq` (sequence). Если seq gap > 1 — мы пропустили updates, нужно re-snapshot через REST. Это edge case, но критичный для consistency.

5. **Throttling != batching.** Throttling = max 1 update per 100ms (последний state выигрывает). Batching = собирать updates в array и слать пакетом. Нам нужен throttling, не batching.

6. **Equity recorder JSONL format.** Каждая строка — `{timestamp: ISO8601, equity: number, available: number, unrealizedPnl: number}`. Endpoint `/dynamics` парсит файл, фильтрует по time range, возвращает в ALOR format.

7. **Blotter может потребовать много endpoints.** Если найдётся endpoint которого нет в adapter — implement с минимальной заглушкой, продолжай дальше. Не блокируйся на одном endpoint.

8. **WS stability test не блокирует другую работу.** Запусти dev в фоне, дай 1 час прокрутиться, продолжай работу. Через час — проверь логи.

9. **Не использовать Hummingbot** в этом спринте. Оставлен в WSL без изменений.

10. **OSS audit обязателен** — даже если 0 новых dependencies в этом спринте, делается **full deps snapshot** для baseline на будущее.

11. **Не запускать live mainnet trading.** Всё через Bybit demo trading account.

12. **MOEX-specific код в Astras не трогать.** Dormant функционал.

## Открытые вопросы которые могут возникнуть

Если возникнут вопросы которые не покрыты этим промптом — записать в `sprint_3_report.md` секцию "Открытые вопросы" с конкретикой. Не пытаться решить самостоятельно архитектурные вопросы.

Особенно записать если:
- ALOR orderbook format ожидает incremental updates (а не full snapshots) — тогда стратегия throttling меняется
- Sequence number gaps систематически встречаются — может потребоваться более сложная re-sync логика
- Какой-то Blotter tab требует endpoint которого нет в простом mapping ALOR ↔ Bybit
- Equity curve frontend ожидает специфический format (TradingView Lightweight Charts series format) который сложно построить из equity recorder JSONL
