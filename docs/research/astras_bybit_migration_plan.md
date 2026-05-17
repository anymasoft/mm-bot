# План миграции Astras-Trading-UI → Bybit (финальный roadmap)

**Дата принятия архитектурных решений:** 2026-05-17
**Источник:** https://github.com/alor-broker/Astras-Trading-UI (Apache-2.0)
**Наш fork:** https://github.com/anymasoft/astras-bybit-ui (default branch `master`)
**Бэкенд-адаптер:** https://github.com/anymasoft/bybit-adapter (новый, Apache-2.0)
**Координирующий репо:** https://github.com/anymasoft/mm-bot
**Desktop wrap:** Tauri 2.0 + Node.js sidecar

## 0. Финальные архитектурные решения (одобрено архитектором 2026-05-17)

| # | Вопрос | Решение |
|---|---|---|
| 1 | Архитектурный путь | **Путь A — proxy backend (Node.js)**. Frontend трогаем минимально, дивергенция от upstream минимальна |
| 2 | Хранение форка | **Отдельные репозитории** под `anymasoft/`, не sub-folders |
| 3 | Первая UI-фича | **chart + DOM + manual order placement + blotter** — все четыре к концу Sprint 3-4 |
| 4 | Порядок с Hummingbot | **Astras desktop первым (Sprint 1-4), стратегия запускается в Sprint 5** — без bridge solutions, без web UI как промежуточного шага |
| 5 | Desktop wrap | **Tauri 2.0 + Node.js sidecar** (а не Electron). Node sidecar = наш bybit-adapter, упакованный внутрь Tauri-инсталлятора |
| 6 | Лицензия форка | **Apache-2.0** с NOTICE-атрибуцией ALOR |

**Timeline:** 6-8 недель до первого запуска стратегии с visual control. Testnet $1270 ждёт, mainnet — только после 2-3 недель валидации стратегии в testnet.

---

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
- TradingView charts (платная коммерческая library, ALOR имеет лицензию — у нас fallback на lightweight-charts)
- Темизация и UX как в проф. терминалах
- Многооконные layouts
- AGENTS.md инструкции для AI-driven разработки (упрощает наш workflow с Claude Code)

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
Только Capacitor для Android/iOS. Для Windows .exe нужен Tauri 2.0 (выбран) или Electron (отклонён по причинам ниже).

## 3. Финальная архитектура: proxy backend + Tauri 2.0 sidecar

```
┌────────────────────────────────────────────┐
│  Tauri 2.0 native window (Rust + WebView2) │
│  ┌──────────────────────────────────────┐  │
│  │  Astras-Trading-UI (наш форк)         │  │
│  │  Angular 21 production build          │  │
│  │  served as embedded static assets     │  │
│  └─────────────┬────────────────────────┘  │
│                │ HTTP/WS localhost:3000    │
│                ▼                            │
│  ┌──────────────────────────────────────┐  │
│  │  Bybit Adapter (Node.js sidecar)      │  │
│  │  Fastify + TypeScript + bybit-api     │  │
│  │  - ALOR-format API endpoints          │  │
│  │  - Bybit V5 REST + WS клиент          │  │
│  │  - Format translation в обе стороны   │  │
│  │  - Auth bridge (ключи в OS keystore)  │  │
│  │  Запускается как child process Tauri  │  │
│  └─────────────┬────────────────────────┘  │
└────────────────┼───────────────────────────┘
                 │ Bybit V5 REST + WS (HTTPS/WSS)
                 ▼
┌────────────────────────────────────────────┐
│  Bybit testnet / mainnet                   │
└────────────────────────────────────────────┘
```

### Почему Tauri 2.0, а не Electron

| Параметр | Tauri 2.0 | Electron | Выбор |
|---|---|---|---|
| Размер .exe | 5-15 MB | 80-300 MB | Tauri (важно для distribution) |
| RAM idle | 30-50 MB | 150-300 MB | Tauri (Hummingbot уже жрёт 4 GB в WSL2) |
| Startup time | <1 сек | 2-5 сек | Tauri |
| Performance | Native (Rust + WebView2) | Embedded Chromium | Tauri (real-time market data рисуется плавнее) |
| Системная интеграция | OS keystore, tray, notifications нативно | Через npm-обёртки | Tauri |
| Зрелость 2026 | v2.0 stable с октября 2024, production-ready | v25+ выпускают, проверен годами | Оба ОК |
| Sidecar Node.js | Поддерживается через `tauri.conf.json` externalBin | Не нужен (Node встроен в main process) | Tauri требует extra config, но выполнимо |
| Auto-updater | Встроен, signed updates | Через electron-updater | Оба ОК |

