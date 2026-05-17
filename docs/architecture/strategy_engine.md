# Strategy Engine Architecture (Sprint 4 pivot)

## TL;DR

PMM Dynamic (Avellaneda-Stoikov) реализован **напрямую в TypeScript** внутри `bybit-adapter`, как module `src/strategy/`. **Hummingbot не используется в активной разработке** начиная с Sprint 4. Установка Hummingbot в WSL остаётся как dormant fallback — для возможной cross-validation реализации позже, но в стандартном workflow не запускается.

## Почему не Hummingbot

Hummingbot — респектабельный OSS market-making framework на Python (Apache-2.0). Изначальный план Sprint 5 предполагал использовать его как execution engine для нашей PMM стратегии. Но при детальной оценке стоимости интеграции получилась картина, в которой собственная TypeScript реализация в 2-3 раза проще и не теряет ни одной важной возможности:

### Что Hummingbot добавил бы

- **Готовые формулы PMM Dynamic** — Avellaneda-Stoikov + inventory skew implemented. ~500 строк Python.
- **Connector к Bybit V5** — через `gateway` (отдельный Node.js процесс) или `ccxt`. Не universally stable.
- **Built-in backtesting harness** (через `--backtest` flag).
- **Готовое CLI**: команды `start`, `stop`, `status`, `config`.
- **Telegram / Discord интеграция** для уведомлений (но мы её и не планировали).

### Что Hummingbot добавил бы как cost

- **Отдельный Python 3.10 процесс** в WSL2 Ubuntu, требующий собственного venv / Conda.
- **Hummingbot Gateway** — ещё один Node.js процесс между Hummingbot и Bybit для тех connector'ов, где Python не справляется. То есть три процесса вместо одного.
- **Конфиг split**: Hummingbot хранит `conf/strategies/*.yml` в его papke, мы храним state в `bybit-adapter` — нужна синхронизация.
- **Subprocess management**: запуск, остановка, recovery, логи в трёх местах вместо одного.
- **Path / WSL gotchas**: Windows host ↔ WSL2 file paths, особенно для config'ов и log file rotation.
- **Cross-process latency** между нашим bybit-adapter (который уже маршрутизирует WS / REST к Bybit) и Hummingbot. Для market-making'а где queue priority это деньги — добавочная latency болезненна.
- **Версии**: Hummingbot активно меняет внутренний API между minor versions. Когда они обновятся, мы обновляемся (или фризим версию и теряем security patches).

### Что мы делаем вместо

Реализация в `bybit-adapter/src/strategy/`:

```
strategy/
├── avellaneda-stoikov.ts        — чистая математика (140 строк)
├── volatility-estimator.ts      — rolling σ из log-returns (90 строк)
├── inventory-manager.ts         — position state + canBuy/canSell (95 строк)
├── risk-manager.ts              — daily SL/TP + UTC rollover (100 строк)
├── order-manager.ts             — reconcile loop + dry-run (220 строк)
├── action-logger.ts             — JSONL + ring buffer + WS broadcast (90 строк)
├── pmm-dynamic.ts               — главный controller (440 строк)
├── config-schema.ts             — Zod schema + defaults (110 строк)
├── types.ts                     — TS interfaces (110 строк)
└── index.ts                     — singleton + persistence (95 строк)
```

Всего ~1500 строк production кода + ~600 строк vitest тестов. Полное покрытие математики и пограничных случаев unit-тестами; integration test через manual smoke на Bybit demo.

### Что мы получили

