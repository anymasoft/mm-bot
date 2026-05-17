# Sprint 4 (PIVOT): PMM Dynamic Strategy + Admin Panel + Custom Equity Tracker

## Контекст для Claude Code — ВАЖНО: КОНЦЕПЦИЯ ПРОЕКТА ИЗМЕНЕНА

После Sprint 3 пользователь сделал **strategic pivot**. Изначальный план Sprint 4 (Tauri wrap + Chart Trading Phase 1 + production auth) — **отменён**. Текущий план Sprint 4 концептуально другой.

**Что изменилось:**

1. **Bybit web UI становится primary visual layer** — для observing цен, активных ордеров на графике, manual override при необходимости. Пользователь открывает https://www.bybit.com/trade/usdt/BTCUSDT во второй вкладке параллельно с нашим Astras admin panel.

2. **Astras превращается в admin/control panel**, не в полноценный trading terminal. Мы перестаём дублировать функционал, который Bybit предоставляет бесплатно через свой web UI. Astras теперь только то, чего нет у Bybit:
   - Параметры PMM Dynamic стратегии (Avellaneda-Stoikov)
   - Кнопки Start/Stop/Pause/Reset
   - Action log стратегии (decision rationale stream)
   - Custom equity tracker chart с point-by-point точностью

3. **Hummingbot убирается из активной разработки.** Установка в WSL остаётся как dormant fallback. Стратегия PMM Dynamic реализуется **напрямую в TypeScript в bybit-adapter**. Это резко упрощает архитектуру: один процесс, один log file, прямой контроль из admin panel через REST adapter API.

4. **Главная цель Sprint 4 — выйти на demo trading самой стратегии.** Не строить идеальный UI. После Sprint 4 пользователь нажимает Start → стратегия размещает реальные ордера на Bybit demo → пользователь следит за их движением через Bybit web UI → видит equity dynamics в нашем custom tracker → может настраивать параметры на лету.

## Архитектурное решение: PMM Dynamic в TypeScript

Avellaneda-Stoikov алгоритм реализуется как новый module в `bybit-adapter/src/strategy/`. Не используем Hummingbot.

**Обоснование:**
- bybit-adapter уже имеет всю инфраструктуру: WS subscriptions (ticker, orderbook, executions, wallet), REST endpoints (place/amend/cancel orders), state management (orderbook-state.ts)
- Стратегия добавляется как класс, подписывается на existing events, вызывает existing methods
- Один процесс = простой lifecycle management, atomic config updates, единый log
- Параметры стратегии в JSON в репо, версионируются в git
- Нет subprocess management, нет REST gateway между процессами, нет path issues между Windows host и WSL

Hummingbot установка в WSL **не удаляется** — остаётся для возможной cross-validation реализации позже.

## 100% Open Source Constraint

Project memory hard constraint остаётся в силе. Перед `npm install` любого нового пакета — `npm view <package> license`. Allowed: MIT, Apache-2.0, BSD, ISC, MPL, GPL, LGPL. Blocked: anything proprietary, freemium, "free for non-commercial", trial-period, Commons Clause.

## Цель Sprint 4

После Sprint 4 пользователь:
1. Открывает Astras → выбирает tab `Crypto`
2. В widget "Strategy Control Panel" видит форму с параметрами PMM Dynamic, текущий status (Running/Stopped), кнопки управления
3. Нажимает Start → стратегия запускается на BTCUSDT demo
4. Открывает вторую вкладку браузера на https://www.bybit.com/trade/usdt/BTCUSDT — видит, как наши ордера появляются на графике, в стакане, двигаются согласно стратегии
5. В widget "Equity Tracker" видит точки изменения equity в реальном времени (каждая сделка → новая точка)
6. В widget "Strategy Action Log" видит decision rationale стрим: "Placed bid 67050 (ref price 67075, spread 25bps)", "Filled buy 0.001 @ 67050, inventory +0.001 BTC", "Cancelled bid: drifted 5bps from target", и т.д.
7. Может на лету менять параметры (например increase γ) → click Apply → стратегия учитывает new params без рестарта

## Эпики

### Epic A: PMM Dynamic Strategy Engine (bybit-adapter)

#### A.1: Структура module

Создать `bybit-adapter/src/strategy/`:

