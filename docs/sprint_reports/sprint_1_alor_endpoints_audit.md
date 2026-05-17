# Astras-Trading-UI ALOR API Audit Report
## Sprint 1 MVP Endpoint Discovery

**Generated**: 2025-05-17  
**Target**: Bybit Adapter (Minimal Implementation for Manual Trading on BTCUSDT)  
**Source Codebase**: `C:\BUFFER\mm-bot\astras-bybit-ui\` (Angular 21, Fastify frontend)

---

## Executive Summary

Astras-Trading-UI is a sophisticated multi-broker trading frontend (primarily targeting MOEX/Forex/FX via ALOR API). Analysis covers 60+ service files in `src/app/shared/services/` and modules to extract **HTTP endpoints** and **WebSocket opcodes** actually used in the trading workflow.

**Key Architecture Insights:**
- Dual transport: REST for static data (instruments, history, account info) + WebSocket (wss://apidev.alor.ru/ws and wss://apidev.alor.ru/cws) for live updates
- Auth: JWT token from `ssoUrl` (`https://login-dev.alor.ru`), passed in all requests via `token` field
- Client data API (`clientDataUrl: https://lk-api-dev.alorbroker.ru`) handles user portfolios separately
- WS uses guid-based multiplexing for subscription tracking and confirm responses
- Prices/volumes mostly as `float`, timestamps as Unix seconds, field names `camelCase`, exchanges as strings like "MOEX"

---

## A. REST Endpoints (HTTP)

### Legend
- **Base URL**: Which environment variable (apiUrl/clientDataUrl/etc.)
- **Priority**: CRITICAL (7 MVP features) / MEDIUM (UI works with defaults) / LOW (can stub)
- **Service File**: where Angular service calls this endpoint
- **Request/Response**: extracted from TypeScript models

---

### 1. Authentication & User

| Method | Path | Base | Service | Purpose | Priority | Request | Response |
|--------|------|------|---------|---------|----------|---------|----------|
| **SSO** (external) | `/auth/login` or similar | ssoUrl | (Firebase/SSO service) | Obtain JWT token for subsequent requests | CRITICAL | `{login, password}` or OAuth | `{token, expirationTime, refreshCallback}` |
| GET | `/client/v1.0/users/{login}/full-name` | clientDataUrl | `account.service.ts` | Get user full name | MEDIUM | — | `{firstName, middleName, lastName}` |
| GET | `/client/v1.0/users/{clientId}/all-portfolios` | clientDataUrl | `account.service.ts` | List all available portfolios for user | CRITICAL | — | `PortfolioMeta[]` = `{portfolio, exchange, market, isVirtual, ...}` |
| GET | `/client/v2.0/agreements/{agreement}/portfolios/any/dynamics` | clientDataUrl | `account.service.ts` | Portfolio equity curve (P&L over time) | MEDIUM | Query: `startDate` (ISO), `endDate` (ISO) | `{portfolioValues: [{date, value}, ...]}` |

---

### 2. Instruments & Market Data (REST)

| Method | Path | Base | Service | Purpose | Priority | Request | Response |
|--------|------|------|---------|---------|----------|---------|----------|
| GET | `/md/v2/Securities/{exchange}/{symbol}` | apiUrl | `instruments.service.ts:25` | Get single instrument details | CRITICAL | Query: `instrumentGroup?` | `{symbol, shortname, description, exchange, board/primary_board, ISIN, currency, minstep, pricestep, lotsize, cfiCode, type, marginbuy/marginsell, cancellation (expiry), tradingStatus, market}` |
| GET | `/md/v2/Securities` | apiUrl | `instruments.service.ts:69` | Search instruments by filter | MEDIUM | Query: `{symbol?, exchange?, code?, IncludeUnknownBoards=false, ...filter}` | `InstrumentSearchResponse[]` (array of instrument objects) |
| GET | `/md/v2/Securities/{exchange}/{symbol}/availableBoards` | apiUrl | `instruments.service.ts:94` | Get all trading boards for instrument | LOW | — | `string[]` (board names) |
| GET | `/md/v2/Securities/{exchange}:{symbol}/quotes` | apiUrl | `quotes.service.ts:66` | Get latest quote/price snapshot | CRITICAL | — | `Quote[] = {last_price, bid, ask, total_bid_vol, total_ask_vol, ...}` (returns array, take first) |

