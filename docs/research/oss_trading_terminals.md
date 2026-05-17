# Open-source DESKTOP торговые терминалы для Bybit — финальный отчёт

**Дата:** 2026-05-17 (обновлено после уточнения требований)
**Уточнённые жёсткие фильтры:** только desktop GUI приложения (native binary / Electron / Tauri / Qt / WPF / Avalonia), только OSI-approved лицензии без оговорок, активные коммиты после 2025-11, нативная или CCXT-поддержка Bybit, без trial/freemium/paid pro tiers, не TUI/CLI, не web/SaaS.

## 🟢 СТАТУС: РЕШЕНИЕ ПРИНЯТО (2026-05-17)

После рассмотрения всех вариантов из этого отчёта **архитектор принял принудительное решение**:

> **Использовать форк [alor-broker/Astras-Trading-UI](https://github.com/alor-broker/Astras-Trading-UI) (Apache-2.0, Angular 21) с адаптацией под Bybit + desktop wrap через Tauri 2.0.**

**Это пятый вариант**, который не входил в Tier 1/2/3 этого research, потому что Astras-Trading-UI это **web-приложение, а не desktop**. Решение принимает на себя дополнительный объём работы по миграции (с ALOR API на Bybit) и desktop wrap.

Детальный план миграции: [astras_bybit_migration_plan.md](./astras_bybit_migration_plan.md).

Этот research-документ остаётся **как контекст принятия решения** — показывает что других реалистичных OSS desktop options нет, поэтому путь "форк + адаптация" обоснован.

---

## Что осталось важным после принятия решения

- **flowsurface** остаётся как **read-only вспомогательный инструмент** для orderflow visualization, **параллельно** с нашим форком Astras. Это zero-effort 10-минутный install.
- **StockSharp Terminal** остаётся как **fallback** если Astras миграция упрётся в неразрешимый блокер в Sprint 1.
- **DIY с нуля** более не рассматривается — Astras даёт нам ~70% работы готовой.

---

## Контекст и почему второй research

Первая итерация research предлагала **composite UI** (Bybit web + TradingView free + flowsurface). Это было отклонено: пользователь **жёстко требует desktop OSS приложение**, не web-сервисы и не браузерные UI. Bybit web и TradingView — не подходят (это сервисы в браузере, а не OSS desktop).

Этот документ заменяет предыдущую версию.

## TL;DR

**По совокупности "near-Quantower/ASTRAS уровень + OSS desktop + Bybit + активный" реальный кандидат один — flowsurface.** Второй с натяжкой — StockSharp Terminal. Всё остальное либо web, либо заброшено, либо не про крипту, либо с подвохом лицензии. Это **объективная реальность рынка**, не пробел в поиске.

## Tier 1 — реально подходят

### 1. flowsurface (единственный полноценный кандидат)

| Параметр | Значение |
|---|---|
| Репо | https://github.com/flowsurface-rs/flowsurface (мигрировал из `akenshaw/flowsurface`) |
| Лицензия | **GPL-3.0** — чистый OSI, без Commons Clause |
| Stars | ~1.5k |
| Последний коммит | 17 мая 2026 (релиз v0.8.8 — 24 апреля 2026), регулярные коммиты весной 2026 |
| GUI framework | Rust + `iced` (нативный desktop, **не Electron, не WebView**) |
| Бинарники | Windows, macOS, Linux в Releases |
| Биржи | **Bybit (native)**, Binance, OKX, Hyperliquid, MEXC |
| API keys | Нужны только для расширения до trading; для маркет-даты — public WS/REST |

**Функционал (что реально есть):**
- **Heatmap (Historical DOM)** — Bookmap-style, основная фича. Time-series heatmap из live trades + L2 orderbook с настраиваемой группировкой цен, разными time aggregations, fixed/visible range volume profiles
- **Footprint charts** — price-grouped + interval-aggregated с кластеризацией трейдов, imbalance, naked-POC
- **DOM / Ladder** — current L2 orderbook + recent trade volumes на price levels
- **Candlestick chart** — multi-timeframe
- **Time & Sales**
- **Multi-window, persistent layouts**
- **Темы** — тёмная/светлая, кастомизация
- **Audio cues** по трейдам (как у Bookmap)

**Чего НЕТ — критично:**
- ❌ **Manual order placement отсутствует.** Это observer/analyzer, **не trade executor**
- ❌ Drawing tools уровня TradingView (только базовые)
- ❌ Встроенных индикаторов уровня TradingView (только базовые)
- ⚠️ **Fetching trades для Bybit/Hyperliquid не поддерживается** — нет подходящего REST API. Heatmap работает с live данными, но historical lookback trades через REST нет

**Оценка vs ASTRAS/Quantower:** **6/10**.
- По heatmap/footprint/orderflow — на уровне Bookmap-light, что уже выше большинства брокерских терминалов
- По manual trading / drawing / индикаторам — сильно слабее
- Для нашего use case (мониторить что делает PMM Dynamic бот) **идеально**: бот сам ставит ордера, нам нужно видеть рынок и реакцию

**Sources:** [GitHub](https://github.com/flowsurface-rs/flowsurface), [flowsurface.com](https://flowsurface.com/), [Releases](https://github.com/flowsurface-rs/flowsurface/releases)

### 2. StockSharp (S#) — серьёзный, но с критичными нюансами

| Параметр | Значение |
|---|---|
| Репо | https://github.com/StockSharp/StockSharp |
| Лицензия репо | Apache-2.0 |
| Stars | ~1.6k |
| Последний коммит | 16 мая 2026 (11.7k коммитов всего — очень активный) |
| GUI framework | C# / WPF (+ Avalonia в части сборок) — native Windows desktop |
| Платформы | Win primary; macOS/Linux только частично через Avalonia |
| Биржи | **Bybit поддерживается официально** + 90+ других коннекторов |

**Что есть:**
- **S#.Terminal** — полноценный торговый терминал: charts (70+ индикаторов), order book с heatmap/scalper view, **manual orders**, position management
- **S#.Designer** — визуальный конструктор стратегий
- **S#.Hydra** — загрузчик исторических данных
- Multi-monitor, drawing tools, темы

**КРИТИЧНЫЙ НЮАНС лицензии:**
- На stocksharp.com/products/sources/ исходники их финального коммерческого билда продаются: **$400/мес индивидуалам, $950/мес компаниям, минимум 6 месяцев подписка**
- Apache-репо — это исходники базовой части. **Бинарники Designer/Terminal/Hydra скачиваются с сайта бесплатно как закрытые сборки** (это free-as-in-beer, не free-as-in-speech)
- **Реальная сборка GUI-приложения из репо нетривиальна** — части UI кода в платном репо
- Формально OSI Apache фильтр проходит (бесплатно после git clone && build && run базовой части), но **на практике** "полный" терминал = либо downloading proprietary binary, либо платить за исходники

**Оценка vs ASTRAS/Quantower:** **8/10 по фичам, 5/10 по UX**.
- По функциональности S#.Terminal **ближе всех к Quantower** из всего OSS
- По UX — устаревший WPF, документация на русском/в Wiki, кривая обучения крутая
- Не "красивый", но рабочий
- Платформа исторически заточена под русский фондовый рынок + Plaza II / QUIK, **крипта приделана сбоку** — качество Bybit-коннектора зависит от того, как часто его правят (бывают баги в issues)

**Sources:** [StockSharp GitHub](https://github.com/StockSharp/StockSharp), [Bybit connector docs](https://doc.stocksharp.com/topics/api/connectors/crypto_exchanges/bybit.html)

## Tier 2 — близко, но не дотягивают

### Plutus Terminal
- https://github.com/plutus-terminal/plutus-terminal
- Python desktop, GPL-3.0, активный
- **Проблема:** только DEX (Foxify, GMX в планах). **Bybit не поддерживается принципиально**

### VisualHFT
- https://github.com/visualHFT/VisualHFT
- WPF/C# native desktop, Apache-2.0, ~1.1k stars
- **Проблемы:** (1) **Bybit в списке коннекторов НЕТ** (Binance, Bitfinex, BitStamp, Coinbase, Gemini, Kraken, KuCoin, generic WebSocket); (2) только визуализация микроструктуры, **manual orders отсутствуют**; (3) последний релиз — март 2025, граница активности
- Если бы был Bybit — был бы Tier 1.5

### QtBitcoinTrader (JulyIghor)
- Native Qt desktop, GPL, реальный exe
- **Проблема:** последний релиз май 2023, заброшен; Bybit неуверенно
- Не проходит фильтр активности

### bybit-tools (TranceGeniK)
- Electron desktop, GPL-3.0, есть manual orders включая scaled
- **Проблема:** в README сказано **"Bybit-tools is not maintained anymore"**. Заброшен

## Tier 3 — НЕ подходят и почему

| Кандидат | Причина отказа |
|---|---|
| **Profitmaker** (suenot) | Лицензия "MIT + Commons Clause" — НЕ OSI-approved. Плюс это **web app** (React + Vite на :8080). Двойной фейл |
| **OpenAlgo Desktop** (Tauri 2.0, Rust) | Native desktop ✓, AGPL-3.0 ✓, но поддерживает **только индийских брокеров** (Angel One, Zerodha, Fyers). Bybit нет, крипты нет |
| **OpenBB Platform** | Python SDK + CLI + web Workspace (последний — фактически SaaS на pro.openbb.co). **Нативного desktop приложения нет** |
| **gocryptotrader** | CLI/gRPC-сервер, GUI клиента нет |
| **ASTRAS-Trading-UI** (alor-broker) | Apache-2.0, активный (релиз 7.0 — июнь 2025), но это **Angular web app** (запускается `pnpm start` на :4200). Заточен под MOEX/ALOR, крипты по сути нет. Desktop-обёртки нет |
| **Kupi terminal** (FXCryptoCat) | Express.js + React/Vue web-app, не desktop. 1 star, мёртв |
| **Cryexc** (josedonato) | Не open source — исходников нет. Даже если бы были — C++ + ImGui компилируется в WASM (web) |
| **HyperData Terminal** | TUI dashboard, не GUI с мышкой |
| **OpenTrader** | Web UI на :8000, не desktop |
| **TradeMaster-NTU** | RL research platform на Python с Jupyter, не торговый терминал |
| **Hummingbot Dashboard** | Streamlit web — НЕ desktop. **Plus deprecated** (последний релиз 10-2024) |
| **Hummingbot Condor** | Web + Telegram — НЕ desktop. (хоть и активный OSS) |
| **Freqtrade FreqUI** | Vue web app — НЕ desktop |
| **Superalgos** | Web — НЕ desktop |
| **OctoBot** | Web — НЕ desktop |
| **Jesse** | Web built-in — НЕ desktop |
| **NautilusTrader** | Production-grade engine, **нет GUI вообще** — только Python/Jupyter |
| **Tribeca** | Мёртв с 2015 |

## ASTRAS / российское комьюнити — отдельная проверка

Пользователь упомянул ASTRAS от ALOR как референс качества. Проверено:

- **ALOR публикует SDK** на GitHub (`alor-broker/openapi.sdk`, `alor-broker/Astras-Trading-UI`), но всё под **web** (Angular)
- **Desktop-приложения, вдохновлённого ASTRAS, на GitHub нет**
- **ASTRAS Windows-клиент (.NET WPF) — closed source**
- Open source от ALOR — только их Angular-вебка
- Российских OSS desktop-стакан-визуализаторов крипты в значимом количестве **на GitHub нет**
- Большая часть русскоязычного крипто-OSS — это боты (Hummingbot-форки, тинькоф Avalonia-проекты под их Invest API) либо closed source утилиты в Telegram

## Объективная реальность рынка — почему OSS desktop terminal уровня Quantower/ASTRAS почти не существует

Это закономерность, а не пробел поиска:

1. **Cryptowatch Desktop** (тот самый Rust+iced проект Kraken, который был "правильным" продуктом) **закрыт Kraken 30 сентября 2023**. flowsurface фактически занял освободившийся вакуум.

2. **Трудозатраты на полнофункциональный терминал** — десятки человеко-лет. Quantower разрабатывают с 2017, NinjaTrader с 2003. OSS-комьюнити обычно покрывает либо одну фичу хорошо (flowsurface — orderflow), либо платформу для разработки бота (Freqtrade, Hummingbot), но не "терминал-всё-в-одном".

3. **Узкая аудитория**: serious manual traders готовы платить $50-200/мес за Bookmap/Quantower/Sierra Chart — коммерческие продукты доминируют и засасывают талант.

4. **Сложность поддержки live trading в production**: ответственность за чужие деньги при ошибке, exchange API меняются каждые 2-3 месяца — отпугивает мейнтейнеров. Многие проекты сознательно остаются именно read-only (как flowsurface).

5. **Бизнес-модель**: даже у Quantower бесплатна только базовая версия. Чисто OSS вне зоны экономического стимула для разработчиков-трейдеров.

**Вывод:** flowsurface — это **потолок OSS desktop crypto orderflow на 2026 год**. StockSharp Terminal — потолок по manual trading capability, но с нюансами.

## DIY оценка — если строить своё

Если flowsurface (read-only) и StockSharp (платные исходники GUI) не устраивают — реалистичный путь это **построить свой минимальный desktop terminal**.

| Стек | Время до MVP | Время до "near-Quantower lite" | Плюсы / Минусы |
|---|---|---|---|
| **Tauri (Rust core) + TradingView lightweight-charts + bybit-api (TS) или ccxt-rs** | 2-3 недели | 4-6 месяцев (1 dev) | Малый бинарь (~10MB), быстрый, low memory. lightweight-charts Apache-2.0. **Минус:** lightweight-charts без footprint/heatmap — для них нужно своё (egui-charts даёт 130+ индикаторов как альтернатива) |
| **Electron + lightweight-charts + ccxt (Node)** | 1-2 недели | 3-5 месяцев | Самый быстрый старт, max экосистема. **Минус:** 150-300MB бинарь, прожорливый, "ощущается" как браузер |
| **Avalonia 11 (C#) + LiveCharts2 + Bybit.Net (jkorf)** | 3-4 недели | 4-6 месяцев | Истинно native, кроссплатформа Win/Mac/Linux, по UX ближе к Quantower. Хорошие .NET-библиотеки для Bybit. **Минус:** меньше OSS примеров под крипту |

**Бутстрап MVP за выходные (Tauri):** окно с одним символом, real-time candles через WS, минимальный стакан, кнопки Market Buy/Sell с pre-filled размером. Это **"одно окно вместо браузера"**, не Quantower-замена. До flowsurface-уровня heatmap+footprint — реально **месяцы**.

## Финальная рекомендация — три варианта

### Вариант A: 🟢 flowsurface + Hummingbot CLI (рекомендую как pragmatic minimum)

- Установить **flowsurface** (Windows .exe из Releases) как desktop terminal для наблюдения
- Manual orders (если редко нужны) — через Hummingbot CLI команды или Bybit web (но строго: web не входит в наш OSS стек, это аварийная опция)
- Хватит для Sprint 1 (запуск PMM Dynamic): бот сам ставит ордера, flowsurface показывает рынок
- **Затраты:** 0 минут setup, $0
- **Закрывает Sprint 0 acceptance.** Можно сразу к Sprint 1

### Вариант B: 🟡 StockSharp Terminal (если manual orders из GUI обязательны)

- Скачать бесплатный бинарник S#.Terminal с stocksharp.com
- Настроить Bybit-коннектор, базовый workflow
- **Плюсы:** реальный desktop с manual orders, charts, DOM
- **Минусы:** устаревший UX (~5/10), исходники GUI-сборок платные ($400/мес если захочешь патчить), документация местами только на русском, баги в Bybit-коннекторе бывают
- **Затраты:** ~3-4 часа на установку и освоение
- Это **не чистая OSS** в строгом смысле (free binary + paid sources), но формально базовая платформа Apache-2.0

### Вариант C: 🔴 DIY на Tauri (если ничто готовое не устраивает)

- Свой минимальный desktop terminal: Tauri + lightweight-charts + bybit-api
- MVP за 2-3 недели solo
- "Near-Quantower lite" за 4-6 месяцев
- **Плюсы:** полный контроль, чистый OSS-стек, можно затачивать под наш use case
- **Минусы:** это **отдельный проект на месяцы**, отодвигает реальную торговлю. Для $1000-2000 капитала экономически сомнительно

## Моя рекомендация для нашего проекта

**Вариант A (flowsurface) для Sprint 0/1**, с возможным переходом на **Вариант C (DIY на Tauri)** позже, когда:
- Стратегия PMM Dynamic подтвердит прибыльность в testnet
- Мы поймём какие именно visual фичи нам реально нужны (а не "все")
- Капитал и опыт оправдают вложение в свой terminal

**Почему не Вариант B (StockSharp):** платная подписка на исходники GUI противоречит духу "100% OSS", даже если базовая лицензия Apache. Бесплатный бинарник из непрозрачной сборки — это де-факто proprietary.

**Что НЕ делать сейчас:**
- ❌ Тратить недели на DIY терминал до того как стратегия доказала прибыльность
- ❌ Использовать web/SaaS решения как замену desktop (отклонено пользователем)
- ❌ Пытаться построить идеальный terminal — perfect is enemy of good

## Action plan для закрытия Sprint 0

1. **Установить flowsurface** на Windows:
   - Скачать `flowsurface-windows-x86_64.zip` с https://github.com/flowsurface-rs/flowsurface/releases/latest
   - Распаковать, запустить `.exe`
   - В UI: Settings → добавить Bybit (без API ключей, для маркет-даты не нужны)
   - Открыть BTC/USDT chart, heatmap, footprint — убедиться что работает
   - Время: 10-15 минут

2. **Smoke test** в новой схеме:
   - Hummingbot CLI запущен (`connect bybit_testnet` уже работает)
   - flowsurface запущен с Bybit
   - В Hummingbot CLI `status` показывает баланс/позиции
   - В flowsurface виден live рынок BTCUSDT
   - Опционально: разместить тестовый ордер через Hummingbot CLI команду (или через `connect bybit_perpetual_testnet` и `balance`)
   - Время: 10-15 минут

3. **Обновить sprint_0_report.md** результатами + скриншоты flowsurface

4. **Commit + push** → Sprint 0 закрыт → переходим к Sprint 1

## Sources

- [flowsurface — main repo](https://github.com/flowsurface-rs/flowsurface)
- [flowsurface — site](https://flowsurface.com/)
- [flowsurface — releases (binaries)](https://github.com/flowsurface-rs/flowsurface/releases)
- [StockSharp main repo](https://github.com/StockSharp/StockSharp)
- [StockSharp Bybit connector docs](https://doc.stocksharp.com/topics/api/connectors/crypto_exchanges/bybit.html)
- [Plutus Terminal](https://github.com/plutus-terminal/plutus-terminal)
- [VisualHFT](https://github.com/visualHFT/VisualHFT)
- [OpenAlgo Desktop (Tauri)](https://github.com/marketcalls/openalgo-desktop)
- [QtBitcoinTrader](https://github.com/JulyIghor/QtBitcoinTrader)
- [bybit-tools (abandoned)](https://github.com/TranceGeniK/bybit-tools)
- [ASTRAS-Trading-UI (Angular web)](https://github.com/alor-broker/Astras-Trading-UI)
- [Tauri framework](https://github.com/tauri-apps/tauri)
- [TradingView lightweight-charts](https://github.com/tradingview/lightweight-charts)
- [bybit-api (TypeScript)](https://github.com/tiagosiebler/bybit-api)
- [Bybit.Net (C# .NET)](https://github.com/JKorf/Bybit.Net)
- [Awesome Tauri apps](https://github.com/tauri-apps/awesome-tauri)
- [QuantVPS — Top 7 Bookmap Alternatives](https://www.quantvps.com/blog/bookmap-alternatives)
- [Hummingbot Condor (web, для справки)](https://github.com/hummingbot/condor)