```
strategy/
├── pmm-dynamic.ts          # Main controller class
├── avellaneda-stoikov.ts   # Math: reservation price, optimal spread
├── inventory-manager.ts    # Inventory state, skew, target tracking
├── volatility-estimator.ts # Rolling σ from price returns
├── order-manager.ts        # Track active orders, place/cancel/amend
├── risk-manager.ts         # Daily PnL limits, max inventory, kill switch
├── action-logger.ts        # Decision rationale streaming via WS
├── config-schema.ts        # Zod schema для параметров
├── types.ts                # TypeScript interfaces
└── index.ts                # Exports
```

#### A.2: Avellaneda-Stoikov core math

Из academic paper (Avellaneda & Stoikov 2008):

```
Reservation price:
  r(s, q, t) = s - q * γ * σ² * (T - t)

Optimal spread:
  δ(t) = γ * σ² * (T - t) + (2/γ) * ln(1 + γ/k)

Где:
  s = mid price (текущий)
  q = inventory (positive = long, negative = short)
  γ = risk aversion (config parameter)
  σ = volatility (rolling std of mid price returns)
  T = time horizon (set to 1.0 для continuous trading)
  t = current time progress (always 0 для continuous)
  k = order arrival rate (estimated from orderbook depth)

Then:
  bid = r - δ/2
  ask = r + δ/2
```

Реализация в `avellaneda-stoikov.ts`:
```typescript
export function calculateReservationPrice(
  midPrice: number,
  inventory: number,
  riskAversion: number,
  volatility: number,
  timeHorizon: number = 1.0
): number {
  return midPrice - inventory * riskAversion * volatility * volatility * timeHorizon;
}

export function calculateOptimalSpread(
  riskAversion: number,
  volatility: number,
  orderArrivalRate: number,
  timeHorizon: number = 1.0
): number {
  const inventoryPart = riskAversion * volatility * volatility * timeHorizon;
  const arrivalPart = (2 / riskAversion) * Math.log(1 + riskAversion / orderArrivalRate);
  return inventoryPart + arrivalPart;
}

export function calculateBidAsk(
  reservationPrice: number,
  optimalSpread: number
): { bid: number; ask: number } {
  return {
    bid: reservationPrice - optimalSpread / 2,
    ask: reservationPrice + optimalSpread / 2,
  };
}
```

#### A.3: Volatility Estimator

Rolling standard deviation of mid-price log returns over configurable window:

```typescript
export class VolatilityEstimator {
  private prices: { ts: number; mid: number }[] = [];
  private windowSec: number;
  
  constructor(windowSec: number = 600) {
    this.windowSec = windowSec;
  }
  
  update(midPrice: number, timestamp: number = Date.now()) {
    this.prices.push({ ts: timestamp, mid: midPrice });
    // Drop entries older than window
    const cutoff = timestamp - this.windowSec * 1000;
    this.prices = this.prices.filter(p => p.ts >= cutoff);
  }
  
  getVolatility(): number {
    if (this.prices.length < 10) return 0.001;  // bootstrap minimum
    
    const returns: number[] = [];
    for (let i = 1; i < this.prices.length; i++) {
      const ret = Math.log(this.prices[i].mid / this.prices[i-1].mid);
      returns.push(ret);
    }
    
    const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
    const variance = returns.reduce((sum, r) => sum + (r - mean) ** 2, 0) / returns.length;
    return Math.sqrt(variance);
  }
}
```

#### A.4: Order Arrival Rate Estimation

`k` параметр в Avellaneda-Stoikov формуле — это intensity того, насколько часто наш ордер на конкретном distance от mid'а исполняется. Простая аппроксимация:
- `k` ≈ orderbook depth at near levels / time
- Можно использовать константу для начала: `k = 1.5` (default из Hummingbot)
- Расширенная version: считать fills history и calibrate

Для Sprint 4 — использовать константу из config (параметр `k_default = 1.5`), оставив TODO на adaptive calibration в Sprint 5.

#### A.5: Inventory Manager

Tracks current position size, calculates skew:

