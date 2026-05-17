# Промпт-дополнение к Спринту 0: Проверка и настройка WSL2

## Контекст

Это **промпт-дополнение**, который выполняется **ПЕРЕД** основным промптом Спринта 0 (`sprint_0_setup_prompt_windows_wsl.md`). Цель — убедиться, что WSL2 на компьютере пользователя в рабочем состоянии, или привести его в рабочее состояние, прежде чем начинать установку Hummingbot.

После завершения этого промпта-дополнения переходи к основному промпту Спринта 0.

В конце всего процесса (после основного промпта Спринта 0) создаётся **USAGE.md** — инструкция по повседневному использованию системы. Это требование описано в Части 4 ниже.

## Окружение пользователя

- ОС: Windows 10
- Уже установлено: Python 3.11 (на Windows), Node.js (на Windows)
- WSL2 статус: **неизвестен** — может быть установлен, может не быть, может быть в нерабочем состоянии. Задача — диагностировать и привести к рабочему виду.

## Часть 1: Диагностика текущего состояния WSL

### Шаг 1.1: Системная информация

Открыть **обычный** PowerShell (не от админа пока), выполнить:

```powershell
# Версия Windows
[System.Environment]::OSVersion
winver  # это откроет диалоговое окно

# Build number (важно — WSL2 требует 19041+)
[System.Environment]::OSVersion.Version

# Архитектура процессора
$env:PROCESSOR_ARCHITECTURE
```

**Что проверить:**
- Версия Windows 10 build должна быть ≥ 19041 (это Windows 10 версии 2004 или новее). Если меньше — нужно обновить Windows, без этого WSL2 не работает. Записать в отчёт.
- Архитектура AMD64 (x64). ARM64 — отдельная история, не наш случай.

### Шаг 1.2: Проверка виртуализации в BIOS

```powershell
# Проверка что виртуализация включена в BIOS/UEFI
systeminfo | Select-String -Pattern "Virtualization Enabled In Firmware|Hyper-V Requirements"
```

**Возможные результаты:**
- `Virtualization Enabled In Firmware: Yes` — виртуализация включена, можно продолжать
- `Virtualization Enabled In Firmware: No` — **остановиться**, записать в отчёт что пользователю нужно зайти в BIOS/UEFI и включить Intel VT-x или AMD-V вручную. Дать инструкции:
  1. Перезагрузить компьютер
  2. Нажать DEL / F2 / F10 (зависит от материнской платы) при загрузке
  3. Найти раздел Advanced / CPU Configuration / Security
  4. Включить **Intel Virtualization Technology** (для Intel) или **SVM Mode** (для AMD)
  5. Save & Exit
  6. После загрузки Windows вернуться к этому промпту

Не пытаться продолжать установку WSL2 без виртуализации — это бесполезно.

### Шаг 1.3: Проверка WSL установлен ли вообще

```powershell
# Получить состояние WSL
wsl --status
```

**Возможные результаты:**

**Вариант A:** Команда возвращает информацию о WSL версии, kernel version, default distribution — WSL **установлен**. Запомнить вывод.

**Вариант B:** Команда выдаёт ошибку типа "Windows Subsystem for Linux is not installed" или "WSL is not installed" — WSL **не установлен**. Переходим к установке (Часть 2).

**Вариант C:** Команда вообще не существует или возвращает старую WSL1 формат — это может означать WSL1 без WSL2 features. Переходим к апгрейду до WSL2 (Часть 3).

### Шаг 1.4: Если WSL установлен — проверка дистрибутивов

Если шаг 1.3 показал что WSL установлен:

```powershell
# Список установленных дистрибутивов
wsl --list --verbose

# Версия WSL kernel
wsl --version
```

**Что искать в выводе `wsl --list --verbose`:**
- Колонка NAME — есть ли Ubuntu (или другой Linux distro)
- Колонка STATE — Running / Stopped
- Колонка VERSION — должна быть 2 (не 1)