---

### 3. Order History & Candles

| Method | Path | Base | Service | Purpose | Priority | Request | Response |
|--------|------|------|---------|---------|----------|---------|----------|
| GET | `/md/v2/history` | apiUrl | `history.service.ts:25` | Get candle/OHLC history | CRITICAL | Query: `{symbol, exchange, tf (timeframe), from (unix sec), to (unix sec), countBack?}` | `{history: [{open, high, low, close, volume, time, ...}, ...]}` |
| GET | `/md/v2/Securities/{exchange}/{symbol}/alltrades` | apiUrl | `all-trades.service.ts:44` | Get all trades (tick history) | MEDIUM | Query: `{instrumentGroup?, pagination (skip/take), sort (field/order)}` | `AllTradesItem[]` = `{id, price, volume, side, time, ...}` |
| GET | `/md/v2/Clients/{login}/positions` | apiUrl | `positions.service.ts:29` | List positions for login | CRITICAL | — | `PositionResponse[]` = `{symbol, exchange, portfolio, qty, avgPrice, expectedYield, ...}` |
| GET | `/md/v2/Clients/{exchange}/{portfolio}/positions` | apiUrl | `positions.service.ts:34` | List positions for portfolio | CRITICAL | — | `PositionResponse[]` |

---

### 4. Order Evaluation & Cost Estimation

| Method | Path | Base | Service | Purpose | Priority | Request | Response |
|--------|------|------|---------|---------|----------|---------|----------|
| POST | `/commandapi/warptrans/FX1/v2/client/orders/estimate` | apiUrl | `evaluation.service.ts:19` | Estimate commission/fees for order | MEDIUM | `{portfolio, ticker, exchange, board, price, lotQuantity, includeLimitOrders: true}` | `{commission, marginRequired, riskAmount, ...}` |
| POST | `/commandapi/warptrans/FX1/v2/client/orders/estimate/all` | apiUrl | `evaluation.service.ts:41` | Batch estimate multiple orders | LOW | `[{portfolio, ticker, exchange, board, budget, price}, ...]` | `Evaluation[]` |

---

### 5. Account & Portfolio Position (REST)

| Method | Path | Base | Service | Purpose | Priority | Request | Response |
|--------|------|------|---------|---------|----------|---------|----------|
| GET | `/md/v2/Clients/{login}/positions` | apiUrl | `positions.service.ts:29` | Get all positions by login (for portfolio enumeration) | CRITICAL | — | `PositionResponse[]` |

---

## B. WebSocket Protocol

### Connection Details

- **Primary WS URLs**:
  - `wss://apidev.alor.ru/ws` — subscription data feed (quotes, orderbook, candles, positions, orders, trades)
  - `wss://apidev.alor.ru/cws` — command/order submission WebSocket (placed orders)

### Message Format (Generic)

**Client → Server (Subscription Request)**:
```json
{
  "opcode": "OrderBookGetAndSubscribe",
  "code": "BTCUSDT",
  "exchange": "BYBIT",
  "instrumentGroup": "SPOT",
  "depth": 20,
  "format": "slim",
  "guid": "uuid-v4-generated-by-client",
  "token": "jwt-token-from-auth",
  "repeatCount": 1
}
```

**Server → Client (Subscription Response with Multiplexing)**:
```json
{
  "guid": "uuid-matching-request",
  "data": {
    "a": [{"p": 100.50, "v": 1.5}, ...],  // asks (price, volume)
    "b": [{"p": 100.40, "v": 2.0}, ...]   // bids
  }
}
```

**Unsubscribe Message**:
```json
{
  "opcode": "unsubscribe",
  "guid": "uuid-of-subscription",
  "token": "jwt-token"
}
```

**Ping/Pong** (heartbeat every 30s by default):
```json
{
  "opcode": "ping",
  "guid": "uuid",
  "confirm": true,
  "token": "jwt-token"
}
```

---

### Data Feed WebSocket Opcodes (Subscriptions)

Handled by: `src/app/shared/services/subscriptions-data-feed.service.ts`