```typescript
export class InventoryManager {
  private inventoryBase: number = 0;  // в base currency (BTC)
  private targetInventory: number = 0;
  private maxInventory: number;
  
  constructor(maxInventoryBase: number, targetInventoryBase: number = 0) {
    this.maxInventory = maxInventoryBase;
    this.targetInventory = targetInventoryBase;
  }
  
  // Normalized inventory: -1.0 to +1.0
  getNormalizedInventory(): number {
    if (this.maxInventory === 0) return 0;
    return Math.max(-1, Math.min(1, this.inventoryBase / this.maxInventory));
  }
  
  // Skew factor для inventory bias в reservation price
  getInventoryDeviation(): number {
    return this.inventoryBase - this.targetInventory;
  }
  
  updateFromPosition(positionSize: number) {
    this.inventoryBase = positionSize;
  }
  
  isOverLimit(): boolean {
    return Math.abs(this.inventoryBase) >= this.maxInventory;
  }
  
  canBuy(amount: number): boolean {
    return this.inventoryBase + amount <= this.maxInventory;
  }
  
  canSell(amount: number): boolean {
    return this.inventoryBase - amount >= -this.maxInventory;
  }
}
```

#### A.6: Main Strategy Controller

```typescript
export class PMMDynamicStrategy {
  private config: PMMDynamicConfig;
  private state: 'stopped' | 'starting' | 'running' | 'paused' | 'stopping' | 'error' = 'stopped';
  
  private volatilityEstimator: VolatilityEstimator;
  private inventoryManager: InventoryManager;
  private orderManager: OrderManager;
  private riskManager: RiskManager;
  private actionLogger: ActionLogger;
  
  private refreshTimer: NodeJS.Timeout | null = null;
  
  async start() {
    if (this.state !== 'stopped') {
      throw new Error(`Cannot start, current state: ${this.state}`);
    }
    
    this.state = 'starting';
    this.actionLogger.log('strategy_start', { config: this.config });
    
    // 1. Subscribe to ticker, orderbook, wallet, position, execution WS feeds
    this.subscribeFeeds();
    
    // 2. Initial position fetch (sync inventory state)
    await this.syncInventoryFromBybit();
    
    // 3. Cancel any existing orders left from previous run
    await this.cancelAllOurOrders();
    
    // 4. Start refresh loop
    this.refreshTimer = setInterval(
      () => this.refreshOrders(),
      this.config.order_refresh_interval_sec * 1000
    );
    
    this.state = 'running';
    this.actionLogger.log('strategy_running', {});
  }
  
  async stop() {
    if (this.state === 'stopped') return;
    
    this.state = 'stopping';
    this.actionLogger.log('strategy_stop', { reason: 'manual' });
    
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = null;
    }
    
    await this.cancelAllOurOrders();
    this.unsubscribeFeeds();
    
    this.state = 'stopped';
  }
  
  private async refreshOrders() {
    try {
      // 1. Get current mid price
      const mid = this.getCurrentMidPrice();
      if (!mid) return;
      
      // 2. Update volatility
      this.volatilityEstimator.update(mid);
      const sigma = this.volatilityEstimator.getVolatility();
      
      // 3. Calculate reservation price + spread (Avellaneda-Stoikov)
      const inventory = this.inventoryManager.getInventoryDeviation();
      const reservationPrice = calculateReservationPrice(
        mid, inventory, this.config.gamma, sigma, this.config.T
      );
      const optimalSpread = calculateOptimalSpread(
        this.config.gamma, sigma, this.config.k_default, this.config.T
      );
      
      // 4. Apply min/max spread constraints
      const minSpread = mid * (this.config.min_spread_bps / 10000);
      const maxSpread = mid * (this.config.max_spread_bps / 10000);
      const effectiveSpread = Math.max(minSpread, Math.min(maxSpread, optimalSpread));
      
      let targetBid = reservationPrice - effectiveSpread / 2;
      let targetAsk = reservationPrice + effectiveSpread / 2;
      
      // 5. Round to tick size
      targetBid = this.roundToTickSize(targetBid, 'down');
      targetAsk = this.roundToTickSize(targetAsk, 'up');
      
      // 6. Risk checks
      if (this.riskManager.shouldStop()) {
        await this.stop();
        return;
      }
      
      // 7. Cancel orders that drifted too far, place new ones
      await this.orderManager.reconcile({
        targetBid,
        targetAsk,
        orderAmount: this.config.order_amount,
        canBuy: this.inventoryManager.canBuy(this.config.order_amount),
        canSell: this.inventoryManager.canSell(this.config.order_amount),
        cancelThreshold: this.config.cancel_threshold_bps,
      });
      
      // 8. Log decision
      this.actionLogger.log('refresh', {
        mid, sigma, inventory,
        reservationPrice, effectiveSpread,
        targetBid, targetAsk,
      });
      
    } catch (err) {
      this.actionLogger.log('refresh_error', { error: String(err) });
      // Don't crash strategy on transient errors
    }
  }
  
  // ... handlers for fill events, position updates, etc.
}
```

