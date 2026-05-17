# План миграции Astras-Trading-UI → Bybit (+ desktop wrap)

**Дата:** 2026-05-17
**Источник:** https://github.com/alor-broker/Astras-Trading-UI (Apache-2.0)
**Целевая платформа:** наш форк под `anymasoft/` + Bybit V5 API + native desktop (Tauri 2.0)

## 1. Что мы берём и зачем

**Astras-Trading-UI** — это:
- Angular 21 SPA, активная разработка (last push 2026-05-08)
- 36 модулей включая `scalper-order-book`, `tech-chart`, `orderbook`, `blotter`, `all-trades`, `portfolio-summary`, `order-commands`, `arbitrage-spread`
- ng-zorro (Ant Design), gridster для drag-drop виджетов
- TradingView charting library, Chart.js, Lightweight-charts, D3
- LESS темы (тёмная/светлая)
- Apache-2.0 — чистая OSI лицензия
- Mobile через Capacitor; desktop wrap — отсутствует

**Что мы получаем бесплатно** (требует только rewire data source):
- Профессиональный widget framework
- Все базовые UI компоненты торгового терминала
- TradingView charts (платная коммерческая library, ALOR имеет лицензию — нужно проверить наш статус)
- Темизация и UX как в проф. терминалах
- Многооконные layouts
- AGENTS.md инструкции для AI-driven разработки (бонус — упрощает наш workflow с Claude Code)

## 2. Что НЕ работает из коробки и почему

### 2.1. Backend — ALOR API
- Frontend ожидает специфичные ALOR endpoints (REST + WebSocket)
- API spec на https://alor.dev
- SSO auth с JWT redirect
- Bybit V5 API структурно другой: REST + WS, key/secret HMAC auth, другие endpoint shapes

### 2.2. Market-specific логика
| Слой | ALOR (MOEX) | Bybit (crypto) | Нужна адаптация |
|---|---|---|---|
| Instruments | SBER, GAZP, etc | BTCUSDT, ETHUSDT | mapping layer |
| Trading hours | 10:00-18:50 МСК | 24/7 | UI hints + scheduling |
| Settlement | T+1 (акции) | instant | order state machine |
| Currency display | RUB | USDT/USDC | locale + formatters |
| Order types | limit, market, conditional | + PostOnly, ReduceOnly, TimeInForce | order form expansion |
| Lot size | 1, 10, 100 | floating decimals | tick/step rounding |
| Margin | особенности рос. рынка | cross/isolated, leverage 1x-100x | margin module |
| Asset classes | акции, облиги, фьючерсы, опции | spot, perpetual, options | оставить только spot/perpetual |

### 2.3. Desktop wrap отсутствует
Только Capacitor для Android/iOS. Для Windows .exe нужен Electron или Tauri.

## 3. Архитектурный выбор: proxy backend (Путь A)

```
┌──────────────────────────────────────┐
│  Astras-Trading-UI (наш форк)         │
│  Angular 21 + ng-zorro + gridster     │
│  Wrapped in Tauri 2.0 → .exe          │
└──────────────┬───────────────────────┘
               │  ALOR-format WS / REST
               │  (frontend остаётся максимально нетронутым)
               ▼
┌──────────────────────────────────────┐
│  Bybit Adapter (новый сервис)         │
│  Node.js + TypeScript                 │
│  - Принимает запросы в ALOR-формате   │
│  - Конвертирует в Bybit V5 API         │
│  - Конвертирует WS streams Bybit ←→ ALOR │
│  - Кеширует instruments, hot-data     │
│  - Auth bridge: фронт думает SSO,     │
│    proxy держит Bybit key/secret      │
└──────────────┬───────────────────────┘
               │  Bybit V5 REST + WS
               ▼
┌──────────────────────────────────────┐
│  Bybit testnet / mainnet              │
└──────────────────────────────────────┘
```

**Почему Путь A (proxy), а не B (прямая модификация Angular services):**
- Минимизирует дивергенцию от upstream — можно мерджить релизы ALOR
- Bybit-specific логика в одном месте (proxy), легче дебажить и тестировать
- Frontend остаётся "broker-agnostic" → потенциально можно добавить другие биржи позже
- AGENTS.md upstream подразумевает что core архитектуру лучше не ломать

