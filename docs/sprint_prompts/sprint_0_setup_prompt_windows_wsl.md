# Спринт 0 (Windows 10 + WSL2): Установка Hummingbot и Quantower с Bybit testnet

## Контекст для Claude Code

Это первый спринт большого проекта по созданию торгового бота на стратегии Pure Market Making Dynamic (Avellaneda-Stoikov) на Bybit. Используем **Hummingbot 2.x** как движок стратегии и **Quantower** как профессиональный desktop terminal для визуализации.

**Цель этого спринта — ТОЛЬКО установка и проверка работоспособности. Никакого кода стратегии, никакой торговой логики. Только инфраструктура.**

## Окружение пользователя

- ОС: **Windows 10** (host)
- Уже установлено: Python 3.11 (Windows), Node.js (Windows)
- Уже **НЕ** установлено: Anaconda, Docker — и устанавливать НЕ нужно
- Hummingbot будет работать в **WSL2 (Ubuntu)** через **Miniconda внутри WSL** — это не Docker, это нативная Linux подсистема Windows
- Quantower будет работать на **Windows нативно**

После выполнения этого спринта пользователь должен получить:
1. WSL2 с Ubuntu 22.04 LTS
2. Miniconda внутри WSL
3. Hummingbot 2.x скомпилированный и запущенный из CLI в WSL
4. Quantower на Windows, на русском языке, светлая тема
5. Оба подключены к Bybit testnet и видят баланс
6. Smoke test: ордер виден в обеих системах
7. Файл `sprint_0_report.md` с детальным отчётом

## Часть 1: Установка WSL2 на Windows 10

### Pre-checks

Открыть PowerShell от **администратора** (это важно — без админских прав WSL не установится). Выполнить:

```powershell
# Проверить версию Windows
winver
```

Должно быть Windows 10 версии 2004 (build 19041) или выше. Если ниже — обновить Windows через Settings → Update & Security перед продолжением.

```powershell
# Проверить включена ли виртуализация в BIOS
systeminfo | findstr /C:"Virtualization Enabled In Firmware"
```

Если показывает `No` — нужно зайти в BIOS/UEFI и включить Intel VT-x / AMD-V. Без этого WSL2 не запустится. Если пользователь не уверен — может остановиться здесь, сделать это вручную, и продолжить.

### Установка WSL2

```powershell
# Одной командой ставит WSL2 + Ubuntu по умолчанию
wsl --install
```

Эта команда:
- Включает Virtual Machine Platform feature
- Включает Windows Subsystem for Linux feature
- Скачивает WSL2 kernel
- Скачивает и устанавливает Ubuntu (последний LTS — 22.04 или 24.04)
- Устанавливает WSL2 как версию по умолчанию

**Обязательная перезагрузка Windows** после установки.

После перезагрузки автоматически откроется окно Ubuntu, которое попросит:
1. Создать **UNIX username** — рекомендую `sergei` или просто `dev`
2. Создать **UNIX password** — записать в надёжное место

После создания пользователя — будешь в bash shell Ubuntu внутри Windows.

### Проверка установки WSL2

В PowerShell:
```powershell
wsl --list --verbose
```

Должно показать:
```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

Если VERSION показывает `1` — выполнить `wsl --set-version Ubuntu 2` для апгрейда.

### Acceptance проверка Части 1

В Ubuntu terminal выполнить:
```bash
uname -a
cat /etc/os-release
```

Должно показать Linux kernel и Ubuntu 22.04 (или 24.04).

## Часть 2: Установка Miniconda в WSL

Miniconda — это minimal версия Anaconda (всего ~400 MB), необходимая для Hummingbot. Устанавливается **внутри Ubuntu (WSL)**, не на Windows host. На Windows никакой Anaconda не появится.

### Установка

В Ubuntu terminal:

```bash
# Скачать инсталлятор
cd ~
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