#### A.7: Config Schema (Zod)

```typescript
import { z } from 'zod';

export const PMMDynamicConfigSchema = z.object({
  // Avellaneda-Stoikov core
  gamma: z.number().min(0.01).max(2.0).default(0.5),
  T: z.number().min(0.1).max(10.0).default(1.0),
  k_default: z.number().min(0.1).max(10.0).default(1.5),
  sigma_window_sec: z.number().int().min(60).max(7200).default(600),
  
  // Order management
  symbol: z.string().default('BTCUSDT'),
  order_amount: z.number().min(0.0001).max(1.0).default(0.001),
  order_levels: z.number().int().min(1).max(5).default(1),
  min_spread_bps: z.number().min(0.1).max(1000).default(5),
  max_spread_bps: z.number().min(0.1).max(1000).default(100),
  order_refresh_interval_sec: z.number().int().min(1).max(300).default(10),
  cancel_threshold_bps: z.number().min(0.1).max(100).default(3),
  
  // Inventory management
  max_inventory_base: z.number().min(0.0001).max(10).default(0.05),
  target_inventory_base: z.number().default(0),
  inventory_skew_enabled: z.boolean().default(true),
  
  // Risk management
  daily_pnl_stop_loss_usdt: z.number().min(0).max(100000).default(50),
  daily_pnl_take_profit_usdt: z.number().min(0).max(100000).default(200),
  max_orders_per_side: z.number().int().min(1).max(10).default(1),
  
  // Operational
  enabled: z.boolean().default(false),
  dry_run: z.boolean().default(true),  // По умолчанию dry run для безопасности
});

export type PMMDynamicConfig = z.infer<typeof PMMDynamicConfigSchema>;
```

**Где хранить config:** `bybit-adapter/config/strategy.json`, в `.gitignore`. Шаблон в `bybit-adapter/config/strategy.example.json`.

#### A.8: REST endpoints для admin panel

В `bybit-adapter/src/routes/strategy.ts`:

```
GET    /strategy/status               -> текущее state, last action timestamp
GET    /strategy/config               -> current config JSON
POST   /strategy/config               -> update config (validates via Zod)
POST   /strategy/start                -> запустить strategy
POST   /strategy/stop                 -> остановить + cancel all our orders
POST   /strategy/pause                -> приостановить (не cancel orders, не размещать новые)
POST   /strategy/resume               -> resume from pause
GET    /strategy/actions              -> last N actions из action log
GET    /strategy/metrics              -> session PnL, trades count, fill rate
```

#### A.9: WS broadcast для action log

Когда стратегия логирует action — broadcast в WS topic `strategy.actions`. Frontend subscribe → live stream в Action Log widget.

```typescript
// В action-logger.ts
class ActionLogger {
  log(event: string, data: any) {
    const entry = {
      timestamp: new Date().toISOString(),
      event,
      data,
    };
    
    // 1. Persist to JSONL file
    this.appendToFile(entry);
    
    // 2. Broadcast to WS subscribers
    this.wsServer.broadcast('strategy.actions', entry);
  }
}
```

### Epic B: Admin Panel UI (Astras)

Создать **новый Astras widget** в `astras-bybit-ui/src/app/features/strategy-control/`:

#### B.1: Widget структура

Three sub-components in single widget:

```
Strategy Control Panel
├── Status header (Running/Stopped/Paused, Start/Stop/Pause buttons, Apply button)
├── Parameters form (collapsed by default)
│   ├── Core: γ, T, k, σ window
│   ├── Orders: amount, levels, min/max spread, refresh interval, cancel threshold
│   ├── Inventory: max, target, skew enabled
│   ├── Risk: daily SL, daily TP, max orders/side
│   ├── Operational: symbol, dry run toggle
│   └── Buttons: Reset to defaults, Apply changes
└── Metrics summary (Session PnL, fills count, avg spread captured, inventory current)
```

#### B.2: Action Log widget (отдельный)

Создать отдельный widget `strategy-action-log`:
- Subscribes на WS `strategy.actions`
- Append-only список (auto-scroll к последнему)
- Filter by event type (refresh / fill / cancel / error / start / stop)
- Каждая строка: `[HH:MM:SS] event_type | rationale data`
- Capped at last 500 entries в memory, rest в file

