# Trading Bot MM — Market Making Strategy on Bybit

Алгоритмический торговый бот на стратегии **Pure Market Making Dynamic** (Avellaneda-Stoikov) для Bybit.

## Архитектура

Распределённая по трём репозиториям:

| Компонент | Репо | Стек | Статус |
|---|---|---|---|
| **Engine** (торговый бот) | [anymasoft/mm-bot](https://github.com/anymasoft/mm-bot) (этот) | Hummingbot 2.14.0, Python 3.13, WSL2 Ubuntu 24.04 | Установлен, готов к Sprint 5 |
| **UI** (desktop terminal) | [anymasoft/astras-bybit-ui](https://github.com/anymasoft/astras-bybit-ui) | Angular 21 + ng-zorro + Tauri 2.0 (fork [alor-broker/Astras-Trading-UI](https://github.com/alor-broker/Astras-Trading-UI), Apache-2.0) | Fork создан, Sprint 2-4 |
| **Backend adapter** | [anymasoft/bybit-adapter](https://github.com/anymasoft/bybit-adapter) | Node.js + TypeScript + Fastify + bybit-api, Apache-2.0 | Репо создан, Sprint 1 |

- **Биржа:** Bybit (Testnet → Mainnet после 2-3 недель валидации стратегии)
- **Стратегия:** PMM Dynamic / Avellaneda-Stoikov на perpetual futures
- **Desktop wrap:** один `.msi` инсталлятор (Tauri 2.0 + Node sidecar)
- **Принцип:** 100% open source. Никаких proprietary tools, trial-периодов или paid pro tiers.

Подробный план миграции и архитектурные решения: [docs/research/astras_bybit_migration_plan.md](docs/research/astras_bybit_migration_plan.md).

## Статус проекта

**Sprint 0 закрыт** (2026-05-17): инфраструктура установлена, UI-стек выбран, два репозитория созданы, все 6 архитектурных вопросов закрыты.

**Следующий шаг — Sprint 1:** Bybit adapter MVP в [anymasoft/bybit-adapter](https://github.com/anymasoft/bybit-adapter) (Node.js proxy с REST + WS endpoints в ALOR-формате).

Timeline до первого запуска стратегии: 6-8 недель (5 спринтов). Полный roadmap — в [migration plan](docs/research/astras_bybit_migration_plan.md#4-roadmap--5-спринтов-до-запуска-торговли).

См. [`docs/sprint_reports/`](docs/sprint_reports/) для детальных отчётов по каждому спринту.

## Структура этого репозитория

```
mm-bot/
├── docs/
│   ├── sprint_prompts/    # Промпты от архитектора для каждого спринта
│   ├── sprint_reports/    # Отчёты Claude Code по выполненным спринтам
│   └── research/          # Аналитические документы (UI стек, миграции)
├── strategies/             # YAML конфиги стратегий Hummingbot (без API keys)
├── screenshots/            # Скриншоты UI для архитектора
├── scripts/                # Вспомогательные скрипты (Hummingbot wrappers)
├── USAGE.md                # Инструкция по ежедневному использованию
└── README.md               # Этот файл
```

Frontend и backend-adapter живут в отдельных репозиториях (см. таблицу выше) — это решение архитектора для минимизации upstream-дивергенции от ALOR и независимой разработки adapter'а.

## Безопасность

**API ключи никогда не коммитятся.** Все credentials хранятся:

- Hummingbot: в `~/projects/hummingbot/conf/` внутри WSL2 (encrypted, исключён через `.gitignore`)
- Bybit adapter (dev): в env-файле `~/.bybit-adapter/.env` (gitignore)
- Bybit adapter (production): в Windows Credential Manager через `tauri-plugin-stronghold`, передаются в sidecar через IPC на старте
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