# Запустить
bash Miniconda3-latest-Linux-x86_64.sh
```

Во время установки:
- Принять license agreement (нажимать Enter, потом yes)
- Default install location `~/miniconda3` — оставить
- На вопрос "Do you wish the installer to initialize Miniconda3?" — **yes**

После установки **закрыть terminal и открыть Ubuntu заново**, чтобы загрузился `~/.bashrc` с conda init.

### Проверка

В новом Ubuntu terminal:
```bash
conda --version
which conda
```

Должно показать версию (например `conda 24.x.x`) и путь `~/miniconda3/condabin/conda` или похожий.

### Отключение auto-activation base environment (опционально, для чистоты)

```bash
conda config --set auto_activate_base false
```

Это чтобы не активировался `base` env автоматически при старте terminal. Hummingbot использует свой собственный env.

### Acceptance проверка Части 2

`conda --version` отрабатывает без ошибок.

## Часть 3: Установка Hummingbot из исходников в WSL

### Установка системных зависимостей

```bash
sudo apt update
sudo apt install -y build-essential git curl wget
```

`build-essential` нужен для компиляции некоторых Python зависимостей Hummingbot.

### Клонирование репозитория

```bash
cd ~
mkdir -p projects
cd projects
git clone https://github.com/hummingbot/hummingbot.git
cd hummingbot
```

### Установка через скрипт ./install

```bash
./install
```

Этот скрипт:
- Создаёт conda env `hummingbot` с Python 3.10 (Hummingbot пока требует 3.10, не 3.11)
- Устанавливает все Python зависимости через pip
- Может занять 10-20 минут

Если падает на какой-то зависимости — записать в отчёт, проверить в логе.

### Активация environment

```bash
conda activate hummingbot
```

Префикс `(hummingbot)` должен появиться в командной строке. Это значит ты в правильном env.

### Компиляция

```bash
./compile
```

Компилирует Cython модули. Занимает 2-5 минут. Если падает — проверить что `build-essential` установлен.

### Первый запуск (тестовый)

```bash
bin/hummingbot.py
```

Должна загрузиться Hummingbot CLI с приветственным экраном (ASCII логотип, version info).

В CLI выполнить:
```
status
```

Должно показать "Bot is not running" и список доступных команд.

Выйти из Hummingbot:
```
exit
```

### Acceptance проверка Части 3

- `(hummingbot) conda env активен`
- `bin/hummingbot.py` запускает CLI без ошибок
- Команда `status` отрабатывает

## Часть 4: Подключение Bybit testnet к Hummingbot

### Получение testnet ключей

У пользователя они уже есть — он использовал их раньше для проверки. Если потерялись — заново через https://testnet.bybit.com:
1. Войти / зарегистрироваться
2. **Account & Security → API Management → Create New Key → System-generated**
3. Permissions: **Read + Derivatives Trade** (без Withdraw)
4. Сохранить API Key и API Secret

### Получение testnet USDT

Без USDT бот не сможет торговать. Запросить:
1. На testnet.bybit.com → **Assets → My Assets**
2. Найти **Faucet** или **Request Test Coins**
3. Запросить **10 000 USDT**
4. Перевести USDT в **Derivatives Account** (Unified Trading Account) через Internal Transfer

Если faucet недоступен — поискать через testnet интерфейс Bybit, иногда они меняют расположение. Альтернативно — Telegram бот Bybit testnet.

### Подключение в Hummingbot CLI

В Ubuntu terminal:
```bash
cd ~/projects/hummingbot
conda activate hummingbot
bin/hummingbot.py
```

В Hummingbot CLI:
```
connect bybit_perpetual_testnet
```

Будет запрошен API Key, потом API Secret. Ввести.

### Проверка баланса

В Hummingbot CLI:
```
balance
```

Должен показать USDT баланс на bybit_perpetual_testnet. Если показывает 0 при наличии USDT в Bybit — это **известная проблема с Unified Trading Account**. Записать в отчёт, я (архитектор) приму решение.

Возможные обходные пути:
- Создать sub-account в Bybit с отдельными API keys
- Попробовать последнюю dev версию Hummingbot
- Сообщить в Hummingbot Discord (#support channel)

### Acceptance проверка Части 4

- В Hummingbot CLI `balance` показывает 10 000 USDT (или близкое значение) на bybit_perpetual_testnet
- Никаких ошибок в логах

## Часть 5: Установка Quantower на Windows

Quantower — native Windows приложение. Бесплатно при подключении Bybit (все Premium features доступны).

### Скачивание и установка

1. Открыть в браузере https://www.quantower.com
2. **Download** → выбрать Windows
3. Запустить скачанный installer
4. Установить в Program Files как обычное приложение
5. При первом запуске — создать **Quantower Account** (бесплатно, email + password)
6. Дождаться загрузки рабочего стола

### Русская локализация

В Quantower:
1. **Settings (Настройки)** → **General (Основные)** → **Language → Russian**
2. Перезапустить Quantower
3. Интерфейс будет на русском

### Светлая тема

1. **Settings (Настройки)** → **Appearance (Внешний вид)** → **Theme → Light (Светлая)**
2. Применить

### Подключение Bybit testnet

1. Главное меню → **Connections (Подключения)** → **Add Connection (Добавить подключение)**
2. Выбрать **Bybit**
3. **Mode (Режим): Trading**
4. **Network (Сеть): Testnet** или **Demo**
5. Ввести **API Key** и **API Secret** (можно те же что в Hummingbot, или создать вторую пару с Read-only правами для безопасности)
6. **Connect (Подключиться)**

### Проверка подключения

После подключения должны быть видны:
- Статус **Connected** в Connections панели
- В **Account Manager** баланс ~10 000 USDT
- При открытии графика **BTCUSDT.P** (perpetual) — данные загружаются в реальном времени

Если ошибка "Timestamp error" — синхронизировать системное время Windows: Settings → Time & Language → Sync now.

### Acceptance проверка Части 5

- Quantower запущен, на русском, светлая тема
- Подключение к Bybit testnet активно
- Виден баланс ~10 000 USDT
- График BTCUSDT.P обновляется в реальном времени

## Часть 6: Smoke test всей системы

Финальная проверка что обе системы видят одни и те же данные через один и тот же Bybit аккаунт.

1. **Hummingbot CLI запущен** в WSL terminal
2. **Quantower запущен** на Windows с подключённым Bybit testnet

### Тестовый ордер из Quantower

В Quantower:
1. Открыть **DOM Trader** или **Chart Trading** для BTCUSDT.P
2. Разместить **limit ордер на покупку 0.001 BTC по цене ЗНАЧИТЕЛЬНО НИЖЕ рынка** (например, если рынок 67000, ставить на 60000) — чтобы он точно не исполнился
3. Подтвердить размещение

### Проверка видимости в обеих системах

**В Quantower:** Working Orders должен содержать этот ордер.

**В Hummingbot CLI:**
```
orders
```
или
```
status
```

Должен быть виден тот же самый ордер (тот же ID, цена, количество). Если Hummingbot не видит свои ордера в этом режиме — это OK, он видит **позиции и баланс**, а отдельные ордера могут не отображаться по умолчанию без активной стратегии. В этом случае проверить через **Bybit testnet веб-интерфейс** что ордер размещён.

### Отмена ордера

Из Quantower отменить тестовый ордер. Проверить что он исчез:
- В Quantower (моментально)
- На testnet.bybit.com (через refresh)

### Acceptance проверка Части 6

Тестовый ордер успешно размещён через Quantower, виден на Bybit testnet (это критичный признак что Quantower подключён правильно), успешно отменён.

## Часть 7: Создание отчёта

Создать файл `~/projects/sprint_0_report.md` в WSL (или в Windows `\\wsl$\Ubuntu\home\<username>\projects\sprint_0_report.md`):

```markdown
# Отчёт Спринта 0: Установка инфраструктуры