1. **Один процесс — один log file.** Все события (REST API, WS messages, strategy decisions, equity changes) в одном pino потоке.
2. **Atomic config updates.** REST `POST /strategy/config` валидирует через Zod, применяет через `PMMDynamicStrategy.applyConfig()` без рестарта. Параметры тут же подхватываются: новый γ применяется на следующем refresh tick'е через 10 секунд.
3. **Прямой доступ к Bybit V5 client.** `bybit-api` (tiagosiebler, MIT) — уже подключена в adapter, используется для REST/WS повсеместно. Стратегия пере-использует тот же объект, никакого дополнительного wrap'а.
4. **Дешёвая live communication с Astras.** Action logger broadcast'ит в WS topic `strategy.actions` через тот же `forEachSubscriptionForTopic` plumbing, который уже обслуживает orderbook / ticker / position feeds. Без дополнительной inter-process IPC.
5. **Точный контроль над order lifecycle.** Order Manager tracks active orders по `orderLinkId` prefix, может различить наши ордера от manual (placed через Astras UI или Bybit web). Дешёвый dry-run mode реализован одним boolean check'ом — Hummingbot dry_run (`paper_trade`) требует отдельной конфигурации paper-trade exchange.
6. **Чистая Avellaneda-Stoikov без оптимизаций Hummingbot.** Hummingbot добавил несколько эвристик поверх AS (inventory hopping, dynamic spread adjustment based on volatility regime). Эти эвристики могут быть полезны на конкретных рынках но они «прячут» поведение базового алгоритма. Мы делаем чистый AS — если хотим эвристики потом, добавим осознанно с возможностью отключить.
7. **Sprint 5 backtest** реализуем над тем же кодом — backtest harness читает исторические orderbook snapshots, кормит их `pmm-dynamic.ts` с моками `bybit.submitOrder`. Никакого моста между Python и наш стек.

## Когда вернуться к Hummingbot

Hummingbot остаётся как dormant fallback. Сценарий повторной активации:

1. Sprint 5+ — нам нужен **cross-validation** для нашей реализации Avellaneda-Stoikov. Hummingbot гоняем на тех же демо-параметрах параллельно, сравниваем equity curves. Расхождение >5% over 24h → bug в нашей реализации.
2. Если стратегия диверсифицируется и мы хотим **Cross-Exchange Market Making** (CXM), Hummingbot уже умеет это из коробки. Реализация CXM с нуля — недели работы.
3. Если хотим **portfolio of strategies** (Pure MM + Cross-Exchange + Liquidity Mining + Avellaneda-Stoikov одновременно) — Hummingbot scaffold для multi-strategy uptime управления зрелее, чем мы успеем построить.

Эти сценарии — после mainnet validation основной стратегии. До тех пор Hummingbot не нужен.

## Hummingbot в WSL — текущее состояние

- Установлен в `~/projects/hummingbot/` внутри WSL2 Ubuntu 24.04 (Sprint 0)
- Conda environment `hummingbot` создан, dependencies резолвятся
- `~/projects/hummingbot/conf/` содержит секции для будущих стратегий (encrypted credentials, gitignored)
- В `mm-bot/strategies/` есть placeholder YAML конфигов для возможного будущего использования
- В `mm-bot/scripts/` могут быть тонкие wrapper'ы для CLI

**Не запускай Hummingbot одновременно со стратегией в `bybit-adapter` на том же account.** Это вызовет:
- Двойную инвентаризацию (Hummingbot не знает про наши ордера и наоборот)
- Конкурирующие cancel/place на orderbook → rate-limit penalty от Bybit
- Хаос в action log и equity tracker

## API контракт стратегии

Стратегия живёт за REST в `bybit-adapter`:

```
GET    /strategy/status        — { state, lastRefreshAt, dryRun, symbol, lastError }
GET    /strategy/metrics       — { fillsCount, realisedPnlUsdt, inventoryBase, ... }
GET    /strategy/config        — текущий PMMDynamicConfig
POST   /strategy/config        — body: PMMDynamicConfig (Zod validation server-side)
POST   /strategy/start         — запустить
POST   /strategy/stop          — body?: {reason} — cancel-all + остановка
POST   /strategy/pause         — оставить ордера, перестать делать новые refresh
POST   /strategy/resume        — продолжить с pause
GET    /strategy/actions       — query: ?limit, ?event — last N действий
GET    /strategy/snapshot      — { status, metrics, config, activeOrders }
```

WS opcodes:

```
StrategyActionsSubscribe      — live decision-rationale stream (ActionLogEntry)
EquityUpdatesSubscribe        — live point-by-point equity changes (EquityPoint)
```

Подробности — в `bybit-adapter/src/routes/strategy.ts` и `bybit-adapter/src/ws/data-handler.ts`.

## Файлы

- Стратегия: `bybit-adapter/src/strategy/`
- Persistence: `bybit-adapter/config/strategy.json` (gitignored), template `strategy.example.json`
- Action log: `bybit-adapter/data/strategy-actions-YYYY-MM.jsonl`
- Equity history: `bybit-adapter/data/equity-YYYY-MM.jsonl`
- Frontend: `astras-bybit-ui/src/app/modules/strategy-control/`, `strategy-action-log/`, `equity-tracker/`
