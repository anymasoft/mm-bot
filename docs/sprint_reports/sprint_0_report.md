# Отчёт Спринта 0: Установка инфраструктуры

**Дата:** 2026-05-17
**Окружение:** Windows 10 Enterprise (19045) + WSL2 + Ubuntu 24.04 LTS
**Проект:** trading-bot-mm на Bybit (Hummingbot 2.x + Quantower)

## Системная информация

| Параметр | Значение |
|---------|---------|
| Windows версия | 10.0.19045 (Корпоративная) |
| Архитектура | AMD64 |
| RAM | 15.42 GB |
| Виртуализация в BIOS | Enabled |
| WSL2 версия | 2.6.3.0 |
| WSL kernel | 6.6.87.2-microsoft-standard-WSL2 |
| Ubuntu в WSL | 24.04.4 LTS |
| Miniconda версия | 26.3.2 |
| Свободно в WSL VHDX | 955 GB из 1007 GB |

## Установлено

### WSL2 + Ubuntu

| Параметр | Значение |
|---------|---------|
| WSL версия | 2 |
| Ubuntu | 24.04.4 LTS |
| UNIX username | `dev` (uid=1000) |
| Sudo | passwordless (через `/etc/sudoers.d/90-dev`) |
| Default user | `dev` (через `/etc/wsl.conf`) |
| Systemd | enabled |
| `.wslconfig` | memory=4GB, processors=2, swap=2GB |

См. подробный отчёт диагностики: [`wsl_diagnostic_report.md`](wsl_diagnostic_report.md).

### Hummingbot

| Параметр | Значение |
|---------|---------|
| Версия | **2.14.0** (commit `91ff6bf`, 2026-04-21) |
| Расположение | `~/projects/hummingbot` внутри WSL |
| Conda env | `hummingbot` (Python 3.13.13) |
| Установлен через | `./install` (после фикса) + `pip install -e .` |
| Компиляция Cython | SUCCESS |
| CLI запускается | YES (Welcome screen + Version 2.14.0) |

**Проверенные модули:**
- `hummingbot.core.pubsub.PubSub` — Cython core OK
- `hummingbot.strategy.pure_market_making.pure_market_making.PureMarketMakingStrategy` — PMM OK
- `hummingbot.strategy.avellaneda_market_making.avellaneda_market_making.AvellanedaMarketMakingStrategy` — **Avellaneda-Stoikov OK** (целевая стратегия)
- `hummingbot.connector.derivative.bybit_perpetual.bybit_perpetual_derivative.BybitPerpetualDerivative` — Bybit connector OK

### Quantower — ОТКЛОНЁН (не open source)

⚠️ **Quantower вычеркнут из проекта.** При оценке обнаружено: free trial 7 дней, потом Crypto Package / Multi-asset / Advanced Features — отдельно платные. **Не open source, исходники недоступны.**

Решено пивотнуть на 100% OSS стек до начала торговой работы. См. детальное research: [`../research/oss_trading_terminals.md`](../research/oss_trading_terminals.md).

**Замена:** composite UI = **Bybit web + TradingView free + (опционально) flowsurface + Hummingbot Condor**.

