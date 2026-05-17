# Отчёт Sprint 0: Установка инфраструктуры + пивот UI-стека

**Дата:** 2026-05-17
**Окружение:** Windows 10 Enterprise (19045) + WSL2 + Ubuntu 24.04.4 LTS
**Проект:** mm-bot — алгоритмический market-making бот на Bybit (Hummingbot 2.x + кастомный UI)
**GitHub:** https://github.com/anymasoft/mm-bot

## Краткое резюме

Sprint 0 выполнен с двумя крупными пивотами от исходного плана:

1. **Quantower вычеркнут** — не open source (free trial 7 дней + платные Crypto Package).
2. **UI-стек принят: форк Astras-Trading-UI от ALOR**, адаптация под Bybit + desktop wrap. Это превращает UI часть из "поставить готовый терминал" в **отдельный многоспринтовый sub-проект**.

Hummingbot 2.14.0 установлен, скомпилирован, подключён к Bybit testnet — балансы видны ($1270). Инфраструктурная часть полностью готова.

---

## 1. Системное окружение

| Параметр | Значение |
|---|---|
| Windows | 10.0.19045 Enterprise, AMD64 |
| RAM | 15.42 GB |
| Виртуализация в BIOS | Enabled |
| WSL2 kernel | 6.6.87.2-microsoft-standard-WSL2 |
| WSL2 версия | 2.6.3.0 |
| Ubuntu в WSL | 24.04.4 LTS |
| UNIX user | `dev` (uid=1000), passwordless sudo, systemd enabled |
| `.wslconfig` | memory=4GB, processors=2, swap=2GB |
| Свободно в WSL VHDX | 955 GB из 1007 GB |
| Miniconda | 26.3.2 |
| Python (в conda env) | 3.13.13 |
| Hummingbot | 2.14.0 (commit `91ff6bf`, 2026-04-21) |
| Bybit testnet balance | BTC 0.0085 + USDT 608.65 = **$1270 total** (spot) |
| Git | 2.49.0 (Windows), 2.43.0 (Ubuntu) |
| GitHub CLI | 2.60.1 (логин `anymasoft`, scopes: gist, read:org, repo, workflow) |

---

## 2. Что сделано (хронологически)

### 2.1. Чистка рабочей папки

Удалён старый Python scaffold (`src/mm_bot/`, `.venv/`, `pyproject.toml`, `tests/`, кэши). Сохранены: `.env` (с ключами Bybit, в `.gitignore`) и 3 промпта Sprint 0 — позже перемещены в `docs/sprint_prompts/`.

### 2.2. Починка WSL2 — две блокирующие проблемы

**Проблема №1: `0x800705aa Insufficient system resources`.**
WSL2 не стартовал. Свободно было ~3 GB из 15.42 GB (PyCharm + Opera + Claude Code), а WSL2 по умолчанию пытается захватить 50% RAM = ~7.7 GB.

**Решение:** создан `C:\Users\User\.wslconfig` с лимитами для систем <16 GB:
```ini
[wsl2]
memory=4GB
processors=2
swap=2GB
```

**Проблема №2: VHDX-файл Ubuntu отсутствовал.**
`C:\Users\User\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu24.04LTS_*\LocalState\ext4.vhdx` не существовал, хотя реестр содержал валидную регистрацию `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\{2bd4f362-...}` (State=1, DefaultUid=0x3e8, RunOOBE=0). Причина неизвестна — мог быть удалён сторонней утилитой очистки или после Windows update.

**Решение:** `wsl --unregister Ubuntu-24.04` + `wsl --install -d Ubuntu-24.04 --no-launch`.

### 2.3. Создание пользователя `dev` через root-режим

Поскольку `--no-launch` обходит интерактивный OOBE wizard, создал пользователя программно через `wsl -d Ubuntu-24.04 -u root -- bash -c "..."`:

```bash
useradd -m -s /bin/bash -G sudo dev
echo 'dev:111' | chpasswd
echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-dev
printf '[user]\ndefault=dev\n[boot]\nsystemd=true\n' > /etc/wsl.conf
```

Пароль `111` (по решению пользователя), passwordless sudo, systemd. После `wsl --terminate` дефолтный пользователь стал `dev`, sudo без пароля работает.