## Системная информация
- Windows версия: [winver output]
- RAM: [GB]
- WSL2 версия: [wsl --version output]
- Ubuntu в WSL: [версия из /etc/os-release]
- Miniconda версия: [conda --version]

## Установлено

### WSL2 + Ubuntu
- WSL версия: [2]
- Ubuntu версия: [22.04 / 24.04]
- UNIX username: [имя пользователя]

### Hummingbot
- Версия: [output of git log -1 --format="%h %s" в директории hummingbot]
- Расположение: [~/projects/hummingbot в WSL]
- Conda env создан: [YES]
- Компиляция: [SUCCESS / описание ошибки]
- CLI запускается: [YES]

### Quantower
- Версия: [из меню About]
- Язык интерфейса: [Русский]
- Тема: [Светлая]

## Bybit testnet

### Аккаунт
- Account Mode: [Classic / UTA]
- Testnet USDT: [10 000 или другое]
- Location: [Derivatives Account / Spot]
- IP restriction на ключах: [None / специфичный]

### Connectivity
- Hummingbot connector: bybit_perpetual_testnet
- Hummingbot balance: [10 000 USDT — VISIBLE / 0 — UTA issue / другое]
- Quantower подключение: [Connected]
- Quantower balance: [10 000 USDT — VISIBLE]
- Quantower видит график BTCUSDT.P: [YES]