**Возможные результаты:**

**Вариант D:** Есть Ubuntu, VERSION = 2 — отлично, WSL2 + Ubuntu готовы. Проверить, что Ubuntu стартует:
```powershell
wsl -d Ubuntu -- uname -a
```
Если вывод показал Linux kernel info — WSL2 готов к работе. Переходи к Части 4 (Финализация и доклад).

**Вариант E:** Есть Ubuntu, но VERSION = 1 — нужно апгрейдить до WSL2. Переходи к Части 3.

**Вариант F:** WSL установлен, но дистрибутивов нет — нужно установить Ubuntu. Переходи к Части 2.

**Вариант G:** Есть другой дистрибутив (Debian, Kali, и т.д.) вместо Ubuntu — записать в отчёт, согласовать с архитектором, использовать ли существующий или поставить Ubuntu параллельно. Hummingbot тестировался на Ubuntu, но в принципе работает на любом современном glibc-based Linux.

## Часть 2: Установка WSL2 + Ubuntu (если не установлен)

**Только если в Части 1 выявлено что WSL не установлен или нет дистрибутивов.**

Открыть PowerShell **от администратора** (важно!).

### Шаг 2.1: Установка WSL2 + Ubuntu одной командой

```powershell
wsl --install
```

Эта команда:
- Включает Virtual Machine Platform feature
- Включает Windows Subsystem for Linux feature  
- Скачивает WSL2 kernel update
- Скачивает и устанавливает Ubuntu (последний LTS)
- Устанавливает WSL2 как версию по умолчанию

**Обязательная перезагрузка Windows.**

### Шаг 2.2: После перезагрузки — настройка Ubuntu

После reboot автоматически откроется окно Ubuntu. Если не откроется — запустить из Start menu приложение "Ubuntu".

Ubuntu попросит:
1. Создать **UNIX username** (рекомендация: `sergei` или короткое латинское имя без пробелов)
2. Создать **UNIX password** (записать в надёжное место — пароль будет нужен для `sudo`)

После создания пользователя — будешь в bash shell.

### Шаг 2.3: Проверка установки

В PowerShell:
```powershell
wsl --list --verbose
```

Должно показать:
```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

Если VERSION = 1 — переходи к Части 3 для апгрейда.

## Часть 3: Апгрейд WSL1 → WSL2 (если необходимо)

**Только если в Части 1 или 2 выявлено что дистрибутив на WSL1.**

### Шаг 3.1: Скачивание kernel update

```powershell
# Скачать обновление kernel (если ещё не скачано)
# Адрес — официальный Microsoft
Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" -OutFile "$env:TEMP\wsl_update_x64.msi"

# Установить
Start-Process msiexec.exe -ArgumentList "/i", "$env:TEMP\wsl_update_x64.msi", "/quiet" -Wait
```

### Шаг 3.2: Установка WSL2 как версии по умолчанию

```powershell
wsl --set-default-version 2
```

### Шаг 3.3: Конвертация существующего дистрибутива

Если есть Ubuntu (или другой) на WSL1:
```powershell
wsl --set-version Ubuntu 2
```

Это может занять 10-30 минут в зависимости от размера данных в дистрибутиве. Не прерывать.

### Шаг 3.4: Проверка

```powershell
wsl --list --verbose
```

VERSION должна стать 2.

## Часть 4: Финализация и smoke test WSL2

Независимо от того, какой путь привёл сюда — финальная проверка что WSL2 в рабочем состоянии.

### Шаг 4.1: Тестовый запуск Ubuntu

```powershell
wsl -d Ubuntu
```

Должна открыться bash shell Ubuntu. Внутри:

```bash
# Проверка дистрибутива
cat /etc/os-release

# Проверка ядра
uname -a

# Проверка сети
ping -c 3 google.com