## 4. Roadmap — разбивка на спринты

### Sprint 1 (UI side): Bybit adapter MVP + первый widget работает

**Цель:** один widget (например `tech-chart`) показывает live BTCUSDT данные из Bybit через наш proxy.

**Задачи:**
1. Fork `alor-broker/Astras-Trading-UI` → `anymasoft/astras-bybit-ui` (Apache-2.0, добавить NOTICE c атрибуцией ALOR)
2. Создать новый репо `anymasoft/bybit-adapter` (Node.js + TypeScript)
3. В adapter'е реализовать минимум:
   - `GET /securities/{board}/{ticker}` → Bybit instrument info
   - `WS /md/v2/Securities/{ticker}/quotes` → Bybit `tickers` WS topic
   - `WS /md/v2/Securities/{ticker}/trades` → Bybit `publicTrade` WS topic
   - `WS /md/v2/Securities/{ticker}/orderbook` → Bybit `orderbook` WS topic
   - Mock SSO endpoint (фронт думает что залогинен, ключи Bybit в env adapter'а)
4. Запустить Astras-Trading-UI локально, подменить env с `https://alor.dev` на `http://localhost:3000` (наш adapter)
5. В UI добавить инструмент `BYBIT:BTCUSDT` (mapping в adapter'е)
6. Открыть `tech-chart` widget → должен показывать live свечи BTCUSDT

**Срок:** 2-3 недели full-time (или ~6-8 недель part-time).

**Acceptance:** живой график BTCUSDT в Angular UI через локальный adapter.

### Sprint 2 (UI side): Расширение widgets + manual orders

**Задачи:**
1. Добавить в adapter endpoints для:
   - `POST /commandapi/warptrans/TRADE/v2/client/orders` → Bybit `place_order`
   - `DELETE /commandapi/warptrans/TRADE/v2/client/orders/{id}` → Bybit `cancel_order`
   - WS positions / orders feed
2. В UI заработают: `scalper-order-book`, `orderbook`, `blotter`, `all-trades`, `order-commands`
3. Сделать первый manual order через UI на testnet
4. Отключить нерелевантные модули (`bond-screener`, `option-board`, `invest-ideas`, рос. ETF)

**Срок:** 2-3 недели.

**Acceptance:** полнофункциональный dashboard с chart + DOM + orderbook + blotter + manual orders, всё на Bybit testnet.

### Sprint 3 (UI side): Desktop wrap через Tauri 2.0

**Задачи:**
1. Установить Tauri CLI, создать `src-tauri/` в Angular проекте
2. Сконфигурить Tauri для запуска Angular dev-server в production-mode
3. Bundle adapter (Node.js) внутрь Tauri как sidecar или как отдельный установщик
4. Custom installer для Windows (.msi или .exe)
5. Тестирование на чистой Windows VM

**Срок:** 1-2 недели.

**Acceptance:** один `.exe` запускает наш terminal без необходимости отдельного Node.js / Angular dev-server.

### Sprint 4+ (UI side): Polish и интеграция с Hummingbot

- Тёмная/светлая темы fine-tuning
- Hummingbot bot status panel (custom widget — показывает что делает PMM Dynamic)
- Crypto-specific features: funding rate display, perpetual leverage, position liquidation price
- Multi-symbol layouts

## 5. Параллельный трек: Hummingbot стратегия

UI-разработка не блокирует разработку стратегии. Архитектор должен решить порядок:

**Опция A (рекомендую):** Sprint 1 (бот) → Sprint 2 (UI adapter MVP) → Sprint 3 (бот тюнинг) → Sprint 4 (UI расширение)
- Стратегия идёт первой потому что без неё UI не на чем тестировать
- Bybit web достаточен для дебага стратегии в первые недели

**Опция B:** Sprint 1 (UI MVP) → Sprint 2 (бот)
- UI готов как только бот запустится
- Но рискуем тратить время на UI без понимания что нам реально нужно показывать

**Опция C:** Параллельно
- Требует разделения внимания, не рекомендую для solo-сетапа

## 6. Технические риски и mitigation

### 6.1. TradingView charting library — лицензия
**Риск:** ASTRAS использует commercial TradingView charting library. У ALOR есть лицензия — у нас её нет.
**Mitigation:** скрипт `copy_charting_library_files.sh` в репо показывает что library подгружается отдельно. Скорее всего downloadable с TradingView для зарегистрированных разработчиков. Если будут проблемы — переключиться на `lightweight-charts` (тоже в deps, тоже бесплатная Apache-2.0). Это понизит качество charts, но не критично для MVP.

### 6.2. Upstream дивергенция
**Риск:** ALOR продолжает разрабатывать ASTRAS, мы будем отставать или конфликтовать с их изменениями.
**Mitigation:** Путь A (proxy) минимизирует frontend изменения. Раз в 2-3 месяца — pull from upstream, merge.

### 6.3. Bybit V5 API breaking changes
**Риск:** Bybit меняет API ~раз в 6 месяцев, ломая клиентов.
**Mitigation:** adapter изолирует frontend от Bybit API. Меняем только adapter.

### 6.4. Tauri vs Electron stability
**Риск:** Tauri 2.0 относительно молодой, может быть проблем с Angular SSR/static build.
**Mitigation:** если Tauri не взлетит — fallback на Electron (более прожорливый, но проверенный).

### 6.5. ALOR API spec неполная
**Риск:** документация на alor.dev может не покрывать всё что использует frontend.
**Mitigation:** reverse-engineer через DevTools Network — запустить ASTRAS в demo-mode (если есть) и наблюдать реальные WS/REST вызовы. Иначе через AGENTS.md спросить у их CI/AI tools.

## 7. Trade-offs сравнение

| Аспект | Astras-Trading-UI fork (наш путь) | flowsurface | StockSharp Terminal | DIY на Tauri |
|---|---|---|---|---|
| Время до MVP | 2-3 недели (один widget) | 0 минут | 0 минут | 2-3 недели |
| Время до полного terminal | 3-5 месяцев | n/a (read-only) | n/a (готов сразу) | 4-6 месяцев |
| Manual orders | ✓ (после Sprint 2) | ✗ | ✓ | требует разработки |
| Качество UI | 8/10 (Angular + Ant Design) | 6/10 (хорош для orderflow) | 5/10 (устаревший WPF) | сами решаем |
| Desktop native | требует Tauri wrap | ✓ нативный Rust | ✓ нативный WPF | требует Tauri/Electron |
| Кастомизация | полная (наш fork) | сторонний проект | связаны upstream | полная |
| Maintenance burden | средний (нужно мержить upstream + поддерживать adapter) | низкий | низкий | высокий (всё наше) |
| OSS чистота | ✓ Apache-2.0 + наш fork | ✓ GPL-3.0 | ⚠️ free binary, paid sources | ✓ всё наше |

## 8. Что нужно от архитектора для старта Sprint 1 (UI track)

1. Подтверждение **Путь A (proxy)** vs альтернатив
2. Подтверждение **первой feature** (chart, DOM, blotter, или dashboard сразу)
3. Решение по **порядку с Hummingbot стратегией** (опции A/B/C из секции 5)
4. Подтверждение **Tauri 2.0** для desktop wrap (или Electron)
5. Решение по **расположению форка**:
   - Отдельный репо `anymasoft/astras-bybit-ui` + `anymasoft/bybit-adapter`
   - Или sub-folders внутри `mm-bot/` (`astras-trading-ui/`, `bybit-adapter/`)

Рекомендую **отдельные репозитории** — упрощает upstream merges и downstream isolation.

## 9. Источники и референсы

- [Astras-Trading-UI](https://github.com/alor-broker/Astras-Trading-UI)
- [ALOR API docs](https://alor.dev)
- [Bybit V5 API docs](https://bybit-exchange.github.io/docs/v5/intro)
- [bybit-api (Node.js)](https://github.com/tiagosiebler/bybit-api) — рекомендуемая библиотека для adapter
- [Tauri 2.0 docs](https://v2.tauri.app/)
- [Angular 21 release notes](https://blog.angular.dev/)
- [ng-zorro-antd](https://ng.ant.design/) — UI kit Astras
- [TradingView charting library](https://www.tradingview.com/charting-library-docs/) — нужна лицензия / fallback на lightweight-charts
