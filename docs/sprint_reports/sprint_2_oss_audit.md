# Sprint 2 — OSS Compliance Audit

**Hard constraint проекта:** все компоненты торговой системы 100% open source GitHub, OSI-approved licenses без оговорок типа Commons Clause / freemium / application-required.

Audit покрывает обе кодовые базы (`bybit-adapter`, `astras-bybit-ui`) после завершения Sprint 2 и подтверждает что **в системе нет proprietary зависимостей**.

## Удалено в Sprint 2

| Что | Лицензия | Где сидело | Решение |
|---|---|---|---|
| **TradingView Charting Library** | Proprietary, application-required | `astras-bybit-ui/src/assets/charting_library/` (22 МБ), `assets/lib/charting_library/` (8.6 МБ) | Удалено целиком (1 550 файлов) в Epic B. Через `git rm -r`. Замена — Lightweight Charts (Apache-2.0). |
| **tech-chart module** | Зависел от TradingView Charting Library | `astras-bybit-ui/src/app/modules/tech-chart/` (15+ ts/html/spec/less) | Удалён целиком. Заменён light-chart везде в `default-dashboards-config.json` и `widgets-meta-config.json`. |
| **copy_charting_library_files.sh** | (build-скрипт ALOR) | repo root | Удалён, больше не нужен. |
| **angular.json `scripts` injection** | (глобальный `<script>` тег для charting_library.js) | `angular.json` строки 89/210 | Очищено (`"scripts": []` в обеих конфигурациях). |

## Новое в Sprint 2

| Package | Version | License | Где добавлено | OK? |
|---|---|---|---|---|
| `technicalindicators` | 3.1.0 | **MIT** | `astras-bybit-ui` (light-chart-wrapper, indicators) | ✅ |

Проверка лицензии:
```bash
npm view technicalindicators license
# Output: MIT
```

## Audit ключевых зависимостей (по умолчанию)

### astras-bybit-ui (Angular 21 fork от alor-broker/Astras-Trading-UI)

| Package | License | Зачем | OK? |
|---|---|---|---|
| `@angular/*` (21.0.0) | MIT | Framework | ✅ |
| `@ngrx/*` (21.0.0) | MIT | State management | ✅ |
| `@apollo/client` (4.0.0) | MIT | GraphQL (для Hyperion stub) | ✅ |
| `apollo-angular` (13.0.0) | MIT | Angular bridge для Apollo | ✅ |
| `angular-gridster2` | MIT | Dashboard grid layout | ✅ |
| `chart.js` (4.5.1) | MIT | Portfolio charts (equity curve) | ✅ |
| `chartjs-chart-treemap` (3.1.0) | MIT | Treemap widget | ✅ |
| `d3` (7.9.0) | ISC | Чартинг для отдельных виджетов | ✅ |
| `firebase` | Apache-2.0 | Push-нотификации (mobile) | ✅ |
| `lightweight-charts` (5.0.9) | **Apache-2.0** | **Основной chart widget (light-chart)** | ✅ |
| `ng-zorro-antd` | MIT | UI kit (Ant Design Angular) | ✅ |
| `ngx-markdown` | MIT | Markdown rendering | ✅ |
| `rxjs` (8) | Apache-2.0 | Reactive primitives | ✅ |
| `technicalindicators` (3.1.0) | **MIT** | **SMA/EMA/BB/RSI/ATR (Epic B)** | ✅ |
| `zod` | MIT | Schema validation | ✅ |
| `@jsverse/transloco` | MIT | i18n | ✅ |
| `@capacitor/*` | MIT | Native mobile wrap (Sprint 3+) | ✅ |
| `@ionic/angular` | MIT | Mobile UI primitives | ✅ |
| `@comfyorg/litegraph` | MIT | AI graph editor (unused в Sprint 2) | ✅ |
| `karma`, `jasmine`, `eslint`, `husky` | MIT/Apache-2.0 | dev tooling | ✅ |

Всего deps в `astras-bybit-ui/package.json`: **91**. Кроме перечисленных выше, остальное — это `@angular-eslint/*`, `@graphql-codegen/*`, `@stylistic/eslint-plugin`, `@types/*`, `marked`, `less`, `ng-mocks`, `typescript-eslint` — это всё стандартный Angular toolchain, лицензии MIT / Apache-2.0 / ISC.

### bybit-adapter (Node.js / Fastify)

| Package | License | Зачем | OK? |
|---|---|---|---|
| `@fastify/cors` | MIT | CORS middleware | ✅ |
| `@fastify/jwt` | MIT | JWT mock auth (Sprint 1) | ✅ |
| `@fastify/websocket` | MIT | WS upgrade в Fastify | ✅ |
| `bybit-api` (3.10.20, tiagosiebler) | **MIT** | **Bybit V5 REST + WS клиент** | ✅ |
| `dotenv` | BSD-2-Clause | .env loader | ✅ |
| `fastify` | MIT | HTTP сервер | ✅ |
| `pino`, `pino-pretty` | MIT | Logger | ✅ |
| `uuid` | MIT | ID для subscription registry | ✅ |
| `zod` | MIT | Schema validation | ✅ |
| `tsx`, `vitest`, `typescript` | MIT/Apache-2.0 | dev | ✅ |

**Всего deps в `bybit-adapter/package.json`: 15.** Все — MIT / Apache-2.0 / BSD.

## Проверка чистоты — что искал и что нашёл

После Epic B сделал широкий grep'ы по всему репо:

```bash
grep -r "tech-chart" astras-bybit-ui/src       # 1 match (мой комментарий о удалении в parent-widget.component.ts)
grep -r "TechChart"  astras-bybit-ui/src       # 0 matches
grep -r "charting_library" astras-bybit-ui     # eslint.config.js (ignore patterns), README.md
grep -r "@tradingview" .                       # 0 matches
grep -r "tradingview" package.json             # 0 matches
```

Единственное упоминание `charting_library` после очистки — в:
- `eslint.config.js` — старые ignore patterns для лучей в bundles (можно убрать в следующий cleanup, но это уже не загружает proprietary код)
- `README.md` — описательное упоминание удалённой библиотеки (можно убрать в Sprint 3 doc pass)

Эти 2 артефакта **не загружают** и **не активируют** proprietary код в production — это просто текстовые упоминания.

## Verdict

**Sprint 2 OSS compliance: ✅ PASS.**

Система полностью свободна от proprietary chart/trading dependencies. Любые будущие `npm install` должны проходить через фильтр `npm view <pkg> license` (см. Замечание #2 в `mm-bot/sprint_2_stabilization_and_visual.md`), и результат записываться в эту же таблицу.