# Проверка дискового пространства
df -h
```

**Что проверить:**
- `os-release` показывает Ubuntu 22.04 / 24.04 (или какой стоит)
- `uname -a` показывает Linux + версию kernel + microsoft в имени (это признак WSL2)
- Ping проходит — есть интернет
- Свободно минимум 10 GB в корневой ФС (для Hummingbot и зависимостей)

### Шаг 4.2: Обновление системы

```bash
sudo apt update
sudo apt upgrade -y
```

Свежая Ubuntu может потребовать обновлений. Это нормально.

### Шаг 4.3: Конфигурация ресурсов WSL (опционально)

Если у пользователя 16 GB RAM или больше — стоит ограничить WSL чтобы не съел всё. Создать в Windows файл `C:\Users\<username>\.wslconfig` со следующим содержимым:

```ini
[wsl2]
memory=8GB
processors=4
swap=2GB
```

Это даст WSL до 8 GB RAM и 4 CPU cores — достаточно для Hummingbot, и Windows host останется отзывчивым.

Если меньше 16 GB RAM:
```ini
[wsl2]
memory=4GB
processors=2
swap=2GB
```

После изменения `.wslconfig` нужно перезапустить WSL:
```powershell
wsl --shutdown
```

И открыть Ubuntu заново.

### Шаг 4.4: Acceptance проверка

- WSL2 версия kernel показывается через `wsl --version`
- `wsl --list --verbose` показывает Ubuntu, VERSION 2, STATE Running
- Внутри Ubuntu: интернет работает, диск >10 GB свободен, `sudo apt update` отрабатывает без ошибок

## Часть 5: Отчёт о состоянии WSL

Создать или обновить файл `wsl_diagnostic_report.md` в каталоге `~/projects/` Windows host пользователя (например `C:\Users\<username>\projects\` или путь который удобен) со следующим содержимым:

```markdown
# Отчёт диагностики WSL2

## Состояние ДО

- Windows версия: [например 10.0.19045]
- Виртуализация в BIOS: [Enabled / Disabled]
- WSL был установлен: [YES / NO]
- WSL версия (если был): [1 / 2 / не применимо]
- Установленные дистрибутивы: [список с версиями, или "нет"]

## Действия

[Список того, что было сделано. Например:
1. WSL не был установлен — выполнен `wsl --install`
2. Перезагружен Windows
3. Создан UNIX user "sergei"
4. Установлена Ubuntu 24.04
5. Обновлены пакеты через apt update / apt upgrade
6. Создан .wslconfig с лимитами памяти и CPU]

## Состояние ПОСЛЕ

- WSL2 рабочий: [YES]
- Дистрибутив: Ubuntu [22.04 / 24.04]
- UNIX user: [имя]
- Свободно места: [GB]
- WSL kernel версия: [output of `wsl --version`]
- Конфигурация .wslconfig: [применена / не применена, если применена — параметры]

## Найденные проблемы и решения

[Если что-то пошло не по плану — описать здесь со скриншотами / логами]

## Готовность к Спринту 0

[YES — можно переходить к основному промпту Спринта 0 / NO — описание блокеров]
```

После создания этого отчёта — **переходи к основному промпту Спринта 0** (`sprint_0_setup_prompt_windows_wsl.md`).

## Часть 6: Финальная инструкция для пользователя (создаётся в самом конце, после завершения Спринта 0)

**Этот шаг выполняется ПОСЛЕ завершения основного промпта Спринта 0**, когда Hummingbot и Quantower установлены и работают. Цель — создать документ, который пользователь сможет использовать каждый день для запуска и работы с системой, без необходимости снова смотреть в промпт.

Создать файл `USAGE.md` в `~/projects/` (например `C:\Users\<username>\projects\USAGE.md` или внутри WSL `/home/<username>/projects/USAGE.md`) со следующей структурой:

```markdown
# Руководство по ежедневной работе с торговой системой

Эта инструкция описывает, как запускать, использовать и обслуживать связку **Hummingbot (в WSL2) + Quantower (на Windows)** для market-making торговли на Bybit testnet.