| Opcode | Handler Service | Purpose | Subscribe Payload | Expected Data in Response | Multiplexing |
|--------|-----------------|---------|-------------------|--------------------------|--------------
| **OrderBookGetAndSubscribe** | `orderbook.service.ts` (via OrderBookDataFeedHelper) | Live orderbook (depth snapshot + updates) | `{opcode, code, exchange, instrumentGroup?, depth, format: "slim"\|"full", guid, token}` | `{data: {a: [{p, v}, ...], b: [{p, v}, ...]}}` | guid-based, one subscription per symbol+exchange+depth |
| **BarsGetAndSubscribe** | `candles.service.ts` | Live candlestick data | `{opcode, code, exchange, instrumentGroup?, format: "simple", tf, from (unix sec), guid, token}` | `{data: Candle}` (incremental updates) | guid-based |
| **QuotesSubscribe** | `quotes.service.ts` | Latest quote/price tick | `{opcode, code, exchange, instrumentGroup?, format: "simple", guid, token}` | `{data: {last_price, bid, ask, volume, ...}}` | guid-based |
| **AllTradesSubscribe** | `all-trades.service.ts` | Live tick data | `{opcode, code, exchange, instrumentGroup?, depth?, format: "simple", guid, token, repeatCount?}` | `{data: {id, price, volume, side, time, ...}}` | guid-based |
| **PositionsGetAndSubscribeV2** | `portfolio-subscriptions.service.ts` | Live portfolio positions (per portfolio+exchange) | `{opcode, portfolio, exchange, guid, token, skipHistory?: true}` | `{data: PositionResponse}` (per-instrument updates) | guid-based, subscription_key = "opcode_portfolio_exchange" |
| **OrdersGetAndSubscribeV2** | `portfolio-subscriptions.service.ts` | Live active orders (per portfolio) | `{opcode, portfolio, exchange, format: "heavy", skipHistory?: true, guid, token}` | `{data: OrderResponse}` (per-order updates) | guid-based |
| **StopOrdersGetAndSubscribeV2** | `portfolio-subscriptions.service.ts` | Live stop orders | `{opcode, portfolio, exchange, guid, token, skipHistory?: true}` | `{data: StopOrderResponse}` | guid-based |
| **TradesGetAndSubscribeV2** | `portfolio-subscriptions.service.ts` | Live filled trades/executions | `{opcode, portfolio, exchange, format: "heavy", skipHistory?: true, guid, token}` | `{data: TradeResponse}` (per-trade) | guid-based |
| **SummariesGetAndSubscribeV2** | `portfolio-subscriptions.service.ts` | Portfolio summary (P&L, margin, cash, etc.) | `{opcode, portfolio, exchange, guid, token}` | `{data: CommonSummaryModel}` (buying power, equity, P&L, etc.) | guid-based |
| **RisksGetAndSubscribe** | `portfolio-subscriptions.service.ts` | Portfolio risk limits | `{opcode, portfolio, exchange, guid, token}` | `{data: Risks}` | guid-based |
| **SpectraRisksGetAndSubscribe** | `portfolio-subscriptions.service.ts` | Advanced risk (Spectra module) | `{opcode, portfolio, exchange, guid, token}` | `{data: ForwardRisks}` | guid-based |

---

### Command WebSocket (Order Submission)

Handled by: `src/app/client/services/orders/ws-orders-connector.ts` and `client-order-command.service.ts`

**Connection**: `wss://apidev.alor.ru/cws` (separate from data feed ws)