Пример отображения:
```
[18:30:45] refresh    mid=67082 σ=0.0012 inv=+0.001 r=67081 spread=8.5bps bid=67078 ask=67086
[18:30:48] order_placed   bid=67078 qty=0.001 orderId=abc123
[18:30:48] order_placed   ask=67086 qty=0.001 orderId=def456
[18:30:55] fill   side=buy price=67078 qty=0.001 inv=+0.002 realizedPnL=+0.02
[18:30:58] order_cancelled   orderId=abc123 reason=drifted_5bps
[18:31:01] order_placed   bid=67075 qty=0.001 orderId=ghi789
```

#### B.3: Crypto layout update

Обновить default Crypto dashboard:

```
┌─────────────────────────────────────────────────────────────────┐
│  Strategy Control Panel        │  Custom Equity Tracker         │
│  (params, buttons, metrics)    │  (point-by-point chart)        │
│  (50% width, 50% height)       │  (50% width, 50% height)       │
├────────────────────────────────┴────────────────────────────────┤
│                                                                  │
│  Strategy Action Log                                             │
│  (live stream of strategy decisions)                             │
│  (100% width, 50% height)                                        │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

Существующие виджеты (chart, orderbook, order form) **удалить** из Crypto dashboard — они теперь не нужны там. Пользователь смотрит price action на Bybit web. Эти виджеты остаются доступными через "Виджеты" меню для manual trading сценариев, но в default Crypto layout их нет.

### Epic C: Custom Equity Tracker Widget

Создать новый widget `equity-tracker` в `astras-bybit-ui/src/app/features/equity-tracker/`.

#### C.1: Event-driven equity recorder (полный rewrite)

**Critical:** equity recorder из Sprint 2 был **time-based polling** (snapshot каждые 60 секунд независимо от изменений). Это создавало шум — постоянные одинаковые точки в графике даже когда ничего не происходило.

**Новая логика — event-driven, change-only recording:**

```typescript
class EquityRecorder {
  private lastRecordedWallet: number | null = null;
  private readonly threshold: number = 0.01;  // USDT, минимальное изменение для записи
  
  onWalletUpdate(walletData: BybitWalletUpdate) {
    const walletBalance = parseFloat(walletData.totalWalletBalance);
    const totalEquity = parseFloat(walletData.totalEquity);
    const unrealizedPnl = parseFloat(walletData.totalPerpUPL);  // или эквивалент
    
    // Записываем только если walletBalance изменился существенно
    if (this.lastRecordedWallet === null || 
        Math.abs(walletBalance - this.lastRecordedWallet) >= this.threshold) {
      
      const deltaWallet = this.lastRecordedWallet !== null 
        ? walletBalance - this.lastRecordedWallet 
        : 0;
      
      const point = {
        timestamp: new Date().toISOString(),
        walletBalance,
        totalEquity,
        unrealizedPnl,
        deltaWallet,
        deltaEquity: this.lastRecordedEquity !== null 
          ? totalEquity - this.lastRecordedEquity 
          : 0,
      };
      
      this.appendToJsonl(point);
      this.broadcastToWS('equity.update', point);
      this.lastRecordedWallet = walletBalance;
      this.lastRecordedEquity = totalEquity;
    }
  }
}
```

**Ключевые detail:**

- **Точка появляется только при реальном изменении wallet balance** (не по таймеру). Если рынок встал и ни одна сделка не прошла — на графике 0 новых точек.
- **Threshold = 0.01 USDT** (1 цент). Это отсекает floating-point noise от mark price recalculation в `totalEquity`, capture'ит все meaningful changes (fills, fees). Параметр в config, можно подстроить.
- **Trigger source = walletBalance changes**, не totalEquity. WalletBalance меняется только при реальных realized событиях (filled orders, fees). TotalEquity дёргается на каждом mark price update даже без сделок — это шум для tracking "реальной прибыли стратегии".
- **Каждая точка содержит обе метрики** (walletBalance И totalEquity И unrealizedPnl), чтобы frontend мог toggle между видами.

**Backend endpoint `GET /equity/stream`:**
- Возвращает массив точек из equity recorder JSONL
- Каждая точка: `{ index, timestamp, walletBalance, totalEquity, unrealizedPnl, deltaWallet, deltaEquity }`
- Параметры: `?from=<ISO>&to=<ISO>&limit=<N>`
- Default: последние 1000 точек

**Time-based polling убирается полностью.** Старая логика "snapshot каждые N секунд" удаляется из equity-recorder. Если за час ничего не торговалось — за час 0 точек. Это правильно.

#### C.2: Frontend widget

Использует Lightweight Charts line series, но с **категориальной X axis**:

```typescript
// equity-tracker.component.ts
@Component({...})
export class EquityTrackerComponent {
  private chart: IChartApi;
  private lineSeries: ISeriesApi<'Line'>;
  
