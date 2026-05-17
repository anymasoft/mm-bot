# Руководство по ежедневной работе с торговой системой

**ВАЖНО (Sprint 4 pivot):** этот документ написан до Sprint 4 и описывает legacy workflow с Hummingbot + Quantower. Текущий workflow в Sprint 4+ — **PMM Dynamic стратегия в `bybit-adapter` (TypeScript) + Astras admin panel + Bybit web UI**. Hummingbot оставлен как dormant fallback, в обычном workflow не запускается.

- **Актуальный workflow:** [`docs/USAGE_BYBIT_WEB.md`](docs/USAGE_BYBIT_WEB.md)
- **Архитектура стратегии:** [`docs/architecture/strategy_engine.md`](docs/architecture/strategy_engine.md)

Ниже сохранён legacy раздел про Hummingbot — на случай если потребуется его расконсервировать для cross-validation.

---

## Legacy: Hummingbot + Quantower workflow (НЕ ИСПОЛЬЗУЕТСЯ в Sprint 4+)

Эта инструкция описывала, как запускать, использовать и обслуживать связку **Hummingbot (в WSL2) + Quantower (на Windows)** для market-making торговли на Bybit testnet.

## Что есть в системе

- **WSL2 (Ubuntu 24.04.4 LTS)** — Linux подсистема Windows, где работает Hummingbot
- **Hummingbot 2.14.0** — торговый движок с MM стратегиями, путь: `~/projects/hummingbot` внутри WSL
- **Quantower** — Windows desktop terminal (устанавливается отдельно — см. ниже)
- **Bybit testnet** — тестовый аккаунт на testnet.bybit.com с виртуальными USDT
- **GitHub репо** — https://github.com/anymasoft/mm-bot (публичный)

## Доступ к WSL Ubuntu

UNIX user: `dev`, password: `111` (passwordless sudo настроен).

Старт:
```powershell
wsl
# или явно:
wsl -d Ubuntu-24.04
```

Откроется bash shell в Ubuntu 24.04 от имени `dev`. Все Python/Conda/Hummingbot команды работают из этой сессии.

## Ежедневный запуск

### Шаг 1: Старт WSL и Hummingbot

В **Windows Terminal** (или PowerShell):
```powershell
wsl
```

Внутри Ubuntu:
```bash
cd ~/projects/hummingbot
source ~/miniconda3/etc/profile.d/conda.sh
conda activate hummingbot
python bin/hummingbot.py
```

Альтернатива — wrapper:
```bash
bash /mnt/c/BUFFER/mm-bot/scripts/hb_start.sh
```

Должен открыться CLI Hummingbot с приветствием.

### Шаг 2: Старт Quantower

Открыть Quantower через Start menu или ярлык. Проверить:
- Connections: Bybit (Testnet) — статус **Connected**
- Account Manager: виден баланс (например, ~10 000 USDT)

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
| `connect bybit_perpetual_testnet` | Заново подключить Bybit testnet |
| `create --v2-config` | Создать новую конфигурацию стратегии V2 (PMM Dynamic и т.д.) |
| `start --v2 <config.yml>` | Запустить стратегию по конфигу |
| `stop` | Остановить активную стратегию |
| `config` | Просмотреть или изменить параметры активной стратегии |
| `exit` | Выйти из Hummingbot CLI |

Полный список — `help` в CLI.

## Что делать в Quantower

- **Графики**: Watchlist → выбрать BTCUSDT.P (или другой актив) → правый клик → New Chart
- **DOM Trader / Order Book**: стакан и быстрое размещение ручных ордеров
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

Quantower просто закрыть.

WSL сам не закрывается. Можно оставить или явно остановить:
```powershell
wsl --shutdown
```

### Если зависло

```powershell
wsl --shutdown
wsl
```

И запустить Hummingbot заново.

## Где смотреть логи

- **Hummingbot logs:** `~/projects/hummingbot/logs/` — текстовые логи стратегии, ошибки
- **Hummingbot conf:** `~/projects/hummingbot/conf/` — credentials (encrypted), strategy configs
- **WSL system logs:** `journalctl` внутри WSL
- **Quantower logs:** `C:\Users\User\AppData\Roaming\Quantower\Logs\`

## Troubleshooting

### WSL не стартует / "Insufficient system resources" (0x800705aa)

Память. Уже настроен `C:\Users\User\.wslconfig`:
```ini
[wsl2]
memory=4GB
processors=2
swap=2GB
```
Если опять падает — закрой тяжёлые процессы (браузеры, PyCharm) и повтори `wsl`.

### Hummingbot не запускается / `bin/hummingbot.py` ошибка

1. Проверь что conda env активен: видно `(hummingbot)` в prompt
2. Если падает на import — `cd ~/projects/hummingbot && ./compile`
3. Если падает на API — testnet API keys могут истечь, проверь на testnet.bybit.com

### Hummingbot показывает balance = 0 при наличии USDT в Bybit

Это известная Unified Trading Account (UTA) проблема. Решения:
1. В Bybit Settings проверить mode — попробовать Classic если возможно
2. Создать sub-account в Bybit с отдельными API keys
3. Проверить последнюю dev версию Hummingbot

### Quantower показывает "Connection error" к Bybit

1. Проверить синхронизацию времени Windows: Settings → Time & Language → Sync now
2. Проверить что API keys активны на testnet.bybit.com
3. Reconnect через Settings → Connections

### Цены в Quantower не обновляются

1. Проверить статус подключения Bybit в Connections
2. Reconnect
3. Если не помогло — рестарт Quantower

## Что НЕ делать

- Не закрывать WSL window когда там запущен Hummingbot со стратегией — бот остановится
- Не удалять `~/projects/hummingbot/conf/` — там зашифрованные API keys и конфиги стратегий
- Не модифицировать код Hummingbot напрямую — все настройки через `config` или YAML конфиги в `conf/`
- Не делать commits API keys в git — они в `.gitignore`, но всегда проверять `git diff --staged`
- Не запускать одновременно две инстанции Hummingbot — конфликт API запросов к Bybit
- Не коммитить `.env` — в .gitignore, но дважды проверяй

## Workflow со спринтами

1. Архитектор (Claude в чате) пишет промпт в `docs/sprint_prompts/sprint_N_*.md`
2. Claude Code выполняет промпт локально
3. По завершению — отчёт в `docs/sprint_reports/sprint_N_report.md`
4. Скриншоты — в `screenshots/sprint_N_*.png`
5. Стратегии YAML (без API keys) — в `strategies/`
6. Всё коммитится и пушится в GitHub
7. Архитектор читает отчёт через GitHub, пишет следующий промпт

## Контакты для проблем

- **Архитектор (Claude):** присылать `sprint_N_report.md` после каждого спринта через ссылку на GitHub
- **Hummingbot Discord:** #support channel для специфичных проблем фреймворка
- **Bybit Support:** для проблем с testnet/mainnet API

---

**Версия документа:** 2026-05-17
**Версия Hummingbot:** 2.14.0 (commit `91ff6bf`)
**WSL kernel:** 6.6.87.2-microsoft-standard-WSL2
**Ubuntu:** 24.04.4 LTS
