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

### Quantower

⚠️ **НЕ установлен в Sprint 0** — требует ручного скачивания с https://www.quantower.com и интерактивной настройки (Quantower Account, язык, тема, подключение Bybit). См. раздел "Открытые шаги" ниже.

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
| Hummingbot CLI `connect bybit_perpetual_testnet` | ⚠️ **требует ручной шаг** — см. ниже |
| Hummingbot CLI `balance` | ⚠️ зависит от предыдущего шага |
| Quantower подключение | ⚠️ не настроено (Quantower не установлен) |

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

## Открытые шаги (требуют пользователя)

### Шаг A: Hummingbot — connect Bybit testnet + balance check

В WSL terminal:
```bash
cd ~/projects/hummingbot
source ~/miniconda3/etc/profile.d/conda.sh
conda activate hummingbot
python bin/hummingbot.py
```

В Hummingbot CLI:
1. При первом запуске придумать **password** (используется для шифрования conf/connectors/).
2. Ввести команду:
   ```
   connect bybit_perpetual_testnet
   ```
3. На запрос API key ввести значение из `.env` (`MM_BOT_BYBIT_API_KEY`)
4. На запрос API secret ввести значение из `.env` (`MM_BOT_BYBIT_API_SECRET`)

   Из WSL `.env` доступен по пути `/mnt/c/BUFFER/mm-bot/.env`. Удобно открыть его в редакторе и скопировать значения. **Никогда не вставлять ключи напрямую в git-коммиты или публичные документы.**
5. Ввести `balance` — должен показать USDT баланс на bybit_perpetual_testnet.

**Если balance = 0 при наличии USDT** — это UTA issue. Записать сюда в отчёт и сообщить архитектору.

### Шаг B: Quantower — установка и настройка

1. Открыть https://www.quantower.com → Download → Windows installer
2. Установить как обычное Windows-приложение
3. Создать **Quantower Account** (email + password)
4. **Settings → General → Language → Russian** → перезапуск
5. **Settings → Appearance → Theme → Light**
6. **Connections → Add Connection → Bybit**:
   - Mode: Trading
   - Network: Testnet
   - API Key: значение из `.env` (`MM_BOT_BYBIT_DEMO_API_KEY` — отдельная пара для Quantower для разделения ролей) **ИЛИ** те же что в Hummingbot
   - API Secret: соответствующий (`MM_BOT_BYBIT_DEMO_API_SECRET` или `MM_BOT_BYBIT_API_SECRET`)
7. Проверить: статус **Connected**, баланс ~10 000 USDT, график **BTCUSDT.P** обновляется

Если ошибка "Timestamp error" — синхронизировать время Windows: Settings → Time & Language → Sync now.

### Шаг C: Smoke test

1. В Quantower открыть **DOM Trader** для BTCUSDT.P
2. Разместить **лимитный ордер на покупку 0.001 BTC** по цене **значительно ниже рынка** (например, рынок 67000, ставим 50000)
3. Подтвердить → ордер должен появиться в **Working Orders**
4. Открыть https://testnet.bybit.com → Orders → подтвердить что ордер видно там
5. Из Quantower **отменить** ордер → исчезает из Quantower и testnet.bybit.com

Если ордер виден в обеих системах — smoke test пройден.

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

1. **Sprint 1 готовность.** Когда пользователь завершит Шаги A/B/C, можно ли сразу переходить к Sprint 1 (запуск PMM Dynamic на BTCUSDT testnet)? Или нужна промежуточная проверка отчёта от пользователя?

2. **UTA balance display.** Если в Шаге A balance = 0 при наличии USDT — это известная проблема. План B (subaccount) или другой подход?

3. **Quantower API keys.** Использовать те же что в Hummingbot, или вторую пару с Read-only правами? Сейчас в `.env` есть отдельные **Demo keys** — их можно использовать в Quantower для разделения ролей.

4. **Hummingbot версия 2.14.0** — самая свежая на дату. Подходит для нашего use case с PMM Dynamic / Avellaneda-Stoikov.

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

## Acceptance criteria — статус

- [x] WSL2 установлен и работает
- [x] Ubuntu в WSL запускается, есть UNIX user (`dev`)
- [x] Miniconda установлена в WSL, `conda --version` работает (26.3.2)
- [x] Hummingbot склонирован в `~/projects/hummingbot`
- [x] `conda env hummingbot` создан и активируется (Python 3.13.13)
- [x] `./compile` завершился без ошибок
- [x] `bin/hummingbot.py` запускает CLI (Version 2.14.0)
- [ ] Quantower установлен на Windows, на русском, светлая тема — **ШАГ B**
- [ ] Bybit testnet API key работают в Hummingbot — **ШАГ A**
- [x] Testnet USDT (~10 000) получены пользователем ранее (заявлено)
- [ ] Hummingbot CLI: `balance` показывает USDT — **ШАГ A**
- [ ] Quantower: видит баланс и график BTCUSDT.P — **ШАГ B**
- [ ] Smoke test: ордер размещён через Quantower — **ШАГ C**
- [x] Файл `sprint_0_report.md` создан со всеми разделами
- [x] Git репо `mm-bot` создан на GitHub: https://github.com/anymasoft/mm-bot
- [x] Initial commit запушен в `origin/main`

**Sprint 0 закрыт частично** — инфраструктура полностью готова, открыты 3 интерактивных шага для пользователя (Bybit connect, Quantower install, smoke test).