| Opcode | Purpose | Request Payload | Response | Status Code |
|--------|---------|-----------------|----------|-------------|
| **submit:Limit** | Place limit order | `{opcode: "submit:Limit", guid, token, user: {portfolio}, ticker, exchange, board, side, quantity, price, timeInForce, orderEndUnixTime?, ...}` | `{requestGuid, httpCode, message, orderNumber?}` | 200 = success |
| **submit:Market** | Place market order | `{opcode: "submit:Market", guid, token, user: {portfolio}, ticker, exchange, board, side, quantity, ...}` | `{requestGuid, httpCode, message, orderNumber?}` | 200 = success |
| **submit:StopMarket** | Place stop-market order | `{opcode: "submit:StopMarket", guid, token, user: {portfolio}, ticker, exchange, board, side, quantity, triggerPrice, condition ("Less"\|"More"), ...}` | `{requestGuid, httpCode, message, orderNumber?}` | 200 = success |
| **submit:StopLimit** | Place stop-limit order | `{opcode: "submit:StopLimit", guid, token, user: {portfolio}, ticker, exchange, board, side, quantity, price, triggerPrice, condition, ...}` | `{requestGuid, httpCode, message, orderNumber?}` | 200 = success |
| **delete:Limit** | Cancel limit order | `{opcode: "delete:Limit", guid, token, orderId, exchange, user: {portfolio}, ...}` | `{requestGuid, httpCode, message, orderNumber?}` | 200 = success |
| **delete:Market** | Cancel market order | `{opcode: "delete:Market", guid, token, orderId, exchange, user: {portfolio}, ...}` | `{requestGuid, httpCode, message, orderNumber?}` | 200 = success |
| **delete:StopMarket** | Cancel stop order | `{opcode: "delete:StopMarket", guid, token, orderId, exchange, user: {portfolio}, ...}` | `{requestGuid, httpCode, message, orderNumber?}` | 200 = success |
| **delete:StopLimit** | Cancel stop-limit order | `{opcode: "delete:StopLimit", guid, token, orderId, exchange, user: {portfolio}, ...}` | `{requestGuid, httpCode, message, orderNumber?}` | 200 = success |

**Response Structure**:
```json
{
  "requestGuid": "guid-from-request",
  "httpCode": 200,
  "message": "OK or error text",
  "orderNumber": "order-id-if-successful"
}
```

---

## C. Authentication Flow

### Current ALOR Auth (JWT-based)

1. **Entry Point**: User is redirected to `ssoUrl` (`https://login-dev.alor.ru/`) (external service, not part of Astras backend)
2. **Token Acquisition**: 
   - After SSO login, frontend receives a JWT `token` + `expirationTime` (unix ms)
   - Token is stored in `ApiTokenProviderService` (singleton)
   - **Service**: `src/app/shared/services/auth/api-token-provider.service.ts`
   - **Token State**: `{token: string, expirationTime: number, refreshCallback: () => void}`

3. **Token Usage**:
   - Automatically injected into **every** WS and HTTP request as `token` field
   - HTTP: Authorization header support may also be present (via interceptor), but primary is WS `token` field
   - Expires 5 seconds before actual expiration (timeReserveMs = 5000)
   - **Refresh Mechanism**: `refreshCallback()` invoked before expiration; assumes external SSO refresh or re-login

4. **HTTP Interceptor**: `src/app/shared/services/` (not directly visible in audit, but inferred)
   - Adds token to request context or headers
   - Skips auth for specific endpoints (e.g., market-settings-config.json) via `HttpContextTokens.SkipAuthorization`

### For Bybit Adapter:
- **Auth Bypass Strategy**: Inject mock JWT token on adapter side OR implement OAuth/Bybit API key passthrough
- Adapter must provide token in every WebSocket `subscribe` message and HTTP request header/param
- No refresh logic needed for MVP (use long-lived or static test tokens)

---

## D. Data Format Quirks

### Enums & Field Values

| Field | Type | Example Values | Notes |
|-------|------|-----------------|-------|
| **side** | enum | `"buy"`, `"sell"` | lowercase in orderbook, may be titlecase in responses; check OrderResponse models |
| **timeInForce** | enum | `"Day"`, `"Ioc"`, `"Gtc"` | PascalCase; see `order.model.ts` |
| **condition** | enum (stops) | `"Less"`, `"More"` | for trigger conditions |
| **tradingStatus** | enum | `"Normal"`, `"ClosingAuction"`, `"OpeningAuction"`, `"Break"` | instrument status |
| **orderType** | enum | `"Limit"`, `"Market"`, `"StopMarket"`, `"StopLimit"` | PascalCase in responses |
| **exchange** | string | `"MOEX"`, `"SPBX"`, `"BYBIT"` (future), `"NASDAQ"` (if supported) | exact string; case-sensitive |
| **status** | string | `"working"`, `"filled"`, `"cancelled"`, `"rejected"` | lowercase |

### Number Formats