### 2.4. Установка Miniconda 26.3.2

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash miniconda.sh -b -p ~/miniconda3
~/miniconda3/bin/conda init bash
~/miniconda3/bin/conda config --set auto_activate_base false
```

**Подводный камень:** `-q` (quiet) flag, который я попробовал передать инсталлятору, не поддерживается — отсюда первая итерация упала. Без `-q` всё прошло.

### 2.5. Клонирование Hummingbot и `./install` — три блокера

```bash
git clone --depth 1 https://github.com/hummingbot/hummingbot.git
```

Версия: 2.14.0 (commit `91ff6bf`, 2026-04-21).

`./install` упал три раза, потребовалось три фикса:

**Блокер №1: Conda Terms of Service не приняты.**
```
CondaToSNonInteractiveError: Terms of Service have not been accepted for the following channels:
    - https://repo.anaconda.com/pkgs/main
    - https://repo.anaconda.com/pkgs/r
```

В conda 26.x требуется явное согласие с ToS для каналов `defaults` и `r`, которые используются в `setup/environment.yml` Hummingbot.

**Решение:**
```bash
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
```

**Блокер №2: `conda develop .` удалён в conda 26.x.**

```
conda: error: argument COMMAND: invalid choice: 'develop'
```

Скрипт `./install` Hummingbot использует устаревший `conda develop .` для регистрации проекта как editable package. В conda 26.x этой команды больше нет (раньше шла из пакета `conda-build`).

**Решение:** заменить на современный эквивалент:
```bash
conda activate hummingbot
cd ~/projects/hummingbot
pip install -e . --no-deps
```

Это создаёт editable install и регистрирует `hummingbot` как импортируемый пакет.

**Блокер №3: `pre-commit` упал, но не критично.**

`./install` запускает `pre-commit install` в конце для git hooks Hummingbot. Падает, потому что мы не в git-режиме разработки. Не критично — на runtime не влияет.

### 2.6. Компиляция Cython

```bash
./compile
```

Скомпилировались все `.so` модули включая критичные для нашей стратегии:
- `hummingbot.core.pubsub.PubSub`
- `hummingbot.strategy.pure_market_making.PureMarketMakingStrategy`
- `hummingbot.strategy.avellaneda_market_making.AvellanedaMarketMakingStrategy` ← **наша целевая стратегия**
- `hummingbot.connector.derivative.bybit_perpetual.BybitPerpetualDerivative`

### 2.7. Запуск CLI

```bash
python bin/hummingbot.py
```

ASCII welcome screen, Version 2.14.0 — работает.

### 2.8. Подключение к Bybit testnet

Сделано пользователем интерактивно через CLI:
1. Создан пароль для шифрования `conf/connectors/`
2. `connect bybit_testnet` (spot connector)
3. Введены API key + secret из `.env`
4. `balance` показал:
   - BTC: 0.0085 (≈ $661.1)
   - USDT: 608.6543 (≈ $608.6)
   - **Total: $1269.7**
5. Никаких UTA issues — баланс отображается корректно

**Замечание:** подключён `bybit_testnet` (spot), не `bybit_perpetual_testnet`. Для PMM Dynamic Avellaneda-Stoikov классически нужен perpetual + USDT в Derivatives Account. Будет частью Sprint 1.

### 2.9. Git/GitHub setup

- Git репо инициализирован в `C:\BUFFER\mm-bot` (пользователь выбрал переиспользовать папку, не создавать отдельную `~/projects/trading-bot-mm`)
- Default branch: `main`
- User: Sergei Nazarov / nazarov.soft@gmail.com
- gh CLI уже был залогинен как `anymasoft`
- Создан публичный GitHub репо: https://github.com/anymasoft/mm-bot
- 4 коммита, последний `16bbcb4` запушен в `origin/main`
- `.gitignore` строгий: `.env`, `**/conf/`, `*.key`, `*credentials*`, `.claude/`, виртуальные envs
- Security scan перед каждым commit'ом: реальные API ключи в diff не попали

---

## 3. Пивот №1: Quantower вычеркнут

При оценке Quantower обнаружено (скриншот в чате архитектора):

- All-in-One Package: **ACTIVE до 24.05.2026, осталось 7 days** (free trial)
- Crypto Package, Multi-asset Package, Advanced Features, Volume Analysis, Power Trades, DOM Surface, TPO Chart, Option Trading — **все BUY**
- Это **не open source**, исходники недоступны

Решение: пивот на 100% OSS стек до начала торговой работы.

---

## 4. Пивот №2: Research → решение принято — Astras-Trading-UI

### 4.1. Что не подходит из протестированных кандидатов

Подробно в [docs/research/oss_trading_terminals.md](../research/oss_trading_terminals.md). Краткий summary:

- **flowsurface** (Rust desktop, GPL-3.0, native Bybit) — лучший OSS Bookmap-clone, но read-only, **нет manual orders**
- **StockSharp Terminal** (C# WPF) — Bybit + manual orders есть, но **исходники GUI продаются $400/мес**, устаревший UX
- **Profitmaker** — web app + Commons Clause (не OSI-approved)
- **VisualHFT** — нет Bybit
- **Plutus Terminal** — только DEX
- **bybit-tools, QtBitcoinTrader** — заброшены
- **Hummingbot Dashboard / Condor / Freqtrade FreqUI / OctoBot / Jesse / Superalgos** — все WEB, не desktop
- **OpenAlgo Desktop (Tauri)** — только индийские брокеры

**Объективная реальность:** OSS desktop trading terminals на уровне Quantower/ASTRAS почти не существуют. Kraken закрыл Cryptowatch Desktop в 2023-09 (главный был кандидат); flowsurface — единственный достойный наследник.

### 4.2. Архитектор принял решение: **форк Astras-Trading-UI от ALOR**

Источник: https://github.com/alor-broker/Astras-Trading-UI

**Решение принудительное** — пользователь оценил все альтернативы и выбрал именно этот путь.

#### Факты про Astras-Trading-UI (проверено 2026-05-17)

| Параметр | Значение |
|---|---|
| Лицензия | **Apache-2.0** — чистая OSI, идеально |
| Stars | 84 |
| Forks | 26 |
| Last push | 2026-05-08 (активный, 5 коммитов в апреле 2026) |
| Open issues | 125 |
| Last release | v7.0 (2025-06-24) |
| Default branch | `master` |
| Размер | 31.9 MB |
| Stack | Angular **21.0.0**, TypeScript, RxJS 7.8, NgRx 21 |
| UI Kit | ng-zorro (Ant Design), angular-gridster2 (drag-drop widgets), TradingView charting library, Chart.js 4.5, Lightweight-charts 5.0, D3 7.9 |
| Backend | **ALOR API** (https://alor.dev) — WebSocket + REST + SSO JWT |
| Mobile | Ionic Capacitor (Android/iOS) |
| Desktop wrap | **НЕТ** (нет Electron, нет Tauri) |
| Crypto/Bybit/CCXT | **НЕТ** в dependencies |
| AGENTS.md | присутствует (значит активно работают с AI-исполнителями) |

#### Что внутри (модули в `src/app/modules/`)

36 feature-модулей. Наиболее релевантные для нашего use case:

- **scalper-order-book** — DOM/scalper view (ключевая фича ASTRAS)
- **orderbook** — стандартный стакан
- **light-chart**, **tech-chart** — графики (TradingView library)
- **all-trades** — Time & Sales
- **blotter** — таблица ордеров и позиций
- **portfolio-charts**, **portfolio-summary** — портфельные дашборды
- **order-commands**, **orders-basket** — manual orders
- **arbitrage-spread** — арбитраж
- **market-trends**, **instruments-correlation**, **treemap** — analytics
- **all-instruments**, **instruments** — справочник инструментов
- **news**, **events-calendar** — новости

Что **не релевантно для крипты** (можно отключить):
- `bond-screener` — облигации
- `option-board` — опционы
- `invest-ideas` — заточено под российский рынок
- `exchange-rate` — курсы валют (можно оставить как полезное)

### 4.3. Реалистичные масштабы работы (важно для архитектора)

**Что НЕ работает из коробки:**
1. **Backend hardcoded на ALOR API** — Angular service layer ожидает WebSocket/REST от https://alor.dev в их специфичном формате
2. **MOEX-специфика в frontend** — instrument codes, market hours (10:00-18:50 МСК), T+1 settlement, рублёвая валюта в портфеле
3. **Auth flow** — SSO с JWT через redirect на ALOR; Bybit использует API key + secret
4. **Desktop wrap отсутствует** — это WEB app; для нативного desktop нужен Electron или Tauri

**Что должно быть проще:**
- TradingView charting library нейтрален к источнику данных — поменять только feed
- Widget framework (gridster + ng-zorro) полностью переиспользуется
- Темы (тёмная/светлая, LESS) — переиспользуются
- NgRx state management — переиспользуется
- Все UI компоненты модулей `scalper-order-book`, `orderbook`, `tech-chart`, `blotter` — переиспользуются, нужно только подменить data source

**Реалистичная оценка миграции (один разработчик full-time):**

| Этап | Срок | Описание |
|---|---|---|
| Bybit adapter (backend) | 2-3 недели | Написать proxy-server (Node.js/Python) который превращает ALOR API в Bybit API |
| Frontend adaptation (минимум) | 2-3 недели | Поменять auth, instrument mapping, отключить нерелевантные модули, базовые crypto-specifics |
| Desktop wrap (Tauri) | 1-2 недели | Завернуть Angular app в Tauri 2.0 для native Windows .exe |
| MVP demo (одно окно + chart + DOM + orderbook + manual order) | **5-8 недель** | Объединение всех трёх |
| "Near-Quantower" (все нужные модули адаптированы) | 3-5 месяцев | Полная миграция |

Это **отдельный multi-sprint проект**, идущий параллельно с Hummingbot-разработкой стратегии.

### 4.4. Архитектурный вариант: Bybit adapter

Два возможных пути:

**Путь A: Proxy backend (рекомендую)**
```
Astras-Trading-UI (Angular)
    ↓ ALOR-format WS/REST
