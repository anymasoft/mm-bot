# Open-source альтернативы Quantower для проекта mm-bot

**Дата:** 2026-05-17
**Триггер:** Quantower оказался не open source (7-дневный trial, Crypto Package — BUY, доступа к исходникам нет). Пользователь требует пивот на 100% OSS-стек, **до начала реальной торговой работы**.

## Контекст

Изначально Sprint 0 предполагал связку **Hummingbot 2.x + Quantower** (Quantower как professional desktop terminal для визуализации). Hummingbot уже установлен и подключён к Bybit testnet (балансы видны: 0.0085 BTC ≈ $661 + 608.65 USDT). Перед установкой Quantower обнаружено:

- **Quantower не open source**. Free 7-day trial, после — платные пакеты (Crypto Package, Multi-asset, Advanced Features и т.п. = BUY). Скриншот в чате архитектора подтверждает.
- Это критично, потому что:
  1. Невозможно аудитировать что Quantower делает с API ключами
  2. После trial — либо платить, либо терять функционал
  3. Невозможно кастомизировать или интегрировать на уровне исходников
  4. Поставить на mainnet с реальными деньгами без аудита — риск

Пользователь упоминает **ASTRAS от ALOR** как референс качества UI (российский desktop terminal, бесплатный для клиентов ALOR, не open source). Это используется как **планка качества**, а не как кандидат (ALOR не работает с Bybit).

## Жёсткие требования

1. Исходный код на GitHub, OSI-approved лицензия (MIT, Apache, GPL, AGPL)
2. Активная разработка (коммит за последние 6 месяцев)
3. Поддержка Bybit (нативно или через CCXT)
4. Real-time графики

## Желательные требования

5. Богатая графика (candlesticks, indicators, timeframes, drawing tools)
6. DOM/Order Book визуализация (как в Bookmap/ASTRAS)
7. Manual order placement
8. Position/balance/PnL display
9. UI на уровне платных терминалов

## Результаты research (проверено 2026-05)

| Проект | Stars | Последний релиз | Лицензия | Bybit | DOM | Charts | Manual orders | UI |
|---|---|---|---|---|---|---|---|---|
| **flowsurface** | 1.5k | v0.8.8 (04-2026) | GPL-3.0 | ✅ нативно | ✅ Heatmap + ladder | ✅ Candles, footprint | ❌ read-only | Desktop, Win/Mac/Linux |
| **Profitmaker** | 352 | активен | MIT + Commons Clause | ✅ через CCXT | ✅ widget | ✅ 13 TF | ✅ market/limit/stop/TP/iceberg | Web (React/shadcn) |
| **Freqtrade + FreqUI** | 50k+ / 987 | 2026.4 / 2.2.5 (04-05 2026) | GPL-3.0 | ✅ spot+futures | ❌ | ✅ candles+indicators | через REST | Web (Vue) |
| **Hummingbot Condor** | 95 | активен | MIT | ✅ через HB | ❌ | Portfolio chart | ✅ CEX module | Telegram + web |
| **OctoBot** | 5.9k | v2.1.1 (03-2026) | GPL-3.0+ | ⚠️ временно отключён | базовый | ✅ | ✅ | Web + mobile |
| **NautilusTrader** | 22.7k | активен | LGPL-3.0 | ✅ stable | ❌ нет GUI | Jupyter only | API only | — |
| **Superalgos** | 5.5k | v1.6.1 (11-2024) | Apache-2.0 | ❓ не подтверждено | ❌ | Visual designer | ✅ | Web, тяжёлый |
| **Hummingbot Dashboard** | 348 | v2.1.0 (10-2024) | Apache-2.0 | через HB | ❌ | Performance only | через CLI | Streamlit — **DEPRECATED** |
| **Jesse** | 7.9k | активен | MIT | ❓ не подтверждено | ❌ | Interactive | авто-стратегии | Built-in |
| **OpenBB Terminal** | 67.7k | активен | AGPL-3.0 | ❌ только research | ❌ | ✅ | ❌ | Workspace |
| **Bybit Perp Web Terminal** (ryu878) | 0 | 4 коммита | MIT | ✅ специально | ❌ | candles | ✅ | React MVP — **сырой** |

## Критические открытия

### 1. Hummingbot Dashboard — DEPRECATED