  async ngOnInit() {
    this.chart = createChart(this.container.nativeElement, {
      layout: { /* light theme */ },
      // Critical: НЕ time-based, используем числовой index
      rightPriceScale: { scaleMargins: { top: 0.1, bottom: 0.1 } },
      timeScale: {
        timeVisible: false,  // Скрываем дефолтные time labels
        secondsVisible: false,
      },
    });
    
    this.lineSeries = this.chart.addLineSeries({
      color: 'rgb(38, 166, 154)',
      lineWidth: 2,
      crosshairMarkerVisible: true,
    });
    
    // Load initial data
    const data = await this.fetchEquityStream();
    this.renderData(data);
    
    // Subscribe to live updates via WS
    this.subscribeWS();
  }
  
  private renderData(points: EquityPoint[]) {
    const seriesData = points.map((p, idx) => ({
      time: idx as Time,  // Используем index как "time" — Lightweight Charts требует time field
      value: p.equity,
    }));
    this.lineSeries.setData(seriesData);
    
    // Store mapping для tooltip: index → timestamp
    this.indexToTimestamp = new Map(points.map((p, idx) => [idx, p.timestamp]));
  }
  
  // Кастомный tooltip через crosshair subscribe
  private setupTooltip() {
    this.chart.subscribeCrosshairMove((param) => {
      if (param.time !== undefined && this.indexToTimestamp.has(+param.time)) {
        const timestamp = this.indexToTimestamp.get(+param.time);
        const value = param.seriesData.get(this.lineSeries) as LineData;
        this.showCustomTooltip(timestamp, value.value, param.point);
      }
    });
  }
}
```

#### C.3: Tooltip requirements

При hover на точку — кастомный HTML tooltip (absolute positioned div):
```
┌──────────────────────────────────┐
│ 18:30:45 17.05.2026              │
│ Wallet Balance: 1 004.50 USDT    │
│ Total Equity:   1 006.20 USDT    │
│ Unrealized PnL: +1.70 USDT       │
│ Δ wallet:       +0.50 (+0.05%)   │
└──────────────────────────────────┘
```

#### C.4: View toggle

Widget header содержит toggle между двумя view modes:
- **Wallet Balance** (default) — линия по `walletBalance` значениям. Это "чистая" прибыль стратегии без шума mark price.
- **Total Equity** — линия по `totalEquity`. Включает unrealized PnL открытых позиций.

Toggle switches data source без перезагрузки страницы — данные уже все есть в state.

#### C.5: Auto-scroll

При новой точке (WS update `equity.update`) — auto-scroll к right edge. Использовать `chart.timeScale().scrollToRealTime()` или manual `chart.timeScale().setVisibleRange()`.

### Epic D: Bybit Web UI Workflow Documentation

Создать `mm-bot/docs/USAGE_BYBIT_WEB.md` — инструкция как пользоваться комбинацией Astras + Bybit web для торговли:

```markdown
# Workflow: Astras Admin Panel + Bybit Web UI

## Setup

1. Открыть две вкладки в браузере:
   - **Tab 1**: http://localhost:4200 — наш Astras admin panel
   - **Tab 2**: https://www.bybit.com/trade/usdt/BTCUSDT — Bybit Demo trading

2. На Bybit web включить:
   - Переключатель "Демо трейдинг" (демо-режим, виртуальные деньги)
   - Русский интерфейс через settings
   - Light theme (если предпочитается)

## Workflow

1. **Старт стратегии:**
   - Tab 1 (Astras) → Strategy Control Panel
   - Проверить параметры в форме (γ, spread bps, order amount, etc.)
   - **Выключить `dry_run` toggle** (по умолчанию включён для безопасности!)
   - Click Start
   - Status должен стать "Running"

2. **Visual monitoring:**
   - Tab 2 (Bybit) → chart BTCUSDT → видны ордера стратегии как horizontal lines на графике
   - Tab 2 → "Книга ордеров" — видны bids/asks стратегии в стакане как highlighted уровни
   - Tab 2 → активные ордера в нижней панели — список ордеров с возможностью manual cancel

