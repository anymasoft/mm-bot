# Промпт-дополнение к Спринту 0: Настройка Git и GitHub для проекта

## Контекст

Это **второй промпт-дополнение** Спринта 0. Выполняется ПОСЛЕ промпта WSL2 диагностики (`sprint_0_wsl2_pre_check.md`) и ПЕРЕД основным промптом установки (`sprint_0_setup_prompt_windows_wsl.md`).

**Цель:** настроить локальный git репозиторий и связать его с публичным репозиторием на GitHub, чтобы архитектор проекта (Claude в чате через web search) мог напрямую читать код, отчёты и документацию проекта в GitHub после каждого коммита.

## Принципиальная схема работы

```
Локальная разработка                    Архитектор (Claude в чате)
────────────────────                    ────────────────────────────
C:\Users\<user>\projects\                              ▲
    trading-bot-mm\                                    │ Web fetch
    ├── README.md                                      │ raw.githubusercontent.com
    ├── docs/        ◄── Claude Code пишет             │
    ├── strategies/                                    │
    ├── screenshots/                                   │
    └── .gitignore                                     │
              │                                        │
              │ git push после спринта                 │
              ▼                                        │
    github.com/<user>/trading-bot-mm  ─────────────────┘
    (публичный репозиторий)
```

Архитектор не имеет прямого доступа к локальной машине пользователя, но может читать публичный GitHub репозиторий через web fetch. Это значит **после каждого спринта Claude Code обязан коммитить и пушить** все артефакты, чтобы архитектор мог проанализировать результаты и написать промпт следующего спринта на основе актуальной информации.

## Часть 1: Проверка существующих инструментов

### Шаг 1.1: Git на Windows

В PowerShell (обычный, не админ):

```powershell
git --version
```

**Вариант A:** Возвращает версию (например `git version 2.42.0.windows.1`) — Git установлен. Записать версию в отчёт.

**Вариант B:** Команда не найдена — Git не установлен. Установить через winget:
```powershell
winget install --id Git.Git -e --source winget
```

После установки закрыть и открыть PowerShell заново. Проверить `git --version`.

### Шаг 1.2: GitHub CLI (опционально, но удобно)

```powershell
gh --version
```

**Вариант A:** Возвращает версию — GitHub CLI установлен. Можно использовать для автоматизации.

**Вариант B:** Команда не найдена — установить через winget:
```powershell
winget install --id GitHub.cli -e --source winget
```

После установки закрыть и открыть PowerShell заново.

Если winget не работает — пропустить установку gh CLI. Создание репозитория можно сделать вручную через GitHub web UI (инструкции ниже в Части 3).

### Шаг 1.3: GitHub аккаунт пользователя

**ВАЖНО: НЕ запрашивать у пользователя пароль или Personal Access Token в чате. Только username публичный.**