Bybit Adapter (новый Node.js или Python proxy)
    ↓ Bybit V5 API
Bybit testnet/mainnet
```

Плюсы: frontend трогаем минимально; proxy инкапсулирует все различия (formats, auth, instrument codes); легко добавлять новые биржи позже.
Минусы: extra moving part; нужна разработка нового сервиса.

**Путь B: Прямая модификация Angular services**
```
Astras-Trading-UI (Angular forked)
    ↓ модифицированные services вызывают Bybit V5 API напрямую
Bybit testnet/mainnet
```

Плюсы: меньше компонентов; не нужен отдельный сервер.
Минусы: дивергенция от upstream сильнее, мерджи новых релизов от ALOR становятся болью; ALOR-specific data structures всё равно надо менять в state.

**Рекомендация:** Путь A (proxy). Сохраняем upstream-совместимость; bybit_adapter — наш собственный микросервис.

---

## 5. Артефакты проекта

```
mm-bot/
├── README.md                                       # описание проекта
├── USAGE.md                                        # ежедневная инструкция (Hummingbot + WSL)
├── .gitignore                                      # строгий, защищает от утечек
├── .env                                            # API ключи Bybit (НЕ в git)
├── docs/
│   ├── sprint_prompts/                             # промпты от архитектора
│   │   ├── sprint_0_wsl2_pre_check.md
│   │   ├── sprint_0_git_setup.md
│   │   └── sprint_0_setup_prompt_windows_wsl.md
│   ├── sprint_reports/
│   │   ├── wsl_diagnostic_report.md                # детали починки WSL
│   │   └── sprint_0_report.md                      # этот файл
│   └── research/
│       ├── oss_trading_terminals.md                # research v2 — desktop only
│       └── astras_bybit_migration_plan.md          # roadmap миграции (создан в этом коммите)
├── scripts/
│   ├── hb_test.sh                                  # smoke test Hummingbot модулей
│   ├── hb_cli_test.sh                              # тест CLI запуска
│   └── hb_start.sh                                 # wrapper для запуска Hummingbot
├── strategies/                                     # YAML конфиги стратегий (Sprint 1+)
├── screenshots/                                    # скриншоты UI
└── astras-trading-ui/                              # форк (планируется в Sprint 1)
```

### Внешние файлы (не в репо)

- `C:\Users\User\.wslconfig` — WSL лимиты
- `~/projects/hummingbot/` (внутри WSL) — Hummingbot installation
- `~/projects/hummingbot/conf/connectors/bybit_testnet_*.yml` — зашифрованные API keys

---

## 6. Acceptance criteria — статус

### Изначальные (из промптов Sprint 0)

- [x] WSL2 установлен и работает
- [x] Ubuntu в WSL запускается, есть UNIX user
- [x] Miniconda установлена в WSL, `conda --version` работает
- [x] Hummingbot склонирован в `~/projects/hummingbot`
- [x] `conda env hummingbot` создан и активируется
- [x] `./compile` завершился без ошибок
- [x] `bin/hummingbot.py` запускает CLI
- ~~Quantower установлен~~ → **ВЫЧЕРКНУТО (не OSS)**
- [x] Bybit testnet API key работают в Hummingbot
- [x] Testnet USDT получены и видны ($1270 total)
- [x] Hummingbot CLI: `balance` показывает USDT
- ~~Quantower видит баланс и график~~ → **ВЫЧЕРКНУТО**
- ~~Smoke test через Quantower~~ → **отложен** (без UI стека сейчас неактуален)
- [x] Файл `sprint_0_report.md` создан со всеми разделами
- [x] Git репо создан на GitHub, публичный, push работает

### Новые (после пивота на Astras-Trading-UI)

- [x] Research desktop OSS terminals выполнен и задокументирован
- [x] Решение по UI стеку принято: форк Astras-Trading-UI + адаптация под Bybit
- [x] Создан migration plan: [astras_bybit_migration_plan.md](../research/astras_bybit_migration_plan.md)
- [ ] **(Sprint 1)** Форк Astras-Trading-UI создан под `anymasoft/astras-bybit-ui`
- [ ] **(Sprint 1)** Bybit adapter prototype (минимальная WS/REST proxy)
- [ ] **(Sprint 1)** Angular приложение запускается локально с Bybit adapter
- [ ] **(Sprint 2+)** Desktop wrap через Tauri 2.0

**Sprint 0 закрыт** — инфраструктура полностью готова, UI-стек выбран, multi-sprint план миграции готов.

---

## 7. Открытые вопросы для архитектора

### 7.1. Стратегия миграции Astras-Trading-UI
- **Путь A (proxy backend)** vs **Путь B (модификация Angular services)** — рекомендую A
- Хранить форк как часть `mm-bot` (sub-folder `astras-trading-ui/`) или отдельный репо `anymasoft/astras-bybit-ui`?
- Какая **первая user-facing feature** должна работать в Sprint 1?
  - Вариант 1: один scalper-order-book widget с live Bybit данными
  - Вариант 2: tech-chart с live BTCUSDT свечами
  - Вариант 3: blotter с позициями и балансом
  - Вариант 4: всё перечисленное в одном dashboard'е

### 7.2. Hummingbot ↔ ASTRAS интеграция
- ASTRAS UI и Hummingbot работают **параллельно**, оба через Bybit API (как изначально планировалось с Quantower)?
- Или построить дополнительный канал: Hummingbot → внутренний API → ASTRAS UI (показывает state бота напрямую)?

### 7.3. Spot vs Perpetual
- Сейчас подключён `bybit_testnet` (spot). Для PMM Dynamic Avellaneda-Stoikov классически нужен perpetual.
- В Sprint 1 переключиться на `bybit_perpetual_testnet`?
- Или сделать первый запуск на spot, чтобы быстрее увидеть результаты?

### 7.4. Desktop wrap
- Tauri 2.0 vs Electron для wrap Astras Angular приложения?
- Tauri (Rust) — 10MB бинарь, быстрый, но Rust learning curve
- Electron (Node) — 150-300MB бинарь, прожорливый, но огромная экосистема и быстрый старт
- Рекомендую Tauri 2.0 для consistency с подходом "лучшие практики 2026"

### 7.5. Лицензирование нашего форка
- Astras-Trading-UI Apache-2.0 → наш форк может остаться Apache-2.0 (просто) или поменять на GPL-3.0 (заставит downstream users open-source-нуть свои изменения)
- Учитывая что это наш приватный торговый инструмент — Apache-2.0 + добавить NOTICE с атрибуцией ALOR

### 7.6. Sprint 1 redefinition
- Изначальный Sprint 1 = "запуск PMM Dynamic на BTCUSDT testnet"
- Теперь требуется выбрать:
  - **Вариант A**: Sprint 1 = запуск PMM Dynamic (стратегия), Sprint 2 = форк Astras и начало миграции — стратегия идёт впереди UI
  - **Вариант B**: Sprint 1 = форк Astras + Bybit adapter MVP, Sprint 2 = PMM Dynamic — UI готовится первым
  - **Вариант C**: параллельно — split sprints (отдельные ветки разработки)

Рекомендую **A** (стратегия первой): без живой стратегии UI не на чем тестировать; testnet через Bybit web достаточно для дебага стратегии.

---

## 8. Lessons learned

1. **Скорая проверка лицензии экономит недели.** Quantower выглядел идеально по фичам, но проверка лицензии за 5 минут до установки спасла от tied-in setup.

2. **WSL2 — fragile в продакшене.** Два независимых блокера в одном сетапе (память + missing vhdx). Учить пользователей `.wslconfig` сразу.

3. **conda 26.x ломает Hummingbot install.** Это известная регрессия. Стоит зафиксировать в USAGE.md / Sprint 0 промптах для будущих установок (ToS accept + `pip install -e .` замена).

4. **OSS desktop trading terminals для крипты — крайне дефицитный рынок.** Объективно есть один кандидат (flowsurface). Если нужно что-то ещё — DIY на месяцы.

5. **Astras-Trading-UI — наиболее качественная OSS Angular база для торгового UI**, но миграция с ALOR на Bybit — multi-sprint sub-проект. Это инвестиция, не "взять и использовать".

6. **API keys hygiene работает.** Все 4 коммита прошли security scan, ни один реальный ключ не утёк в публичный репо. `.gitignore` + manual `git diff --staged` review + автоматический grep на хеш-патерны.