**Решение:** Tauri 2.0. Real-time терминал — это про latency и плавность; на машине пользователя одновременно работают Hummingbot (4 GB), WSL2, IDE — экономия RAM критична. Tauri 2.0 в 2026 — production-ready (документация, awesome-tauri, истории использования OpenAlgo Desktop и др.).

### Почему Node.js sidecar (а не embed adapter в Rust)

- `bybit-api` (tiagosiebler) — best-in-class TypeScript-клиент для Bybit V5 с поддержкой всех WS topics, retry, rate limit handling. Rust-аналоги (`ccxt-rs`, `bybit-rs`) гораздо беднее по фичам и менее активны.
- Bybit меняет API ~раз в 6 месяцев. JS-экосистема реагирует быстрее.
- Adapter изолирован в отдельном репо `anymasoft/bybit-adapter` — его можно разрабатывать и тестировать независимо от Tauri-обёртки.
- Tauri 2.0 sidecar API позволяет упаковать `node` binary + наш скомпилированный JS в installer, пользователь Node устанавливать не должен.

### Почему Путь A (proxy), а не B (модификация Angular services)
- Минимизирует дивергенцию от upstream — можно мерджить релизы ALOR раз в 2-3 месяца
- Bybit-specific логика в одном месте (adapter), легче дебажить и тестировать
- Frontend остаётся "broker-agnostic" → потенциально можно добавить другие биржи позже
- AGENTS.md upstream подразумевает что core архитектуру лучше не ломать

---

## 4. Roadmap — 5 спринтов до запуска торговли

### Sprint 1: Bybit adapter MVP (недели 1-3)

**Цель:** Node.js сервис, который отвечает на минимальный набор ALOR-format endpoints реальными данными из Bybit testnet.