## Smoke test
- Тестовый ордер размещён из Quantower: [цена и количество]
- Виден на testnet.bybit.com: [YES]
- Отменён через Quantower: [SUCCESS]

## Найденные проблемы

[Список конкретных проблем, ошибок, обходных решений. Если всё гладко — "проблем не обнаружено"]

## Открытые вопросы для архитектора

[Если возникли решения которые нужно принять на уровне всего проекта — записать здесь. Например про UTA balance issue.]

## Следующий шаг

Готов к Спринту 1: запуск PMM Dynamic стратегии на BTCUSDT testnet с минимальными параметрами.

## Скриншоты (важно для архитектора)
1. Quantower главный экран с графиком BTCUSDT.P
2. Quantower Account Manager с балансом
3. Quantower DOM Trader / Chart Trading с тестовым ордером
4. Hummingbot CLI после команды balance
```

## Важные замечания для Claude Code

1. **Все команды Hummingbot выполняются ВНУТРИ WSL Ubuntu terminal**, не в PowerShell Windows.

2. **Quantower устанавливается и работает на Windows нативно**, не в WSL.

3. **Между WSL и Windows нет прямой интеграции** в этом спринте. Hummingbot и Quantower подключаются к Bybit testnet **независимо**, оба видят одни и те же данные через cloud API. Это нормальная архитектура.

4. **НЕ ставить Hummingbot Dashboard в этом спринте.** Он не нужен — Quantower даёт всю визуализацию. Dashboard может быть рассмотрен в более поздних спринтах если понадобится.

5. **НЕ запускать никакую торговую стратегию** в этом спринте. Только установка и connectivity check.

6. **API ключи в чате** — никогда не логировать полные ключи в отчёте или коде. Использовать только в Hummingbot CLI (где они хранятся в encrypted form в `conf/`) и в Quantower (в его собственном keystore).

7. **Если на каком-то шаге не получается** — записать в отчёт со скриншотом / логом, не пытаться обойти глубокими модификациями кода Hummingbot.

8. **Системное время** Windows должно быть синхронизировано. Это критично для Bybit API. Если есть расхождение > 5 секунд от UTC — будет ошибка timestamp.

9. **Между WSL и Windows clipboard** работает в обе стороны — можно копировать команды из этого документа в WSL terminal через Ctrl+Shift+V (в Windows Terminal) или ПКМ.

10. **Если WSL не устанавливается** (например, ошибка "WslRegisterDistribution failed") — обычно лечится `wsl --update` в PowerShell, либо включением Hyper-V вручную через "Turn Windows features on or off".

## Acceptance criteria для всего Спринта 0

Все пункты должны выполняться:

- [ ] WSL2 установлен и работает
- [ ] Ubuntu в WSL запускается, есть UNIX user
- [ ] Miniconda установлена в WSL, `conda --version` работает
- [ ] Hummingbot склонирован в `~/projects/hummingbot` внутри WSL
- [ ] `conda env hummingbot` создан и активируется
- [ ] `./compile` завершился без ошибок
- [ ] `bin/hummingbot.py` запускает CLI
- [ ] Quantower установлен на Windows, на русском, светлая тема
- [ ] Bybit testnet API key работают
- [ ] Testnet USDT (~10 000) получены и видны в Derivatives Account
- [ ] Hummingbot CLI: `balance` показывает USDT (или есть запись про UTA issue)
- [ ] Quantower: видит баланс и график BTCUSDT.P
- [ ] Smoke test: ордер размещён через Quantower, виден на Bybit testnet, отменён
- [ ] Файл `sprint_0_report.md` создан со всеми разделами

Если какой-то пункт не выполнен — спринт не закрыт. Не переходить к следующему спринту до closing всех пунктов.

## Что НЕ делать в этом спринте

- Не ставить Hummingbot Dashboard
- Не запускать торговые стратегии
- Не модифицировать код Hummingbot
- Не пытаться установить нативный Hummingbot на Windows (только в WSL)
- Не использовать Docker ни для чего
- Не настраивать сложную интеграцию между Hummingbot и Quantower — они работают независимо
