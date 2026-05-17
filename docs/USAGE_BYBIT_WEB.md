# Workflow: Astras admin panel + Bybit web UI

Этот документ описывает ежедневный workflow Sprint 4 pivot: **Astras перестал быть полноценным trading-терминалом, теперь он — admin/control panel для PMM Dynamic стратегии**. Визуальный слой (chart, orderbook, активные ордера, manual override) — Bybit web UI открытый в соседней вкладке браузера.

Зачем такой pivot: мы перестаём дублировать функционал, который Bybit предоставляет бесплатно через свой web. Astras делает то, чего у Bybit нет — параметры PMM Dynamic стратегии, lifecycle-кнопки, decision-rationale стрим, custom equity tracker с точечной precision.

## Перед запуском

1. Backend `bybit-adapter` запущен на `http://localhost:3000`:
   ```bash
   cd ~/bybit-adapter
   npm run dev      # tsx watch — авто-перезагрузка при изменениях
   ```
   В логах должно быть `bybit-adapter listening` и `equity-recorder started (event-driven, change-only)`.

2. Frontend `astras-bybit-ui` запущен на `http://localhost:4200`:
   ```bash
   cd ~/astras-bybit-ui
   pnpm start
   ```

3. В Bybit web — активирован Demo Trading (виртуальные деньги).
   - Открой https://www.bybit.com/trade/usdt/BTCUSDT
   - Settings → Switch to Demo Trading
   - Settings → Language → Русский (если предпочитается)
   - Settings → Theme → Light (для consistency со светлой темой Astras)

4. API-ключи `bybit-adapter` (`~/.bybit-adapter/.env` или локальный `.env`) — это ключи демо-аккаунта Bybit (BYBIT_ENV=demo). Те же ключи, под которыми мы работали в Sprint 1-3.

## Расклад вкладок

Открой ровно две вкладки в браузере:

- **Tab 1 — Astras admin panel:** `http://localhost:4200`
  - На dashboard `Crypto` (default) должны быть три виджета:
    - **Strategy Control Panel** (верх-лево) — параметры, lifecycle-кнопки, metrics
    - **Equity Tracker** (верх-право) — точечный график изменений equity
    - **Strategy Action Log** (вся ширина внизу) — live decision-rationale stream

- **Tab 2 — Bybit web (Demo):** `https://www.bybit.com/trade/usdt/BTCUSDT`
  - Здесь смотришь chart, orderbook, активные ордера, manual override

## Полный workflow за одну торговую сессию

### 1. Настройка параметров

Tab 1 → Strategy Control Panel → раскрой панель "Параметры стратегии":

- Убедись что **`Dry run` = `dry`** (по умолчанию). Это безопасный режим: вся логика стратегии работает (refresh, AS-расчёты, decision logging), но `submitOrder` / `cancelOrder` не вызываются — только логируются как `dry_run_action`.
- Стартовые conservative defaults уже залиты:
  - γ (risk aversion) = 0.5
  - σ window = 600 сек (10 минут rolling)
  - k = 1.5
  - order_amount = 0.001 BTC (~$70 на $70k BTC)
  - min/max spread = 5 / 100 bps
  - max_inventory = 0.05 BTC
  - daily SL / TP = 50 / 200 USDT
- Если меняешь — `Применить`. Адаптер валидирует через Zod, сохраняет в `bybit-adapter/config/strategy.json` (gitignored), применяет live без рестарта.

### 2. Старт стратегии в dry_run

Tab 1 → кнопка `Старт`.

- Status chip должен стать "Работает" (зелёный)
- Tag "DRY RUN" виден рядом с symbol
- В Action Log сразу появляются:
  - `strategy_start` — конфиг snapshot
  - `tick_size_loaded` — instrumentInfo от Bybit (tickSize, lotSize, minNotional)
  - `position_synced` — текущий inventory с биржи (обычно 0 если нет открытой позиции)
  - `strategy_running`
  - Через `order_refresh_interval_sec` (10 сек по defaults) — первый `refresh` с расчётом mid, σ, reservation price, bid/ask
  - Если есть свободные слоты на сторонах — два `dry_run_action` с `action: place` и расчётными ценами

### 3. Дай поработать в dry_run 5-10 минут

В этом окне:
- Метрики обновляются каждые 2 сек (status / metrics polling)
- Action log стримит каждые ~10 сек refresh + соответствующие dry_run_action
- Reservation price колеблется около mid (потому что inventory=0)
- Equity Tracker молчит — в dry_run wallet balance не меняется → нет точек (это правильное поведение)

Что проверять в dry_run:
- Spread в пределах min/max bps (видно в `refresh.effectiveSpread`)
- Bid и ask округлены к tick size (для BTCUSDT кратны 0.1)
- При inventory_skew_enabled=true и imitированном изменении inventory (через manual order на Bybit web) — reservation price смещается, видно в refresh-логах

### 4. Переход в live (реальные ордера на demo)

**Только когда уверен в параметрах:**
1. Tab 1 → Strategy Control Panel → `Стоп` (state=stopped)
2. В форме параметров: **выключи `Dry run` тумблер** → `Применить` (теперь chip "LIVE" magenta)
3. `Старт`

Что меняется по сравнению с dry_run:
- Action log будет показывать `order_placed` (вместо `dry_run_action`) с реальным `orderId` от Bybit
- На Bybit web (Tab 2) — реальные лимитные ордера типа `PostOnly` в стакане, видны в "Активные ордера"
- При fill — `fill` event в action log + изменение `walletBalance` → новая точка в Equity Tracker (через 1-2 секунды после WS execution event)

