# Sprint 3 — OSS Compliance Audit

**Hard constraint проекта:** все компоненты торговой системы 100% open source GitHub, OSI-approved licenses без оговорок типа Commons Clause / freemium / application-required.

Audit покрывает обе кодовые базы (`bybit-adapter`, `astras-bybit-ui`) после Sprint 3 и подтверждает что **в системе нет proprietary зависимостей**. Также — это первый "full deps snapshot" baseline для проекта (Замечание #10 в Sprint 3 промпте).

## Новое в Sprint 3

| Package | Version | License | Где добавлено | OK? |
|---|---|---|---|---|
| — | — | — | (новых зависимостей не добавляли) | ✅ |

В Sprint 3 backend изменения были чисто алгоритмическими (stateful merge orderbook, throttling, REST seed, blotter endpoints через уже-добавленный `bybit-api`), frontend — переключение виджета и микро-оптимизации Angular (OnPush + trackBy). Установок `npm install` / `pnpm install` не было.

## Удалено в Sprint 3

| Что | Где сидело | Решение |
|---|---|---|
| `**/charting_library/**/*` в `eslint.config.js` `globalIgnores` | `astras-bybit-ui/eslint.config.js:12` | Удалено. Сам код charting_library был удалён в Sprint 2; ignore-паттерн больше не имеет смысла. |
| Упоминание `tradingview(charting_library)` в README | `astras-bybit-ui/README.md:33` | README переписан под актуальный стек (lightweight-charts + technicalindicators); явно прописано "100% open source стек". |
| Stub'ы `[]` для `/stoporders`, `/trades`, `/stats/history/trades` | `bybit-adapter/src/routes/stubs.ts` | Заменены реальными Bybit V5 хэндлерами в `routes/blotter.ts`. Stub для broader `/stats/*` catch-all оставлен на случай неожиданных reads. |

Комментарии в коде, объясняющие удаление TradingView Charting Library (parent-widget.component.ts:19, mobile-dashboard.effects.ts:24) **оставлены намеренно** — это исторический контекст для будущих разработчиков, который не загружает proprietary код.

## Полный аудит deps (baseline после Sprint 3)

### astras-bybit-ui (Angular 21 fork от alor-broker/Astras-Trading-UI)

**production dependencies (29):**

| Package | Version | License | Зачем | OK? |
|---|---|---|---|---|
| `@angular/*` (10 пакетов) | 21.2.9 | MIT | Framework | ✅ |
| `@apollo/client` | 4.1.7 | MIT | GraphQL клиент | ✅ |
| `@capacitor-firebase/messaging` | 8.2.0 | MIT | Push для mobile | ✅ |
| `@capacitor/core`, `ios`, `network` | 8.3.1 | MIT | Mobile wrap Sprint 5+ | ✅ |
| `@comfyorg/litegraph` | 0.8.98 | MIT | AI graph (unused в Sprint 3) | ✅ |
| `@date-fns/tz` | 1.4.1 | MIT | Timezone helper | ✅ |
| `@ionic/angular` | 8.8.4 | MIT | Mobile UI | ✅ |
| `@jsverse/transloco` | 8.3.0 | MIT | i18n | ✅ |
| `@ngrx/*` (7 пакетов) | 21.1.0 | MIT | State management | ✅ |
| `angular-gridster2` | 21.0.1 | MIT | Dashboard grid | ✅ |
| `apollo-angular` | 13.0.0 | MIT | Angular bridge для Apollo | ✅ |
| `chart.js` | 4.5.1 | MIT | Portfolio charts (equity curve) | ✅ |
| `chartjs-adapter-date-fns` | 3.0.0 | MIT | date adapter для Chart.js | ✅ |
| `chartjs-chart-treemap` | 3.1.0 | MIT | Treemap | ✅ |
| `d3` | 7.9.0 | ISC | Утилиты (color, scaling) | ✅ |
| `date-fns` | 4.1.0 | MIT | Date utils | ✅ |
| `firebase` | 12.10.0 | Apache-2.0 | Push notifications | ✅ |
| `gql-query-builder` | 3.8.0 | MIT | GraphQL helper | ✅ |
| `graphql` | 16.13.2 | MIT | GraphQL core | ✅ |
| `json-patch` | 0.7.0 | MIT | Settings migration | ✅ |
| **`lightweight-charts`** | **5.1.0** | **Apache-2.0** | **Основной chart widget** | ✅ |
| `ng-zorro-antd` | 21.2.2 | MIT | UI kit | ✅ |
| `ng2-charts` | 9.0.0 | MIT | Chart.js Angular bridge | ✅ |
| `ngx-device-detector` | 11.0.0 | MIT | Device info | ✅ |
| `ngx-joyride` | 2.5.0 | MIT | UI tour | ✅ |
| `ngx-markdown` | 21.2.0 | MIT | Markdown rendering | ✅ |
| `rxjs` | 7.8.2 | Apache-2.0 | Reactive | ✅ |
| **`technicalindicators`** | **3.1.0** | **MIT** | **SMA/EMA/BB/RSI/ATR** | ✅ |
| `zod` | (см. snapshot) | MIT | Schema validation | ✅ |

**dev dependencies (~30):** Angular toolchain (`@angular-eslint/*`, `@angular/build`, `@angular/cli`), GraphQL codegen (`@graphql-codegen/*`), ESLint (`@stylistic/eslint-plugin`, `eslint`, `typescript-eslint`, `angular-eslint`), типы (`@types/*`), test runner (`karma`, `jasmine`), build tools (`less`, `marked`), husky, ng-mocks. Все MIT / Apache-2.0 / ISC.

### bybit-adapter (Node.js / Fastify)

**production dependencies (10):**

| Package | License | Зачем | OK? |
|---|---|---|---|
| `@fastify/cors` | MIT | CORS | ✅ |
| `@fastify/jwt` | MIT | JWT mock auth | ✅ |
| `@fastify/websocket` | MIT | WS в Fastify | ✅ |
| **`bybit-api`** (tiagosiebler) | **MIT** | **Bybit V5 REST + WS клиент** | ✅ |
| `dotenv` | BSD-2-Clause | .env loader | ✅ |
| `fastify` | MIT | HTTP сервер | ✅ |
| `pino`, `pino-pretty` | MIT | Logger | ✅ |
| `uuid` | MIT | Subscription IDs | ✅ |
| `zod` | MIT | Schema validation | ✅ |

**dev dependencies:** `tsx`, `vitest`, `typescript`, `@types/node`, `@types/uuid`. Все MIT / Apache-2.0.

## Проверка чистоты

```bash
# Astras source code (excluding informational comments about removed code)
grep -rn "tech-chart\|TechChart\|charting_library\|InitialSettingsMap\|@tradingview" \
  --include="*.ts" --include="*.json" --include="*.html" --include="*.less" src/

# → 2 matches, both are explanatory comments documenting Sprint 2 removal:
#   parent-widget.component.ts:19 — "TechChartWidget removed in Sprint 2..."
#   mobile-dashboard.effects.ts:24 — "InitialSettingsMap previously came from..."

# Astras root config / docs
grep -rn "tech-chart\|charting_library\|@tradingview" *.md *.js *.config.*
# → 0 matches after Sprint 3 cleanup (was 3 in Sprint 2 leftover)

# bybit-adapter
grep -rn "tradingview\|charting_library" src/
# → 0 matches
```

## Verdict

**Sprint 3 OSS compliance: ✅ PASS.**

Полный список production deps зафиксирован в `sprint_3_deps_snapshot.txt` как baseline для будущих спринтов. Любой `npm install` / `pnpm add` в Sprint 4+ должен проходить через фильтр `npm view <pkg> license` и записываться в `sprint_N_oss_audit.md` с явным указанием license.