## Что есть в системе

- **WSL2 (Ubuntu)** на твоём Windows — Linux подсистема, в которой работает Hummingbot
- **Hummingbot 2.x** — торговый движок с MM стратегиями, путь: `~/projects/hummingbot` внутри WSL
- **Quantower** — Windows desktop terminal для визуального контроля торговли, установлен в `C:\Program Files\Quantower\` (или похожее)
- **Bybit testnet account** — твой тестовый аккаунт на testnet.bybit.com с виртуальными USDT

## Ежедневный запуск

### Шаг 1: Старт WSL и Hummingbot

Открыть **Windows Terminal** (или PowerShell). Запустить WSL:
```powershell
wsl
```

Откроется bash shell Ubuntu. Перейти в директорию Hummingbot и активировать env:
```bash
cd ~/projects/hummingbot
conda activate hummingbot
```

Запустить Hummingbot CLI:
```bash
bin/hummingbot.py
```

Должен открыться CLI Hummingbot с приветствием.

### Шаг 2: Старт Quantower

Открыть Quantower через Start menu или ярлык на рабочем столе. Дождаться загрузки, проверить:
- Connections: Bybit (Testnet) — статус **Connected**
- Account Manager: видно баланс ~10 000 USDT

Если статус не Connected — Settings → Connections → Bybit → Reconnect.

### Шаг 3: Проверка что всё работает

В Hummingbot CLI:
```
status
balance
```

Должны увидеть текущее состояние бота и USDT баланс.

В Quantower:
- Открыть chart BTCUSDT.P — должны идти обновления цен в реальном времени.

## Основные команды Hummingbot CLI

| Команда | Что делает |
|---------|------------|
| `status` | Текущее состояние бота (запущен ли, какая стратегия активна) |
| `balance` | Баланс на подключённых биржах |
| `history` | История сделок и PnL |
| `connect bybit_perpetual_testnet` | Заново подключить Bybit testnet (если нужно) |
| `create --v2-config` | Создать новую конфигурацию стратегии V2 (PMM Dynamic и т.д.) |
| `start --v2 <config.yml>` | Запустить стратегию по конфигу |
| `stop` | Остановить активную стратегию |
| `config` | Просмотреть или изменить параметры активной стратегии |
| `exit` | Выйти из Hummingbot CLI |

Полный список — `help` в CLI.

## Что делать в Quantower

- **Графики**: Watchlist → выбрать BTCUSDT.P (или другой actив) → правый клик → New Chart
- **DOM Trader / Order Book**: для просмотра стакана и быстрого размещения ручных ордеров
- **Account Manager**: текущий баланс, позиции, нереализованный PnL
- **Working Orders**: активные ордера (твои + те, что разместил Hummingbot)
- **Account History**: история всех сделок и комиссий

## Завершение работы

### Корректное завершение

В Hummingbot CLI:
```
stop          # если есть активная стратегия
exit          # выйти из CLI
```

В Quantower просто закрыть окно.

WSL сам не закрывается. Можно оставить его запущенным или явно остановить:
```powershell
wsl --shutdown
```

### Если зависло

Если Hummingbot CLI зависает — закрыть terminal окно жёстко, потом:
```powershell
wsl --shutdown
wsl
```

И запустить Hummingbot заново.

## Где смотреть логи

- **Hummingbot логи**: `~/projects/hummingbot/logs/` — текстовые логи стратегии, ошибки
- **Hummingbot конфиги**: `~/projects/hummingbot/conf/` — credentials (encrypted), strategy configs
- **WSL логи системы**: `journalctl` внутри WSL
- **Quantower логи**: `C:\Users\<username>\AppData\Roaming\Quantower\Logs\`

## Troubleshooting

### Hummingbot не запускается / `bin/hummingbot.py` ошибка

1. Проверь что conda env активен: `conda activate hummingbot` (видно `(hummingbot)` в prompt)
2. Если падает на import — может потребоваться recompile: `./compile`
3. Если падает на API — проверь testnet API keys, возможно истекли

### Hummingbot показывает balance = 0 при наличии USDT в Bybit

Это известная Unified Trading Account (UTA) проблема. Решения:
1. В Bybit Settings проверить mode — попробовать Classic если возможно
2. Создать sub-account в Bybit с отдельными API keys, использовать его в Hummingbot
3. Проверить последнюю dev версию Hummingbot — могут уже починить

### Quantower показывает "Connection error" к Bybit

1. Проверить синхронизацию системного времени Windows: Settings → Time & Language → Sync now
2. Проверить что API keys активны на testnet.bybit.com
3. Reconnect через Settings → Connections

### WSL не стартует / "WslRegisterDistribution failed"

1. В PowerShell от админа: `wsl --update`
2. Перезагрузка Windows
3. Если не помогло: `wsl --unregister Ubuntu` (удаляет все данные!), потом `wsl --install`

### Цены в Quantower не обновляются

1. Проверить статус подключения Bybit в Connections
2. Reconnect
3. Если не помогло — рестарт Quantower

## Что НЕ делать

- Не закрывать WSL window когда там запущен Hummingbot со стратегией — бот остановится
- Не удалять `~/projects/hummingbot/conf/` — там зашифрованные API keys и конфиги стратегий
- Не модифицировать код Hummingbot напрямую — все настройки через `config` или YAML конфиги в `conf/`
- Не делать commits API keys в git — они в `.gitignore` Hummingbot, но проверить
- Не запускать одновременно две инстанции Hummingbot — конфликт API запросов к Bybit

## Контакты для проблем

- Архитектор (Claude) — присылать `sprint_X_report.md` после каждого спринта
- Hummingbot Discord — #support channel для специфичных проблем фреймворка
- Bybit Discord — для проблем с testnet/mainnet API

---

Версия документа: [дата создания, формат YYYY-MM-DD]
Версия Hummingbot: [git log -1 --format="%h %s" из ~/projects/hummingbot]
```