**Также важно:** **Hummingbot Dashboard deprecated** (последний релиз 10-2024), официальный заменитель — [**Hummingbot Condor**](https://github.com/hummingbot/condor). Это меняет архитектурное решение про visualisation layer.

## Bybit testnet

### Аккаунт

| Параметр | Значение |
|---------|---------|
| Account Mode | UTA (Unified Trading Account) — предположительно |
| API key (testnet) | хранится в `.env` (`MM_BOT_BYBIT_API_KEY`), не коммитится |
| API secret | хранится в `.env` (`MM_BOT_BYBIT_API_SECRET`), не коммитится |
| Testnet USDT | сообщил пользователь, что есть на счету (получено ранее) |
| Demo trading keys | дополнительно есть в `.env` (`MM_BOT_BYBIT_DEMO_*`) — на будущее |
| IP restriction | unknown — проверить если будут timestamp errors |

### Connectivity

| Что | Статус |
|----|--------|
| Hummingbot connector `bybit_perpetual_testnet` | загружается ✓ |
| Hummingbot CLI `connect bybit_testnet` (spot) | ✅ **ВЫПОЛНЕНО** |
| Hummingbot CLI `balance` | ✅ **РАБОТАЕТ** — показано 0.0085 BTC + 608.65 USDT = **$1270 total** на bybit_testnet (spot) |
| Hummingbot CLI `connect bybit_perpetual_testnet` | ⚠️ для PMM Dynamic нужно дополнительно подключить perpetual connector (нужны USDT в Derivatives Account на Bybit) |
| UI для визуализации | ⚠️ **План изменён** — см. research doc |

## Smoke test

⚠️ **Не выполнен в Sprint 0** — требует Quantower (которого пока нет) и подключённого Hummingbot.

## Найденные проблемы и решения

### Проблема 1: WSL2 не стартовал (0x800705aa)
**Причина:** свободно было только ~3 GB из 15.42 GB RAM, WSL2 пытался захватить ~7.7 GB.
**Решение:** создан `C:\Users\User\.wslconfig` с лимитом memory=4GB.

### Проблема 2: VHDX-файл Ubuntu-24.04 отсутствовал
**Причина:** неизвестна (возможно, был удалён сторонней утилитой). Реестр содержал валидную регистрацию.
**Решение:** `wsl --unregister Ubuntu-24.04` + `wsl --install -d Ubuntu-24.04 --no-launch` + создание `dev` пользователя через root режим.

### Проблема 3: Hummingbot `./install` упал при создании conda env
**Причина:** conda 26.x требует принять Terms of Service для каналов `defaults` и `r` перед установкой.
**Решение:** `conda tos accept --override-channels --channel <url>` для обоих каналов, повтор `./install`.

### Проблема 4: `conda develop .` упал в скрипте `./install`
**Причина:** в conda 26.x команда `conda develop` удалена (раньше была частью `conda-build`).
**Решение:** заменено на `pip install -e . --no-deps` — современный editable install. Это эквивалент `conda develop`.

### Проблема 5: Подключение Bybit к Hummingbot через программный API
**Причина:** `Security.secrets_manager_class` отсутствует в новой версии (API refactored).
**Решение:** оставить как интерактивный шаг через CLI Hummingbot (1 минута). Это единоразовая настройка.

## Выполненные шаги

### Шаг A: ✅ Hummingbot — connect Bybit testnet + balance check

Выполнено пользователем интерактивно через CLI. Скриншот в чате архитектора подтверждает:
- `connect bybit_testnet` — спот connector подключился
- `balance` показал на bybit_testnet:
  - BTC: 0.0085 (≈ $661.1)
  - USDT: 608.6543 (≈ $608.6)
  - **Total: $1269.7**
- **Никаких UTA issues** — баланс отображается корректно

**Замечание:** подключён `bybit_testnet` (spot connector), не `bybit_perpetual_testnet`. Для PMM Dynamic Avellaneda-Stoikov потребуется дополнительный `connect bybit_perpetual_testnet` с переводом USDT в Derivatives Account на Bybit testnet. Это будет частью Sprint 1.

### Шаг B: ⛔ Quantower — ОТКЛОНЁН (см. research)

Quantower оказался **не open source** (free trial 7 дней + платные пакеты Crypto/Multi-asset). Пивот на 100% OSS стек.

**Новый план (см. [research doc](../research/oss_trading_terminals.md)):** composite UI вместо single-vendor desktop terminal:

1. **Bybit testnet web** — primary trading UI (все ордера, позиции, manual override). Тот же endpoint, что Hummingbot.
2. **TradingView free** — серьёзный теханализ на втором мониторе (лучшие в индустрии charts).
3. **flowsurface** (опционально) — Rust desktop app, GPL-3.0, Bookmap-style heatmap + DOM ladder. Native Bybit. Read-only визуализатор.
4. **Hummingbot Condor** (для Sprint 1-2) — официальная замена deprecated Dashboard. Web + Telegram, portfolio aggregation.

### Шаг C: 🔄 Smoke test — упрощён

Старая версия требовала Quantower. Новая (через OSS стек):

1. Открыть https://testnet.bybit.com в Chrome
2. Разместить лимит-ордер на покупку 0.001 BTC по цене сильно ниже рынка (например 50000 при рынке 67000)
3. Проверить: ордер виден на Bybit web в **Orders → Active**
4. В Hummingbot CLI (если подключён `bybit_perpetual_testnet`): `orders` или `status`
5. Отменить ордер через Bybit web → исчезает

Это покрывает acceptance criteria "ордер размещён + виден + отменён".

**Альтернатива:** перенести smoke test в Sprint 1 (когда уже будет запущена реальная PMM Dynamic стратегия, бот сам начнёт ставить ордера — это и будет лучший smoke test).

## Артефакты, созданные в этом спринте

- [`docs/sprint_reports/wsl_diagnostic_report.md`](wsl_diagnostic_report.md) — подробный отчёт по починке WSL2
- [`docs/sprint_reports/sprint_0_report.md`](sprint_0_report.md) — этот файл
- [`docs/sprint_prompts/`](../sprint_prompts/) — все три промпта Sprint 0
- [`scripts/hb_test.sh`](../../scripts/hb_test.sh) — smoke test Hummingbot модулей и connectors
- [`scripts/hb_cli_test.sh`](../../scripts/hb_cli_test.sh) — тест запуска CLI (auto-exit)
- [`scripts/hb_start.sh`](../../scripts/hb_start.sh) — wrapper для запуска CLI
- [`README.md`](../../README.md) — описание проекта
- [`.gitignore`](../../.gitignore) — защита от утечки credentials
- `C:\Users\User\.wslconfig` (вне репо) — лимиты WSL2

## Открытые вопросы для архитектора

1. **Quantower вычеркнут — какой OSS стек выбрать?** См. детальное [research doc](../research/oss_trading_terminals.md). Главная развилка:
   - **Вариант 1 (рекомендую):** composite UI = Bybit web + TradingView free + flowsurface (опц.) + Hummingbot Condor. $0 затрат, ~80% качества Quantower, всё OSS-friendly.
   - **Вариант 2:** self-hosted Profitmaker (single web terminal, виджеты). Но лицензия MIT + Commons Clause (не чисто OSI-approved).
   - **Вариант 3:** Freqtrade + FreqUI. Но FreqUI привязан к Freqtrade-боту, не general-purpose.

2. **Hummingbot Dashboard deprecated — нужен ли Condor сразу?** Поставить в Sprint 0 или отложить до Sprint 1-2? Для одиночного PMM на одном активе можно обойтись Hummingbot CLI + Bybit web.

3. **Spot vs Perpetual для первой стратегии.** Сейчас подключён `bybit_testnet` (spot, $1270 видно). Для PMM Dynamic классически — perpetual. План:
   - А) В Sprint 1 переключиться на `bybit_perpetual_testnet`, перевести USDT в Derivatives Account
   - Б) Сделать первый запуск на spot (PMM Dynamic поддерживает spot тоже)
   Что предпочтительнее?