- **Prices**: `float` (e.g., `100.50`, not string)
- **Volumes**: `float` (e.g., `1.5`)
- **Quantities**: `float` or `number`
- **Commission**: `float`
- **Timestamps**: Unix seconds (integer, sometimes float for milliseconds in internal; **check API** — history uses seconds, WS may use ms)

### Field Naming

- **General**: `camelCase` (e.g., `lastPrice`, `tradingStatus`)
- **Abbreviations**: `bid`, `ask`, `qty`, `avg`, `pls`, etc.
- **Response Models**: CamelCase (e.g., `PortfolioMeta`, `OrderResponse`)

### Caution: API Variations

- Some endpoints return `board` field, others `primary_board` (handle both in adapter)
- `OrderResponse` vs raw response: may have nested `user: {portfolio}` structure; check models
- Yields (`y` field in orderbook) present for bonds only; set `0` for stocks

---

## E. Sprint 1 MVP Endpoint Shortlist

**Total to Implement: 15 HTTP endpoints + 6 WS opcodes**

### HTTP Endpoints (Priority: CRITICAL + MEDIUM)

1. **GET** `/md/v2/Securities/{exchange}/{symbol}` (apiUrl) — instrument detail for BTCUSDT
2. **GET** `/md/v2/Securities/{exchange}:{symbol}/quotes` (apiUrl) — last price
3. **GET** `/md/v2/history` (apiUrl) — candles for chart (1m, 5m, 1h, etc.)
4. **GET** `/md/v2/Clients/{exchange}/{portfolio}/positions` (apiUrl) — balance/position
5. **GET** `/client/v1.0/users/{clientId}/all-portfolios` (clientDataUrl) — list portfolios
6. **GET** `/client/v1.0/users/{login}/full-name` (clientDataUrl) — user info (optional)
7. **POST** `/commandapi/warptrans/FX1/v2/client/orders/estimate` (apiUrl) — order cost preview (optional for MVP)
8. **GET** `/md/v2/Securities` (apiUrl) — search/list instruments (populate instrument picker)

### WebSocket Subscriptions (Priority: CRITICAL)

1. **OrderBookGetAndSubscribe** — orderbook (depth 20 for BTCUSDT)
2. **BarsGetAndSubscribe** — candles (1m, 5m feeds)
3. **QuotesSubscribe** — live ticker
4. **PositionsGetAndSubscribeV2** — portfolio positions (equity, margin usage)
5. **OrdersGetAndSubscribeV2** — active orders list (order blotter)
6. **TradesGetAndSubscribeV2** — fills/executions (trade history)

### WebSocket Commands (Priority: CRITICAL)

7. **submit:Limit** — place limit order
8. **delete:Limit** — cancel limit order
9. **submit:Market** — place market order
10. **delete:Market** — cancel market order

---

## F. Architectural Notes for Adapter

### Multiplexing Strategy
- Each WS subscription uses a unique `guid` (UUIDv4, generated client-side)
- **Subscription ID** formed as: `opcode_symbol_exchange_instrumentGroup_depth_format`
- Server routes responses back by matching `guid` in response to `guid` in request
- **Implication for adapter**: implement guid-to-subscription-id map to demux incoming messages and route to correct subscribers

### Reconnection Logic
- Client tracks socket state (open/closed/closing)
- On disconnect, resubscribes all active subscriptions automatically (replay request list)
- Ping/pong every 30 seconds; if pong fails, triggers reconnect

### Token Refresh
- Token is pre-checked before expiration (5s buffer)
- If expired, `refreshCallback()` is invoked (assumes SSO can refresh)
- For adapter MVP: use static long-lived tokens or mock auth

### Data Buffering
- WS subscriptions use `shareReplay(bufferSize)` to buffer last N messages
- New subscribers get cached data immediately (not full history)
- History API used for backfill (e.g., past 2 candles for chart initialization)

---

## G. Known Limitations & Blockers

### No Blockers Found
All 7 MVP features have clear API paths:

