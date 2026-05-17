# Sprint 4 — OSS Compliance Audit

**Hard constraint проекта:** все компоненты торговой системы 100% open source GitHub, OSI-approved licenses без оговорок типа Commons Clause / freemium / application-required / trial-period.

Audit охватывает обе кодовые базы (`bybit-adapter`, `astras-bybit-ui`) после Sprint 4 pivot и подтверждает что **в системе нет proprietary зависимостей**.

## Новое в Sprint 4

| Package | Version | License | Где добавлено | OK? |
|---|---|---|---|---|
| — | — | — | (новых зависимостей не добавляли) | ✅ |

Sprint 4 был чисто алгоритмический (новый strategy module в TypeScript внутри adapter, три новых Angular widget'а в Astras). Установок `npm install` / `pnpm add` не было. Все использованные packages уже находились в `dependencies` из Sprint 1-3:

**bybit-adapter** (Epic A + F.1 + F.2):
- `zod` (3.x, MIT) — уже использовался для env validation, теперь и для PMM config schema
- `bybit-api` (3.x, MIT, tiagosiebler) — уже подключен, новые вызовы: `getInstrumentsInfo`, `getPositionInfo`, `submitOrder` (с `orderLinkId` и `timeInForce=PostOnly`), `cancelOrder`
- `fastify` + `@fastify/cors` + `@fastify/jwt` + `@fastify/websocket` (все MIT) — REST routes + WS broadcast уже инфраструктура
- `vitest` (MIT) — 60+ новых тестов для strategy math на уже-установленном test runner

**astras-bybit-ui** (Epic B + C):
- `@angular/*` 21.x (MIT) — три новых widget модуля
- `ng-zorro-antd` 21.x (MIT) — все form controls (NzInputNumberModule, NzSwitchModule, NzCollapseModule, NzDescriptionsModule, NzRadioModule, etc.) уже использованы в других widgets, импорты из существующих subpath'ов
- `lightweight-charts` 5.x (Apache-2.0) — уже используется в light-chart module, переиспользован для equity-tracker
- `@jsverse/transloco` (MIT) — i18n уже подключен
- `rxjs` (Apache-2.0) — уже используется

## Удалено в Sprint 4

| Что | Где | Решение |
|---|---|---|
| Crypto layout: light-chart + scalper-order-book + order-submit + portfolio-charts + blotter | `astras-bybit-ui/src/assets/default-dashboards-config.json` | Заменены на strategy-control + equity-tracker + strategy-action-log. Сами widget модули **не удалены** — доступны через меню "Виджеты" для manual trading сценариев. |

## Полный аудит deps (snapshot после Sprint 4)

### astras-bybit-ui (Angular 21 fork от alor-broker/Astras-Trading-UI)

**Production dependencies (29):** идентичны Sprint 3 — `@angular/*` (10 пакетов, MIT), `@apollo/client` (MIT), `@capacitor-firebase/messaging` (MIT), `@capacitor/*` (MIT, 3 пакета), `@comfyorg/litegraph` (MIT, unused), `@date-fns/tz` (MIT), `@ionic/angular` (MIT), `@jsverse/transloco` (MIT), `@ngrx/*` (7 пакетов, MIT), `angular-gridster2` (MIT), `apollo-angular` (MIT), `chart.js` (MIT), `chartjs-adapter-date-fns` (MIT), `chartjs-chart-treemap` (MIT), `d3` (ISC), `date-fns` (MIT), `firebase` (Apache-2.0), `gql-query-builder` (MIT), `graphql` (MIT), `json-patch` (MIT), **`lightweight-charts`** 5.1.0 (Apache-2.0), `ng-zorro-antd` (MIT), `ng2-charts` (MIT), `ngx-device-detector` (MIT), `ngx-joyride` (MIT), `ngx-markdown` (MIT), `rxjs` (Apache-2.0), **`technicalindicators`** (MIT), `zod` (MIT). Все ✅.

**Dev dependencies (~30):** идентичны Sprint 3. Angular toolchain (`@angular-eslint/*`, `@angular/build`, `@angular/cli`), GraphQL codegen (`@graphql-codegen/*`), ESLint (`@stylistic/eslint-plugin`, `eslint`, `typescript-eslint`, `angular-eslint`), types (`@types/*`), test runner (`karma`, `jasmine`), build tools (`less`, `marked`), husky, ng-mocks. Все MIT / Apache-2.0 / ISC.

### bybit-adapter (Node.js / Fastify)

**Production dependencies (10):** идентичны Sprint 3.

| Package | License | Зачем | OK? |
|---|---|---|---|
| `@fastify/cors` | MIT | CORS | ✅ |
| `@fastify/jwt` | MIT | JWT mock auth | ✅ |
| `@fastify/websocket` | MIT | WS в Fastify | ✅ |
| **`bybit-api`** (tiagosiebler) | **MIT** | **Bybit V5 REST + WS клиент + новые вызовы стратегии (Sprint 4)** | ✅ |
| `dotenv` | BSD-2-Clause | .env loader | ✅ |
| `fastify` | MIT | HTTP сервер | ✅ |
| `pino`, `pino-pretty` | MIT | Logger | ✅ |
| `uuid` | MIT | Subscription IDs | ✅ |
| `zod` | MIT | Schema validation + PMM config schema (Sprint 4) | ✅ |

**Dev dependencies (5):** `tsx`, `vitest`, `typescript`, `@types/node`, `@types/uuid`. Все MIT / Apache-2.0.

## Проверка чистоты

```bash
# Strategy module — никаких proprietary импортов
grep -rn "import.*tradingview\|import.*hummingbot\|trial\|paid" \
  bybit-adapter/src/strategy/ astras-bybit-ui/src/app/modules/strategy-control/ \
  astras-bybit-ui/src/app/modules/strategy-action-log/ \
  astras-bybit-ui/src/app/modules/equity-tracker/
# → 0 matches

# Astras root config / docs — никаких TradingView упоминаний после Sprint 3 cleanup
grep -rn "tech-chart\|charting_library\|@tradingview" astras-bybit-ui/*.md \
  astras-bybit-ui/eslint.config.js astras-bybit-ui/*.config.*
# → 0 matches

# bybit-adapter
grep -rn "tradingview\|charting_library\|hummingbot" bybit-adapter/src/
# → 0 matches
```

## Hummingbot

Hummingbot 2.14.0 (Apache-2.0) **установлен в WSL2** под `~/projects/hummingbot/`, но **deprecated с Sprint 4** — переведён в режим dormant fallback. Не запускается в стандартном workflow, не вызывается из нашего кода, не имеет никаких npm/Python dependencies в наших репозиториях. Установка остаётся на случай Sprint 5+ cross-validation реализации PMM Dynamic. См. `docs/architecture/strategy_engine.md`.

Hummingbot был и остаётся OSS (Apache-2.0). Архитектурное решение убрать его — про сложность интеграции, а не про лицензию.

## Verdict

**Sprint 4 OSS compliance: ✅ PASS.**

Никаких новых зависимостей не добавлено. Все production deps идентичны Sprint 3. Strategy module и три новых Astras widget'а написаны на уже-установленных OSI-approved пакетах.