## Важные замечания для Claude Code

1. **Если виртуализация в BIOS отключена** — остановиться. Записать в отчёт. Пользователь должен сам зайти в BIOS, это не автоматизируется.

2. **Если Windows версия слишком старая** (build < 19041) — остановиться. WSL2 не поставится. Пользователь должен обновить Windows.

3. **PowerShell от админа vs обычный**: команды `wsl --install`, `wsl --set-default-version`, `wsl --set-version`, изменения features Windows — **только от админа**. Команды диагностики `wsl --status`, `wsl --list --verbose`, `wsl --version` — работают и из обычного.

4. **После `wsl --install`** обязательна перезагрузка Windows. Не пытаться продолжать без перезагрузки.

5. **При первом запуске Ubuntu** нужно интерактивное создание пользователя — это нельзя автоматизировать через PowerShell. Пользователь должен сам ввести username и password в открывшемся окне Ubuntu.

6. **Не редактировать `.wslconfig`** автоматически без согласия пользователя — это влияет на производительность Windows host. Лучше спросить пользователя сколько у него RAM и сколько выделять для WSL.

7. **Логи WSL диагностики** записывать подробно — какая команда что вернула. Это поможет в дальнейшем troubleshooting.

8. **USAGE.md создаётся в самом конце** — после того как и WSL2 настроен, и Hummingbot установлен, и Quantower работает. Не раньше.

## Порядок выполнения промптов

1. **Этот промпт (WSL2 диагностика)** — Часть 1–5
2. **Основной промпт Спринта 0** (`sprint_0_setup_prompt_windows_wsl.md`) — установка Hummingbot и Quantower
3. **Часть 6 этого промпта** — создание USAGE.md
4. **Финальная сборка отчёта** — объединение `wsl_diagnostic_report.md` + `sprint_0_report.md` в единый отчёт для архитектора