3. **Equity tracking:**
   - Tab 1 → Custom Equity Tracker → точечный график каждого изменения equity
   - Hover на точку → datetime + value tooltip
   - Auto-scroll к последней точке

4. **Action log:**
   - Tab 1 → Strategy Action Log → live stream решений стратегии
   - Filter by event type для focus на specific events (fills, errors, etc.)

5. **Manual override:**
   - Если нужно вмешаться — Tab 2 (Bybit) → правый клик на ордере → Cancel или Modify
   - Стратегия увидит cancellation через WS, log'нет в action log, переразместит ордер на следующем refresh

6. **Изменение параметров на лету:**
   - Tab 1 → Strategy Control Panel → изменить значение (например γ с 0.5 на 0.8)
   - Click Apply
   - Стратегия применит new params на следующем refresh без рестарта

7. **Стоп:**
   - Tab 1 → Strategy Control Panel → Stop
   - Все наши ордера будут отменены, стратегия остановится

## Что НЕ нужно делать

- Не размещать ручные ордера через Astras (Order Form widget) во время работы стратегии — конфликты неизбежны
- Не торговать на том же account через мобильное приложение Bybit во время работы стратегии
- Не использовать Hummingbot одновременно с нашей стратегией (один account, конфликты)
```

### Epic E: Hummingbot Deprecation (но не удаление)

Hummingbot остаётся в WSL как dormant fallback.

Действия:
1. В `mm-bot/README.md` обновить секцию архитектуры — указать что Hummingbot теперь optional/experimental, primary strategy реализована в bybit-adapter
2. В `mm-bot/USAGE.md` — добавить заметку что Hummingbot не нужно запускать в обычном workflow
3. Файл `mm-bot/docs/architecture/strategy_engine.md` — описание новой архитектуры (TypeScript implementation, почему не Hummingbot, как переключиться при необходимости)
4. Удалить из `package.json` (`mm-bot` корневой) `npm run dev` зависимости от Hummingbot если есть. `npm run dev` запускает только bybit-adapter + astras-bybit-ui.

### Epic F: Updates and bug fixes из Sprint 3 open questions

1. **Equity recorder rewrite to event-driven** — see Epic C.1. Time-based polling убирается полностью. Recorder подписан на wallet WS topic, на каждый update сравнивает walletBalance с last recorded — записывает точку только при изменении ≥ 0.01 USDT. Каждая точка содержит walletBalance + totalEquity + unrealizedPnl + deltas. Backend broadcasts через WS topic `equity.update` для frontend live updates. Trigger source = walletBalance (не totalEquity), чтобы не записывать mark price noise.

2. **WS order topic дубликаты** — добавить filter в WS handler:
```typescript
// Если order имеет stopOrderType != null/none → отправлять только в stoporders subscription, не в orders
```

## Что НЕ делаем в Sprint 4

- **Tauri 2.0 wrap** — отложен на post-validation phase (Sprint 7+ если стратегия работает)
- **Chart Trading в Astras** — отменено, используем Bybit web
- **Drag-to-move orders в Astras** — отменено
- **Order Book widget improvements** — не нужно, Bybit web справляется
- **Production-grade authentication** — отложено
- **Mobile responsive** — отложено
- **Удаление Order Book / Chart widgets из Astras совсем** — не удаляем код, просто убираем из default Crypto layout
- **Hummingbot uninstall** — оставляем dormant
- **Backtest integration** — Sprint 5
- **Parameter optimization (grid search / Optuna)** — Sprint 5

## Definition of Done для Sprint 4

1. **Strategy engine работает:**
   - `POST /strategy/start` запускает стратегию
   - Стратегия размещает ордера на Bybit demo через bybit-adapter REST
   - При volatility increase — spread увеличивается (видно в action log)
   - При inventory bias — reservation price сдвигается (видно в action log)
   - `POST /strategy/stop` корректно отменяет все наши ордера и останавливает loop

2. **Admin panel UI:**
   - Strategy Control Panel widget виден в Crypto tab
   - Все параметры формы соответствуют PMMDynamicConfigSchema
   - Start/Stop/Pause/Apply кнопки работают
   - Reset to defaults восстанавливает значения

3. **Action log:**
   - Strategy Action Log widget показывает live stream решений
   - WS subscription работает, обновления приходят без рефреша
   - Filter by event type работает
   - Auto-scroll к новым записям

4. **Custom Equity Tracker:**
   - Виджет показывает point-by-point equity changes
   - Каждый flush (5s интервал) + каждый fill → новая точка
   - Tooltip показывает datetime + value + delta
   - Auto-scroll работает

5. **Documentation:**
   - `USAGE_BYBIT_WEB.md` создан с workflow
   - `mm-bot/README.md` обновлён под новую архитектуру
   - `docs/architecture/strategy_engine.md` создан

6. **Smoke test demo trading:**
   - Запустить стратегию с conservative params (gamma=0.5, order_amount=0.001 BTC, min_spread=5bps, dry_run=false) на BTCUSDT demo
   - Дать поработать 30 минут
   - В Bybit web tab убедиться что наши ордера появляются в стакане и на графике
   - В Astras equity tracker увидеть как минимум несколько точек
   - В action log увидеть refresh decisions + fills

7. **OSS audit:**
   - sprint_4_oss_audit.md создан
   - Все новые dependencies — OSI-approved licenses

8. **Все три репо обновлены, push'ed**, URLs последних commits в чат архитектору.

## Workflow

1. Прочитать этот промпт целиком, понять смысл pivot'а
2. Положить копию в `mm-bot/docs/sprint_prompts/sprint_4_pivot_strategy_first.md`
3. Эпики делаем в порядке: A → B+C (параллельно) → D+E+F
4. После каждого Epic — micro commit
5. После Epic A — manual smoke test через curl (запустить стратегию в dry_run mode, проверить логи)
6. После Epic B+C — UI verification (пользователь увидит через npm run dev)
7. После всех эпиков — финальный smoke test на demo
8. Sprint 4 report → push 3 репо → URLs

## Расчётный timeline

15-20 рабочих дней. Возможные тормоза:
- Volatility estimator может потребовать adaptive bootstrap при cold start
- Bybit V5 order rejection edge cases (min order size, max orders per side)
- WS reconnect mid-strategy execution — нужна graceful recovery
- Custom equity tracker tooltip implementation — требует careful chart event handling

## Замечания для Claude Code

1. **PIVOT — это не отказ от Sprint 1-3 работы.** bybit-adapter, astras-bybit-ui, OSS audit, WS stability — всё используется. Pivot только в **scope**: что строим дальше.

2. **Hummingbot не трогать.** Установка в WSL остаётся, не запускаем, документируем как fallback. Никаких uninstall.

3. **Default dry_run=true.** Это критично. Pвiотом для безопасного тестирования логики. Пользователь явно выключит когда захочет реальное demo trading.

4. **Validate ВСЁ через Zod** на input в config. Невалидный config → reject с понятной ошибкой, стратегия не должна стартовать с broken params.

5. **Action log первым делом.** Без него ничего не отлажить. Логировать всё что делает стратегия.

6. **Не оптимизировать стратегию в Sprint 4.** Goal — работающий MVP. Tuning параметров — Sprint 5. Sub-optimal performance в Sprint 4 — OK, главное чтобы logic работала.

7. **Tick size rounding обязателен.** Перед placement каждого ордера — round price к instrument tick size (получить через `instruments-info` endpoint Bybit, уже есть в adapter).

8. **Cancel orders при stop — обязательно.** Никаких leftover orders после Stop click.

9. **Не использовать тестовое окружение для PMM при unstable WS.** Если WS reconnect — стратегия должна pause, дождаться reconnect, sync state, resume. Не пытаться trade при unknown state.

10. **При первом запуске на Bybit demo — order_amount=0.001 BTC, max_inventory=0.01 BTC**. Это микро-объёмы, не повредит даже если логика broken. Tuning размеров — позже.

11. **Equity recorder — event-driven, не time-based**. См. Epic C.1 + Epic F. Точка пишется только при изменении walletBalance ≥ 0.01 USDT. Если рынок встал и нет fills — 0 новых точек. Это правильное поведение, не bug.

12. **Не запускать на mainnet.** Только Bybit demo для всего Sprint 4. Mainnet — после validation в Sprint 5-6.

## Open Questions which might emerge

Записать в `sprint_4_report.md` секцию "Открытые вопросы", если возникнут:
- Подходящие defaults для PMM параметров на BTCUSDT (γ, k) — требуется experimentation
- Bybit demo trading имеет особенности (например искусственная ликвидность) — могут влиять на fill rate
- WebSocket multiplexing strategy.actions через тот же WS endpoint, или отдельный — архитектурное решение
- Persisting strategy config — JSON file vs adapter REST endpoint