Hummingbot Dashboard (наш изначальный fallback в исходных промптах) **больше не разрабатывается**. Последний релиз — октябрь 2024. Команда Hummingbot переходит на новый продукт **Hummingbot Condor** (https://github.com/hummingbot/condor) — official replacement, MIT, активный. Это **отдельное приложение**, не часть Hummingbot Engine.

Condor даёт:
- Web dashboard (новый, не Streamlit)
- Telegram bot для контроля
- Portfolio PnL за 24h/7d/30d
- Активные ордера, позиции на CEX (включая Bybit)
- Manual orders с CEX
- "Harness for AI trading agents" — задумано как фундамент для будущих AI-стратегий

**Вывод:** наш план должен учитывать Condor, не deprecated Dashboard.

### 2. OctoBot временно без Bybit

OctoBot (популярный 5.9k stars web UI) — Bybit коннектор "will soon be available again" по их README. Пока недоступен. Если вернут — отличный кандидат для no-code UI. Сейчас — нет.

### 3. Для market-making лучший read-only терминал — flowsurface

flowsurface (Rust desktop app, 1.5k stars, GPL-3.0) — это **самая близкая open source альтернатива Bookmap**. Готовые бинарники под Windows. Bybit нативно. Имеет именно то, что нужно market-maker'у:
- Heatmap исторического order book (видишь где была ликвидность во времени)
- DOM ladder
- Footprint charts
- Time & sales
- Multi-window для нескольких мониторов
- Кастомные темы (включая светлую)

**Ограничение:** read-only. Поставить ордер вручную нельзя — для этого Bybit web.

Для нашего use case (наблюдать что делает PMM Dynamic бот) это идеально: мы не должны часто вмешиваться вручную, но должны видеть глубину рынка чтобы понимать почему бот делает то, что делает.

### 4. Никакой OSS desktop terminal не дотягивает до Quantower/ASTRAS по совокупности

Это не плохая новость, это объективная реальность. Quantower и ASTRAS — это десятки человеко-лет разработки коммерческими командами. **Никакой OSS клон не существует на уровне 1-в-1**. Лучшие OSS специализируются:
- **flowsurface** — orderflow visualization (узко но глубоко)
- **Profitmaker** — modern widget dashboard (broad но не глубоко)
- **FreqUI** — bot-specific monitoring (привязан к Freqtrade)
- **Condor** — Hummingbot-specific monitoring

Поэтому **правильное решение — не искать "one terminal to rule them all"**, а **собрать composite UI** из нескольких узкоспециализированных инструментов.

## Рекомендованный стек

```
┌────────────────────────────────────────────────────────────────┐
│  Monitor 1: Bybit web (testnet.bybit.com)                      │
│  - Все ордера и позиции (которые ставит Hummingbot)             │
│  - Manual override 2 клика                                      │
│  - Встроенный TradingView чарт                                  │
│  - DOM/L2 order book                                            │
│  - PnL, fills history, баланс                                   │
│  - 100% синхронизирован с тем что видит Hummingbot              │
├────────────────────────────────────────────────────────────────┤
│  Monitor 2: TradingView (бесплатный аккаунт)                    │
│  - Серьёзный теханализ, indicators, drawing tools               │
│  - Multi-timeframe                                              │
│  - Можно подключить Bybit как broker                            │
│  - Best-in-class качество графиков                              │
├────────────────────────────────────────────────────────────────┤
│  Monitor 3 (опционально): flowsurface                          │
│  - Heatmap + footprint + DOM ladder                             │
│  - Для понимания глубины ликвидности                            │
│  - Read-only, локальный Rust desktop app                        │
├────────────────────────────────────────────────────────────────┤
│  Headless: Hummingbot Condor                                    │
│  - Web dashboard + Telegram                                     │
│  - Portfolio aggregation                                        │
│  - Manual orders через UI/Telegram                              │
│  - Параллельно с Hummingbot CLI                                 │
└────────────────────────────────────────────────────────────────┘
```

**Стоимость:** $0 (Bybit web и TradingView free — бесплатные сервисы, не open source но и не self-hosted софт; flowsurface и Condor — OSS).

**Качество:** ~80% от опыта Quantower/ASTRAS, без trial/paywall ограничений, с возможностью аудита OSS-частей.

**Время на запуск:** один вечер.

## Альтернативы (если стек выше не подойдёт)

### Если нужен один self-hosted desktop terminal с manual orders

**Profitmaker** (https://github.com/suenot/profitmaker) — React 18 + shadcn/ui + Tailwind, drag-drop widgets, PostgreSQL. Bybit через CCXT (стабильно). Manual orders: market/limit/stop/TP/trailing-stop/iceberg. Виджеты: chart, order book, trades feed, order form, portfolio, positions.

**Минус:** лицензия **MIT + Commons Clause** — это не чисто OSI-approved (Commons Clause запрещает коммерческое использование как SaaS). Для личного использования OK, но если строго "только OSI-approved" — не подходит.

### Если хочется "всё в одном Python-приложении"

**Freqtrade + FreqUI** — самый зрелый стек (50k+ stars). Но **FreqUI это UI для бота Freqtrade**, не general-purpose terminal. Нет DOM. Manual orders только для пар которые Freqtrade сам отслеживает. Параллельная работа с Hummingbot — возможна, но Freqtrade захочет сам торговать (надо запускать в dry-run).

### Чего НЕ делать

- ❌ **Hummingbot Dashboard** — deprecated, не вкладывайся
- ❌ **OctoBot прямо сейчас** — Bybit отключён, ждать пока вернут
- ❌ **Tribeca** — мёртв с 2015
- ❌ **OpenBB Terminal** — research, не trading
- ❌ **Quantower / Bookmap / NinjaTrader / ASTRAS** — proprietary
- ❌ **wundertrading / 3Commas / finestel** — SaaS с paid tiers
- ❌ **Строить свой terminal с нуля** — для $1000-2000 капитала экономически бессмысленно
- ❌ **Заменять сам Hummingbot** на что-то другое — он работает, Avellaneda-Stoikov скомпилирован, не трогать

## Action plan для Sprint 0 (обновлённый)

### Шаг A: ✅ Bybit testnet в Hummingbot — ВЫПОЛНЕНО

(балансы видны: $1270 total на bybit_testnet — это spot, не perpetual; для PMM Dynamic нужно дополнительно `connect bybit_perpetual_testnet`)

### Шаг B (пересмотрено): Composite UI вместо Quantower

1. **Bybit testnet web** — открыть в Chrome, залогиниться, видеть всё что делает Hummingbot
2. **TradingView free** — открыть BYBIT:BTCUSDT.P чарт на втором мониторе
3. **flowsurface** (опционально, но рекомендуется) — скачать Windows binary с GitHub, подключить Bybit
4. **Hummingbot Condor** (отложить до Sprint 1 или 2) — установка отдельная, есть смысл когда стратегия запущена

### Шаг C: Smoke test (изменён)

Вместо размещения ордера через Quantower:
1. Открыть Bybit testnet web
2. Разместить лимит-ордер на покупку 0.001 BTC по цене сильно ниже рынка (~50000 при рынке 67000)
3. Проверить: ордер видно на Bybit testnet web ✅
4. В Hummingbot CLI: `orders` или `status` — должен видеть ордер (если в режиме `connect bybit_perpetual_testnet`)
5. Отменить ордер через Bybit web → исчезает

Это покрывает acceptance criteria "ордер размещён + виден в обеих системах + отменён".

## Открытые вопросы для архитектора

1. **Spot vs Perpetual.** Сейчас подключён `bybit_testnet` (spot). Для PMM Dynamic нужен `bybit_perpetual_testnet`. Перевести USDT в Derivatives Account? Или использовать spot для первой стратегии (PMM работает и на spot)?
2. **Condor сейчас или потом.** Установить Condor в Sprint 0 (чтобы был с самого начала) или отложить до Sprint 2 когда мы будем готовы к multi-asset deployment? Я склоняюсь к "отложить" — для одиночного PMM на одном активе Hummingbot CLI + Bybit web достаточно.
3. **flowsurface цвет лицензии.** GPL-3.0 — copyleft, если мы добавим свои патчи и захотим их распространять — обязаны под той же лицензией. Для нашего use case (мы клиент, не разработчик) это не проблема. Но стоит явно подтвердить.
4. **TradingView free аккаунт.** Бесплатный tier — 3 indicators, 1 chart per tab. Для market-making это хватает. Если понадобится больше — Pro $14.95/мес. Принципиально ли остаться 100% free?

## Финальная рекомендация

**Сменить план Sprint 0:**
- Quantower вычеркнуть полностью
- Composite UI = **Bybit web + TradingView free + (опционально) flowsurface**
- Hummingbot Condor рассмотреть в Sprint 1-2
- Acceptance criteria адаптировать: "ордер размещён и виден" заменить на "ордер размещён через Bybit web и виден в Hummingbot CLI через `orders`"

**Этот пивот:**
- Снижает риски (no trial, no paywall, no proprietary)
- Не теряет качество (Bybit web + TradingView объективно лучше многих OSS terminals)
- Не блокирует следующие спринты (Sprint 1 запуск стратегии не зависит от выбора UI)
- Сохраняет возможность позже добавить любой OSS terminal без переделок

## Источники

- [flowsurface](https://github.com/flowsurface-rs/flowsurface) — 1.5k ⭐, Rust, Bookmap-style heatmap
- [Profitmaker](https://github.com/suenot/profitmaker) — modern widget terminal
- [Hummingbot Condor](https://github.com/hummingbot/condor) — official replacement for deprecated Dashboard
- [Hummingbot Dashboard (deprecated)](https://github.com/hummingbot/dashboard)
- [Condor docs](https://hummingbot.org/condor/)
- [Freqtrade](https://github.com/freqtrade/freqtrade) — 50k ⭐, мощнейший Python framework
- [FreqUI](https://github.com/freqtrade/frequi) — Vue UI для Freqtrade
- [OctoBot](https://github.com/Drakkar-Software/OctoBot) — web UI, Bybit временно отключён
- [NautilusTrader](https://github.com/nautechsystems/nautilus_trader) — production engine, без GUI
- [Superalgos](https://github.com/Superalgos/Superalgos) — visual designer
- [Jesse](https://github.com/jesse-ai/jesse) — Python framework для крипты
- [OpenBB Terminal](https://github.com/OpenBB-finance/OpenBB) — research only
- [Tribeca](https://github.com/michaelgrosner/tribeca) — мёртв
- [Bybit Perp Web Terminal (ryu878)](https://github.com/ryu878/Bybit-Perpetual-Web-Terminal) — MVP, для справки
- [Freqtrade vs Hummingbot](https://gainium.io/compare/freqtrade-vs-hummingbot)
- [Best OSS crypto bots 2026](https://gainium.io/best/open-source)
- [QuantVPS Bookmap alternatives](https://www.quantvps.com/blog/bookmap-alternatives)