**Задачи:**
1. Инициализировать `anymasoft/bybit-adapter`: TypeScript + Fastify + `bybit-api` (tiagosiebler) + Zod для валидации схем
2. Reverse-engineer ALOR API spec для нужных endpoints (через https://alor.dev + DevTools Network на live Astras в demo-mode)
3. Реализовать минимум:
   - **REST:** `GET /securities/{board}/{ticker}` → Bybit instrument info (`/v5/market/instruments-info`)
   - **WS:** `/md/v2/Securities/{ticker}/quotes` → Bybit `tickers.{symbol}`
   - **WS:** `/md/v2/Securities/{ticker}/trades` → Bybit `publicTrade.{symbol}`
   - **WS:** `/md/v2/Securities/{ticker}/orderbook` → Bybit `orderbook.50.{symbol}`
4. Mock SSO endpoint (фронт думает что залогинен, ключи Bybit в env файле adapter'а или OS keystore)
5. Instrument code mapping: `BYBIT:BTCUSDT` (наш формат) ↔ `BTCUSDT` (Bybit), board `BYBIT_SPOT` / `BYBIT_PERP`
6. Unit-тесты на трансляцию форматов (Bybit JSON → ALOR JSON) — без сети
7. Integration-тесты против Bybit testnet WS — публичные данные

**Срок:** 2-3 недели (≈ 15 рабочих дней full-time, или 4-6 недель part-time).

**Acceptance:** `curl http://localhost:3000/securities/BYBIT_SPOT/BTCUSDT` отвечает ALOR-format JSON с реальной информацией об инструменте. WebSocket подписка на `quotes` отдаёт обновления цены BTCUSDT в реальном времени.

---

### Sprint 2: Astras frontend adaptation (недели 3-5)

**Цель:** Запустить наш форк Astras локально, переключить на наш adapter, показать первый live widget (tech-chart с BTCUSDT).

**Задачи:**
1. Клонировать `anymasoft/astras-bybit-ui` локально, `pnpm install`, `pnpm start`
2. Найти и переопределить env конфиг с `https://alor.dev` → `http://localhost:3000` (наш adapter)
3. Mock SSO: убедиться что фронт принимает наш mock-token и не пытается redirect на ALOR
4. Добавить инструмент `BYBIT:BTCUSDT` в instrument selector
5. Отключить нерелевантные для крипты модули в роутинге/меню:
   - `bond-screener`, `option-board`, `invest-ideas`, российские ETF, новости MOEX, `exchange-rate` (RUB)
6. Адаптировать форматтеры: убрать RUB-locale, переключить на USDT precision (8 знаков base, 2 для quote)
7. Скрыть/адаптировать поля связанные с T+1 settlement
8. Открыть `tech-chart` widget → должен показывать live свечи BTCUSDT
9. Открыть `orderbook` widget → должен показывать live стакан BTCUSDT

**Срок:** 2-3 недели.

**Acceptance:** локально запущенный Astras-Trading-UI показывает живой график и стакан BTCUSDT через наш adapter, без обращений к alor.dev.

---

### Sprint 3: Trading widgets + manual orders (недели 5-6)

**Цель:** Полнофункциональный trading dashboard на testnet с возможностью разместить ордер вручную.

**Задачи:**
1. Расширить adapter:
   - **REST:** `POST /commandapi/warptrans/TRADE/v2/client/orders` → Bybit `POST /v5/order/create`
   - **REST:** `DELETE /commandapi/warptrans/TRADE/v2/client/orders/{id}` → Bybit `POST /v5/order/cancel`
   - **REST:** `GET /md/v2/Clients/{portfolio}/positions` → Bybit `GET /v5/position/list`
   - **REST:** `GET /md/v2/Clients/{portfolio}/orders` → Bybit `GET /v5/order/realtime`
   - **WS:** private streams `execution`, `order`, `position` (с auth)
2. Безопасно хранить Bybit API ключи: в Sprint 3 — через env-файл adapter'а в `~/.bybit-adapter/` (gitignore); в Sprint 4 переведём на OS keystore через Tauri
3. В UI заработают: `scalper-order-book` (DOM), `blotter` (ордера + позиции), `all-trades`, `order-commands` (manual orders)
4. Размещение тестового PostOnly ордера через UI на testnet → проверка что он виден в `blotter`
5. Отмена ордера через UI → проверка что cancel прошёл
6. Адаптация order form: добавить toggle для PostOnly, ReduceOnly, TimeInForce (GTC/IOC/FOK)

**Срок:** 2 недели (часть работы пересекается с Sprint 2 — может пойти быстрее).

**Acceptance:** четыре widget'а (chart + DOM + blotter + order form) работают вместе на одной странице. Можно разместить и отменить limit ордер на testnet через UI. Все позиции и ордера видны в blotter.

---

### Sprint 4: Tauri 2.0 desktop wrap + Node sidecar bundling (недели 6-8)

**Цель:** Один `.exe` инсталлятор, который ставит весь terminal без необходимости Node/Angular CLI на машине пользователя.

**Задачи:**
1. В `anymasoft/astras-bybit-ui`:
   - Добавить `src-tauri/` через `pnpm create tauri-app` (existing project mode) или вручную
   - Сконфигурить `tauri.conf.json`: `frontendDist` → Angular production build (`dist/astras-trading-ui/`)
   - Добавить `tauri build` script в `package.json`
2. Упаковать Node sidecar:
   - В `anymasoft/bybit-adapter` добавить `pkg` или `nexe` или Node SEA (Single Executable Application) для компиляции в standalone exe
   - В `tauri.conf.json` зарегистрировать `bybit-adapter.exe` как `externalBin`
   - Tauri запускает sidecar как child process при старте main window, останавливает при закрытии
3. OS keystore интеграция:
   - Использовать `tauri-plugin-stronghold` или `tauri-plugin-store` (зашифрованный)
   - Bybit ключи вводятся один раз через UI dialog, хранятся в Windows Credential Manager / macOS Keychain
   - Adapter получает ключи через IPC от Tauri main process на старте
4. Custom installer для Windows (.msi через WiX или .exe через NSIS — оба поддерживаются `tauri-bundler`)
5. Code signing (если архитектор предоставит сертификат) — иначе пользователь увидит SmartScreen warning
6. Auto-updater config (включить позже, не обязательно для Sprint 4)
7. Тестирование на чистой Windows VM без установленного Node/Angular

**Срок:** 1.5-2 недели.

**Acceptance:** один скачанный `.msi` файл устанавливает Astras Bybit Terminal. После запуска: вводим Bybit testnet ключи в UI dialog, открывается главное окно с chart/DOM/blotter, всё работает локально без интернета кроме самого Bybit API.

---

### Sprint 5: Hummingbot integration + первый запуск стратегии (недели 8+)

**Цель:** Запустить PMM Dynamic / Avellaneda-Stoikov стратегию на Bybit testnet, наблюдать действия бота через наш Astras desktop, валидировать прибыльность.

**Задачи:**
1. В Hummingbot создать YAML конфиг для `avellaneda_market_making` на `bybit_perpetual_testnet`:
   - Pair: BTCUSDT
   - Order amount: малый (например 0.001 BTC)
   - Risk params: gamma, eta, kappa — стартовые рекомендуемые значения из доки Hummingbot
   - Order refresh: 30 сек
2. Запустить Hummingbot CLI в WSL2: `start` стратегии, мониторить логи
3. В Astras desktop одновременно открыть:
   - chart BTCUSDT с indicator volume + наши ордера visible как markers
   - DOM (scalper-order-book) с подсветкой наших ордеров
   - blotter с открытыми ордерами и позициями
   - portfolio-summary с балансом и PnL
4. Custom widget "Hummingbot Status" (опционально, если время есть):
   - HTTP/IPC bridge к Hummingbot Gateway или MQTT-bridge
   - Показывает: текущие параметры стратегии, last refresh, total trades, PnL since start
5. Стратегия работает на testnet 2-3 недели непрерывно
6. Анализ результатов: Sharpe ratio, max drawdown, hit rate, fill rate
7. **Mainnet decision:** только если testnet валидация прошла + капитал готов

**Срок:** 2 недели для запуска, далее continuous validation.

**Acceptance:** PMM Dynamic стратегия размещает и обновляет maker-ордера на testnet, мы наблюдаем все её действия через Astras desktop terminal в real-time, fills видны в blotter, PnL обновляется.

---

## 5. Что делается в Sprint 1 параллельно с adapter MVP

Архитектор зафиксировал: **никаких bridge solutions, никакого Bybit web UI как промежуточного шага**. До Sprint 5 торговая стратегия не запускается. Это решение взвешенное:
- Запускать стратегию без визуального контроля → нельзя дебажить аномалии
- Использовать Bybit web → противоречит требованию 100% OSS desktop
- Параллельная разработка стратегии без UI → не на чем валидировать промежуточные результаты

**В Sprint 1 параллельно с adapter MVP можно делать:**
- Документировать структуру YAML конфигов Hummingbot для `avellaneda_market_making` (без запуска)
- Изучить параметры (gamma, eta, kappa) и собрать литературу
- Backtesting на исторических данных через Hummingbot's `backtest` mode — если эта инфраструктура работает локально
- Setup мониторинга (логи, метрики) для будущего запуска

Это **подготовка**, не торговля. Первый реальный `start` стратегии — только в Sprint 5.

---

## 6. Технические риски и mitigation

### 6.1. TradingView charting library — лицензия
**Риск:** Astras использует commercial TradingView charting library. У ALOR есть лицензия — у нас нет.
**Mitigation:** скрипт `copy_charting_library_files.sh` в репо показывает что library подгружается отдельно. Скорее всего downloadable с TradingView для зарегистрированных разработчиков (бесплатно для personal/non-commercial use). Если возникнут проблемы — переключиться на `lightweight-charts` (тоже в deps, Apache-2.0). Понизит качество charts (нет drawing tools уровня TradingView), но не критично для MVP.

### 6.2. Upstream дивергенция
**Риск:** ALOR продолжает разрабатывать Astras, наш fork отстаёт или конфликтует с их изменениями.
**Mitigation:** Путь A (proxy) минимизирует frontend изменения. Раз в 2-3 месяца: `git fetch upstream && git merge upstream/master`. Документировать наши специфичные изменения в `BYBIT_ADAPTATIONS.md` в форке.

### 6.3. Bybit V5 API breaking changes
**Риск:** Bybit меняет API ~раз в 6 месяцев, ломая клиентов.
**Mitigation:** adapter изолирует frontend от Bybit API. Меняем только adapter. `bybit-api` (tiagosiebler) обычно выпускает patch в течение недели после Bybit changelog.

### 6.4. ALOR API spec неполная
**Риск:** документация на alor.dev может не покрывать всё что использует frontend.
**Mitigation:** reverse-engineer через DevTools Network — запустить Astras в demo-mode (если есть) и наблюдать реальные WS/REST вызовы. Иначе через AGENTS.md спросить у CI/AI tools проекта. Файл `BYBIT_ADAPTATIONS.md` фиксирует наши находки.

### 6.5. Tauri 2.0 + Angular SSR совместимость
**Риск:** Angular 21 поддерживает SSR; Tauri использует static frontend dist. Возможны сложности с lazy loading модулей.
**Mitigation:** конфигурировать Angular build без SSR (`outputMode: 'static'`), все 36 модулей загружаются как обычные lazy chunks. Тестировать на dev машине перед packaging.

### 6.6. Node sidecar packaging
**Риск:** `pkg` устарел (last commit 2023), `nexe` работает но требует pre-built Node binaries, Node SEA молодой (Node 21+).
**Mitigation:** Sprint 4 первым делом — прототип packaging на dummy adapter. Если все три варианта проблемны — fallback: распространять с системным Node 22+ как требование, проверять на старте.

### 6.7. Code signing для Windows
**Риск:** без signed installer пользователь видит SmartScreen warning, бросает установку.
**Mitigation:** для нашего use case (один пользователь = архитектор) приемлемо. Если позже захотим distribute — купить EV код-сайн сертификат (~$300/год от Sectigo) и подключить в `tauri.conf.json`.

---

## 7. Структура репозиториев

| Репо | Назначение | Лицензия | Статус |
|---|---|---|---|
| [anymasoft/mm-bot](https://github.com/anymasoft/mm-bot) | Координирующий: документация, sprint reports, конфиги Hummingbot стратегий | Private | Существует, Sprint 0 закрыт |
| [anymasoft/astras-bybit-ui](https://github.com/anymasoft/astras-bybit-ui) | Fork от alor-broker/Astras-Trading-UI; Angular 21 frontend, адаптация под Bybit, Tauri wrap | Apache-2.0 (наследует) | Fork создан 2026-05-17, default `master` |
| [anymasoft/bybit-adapter](https://github.com/anymasoft/bybit-adapter) | Node.js + TypeScript proxy: ALOR API ↔ Bybit V5 API. Упаковывается как Tauri sidecar | Apache-2.0 | Создан 2026-05-17, пустой |

**Связь:**
- `mm-bot` ссылается на `astras-bybit-ui` и `bybit-adapter` из README и migration plan
- `astras-bybit-ui` в Sprint 4 имеет `src-tauri/` с конфигом `externalBin = bybit-adapter` (sidecar)
- `bybit-adapter` может развиваться независимо (отдельные релизы, unit-тесты, CI)

---

## 8. Источники и референсы

- [Astras-Trading-UI upstream](https://github.com/alor-broker/Astras-Trading-UI)
- [ALOR API docs](https://alor.dev)
- [Bybit V5 API docs](https://bybit-exchange.github.io/docs/v5/intro)
- [bybit-api (tiagosiebler)](https://github.com/tiagosiebler/bybit-api) — основная JS-библиотека для adapter
- [Tauri 2.0 docs](https://v2.tauri.app/)
- [Tauri Sidecar guide](https://v2.tauri.app/develop/sidecar/)
- [Tauri Plugin Stronghold](https://v2.tauri.app/plugin/stronghold/) — encrypted secrets storage
- [Angular 21 release notes](https://blog.angular.dev/)
- [ng-zorro-antd](https://ng.ant.design/) — UI kit Astras
- [TradingView charting library](https://www.tradingview.com/charting-library-docs/) — нужна регистрация / fallback на lightweight-charts
- [Fastify](https://fastify.dev/) — HTTP framework для adapter
- [Zod](https://zod.dev/) — schema validation
- [Hummingbot avellaneda_market_making docs](https://hummingbot.org/strategies/avellaneda-market-making/)