4. **flowsurface GPL-3.0** — мы клиенты, не разработчики, поэтому copyleft нас не ограничивает. Подтверждение?

5. **TradingView free tier** — 3 indicators, 1 chart per tab. Хватит для MM или Pro $14.95/мес.?

6. **Sprint 0 acceptance закрыть.** Считаем Sprint 0 закрытым по факту:
   - Инфраструктура работает (Hummingbot + Bybit testnet $1270 видны)
   - Решение по OSS UI принято (composite stack)
   - Документация и git-репо готовы
   - Quantower-зависимые шаги адаптированы

   Или нужно дополнительно: установить flowsurface + сделать smoke test через Bybit web до перехода к Sprint 1?

## Следующий шаг

После завершения Шагов A/B/C пользователем — обновить этот отчёт результатами:
- `balance` output из Hummingbot CLI
- Скриншоты Quantower (главный экран, Account Manager, DOM Trader с тестовым ордером)
- Скриншот Hummingbot CLI после `balance`
- Подтверждение smoke test'а

Затем — `git commit` + `git push`. Архитектор пишет промпт Sprint 1.

## Скриншоты (TODO для пользователя)

Положить в `screenshots/`:
1. `sprint_0_quantower_main.png` — Quantower главный экран с графиком BTCUSDT.P
2. `sprint_0_quantower_balance.png` — Quantower Account Manager с балансом
3. `sprint_0_quantower_order.png` — Quantower DOM Trader с тестовым ордером
4. `sprint_0_hummingbot_balance.png` — Hummingbot CLI после команды `balance`

## Acceptance criteria — статус (обновлено после пивота Quantower)

- [x] WSL2 установлен и работает
- [x] Ubuntu в WSL запускается, есть UNIX user (`dev`)
- [x] Miniconda установлена в WSL, `conda --version` работает (26.3.2)
- [x] Hummingbot склонирован в `~/projects/hummingbot`
- [x] `conda env hummingbot` создан и активируется (Python 3.13.13)
- [x] `./compile` завершился без ошибок
- [x] `bin/hummingbot.py` запускает CLI (Version 2.14.0)
- [x] Bybit testnet API key работают в Hummingbot ✅
- [x] Hummingbot CLI: `balance` показывает $1270 (BTC + USDT) ✅
- [x] Testnet USDT получены и видны
- ~~Quantower установлен~~ → **ВЫЧЕРКНУТО (не open source)**
- ~~Quantower видит баланс~~ → **ВЫЧЕРКНУТО**
- [ ] **(новое)** OSS UI стек выбран и установлен — **ждём решения архитектора**
- [ ] **(новое)** Smoke test через Bybit web → ордер виден в Bybit, отменяется
- [x] Файл `sprint_0_report.md` создан со всеми разделами
- [x] Research doc по OSS альтернативам создан: [`oss_trading_terminals.md`](../research/oss_trading_terminals.md)
- [x] Git репо `mm-bot` создан на GitHub: https://github.com/anymasoft/mm-bot
- [x] Все коммиты запушены в `origin/main`

**Sprint 0 готов к закрытию** при принятии архитектором решения по OSS UI стеку. Инфраструктурная часть выполнена полностью, Bybit testnet работает с балансом, пивот Quantower → composite OSS UI задокументирован.