### 5. Visual monitoring через Bybit web

Tab 2 → BTCUSDT linear perpetual:

- **Chart:** видишь свои bid/ask как horizontal lines (если включено "Show orders on chart")
- **Order book:** свои уровни подсвечены
- **Активные ордера** (нижняя панель): два ордера с orderLinkId начинающимся на `pmmd-` (наш prefix из config)
- **История сделок / Fills:** новые fills появляются здесь сразу

В Tab 1 параллельно:
- В Equity Tracker — новая точка через 1-2 сек после fill
- В Action Log — `fill` с fee, price, qty, pnlEstimate, inventoryBase

### 6. На лету меняем параметры

Tab 1 → Strategy Control Panel → меняешь, например γ с 0.5 на 0.8 → `Применить`.

- В Action Log появляется `config_updated` с diff'ом изменённых полей
- Volatility estimator, inventory manager, risk manager — все принимают новые лимиты через `applyConfig()` без рестарта
- На следующем refresh (через 10 сек) уже видны новые reservation price / spread с обновлённым γ

### 7. Manual override через Bybit web

Если нужно вручную отменить наш ордер или закрыть позицию:
1. Tab 2 → Активные ордера → правый клик → Cancel
2. Стратегия увидит cancellation через WS `order` topic → log'нет `order_cancelled` в Action Log → на следующем refresh переразместит ордер на этой стороне

Аналогично — если нужно ручной market close позиции через Bybit web — стратегия увидит обновление через `position` topic, синхронизирует `InventoryManager`, на следующем refresh учтёт новый inventory в reservation price.

### 8. Pause vs Stop

- **Pause**: стратегия перестаёт делать новые refresh tick'и (новые ордера не размещаются), но текущие ордера НЕ отменяются — они могут продолжать наполняться. Используй когда хочется "подождать развития рынка" без потери queue priority.
- **Stop**: cancel-all (все наши tracked ордера отменяются через `bybit.cancelOrder`), отписка от WS, state=stopped.

После Pause → `Продолжить` (Resume). После Stop → надо снова `Старт` (инициализация заново: instrument info, position sync, leftover cancel sweep).

### 9. Risk-trigger автостоп

Если `daily_pnl_stop_loss_usdt` > 0 и реализованный PnL за день опустился до -SL — стратегия логирует `risk_limit_hit` и сама вызывает `stop('risk_limit_hit')`. На фронте status станет stopped, lastError = причина.

Аналогично с `daily_pnl_take_profit_usdt`. Чтобы выключить — установи 0 в соответствующем поле.

PnL accumulator сбрасывается на UTC midnight.

## Что НЕ делать одновременно

- **Не размещать manual лимитные ордера через Bybit web** в том же direction/symbol при работающей стратегии — конфликты неизбежны (наша инвентаризация не учитывает их, может выставить ордер сверху).
- **Не торговать на том же демо-аккаунте через мобильное приложение Bybit** во время сессии — те же конфликты.
- **Не запускать Hummingbot одновременно** с нашей стратегией на том же account (Hummingbot deprecated в Sprint 4, см. `docs/architecture/strategy_engine.md`).

## Где смотреть логи и историю

- **Action log файлы**: `bybit-adapter/data/strategy-actions-YYYY-MM.jsonl` — все decision события сохранены, ring buffer в памяти ограничен 500 entries.
- **Equity history**: `bybit-adapter/data/equity-YYYY-MM.jsonl` — все meaningful walletBalance changes.
- **Adapter pino log**: `npm run dev` выводит в консоль.
- **REST endpoints для пост-фактум анализа:**
  - `GET /strategy/actions?limit=500&event=fill` — последние 500 fill-событий
  - `GET /strategy/snapshot` — полное состояние (status + metrics + config + active orders)
  - `GET /equity/stream?from=<msEpoch>&to=<msEpoch>&limit=10000`

## Troubleshooting

**Стратегия стартанула но `refresh` не появляются:**
- Проверь что Bybit private WS подключён (в adapter log: `Bybit private WS opened`)
- Проверь что ticker subscription активна — должно быть `bid1Price` / `ask1Price` в кеше. Подпишись на BTCUSDT в каком-то Astras widget с QuotesSubscribe чтобы прогреть; либо подожди — strategy сама подписывается на ticker на start.

**Equity Tracker не обновляется при fills:**
- Проверь что WS опкод `EquityUpdatesSubscribe` подписан (DevTools → Network → WS frames). Должно идти `{guid, opcode: "EquityUpdatesSubscribe"}` и через подтверждение `{requestGuid, httpCode: 200}`.
- `equity_threshold_usdt` слишком большой? Если установлен в, например, 10 USDT — мелкие fills с комиссией 0.05 USDT не пробьют threshold. Снизь до 0.01.

**В Action Log постоянно `refresh_error`:**
- Bybit rate limit (60 req/sec per IP по умолчанию) — увеличь `order_refresh_interval_sec`
- WS reconnect mid-refresh — обычно безвредно, следующий tick всё переразместит. Если устойчиво — проверь network / API key validity.

**Strategy stopped с lastError на старте:**
- Проверь instrument symbol правильный (BTCUSDT, не BTCUSD)
- Проверь что API key имеет permissions на trading на demo

## Связанные документы

- `mm-bot/docs/architecture/strategy_engine.md` — почему именно TS-реализация, а не Hummingbot
- `mm-bot/docs/sprint_prompts/sprint_4_pivot_strategy_first.md` — оригинальный prompt Sprint 4
- `bybit-adapter/src/strategy/` — исходники стратегии
- `bybit-adapter/config/strategy.example.json` — шаблон config'а