1. ✅ **Auth bypass** — inject mock JWT, no external SSO needed for adapter
2. ✅ **Instruments + BTCUSDT** — `/md/v2/Securities/{ex}/{sym}`
3. ✅ **Candles** — `/md/v2/history` + `BarsGetAndSubscribe`
4. ✅ **Orderbook** — `OrderBookGetAndSubscribe`
5. ✅ **Balance/Positions** — `/md/v2/Clients/{ex}/{port}/positions` + `PositionsGetAndSubscribeV2` + `SummariesGetAndSubscribeV2`
6. ✅ **Place/Cancel** — `submit:Limit`, `delete:Limit` (cws WebSocket)
7. ✅ **Live updates** — `OrdersGetAndSubscribeV2`, `TradesGetAndSubscribeV2`, `PositionsGetAndSubscribeV2`

### Design Considerations
- **Dual WS connections** needed: one for data feeds (ws), one for commands (cws)
- **Token injection** must be automated (interceptor pattern)
- **Orderbook format** depends on request `format: "slim"` vs `"full"` (slim = {p, v} only; full = more fields like yield)

---

## H. Reference Models (TypeScript Extracts)

### Key Request/Response Types Found

```typescript
// From src/app/shared/models/orders/new-order.model.ts
interface NewLimitOrder {
  side: Side;  // "buy" | "sell"
  instrument: InstrumentKey;
  quantity: number;
  price: number;
  timeInForce?: TimeInForce;
  orderEndUnixTime?: number;
  icebergFixed?: number;
  icebergVariance?: number;
  allowMargin?: boolean;
}

// From src/app/shared/models/history/history-request.model.ts
interface HistoryRequest {
  symbol: string;
  exchange: string;
  tf: string;  // "1" (1min), "5", "15", "60" (1h), "D" (daily)
  from: number;  // unix seconds
  to: number;
  countBack?: number;
}

// OrderbookRequest (from orderbook.service.ts)
interface OrderbookRequest {
  opcode: 'OrderBookGetAndSubscribe';
  code: string;  // symbol
  exchange: string;
  instrumentGroup?: string;
  depth: number;  // default 17, typical 20
  format: 'slim' | 'full';
}

// OrderbookData (response)
interface OrderbookData {
  a: Array<{p: number, v: number, y?: number}>;  // asks [price, volume, yield]
  b: Array<{p: number, v: number, y?: number}>;  // bids
}
```

---

## Summary Statistics

| Category | Count | Notes |
|----------|-------|-------|
| **REST Endpoints (HTTP)** | 15 active | 8 critical, 5 medium, 2 low |
| **WebSocket Data Feed Opcodes** | 11 | subscription-based, guid-multiplexed |
| **WebSocket Command Opcodes** | 8 | order submit/cancel across 4 types |
| **Base URLs Used** | 4 | apiUrl, clientDataUrl, ssoUrl, wsUrl, cwsUrl |
| **Service Files Audited** | 60+ | focused on trading path (orderbook, orders, instruments, portfolio) |
| **MVP Endpoints Required** | 15 | 8 HTTP + 6 WS subscriptions + 4 WS commands |

---

## Files Used in This Audit

- `src/environments/environment.ts` — base URLs
- `src/app/shared/services/subscriptions-data-feed.service.ts` — WS subscription logic
- `src/app/client/services/orders/ws-orders-connector.ts` — WS command connector
- `src/app/client/services/orders/client-order-command.service.ts` — order submission
- `src/app/shared/services/account.service.ts` — portfolio/user endpoints
- `src/app/shared/services/positions.service.ts` — positions (REST)
- `src/app/shared/services/history.service.ts` — candle history
- `src/app/shared/services/portfolio-subscriptions.service.ts` — portfolio WS subscriptions
- `src/app/shared/services/quotes.service.ts` — quotes/price ticks
- `src/app/modules/orderbook/services/orderbook.service.ts` — orderbook aggregation
- `src/app/modules/orderbook/utils/order-book-data-feed.helper.ts` — orderbook request formatting
- `src/app/modules/instruments/services/instruments.service.ts` — instrument search/detail
- `src/app/modules/instruments/services/candles.service.ts` — candle subscription
- `src/app/shared/services/all-trades.service.ts` — all trades (tick history)
- `src/app/shared/services/evaluation.service.ts` — order cost estimation
- Order models: `src/app/shared/models/orders/new-order.model.ts`, `order.model.ts`, `edit-order.model.ts`
- Position/quote models: `src/app/shared/models/positions/`, `quotes/`

---

**End of Report**

