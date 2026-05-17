# Trading Bot MM — Market Making Strategy on Bybit

Алгоритмический торговый бот на стратегии **Pure Market Making Dynamic** (Avellaneda-Stoikov) для Bybit.

## Архитектура

- **Engine:** Hummingbot 2.14.0 (работает в WSL2 Ubuntu, Python 3.13)
- **UI:** форк [Astras-Trading-UI](https://github.com/alor-broker/Astras-Trading-UI) от ALOR (Apache-2.0, Angular 21), адаптированный под Bybit + desktop wrap через Tauri 2.0 — *в разработке, см. [docs/research/astras_bybit_migration_plan.md](docs/research/astras_bybit_migration_plan.md)*
- **Биржа:** Bybit (Testnet → Mainnet после валидации стратегии)
- **Принцип:** 100% open source. Никаких proprietary tools, trial-периодов или paid pro tiers.

## Статус проекта

Текущая фаза: **Sprint 0** — установка инфраструктуры.

См. [`docs/sprint_reports/`](docs/sprint_reports/) для детальных отчётов по каждому спринту.

## Структура репозитория

```
mm-bot/
├── docs/
│   ├── sprint_prompts/    # Промпты от архитектора для каждого спринта
│   ├── sprint_reports/    # Отчёты Claude Code по выполненным спринтам
│   └── research/          # Аналитические документы (UI стек, миграции)
├── strategies/             # YAML конфиги стратегий Hummingbot (без API keys)
├── screenshots/            # Скриншоты UI для архитектора
├── scripts/                # Вспомогательные скрипты (Hummingbot wrappers и т.п.)
├── USAGE.md                # Инструкция по ежедневному использованию
└── README.md               # Этот файл
```

Планируемые отдельные репозитории (Sprint 1+):
- `anymasoft/astras-bybit-ui` — форк Astras-Trading-UI с Bybit адаптерами
- `anymasoft/bybit-adapter` — Node.js proxy между Astras-UI и Bybit V5 API

## Безопасность

**API ключи никогда не коммитятся.** Все credentials хранятся:

- Hummingbot: в `~/projects/hummingbot/conf/` внутри WSL (encrypted, исключён через .gitignore)
- Quantower: в Windows keystore приложения
- Локальные `.env` файлы — в `.gitignore`

## Команды для работы

См. [`USAGE.md`](USAGE.md) для ежедневной инструкции (создаётся в конце Sprint 0).

## Workflow

1. Архитектор пишет промпт в чате — пользователь копирует в `docs/sprint_prompts/sprint_N_*.md`
2. Claude Code выполняет промпт локально
3. По завершению — пишет отчёт в `docs/sprint_reports/sprint_N_report.md`
4. Все артефакты коммитятся и пушатся в GitHub
5. Архитектор читает отчёт через GitHub, пишет промпт следующего спринта

## Лицензия

Приватный проект. Все права защищены.