Спросить у пользователя:
1. Есть ли у него GitHub аккаунт? Если нет — попросить создать (https://github.com/signup) и сообщить username.
2. Какой у него GitHub username?

Записать username в переменную для использования дальше.

### Acceptance проверка Части 1

- `git --version` отрабатывает
- GitHub username пользователя известен
- (опционально) `gh --version` отрабатывает

## Часть 2: Создание локальной структуры проекта

### Шаг 2.1: Создать корневую папку

В PowerShell:
```powershell
$projectPath = "$env:USERPROFILE\projects\trading-bot-mm"
New-Item -ItemType Directory -Force -Path $projectPath
cd $projectPath
```

Это создаёт `C:\Users\<username>\projects\trading-bot-mm\` и переходит туда.

### Шаг 2.2: Создать структуру каталогов

```powershell
# Создать поддиректории
New-Item -ItemType Directory -Force -Path "docs"
New-Item -ItemType Directory -Force -Path "docs\sprint_prompts"
New-Item -ItemType Directory -Force -Path "docs\sprint_reports"
New-Item -ItemType Directory -Force -Path "strategies"
New-Item -ItemType Directory -Force -Path "screenshots"
New-Item -ItemType Directory -Force -Path "scripts"
```

Финальная структура:
```
trading-bot-mm/
├── README.md
├── USAGE.md (создаётся в конце Спринта 0)
├── .gitignore
├── docs/
│   ├── sprint_prompts/         # Промпты от архитектора
│   └── sprint_reports/         # Отчёты по спринтам
├── strategies/                  # YAML конфиги стратегий Hummingbot (копии)
├── screenshots/                 # Скриншоты Quantower и Hummingbot
└── scripts/                     # Вспомогательные скрипты (миграции, дампы и т.д.)
```

### Шаг 2.3: Создать .gitignore (КРИТИЧНО)

Создать файл `.gitignore` в корне проекта со следующим содержимым:

```gitignore
# ============================================
# CRITICAL: Никогда не коммитить чувствительные данные
# ============================================

# Все .env файлы
.env
.env.*
*.env

# Hummingbot encrypted credentials и конфиги с ключами
**/conf/
**/conf_*/
**/credentials/
*.yml-encrypted
*.key
*.pem
*.cer

# API keys в любых файлах
*api_key*
*api_secret*
*credentials*

# ============================================
# Логи и временные файлы
# ============================================

logs/
*.log
*.log.*
*.tmp
*.bak
*.backup

# ============================================
# Системные файлы
# ============================================

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini
$RECYCLE.BIN/

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Linux
*~
.directory

# ============================================
# IDE и редакторы
# ============================================

.vscode/
.idea/
*.swp
*.swo
*~
.project
.pydevproject

# ============================================
# Python
# ============================================

__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
.pytest_cache/
.coverage
htmlcov/

# Virtual envs
venv/
env/
ENV/
.venv/

# ============================================
# Базы данных и данные бэктеста
# ============================================

*.db
*.db-journal
*.db-wal
*.db-shm
*.sqlite
*.sqlite3

# Большие файлы данных
data/
backtest_data/
historical_data/
*.csv.gz
*.parquet

# ============================================
# Node.js (на случай если будем строить frontend)
# ============================================

node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*

# ============================================
# Quantower
# ============================================

# Quantower workspace settings (могут содержать ключи)
QuantowerWorkspace/

# ============================================
# Личные заметки и временные файлы
# ============================================

NOTES_PRIVATE.md
TODO_PRIVATE.md
notes/
private/
```

**Это критично. Без этого .gitignore при первом коммите могут утечь API ключи или другие чувствительные данные.**

### Шаг 2.4: Создать первоначальный README.md

Создать `README.md` в корне проекта:

```markdown
# Trading Bot MM — Market Making Strategy on Bybit

Алгоритмический торговый бот на стратегии **Pure Market Making Dynamic** (Avellaneda-Stoikov) для Bybit Perpetual.

## Архитектура

- **Engine:** Hummingbot 2.x (работает в WSL2 Ubuntu)
- **UI:** Quantower (Windows native, профессиональный desktop terminal)
- **Биржа:** Bybit (Testnet → Mainnet после валидации стратегии)

## Статус проекта

Текущая фаза: **Sprint 0** — установка инфраструктуры.

См. `docs/sprint_reports/` для детальных отчётов по каждому спринту.

## Структура репозитория

```
trading-bot-mm/
├── docs/
│   ├── sprint_prompts/    # Промпты от архитектора для каждого спринта
│   └── sprint_reports/    # Отчёты Claude Code по выполненным спринтам
├── strategies/             # YAML конфиги стратегий Hummingbot
├── screenshots/            # Скриншоты UI для архитектора
├── scripts/                # Вспомогательные скрипты
├── USAGE.md                # Инструкция по ежедневному использованию
└── README.md               # Этот файл
```

## Безопасность

**API ключи никогда не коммитятся.** Все credentials хранятся:
- Hummingbot: в `~/projects/hummingbot/conf/` внутри WSL (encrypted, исключён через .gitignore)
- Quantower: в Windows keystore приложения
- Любые `.env` файлы — в .gitignore

## Команды для работы

См. `USAGE.md` для ежедневной инструкции.

## Workflow

1. Архитектор пишет промпт в чате — пользователь копирует в `docs/sprint_prompts/sprint_N_*.md`
2. Claude Code выполняет промпт локально
3. По завершению — пишет отчёт в `docs/sprint_reports/sprint_N_report.md`
4. Все артефакты коммитятся и пушатся в GitHub
5. Архитектор читает отчёт через GitHub, пишет промпт следующего спринта

## Лицензия

Приватный проект. Все права защищены.
```

### Acceptance проверка Части 2

- Папка `C:\Users\<username>\projects\trading-bot-mm\` создана
- Поддиректории созданы
- `.gitignore` создан со всем содержимым выше
- `README.md` создан

## Часть 3: Инициализация git и создание GitHub репозитория

### Шаг 3.1: Локальная инициализация git

В PowerShell, находясь в директории проекта:

```powershell
# Инициализировать git репо
git init

# Настроить имя ветки по умолчанию как main
git branch -M main

# Настроить user.name и user.email если ещё не настроены глобально
git config user.name "<имя пользователя для коммитов>"
git config user.email "<email пользователя>"
```

**Имя и email** — спросить у пользователя. Email можно использовать GitHub no-reply email (формат `<id>+<username>@users.noreply.github.com`) для приватности, если пользователь не хочет светить личный email в публичных коммитах. Этот no-reply email пользователь может найти в своих GitHub Settings → Emails.

### Шаг 3.2: Первый локальный коммит

```powershell
git add .
git status
```

**Проверить вывод `git status`** перед коммитом — убедиться, что в списке нет ничего из:
- Файлов с api_key, secret, credentials в названии
- `.env` файлов
- Папки `conf/` (Hummingbot encrypted credentials)
- Логов

Если что-то подозрительное попало — **остановиться**, проверить .gitignore, добавить туда нужные паттерны, выполнить `git rm --cached <file>` для уже отслеживаемых, и попробовать снова.

Если всё чисто:
```powershell
git commit -m "Initial commit: project structure and documentation framework"
```

### Шаг 3.3: Создание GitHub репозитория

**Вариант A: Через GitHub CLI (если установлен и работает).**

Сначала авторизоваться:
```powershell
gh auth login
```

Следовать prompts: выбрать GitHub.com → HTTPS → авторизация через браузер (откроется страница GitHub с кодом).

После успешной авторизации создать репозиторий:
```powershell
gh repo create trading-bot-mm --public --source=. --remote=origin --description "Market making bot on Bybit using Hummingbot + Quantower"
```

Это создаёт публичный репозиторий `<username>/trading-bot-mm` на GitHub и связывает локальный repo с remote `origin`.

**Вариант B: Через GitHub web UI (если gh CLI не работает).**

1. Открыть в браузере https://github.com/new
2. Repository name: `trading-bot-mm`
3. Description: `Market making bot on Bybit using Hummingbot + Quantower`
4. Visibility: **Public** (критично, чтобы архитектор мог читать через web fetch)
5. **НЕ** ставить галочку "Add a README" (у нас уже есть локальный)
6. **НЕ** добавлять .gitignore через GitHub (у нас уже есть)
7. **НЕ** выбирать лицензию пока
8. Нажать **Create repository**

После создания GitHub покажет инструкции. Использовать секцию "push an existing repository from the command line":

```powershell
git remote add origin https://github.com/<username>/trading-bot-mm.git
git branch -M main
```

### Шаг 3.4: Push в GitHub

```powershell
git push -u origin main
```

При первом push потребуется авторизация:
- Если установлен GitHub CLI — авторизация автоматическая через сохранённые credentials
- Если нет — откроется GitHub credential manager, нужно войти через браузер или ввести Personal Access Token

**Никогда не вводить и не сохранять PAT в чате с Claude Code.** Если требуется PAT — Claude Code должен попросить пользователя ввести его в браузере / credential manager напрямую.

### Шаг 3.5: Проверка

Открыть в браузере: `https://github.com/<username>/trading-bot-mm`

Должно быть видно:
- README.md в корне репозитория (отрендеренный)
- Папки docs/, strategies/, screenshots/, scripts/ (могут быть пустыми с .gitkeep если git их не хочет добавлять)
- Файл .gitignore

**Если хотя бы один файл с подозрительным содержимым (например, .env) попал в публичный репо** — НЕМЕДЛЕННО:
1. Удалить репозиторий через GitHub web UI (Settings → Danger Zone → Delete this repository)
2. Локально: `git rm --cached <file>`, обновить .gitignore, новый commit
3. Создать репозиторий заново
4. Push заново

Также если случайно скомпрометированы API keys — отозвать их немедленно через Bybit testnet интерфейс и создать новые.

### Acceptance проверка Части 3

- Локальный git репо инициализирован
- Initial commit создан
- GitHub репозиторий создан как публичный
- Push в `origin/main` успешен
- В GitHub web UI видны README, .gitignore, структура папок
- В коммитах нет чувствительной информации

## Часть 4: Workflow для будущих спринтов

После каждого завершённого спринта Claude Code обязан выполнить следующие шаги в локальной директории проекта `C:\Users\<username>\projects\trading-bot-mm\`:

### Шаг 4.1: Скопировать новые артефакты в репо

В зависимости от спринта это может быть:

- Промпт текущего спринта → `docs/sprint_prompts/sprint_N_*.md`
- Отчёт о выполнении → `docs/sprint_reports/sprint_N_report.md`
- Любые скриншоты → `screenshots/sprint_N_<описание>.png`
- YAML конфиги стратегий (без API keys!) → `strategies/<config_name>.yml`
- Любые вспомогательные скрипты → `scripts/<script_name>.py`
- Обновлённый USAGE.md (если изменился) → `USAGE.md` в корне

**Перед копированием каждого файла проверять что в нём нет API keys, паролей, или других чувствительных данных.** Если есть — заменить на placeholder типа `<API_KEY_HERE>` или вообще не коммитить.

### Шаг 4.2: Финальный sanity check

```powershell
cd $env:USERPROFILE\projects\trading-bot-mm
git status
git diff --staged
```

**Внимательно прочитать diff перед коммитом.** Искать:
- Строки с api_key, api_secret, password, token
- Hex-строки длиннее 20 символов (могут быть ключами)
- Email-адреса (если приватные)
- Пути с именем пользователя если это важно

Если что-то подозрительное — `git restore --staged <file>`, исправить, и снова `git add`.

### Шаг 4.3: Commit с осмысленным сообщением

Формат сообщения коммита:
```
Sprint N complete: <краткое описание главного результата>

- Выполнено: ...
- Артефакты: ...
- Проблемы: ...
- Следующий шаг: ...
```

Пример для Спринта 0:
```
Sprint 0 complete: WSL2 + Hummingbot + Quantower installed and connected to Bybit testnet

- WSL2 with Ubuntu 24.04 installed and configured
- Hummingbot 2.x built from source via Miniconda in WSL
- Quantower installed natively on Windows 10, Russian UI, light theme
- Both connected to Bybit testnet with 10000 USDT visible
- Smoke test passed: test order placed via Quantower visible on Bybit testnet

Артефакты:
- docs/sprint_reports/sprint_0_report.md
- docs/sprint_reports/wsl_diagnostic_report.md
- screenshots/sprint_0_quantower_main.png
- screenshots/sprint_0_quantower_balance.png
- screenshots/sprint_0_hummingbot_cli.png
- USAGE.md

Проблемы: <если были, например про UTA mode>
Следующий шаг: ожидание промпта Sprint 1 от архитектора
```

Команда:
```powershell
git add .
git commit -m "Sprint 0 complete: WSL2 + Hummingbot + Quantower installed and connected to Bybit testnet" -m "Detailed: см. docs/sprint_reports/sprint_0_report.md"
```

### Шаг 4.4: Push в GitHub

```powershell
git push
```

### Шаг 4.5: Сообщить пользователю URL коммита

После успешного push дать пользователю прямую ссылку на коммит, например:
```
✅ Спринт 0 закоммичен и опубликован.

GitHub репозиторий: https://github.com/<username>/trading-bot-mm
Последний коммит: https://github.com/<username>/trading-bot-mm/commit/<hash>

Архитектор может теперь прочитать отчёт по адресам:
- https://raw.githubusercontent.com/<username>/trading-bot-mm/main/docs/sprint_reports/sprint_0_report.md
- https://raw.githubusercontent.com/<username>/trading-bot-mm/main/USAGE.md
- https://raw.githubusercontent.com/<username>/trading-bot-mm/main/docs/sprint_reports/wsl_diagnostic_report.md

Скриншоты:
- https://github.com/<username>/trading-bot-mm/tree/main/screenshots
```

Эти URL пользователь передаёт архитектору в чате.

## Часть 5: Безопасность API ключей

### Принципы

1. **API ключи никогда не коммитятся в репо**, даже testnet. Привычка должна выработаться рано — на mainnet это уже критично.
2. **Hummingbot хранит ключи в `~/projects/hummingbot/conf/`** в зашифрованном виде. Эта папка целиком в `.gitignore`.
3. **Quantower хранит ключи в Windows keystore** — это вне нашего репо.
4. **Если случайно ключ попал в коммит** — действовать как описано в Шаге 3.5.

### Чек-лист перед каждым `git commit`

- [ ] Проверил `git diff --staged` глазами
- [ ] В diff нет строк с `api_key`, `secret`, `password`, `token` (кроме placeholder'ов)
- [ ] В diff нет hex-строк выглядящих как ключи
- [ ] Папка `conf/` не попала в staged
- [ ] `.env` файлы не попали в staged

### Если ключ всё-таки утёк в публичный коммит

Действовать **немедленно**:

1. Отозвать утекший API ключ на Bybit (testnet или mainnet) через интерфейс API Management → Delete Key
2. Создать новый API ключ с теми же permissions
3. Перенастроить Hummingbot и Quantower на новые ключи
4. Очистить историю git от утечки. Самый простой способ для маленького проекта — удалить весь репо на GitHub и создать заново. Для сохранения истории можно использовать `git filter-repo` или BFG Repo-Cleaner, но это сложнее.

**Лучше не допускать утечки изначально — внимательность к `git status` и `git diff` перед каждым коммитом.**

## Часть 6: Передача доступа архитектору

После того как репозиторий создан и сделан публичным, **пользователь сообщает архитектору** в чате:

> GitHub репозиторий проекта: https://github.com/<username>/trading-bot-mm

Архитектор может через web fetch читать:
- Любой файл в репо через `https://raw.githubusercontent.com/<username>/trading-bot-mm/main/<path>`
- Список файлов и структуру через GitHub web UI

**Архитектор обязуется:**
- Перед написанием промпта следующего спринта прочитать актуальный отчёт по последнему спринту в репо
- При написании промптов учитывать структуру репо и пути к артефактам
- Не запрашивать у пользователя содержимое файлов которые уже в репо — читать самостоятельно через web fetch

## Acceptance criteria для этого промпта

- [ ] Git установлен и настроен (user.name, user.email)
- [ ] (опционально) GitHub CLI установлен и авторизован
- [ ] GitHub username пользователя известен и записан в отчёт
- [ ] Локальная папка `C:\Users\<username>\projects\trading-bot-mm\` создана с правильной структурой
- [ ] `.gitignore` создан с полным набором правил (см. Часть 2.3)
- [ ] `README.md` создан с описанием проекта
- [ ] Локальный git репо инициализирован, initial commit создан
- [ ] GitHub публичный репо создан, name `trading-bot-mm`
- [ ] `git push` успешен, в GitHub web UI всё видно
- [ ] В первом коммите **проверено отсутствие** API keys, паролей, чувствительных данных
- [ ] Workflow для будущих коммитов понятен (Часть 4)

## Важные замечания для Claude Code

1. **НИКОГДА не запрашивать у пользователя пароль или Personal Access Token в чате.** Если нужна авторизация — направить пользователя к браузерному credential manager или к `gh auth login`.

2. **НИКОГДА не записывать API keys в файлы которые могут попасть в git.** Даже если кажется что .gitignore их исключит — лучше вообще не записывать.

3. **Перед каждым push** — пройти чек-лист безопасности из Части 5.

4. **При создании GitHub репо — обязательно публичный.** Если пользователь категорически против — спросить, как он планирует давать доступ архитектору (это сложнее: либо инвайт архитектора как collaborator с PAT, либо вручную копировать содержимое в чат, что неэффективно).

5. **Имя репо `trading-bot-mm`** — стандартное, не несёт чувствительной информации.

6. **Если push падает** — сначала проверить что remote настроен правильно (`git remote -v`), потом авторизацию, потом сеть.

7. **Локальная папка проекта на Windows host, не в WSL.** Это упрощает интеграцию с Quantower скриншотами и нормальный Windows-доступ к файлам. WSL имеет доступ к этой папке через `/mnt/c/Users/<username>/projects/trading-bot-mm/` — это удобно для копирования Hummingbot конфигов в наш репо.

## Что делать после этого промпта

Переходить к основному промпту Спринта 0 (`sprint_0_setup_prompt_windows_wsl.md`). По его завершению — финальный commit и push в этот GitHub репо со всеми артефактами (отчёты, скриншоты, USAGE.md).
