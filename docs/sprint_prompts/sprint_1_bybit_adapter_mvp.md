# Sprint 1: Bybit Adapter MVP + Manual Trading через Astras

## Контекст для Claude Code

Это **Sprint 1** проекта `anymasoft/mm-bot`. Sprint 0 завершён — инфраструктура установлена (WSL2, Hummingbot, репозитории `astras-bybit-ui` и `bybit-adapter` созданы).

Текущий спринт — **vertical slice approach**: одновременно строим минимальный backend (`bybit-adapter`) и минимальную адаптацию frontend (`astras-bybit-ui`), чтобы по итогу спринта пользователь мог **вручную разместить лимитный ордер на Bybit testnet через UI Astras** и увидеть его в стакане в реальном времени.

Это даёт раннюю валидацию архитектуры (Путь A с proxy) и пользователю — раннее ощущение "потрогать торговлю". Hummingbot подключение оставлено на Sprint 4-5.

## Цель спринта

По итогу Sprint 1 пользователь должен в локально запущенном Astras (в браузере, не Tauri ещё) увидеть:

1. Список доступных инструментов Bybit с возможностью выбрать BTCUSDT
2. Свечной график цены BTCUSDT, обновляющийся в реальном времени
3. Стакан (DOM) BTCUSDT с live обновлениями bids/asks
4. Свой testnet баланс в Account Manager
5. Возможность через UI разместить лимитный ордер (например купить 0.001 BTC по цене $60000 при рынке $67000) — он должен появиться в стакане визуально как мой ордер
6. Возможность через UI отменить ордер — он должен исчезнуть из стакана

Это **manual trading** через Astras desktop UI. Hummingbot, стратегия, автоматизация — позже.

## Окружение

- WSL2 Ubuntu установлен и работает (Sprint 0)
- Hummingbot 2.14.0 установлен в `~/projects/hummingbot` в WSL (Sprint 0) — **не используем в этом спринте**, оставляем как есть
- Локальная директория проекта `C:\Users\<user>\projects\mm-bot\` на Windows, git connected to `anymasoft/mm-bot`
- Репозитории `anymasoft/astras-bybit-ui` (fork от ALOR) и `anymasoft/bybit-adapter` (пустой) созданы

В этом спринте мы клонируем оба репозитория **на Windows нативно** (не в WSL), потому что:
- bybit-adapter работает на Node.js — на Windows нативно лучше, потому что Astras frontend тоже будет на Windows (Tauri wrap позже)
- Astras frontend (Angular) — кросс-платформенный, на Windows без проблем
- Hummingbot в WSL изолирован, не пересекается с adapter в этом спринте

## Часть 1: Подготовка локальных рабочих копий

### Шаг 1.1: Клонировать adapter и фрейм для разработки

В PowerShell:
```powershell
cd $env:USERPROFILE\projects

# Клонировать наши репозитории
git clone https://github.com/anymasoft/bybit-adapter.git
git clone https://github.com/anymasoft/astras-bybit-ui.git

# Проверить
cd bybit-adapter; git status; cd ..
cd astras-bybit-ui; git status; git remote -v; cd ..
```

В `astras-bybit-ui` должно быть видно два remotes — `origin` (anymasoft) и upstream (alor-broker) если был добавлен через `gh repo fork`. Если upstream нет — добавить вручную:
```powershell
cd astras-bybit-ui
git remote add upstream https://github.com/alor-broker/Astras-Trading-UI.git
git remote -v
```

Это нужно чтобы в будущем мерджить обновления от ALOR через `git fetch upstream && git merge upstream/master`.

### Шаг 1.2: Создать рабочую ветку в astras-bybit-ui

В `astras-bybit-ui`:
```powershell
git checkout -b bybit-integration
git push -u origin bybit-integration
```

Это отдельная ветка для нашей работы, чтобы master оставался чистым для merge с ALOR upstream.

### Acceptance Части 1
- Оба репозитория клонированы локально
- В `astras-bybit-ui` есть branch `bybit-integration`
- `git remote -v` показывает upstream от alor-broker для astras-bybit-ui

## Часть 2: Audit ALOR API endpoints, используемых Astras

Прежде чем писать adapter, нужно точно знать что именно он должен реализовать. Astras frontend делает запросы к ALOR backend — какие именно, в каком формате.

### Шаг 2.1: Изучить структуру frontend сервисов

В `astras-bybit-ui`, изучить файлы:
- `src/environments/environment.ts` и `environment.prod.ts` — какие base URLs используются
- `src/app/shared/services/` — все API сервисы
- `src/app/shared/utils/load.utils.ts` (если есть) — конфигурация runtime

Цель: найти все unique HTTP endpoints и WebSocket message types которые отправляет frontend.

### Шаг 2.2: Создать документ audit

Создать `mm-bot/docs/sprint_reports/sprint_1_alor_endpoints_audit.md`:

```markdown
# Audit: ALOR API endpoints используемые Astras-Trading-UI

## REST endpoints (по приоритету для MVP)

### CRITICAL (без них UI не работает)

#### Auth
- `POST /refresh` — обновление JWT токена. Frontend ожидает {token, expires_in}.
- ...

#### Instruments
- `GET /md/v2/Securities/{exchange}/{symbol}` — детали инструмента
- ...

#### Orderbook
- `GET /md/v2/orderbooks/{exchange}/{symbol}` — snapshot стакана
- ...

[И так далее — все critical endpoints]

### MEDIUM (UI работает, но без некоторых фич)

[Endpoints which can be stubbed with empty responses]

### LOW (не нужны в MVP, можно вернуть заглушки)

[Endpoints для arbitrage, complex order types, etc.]

## WebSocket message types

### Subscribe messages

#### `OrderBookGetAndSubscribe`
Frontend отправляет:
```json
{
  "opcode": "OrderBookGetAndSubscribe",
  "exchange": "MOEX",
  "code": "SBER",
  "format": "Simple",
  "depth": 20,
  "guid": "<uuid>"
}
```
Сервер отвечает:
```json
{
  "guid": "<uuid>",
  "data": {
    "bids": [{"price": 250.5, "volume": 100}, ...],
    "asks": [{"price": 250.6, "volume": 150}, ...]
  }
}
```

### Unsubscribe messages

[И т.д.]

## Format peculiarities (важно для translator)

- ALOR использует `exchange` field: "MOEX" / "SPBX". Bybit не имеет такого концепта — будем использовать "BYBIT" как const value.
- Цены в ALOR — float. В Bybit V5 — string. Translator должен конвертировать.
- ALOR `code` = инструмент (например "SBER"). Bybit использует `symbol` (например "BTCUSDT"). Нужен mapping.
- Timestamps: ALOR использует ISO8601, Bybit V5 — Unix milliseconds. Конвертация в обе стороны.
- Order sides: ALOR — "buy"/"sell" (lowercase), Bybit — "Buy"/"Sell" (capitalized).

## Сводный список endpoints для Sprint 1 MVP

Реализовать только эти endpoints + WS subscriptions (всё остальное — заглушки):

1. POST /refresh
2. GET /md/v2/Securities — список доступных инструментов
3. GET /md/v2/Securities/{exchange}/{symbol}
4. GET /md/v2/orderbooks/{exchange}/{symbol}
5. GET /md/v2/history (свечи для chart)
6. GET /md/v2/Clients/{exchange}/{portfolio}/positions
7. GET /md/v2/Clients/{exchange}/{portfolio}/orders
8. GET /md/v2/Clients/{exchange}/{portfolio}/summary (баланс)
9. POST /commandapi/warptrans/TRADE/v2/client/orders/actions/limit (place limit order)
10. DELETE /commandapi/warptrans/TRADE/v2/client/orders/{orderId}/{portfolio} (cancel order)

WS subscriptions:
- OrderBookGetAndSubscribe
- BarsGetAndSubscribe
- QuotesSubscribe
- PositionsGetAndSubscribeV2
- OrdersGetAndSubscribeV2
- TradesGetAndSubscribeV2 (свои сделки)
```

**Точные пути endpoints могут отличаться** — нужно посмотреть в реальном коде Astras что он отправляет.

### Acceptance Части 2
- Документ `sprint_1_alor_endpoints_audit.md` создан с полным списком
- Понятны formats и quirks

## Часть 3: Реализация bybit-adapter

### Шаг 3.1: Initialize project

В `bybit-adapter`:
```powershell
npm init -y
npm install fastify @fastify/cors @fastify/jwt @fastify/websocket bybit-api dotenv pino pino-pretty
npm install -D typescript @types/node tsx vitest @vitest/ui tsconfig-paths
```

### Шаг 3.2: TypeScript config

`tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    },
    "resolveJsonModule": true,
    "declaration": false,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

### Шаг 3.3: Структура проекта

```
bybit-adapter/
├── src/
│   ├── config/
│   │   ├── env.ts              # Load .env, validate via Zod
│   │   └── constants.ts        # Static config
│   ├── bybit/
│   │   ├── client.ts           # Bybit REST client (tiagosiebler/bybit-api)
│   │   ├── ws-public.ts        # Public WS (orderbook, trades, klines)
│   │   └── ws-private.ts       # Private WS (orders, positions, wallet)
│   ├── alor/
│   │   ├── types.ts            # TypeScript types ALOR API contracts
│   │   └── constants.ts        # ALOR-specific values (exchanges, etc.)
│   ├── translators/
│   │   ├── orderbook.ts        # Bybit OB → ALOR OB
│   │   ├── ticker.ts           # Bybit ticker → ALOR quote
│   │   ├── candles.ts          # Bybit kline → ALOR bar
│   │   ├── orders.ts           # Bybit order → ALOR order
│   │   ├── positions.ts        # Bybit position → ALOR position
│   │   ├── balance.ts          # Bybit wallet → ALOR summary
│   │   └── instruments.ts      # Bybit instrument → ALOR security
│   ├── routes/
│   │   ├── auth.ts             # POST /refresh (mock JWT)
│   │   ├── securities.ts       # GET /md/v2/Securities/*
│   │   ├── orderbook.ts        # GET /md/v2/orderbooks/*
│   │   ├── history.ts          # GET /md/v2/history
│   │   ├── clients.ts          # GET /md/v2/Clients/*
│   │   ├── orders.ts           # POST/DELETE orders
│   │   └── index.ts            # Register all routes
│   ├── ws/
│   │   ├── server.ts           # Fastify WS server
│   │   ├── subscriptions.ts    # Subscription manager
│   │   ├── handlers.ts         # Handle subscribe/unsubscribe messages
│   │   └── broadcaster.ts      # Push updates to subscribed clients
│   ├── auth/
│   │   └── mock-jwt.ts         # Issue/validate fake JWT for MVP
│   ├── logger.ts               # pino logger setup
│   └── index.ts                # Entry point
├── tests/
│   ├── translators/
│   └── routes/
├── .env.example
├── .env                        # gitignored
├── package.json
├── tsconfig.json
├── README.md
└── LICENSE                     # уже Apache-2.0 from creation
```

### Шаг 3.4: .env.example

```
# Bybit API (testnet)
BYBIT_API_KEY=
BYBIT_API_SECRET=
BYBIT_TESTNET=true

# Adapter server
SERVER_HOST=127.0.0.1
SERVER_PORT=3000

# Logging
LOG_LEVEL=info

# Mock auth (Sprint 1 only)
JWT_SECRET=local-dev-secret-change-in-production
JWT_MOCK_PORTFOLIO=bybit_testnet
```

### Шаг 3.5: Реализация endpoints

Для каждого endpoint из audit (Часть 2):

1. Определить ALOR contract в `src/alor/types.ts` (TypeScript типы request и response)
2. Реализовать translator в `src/translators/*.ts`
3. Реализовать Fastify route в `src/routes/*.ts`
4. Написать vitest test что translator корректно конвертирует sample Bybit response в ALOR-format

**Приоритет реализации** (внутри Шага 3.5):

Day 1-2:
- Mock JWT auth (`/refresh` endpoint)
- Instruments list (`/md/v2/Securities`)
- Single instrument (`/md/v2/Securities/{exchange}/{symbol}`)

Day 3-4:
- Orderbook snapshot
- Candles history
- Balance/summary

Day 5-7:
- Place limit order
- Cancel order
- Active orders list
- Positions list

Day 8-10:
- WebSocket server setup
- OrderBookGetAndSubscribe handler
- BarsGetAndSubscribe handler

Day 11-12:
- Private WS handlers (orders, positions, trades)
- Integration testing

### Шаг 3.6: Mock JWT auth (важно для понимания)

Astras делает auth flow через ALOR SSO. Мы не можем это replicate. Делаем shortcut:

```typescript
// src/auth/mock-jwt.ts
import jwt from '@fastify/jwt';

export async function issueMockToken(fastify: FastifyInstance) {
  const token = fastify.jwt.sign({
    sub: 'bybit_user',
    portfolio: process.env.JWT_MOCK_PORTFOLIO || 'bybit_testnet',
    exchange: 'BYBIT',
    iat: Math.floor(Date.now() / 1000),
  }, { expiresIn: '24h' });
  return token;
}
```

Endpoint `/refresh` (или `/auth/refresh` в зависимости от того что в Astras frontend) возвращает этот токен независимо от того что прислал клиент. Это **только для MVP**, в production будет проверка реальных учётных данных.

### Шаг 3.7: WebSocket multiplexing

Astras использует **одно WebSocket соединение** с ALOR и через него мультиплексирует подписки на разные инструменты через `guid` field. Adapter должен:

1. Принять WS соединение от Astras на `ws://localhost:3000/ws`
2. Парсить incoming messages по `opcode`
3. Для каждой subscription с `guid` — установить соответствующую подписку на Bybit WS
4. Когда приходит update от Bybit — translate и отправить на клиента с тем же `guid`
5. Поддерживать множественные подписки одновременно
6. Корректно обрабатывать unsubscribe

Архитектура:
```
Astras client (1 WS connection) ←──── adapter WS server
                                            │
                                            ├── Bybit Public WS (orderbook BTC)
                                            ├── Bybit Public WS (kline BTC)
                                            ├── Bybit Public WS (orderbook ETH)
                                            └── Bybit Private WS (orders/positions)
```

### Шаг 3.8: Запуск и smoke test

В `bybit-adapter`:
```powershell
# Заполнить .env (НЕ коммитить!)
notepad .env
# BYBIT_API_KEY=<тут ключ>
# BYBIT_API_SECRET=<тут secret>

# Запустить dev режим
npm run dev
```

Server должен запуститься на :3000, в логах увидеть "Adapter listening on http://127.0.0.1:3000".

Smoke test через curl:
```powershell
# Получить mock JWT
curl http://127.0.0.1:3000/refresh -X POST

# Список инструментов
curl http://127.0.0.1:3000/md/v2/Securities

# Детали BTCUSDT
curl http://127.0.0.1:3000/md/v2/Securities/BYBIT/BTCUSDT

# Стакан BTCUSDT
curl http://127.0.0.1:3000/md/v2/orderbooks/BYBIT/BTCUSDT
```

Каждый endpoint должен возвращать **валидный JSON в ALOR формате** с реальными данными от Bybit testnet.

### Acceptance Части 3
- `bybit-adapter` запускается без ошибок
- Все critical REST endpoints отвечают
- WebSocket subscriptions работают (можно проверить через wscat:
  `wscat -c ws://127.0.0.1:3000/ws` и отправить subscribe message)
- Tests проходят: `npm test`

## Часть 4: Адаптация Astras frontend

### Шаг 4.1: Изменить environment URLs

В `astras-bybit-ui`, найти `src/environments/environment.ts` (и `environment.prod.ts`). Заменить ALOR backend URLs на `http://localhost:3000`.

Конкретные ключи которые нужно изменить — зависит от структуры environment. Типично что-то вроде:
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:3000',  // было: https://api.alor.ru
  wsUrl: 'ws://localhost:3000/ws',  // было: wss://api.alor.ru/ws
  // ... другие настройки
};
```

### Шаг 4.2: Bypass SSO redirect

Astras при старте проверяет JWT, если нет — редиректит на ALOR SSO login. Нужно либо:
- Найти AuthService и подменить чтобы автоматически вызывал наш `/refresh` и сохранял токен
- Или временно захардкодить токен в localStorage при init

Минимальный hack:
```typescript
// В app.component.ts или в auth service init
if (!localStorage.getItem('jwt_token')) {
  const response = await fetch('http://localhost:3000/refresh', { method: 'POST' });
  const data = await response.json();
  localStorage.setItem('jwt_token', data.token);
  // и другие fields которые ожидает Astras
}
```

Это **временный hack** для MVP, в Sprint 2-3 заменим на нормальный auth flow с проверкой API keys.

### Шаг 4.3: Захардкодить exchange как BYBIT

В Astras пользователь обычно выбирает биржу (MOEX / SPBX). Для MVP — захардкодить везде `"BYBIT"` как default. Найти в коде места где выбирается exchange и поставить hardcoded value.

**ВАЖНО:** MOEX-specific код **НЕ УДАЛЯТЬ**. Просто dormant — может пригодиться когда пользователь подключит ALOR account для торговли на Мосбирже параллельно (см. project memory).

### Шаг 4.4: Запуск Astras

```powershell
cd astras-bybit-ui
npm install
npm start
```

Это запустит dev server на :4200. Открыть в Chrome `http://localhost:4200`.

Если всё правильно — должен открыться знакомый интерфейс Astras, но запросы пойдут на наш `localhost:3000`, и данные будут из Bybit testnet.

### Acceptance Части 4
- Astras запускается через `npm start` без ошибок
- В DevTools Network тab видны запросы на `localhost:3000`
- JWT auto-issued, нет редиректа на ALOR SSO
- В UI виден список инструментов с Bybit pairs

## Часть 5: Smoke test - manual trading

### Сценарий

В запущенном Astras:

1. Войти в систему (auto-auth)
2. В Watchlist найти BTCUSDT
3. Открыть Chart widget для BTCUSDT — увидеть свечи
4. Открыть OrderBook widget — увидеть live стакан
5. Открыть Account Manager — увидеть testnet баланс
6. Через Order Form виджет:
   - Side: Buy
   - Type: Limit
   - Price: 60000 (значительно ниже текущего рынка ~67000)
   - Quantity: 0.001 BTC
   - Submit
7. Видеть свой ордер на графике как horizontal line на цене 60000
8. Видеть его в Working Orders таблице
9. В стакане на уровне 60000 видеть свою позицию (если Astras это подсвечивает)
10. Через Working Orders таблицу — Cancel этот ордер
11. Убедиться что ордер исчез из стакана и из таблицы

### Скриншоты (обязательно)

Сохранить в `mm-bot/screenshots/sprint_1_*.png`:
- `sprint_1_astras_main.png` — главный экран с открытыми виджетами
- `sprint_1_btcusdt_chart.png` — chart с свечами
- `sprint_1_orderbook.png` — стакан
- `sprint_1_account_manager.png` — баланс
- `sprint_1_my_order_placed.png` — мой ордер на графике/в таблице
- `sprint_1_my_order_in_dom.png` — мой ордер в стакане
- `sprint_1_order_cancelled.png` — после отмены

### Acceptance Части 5
- Все шаги сценария выполнимы
- Скриншоты сохранены и закоммичены в `mm-bot/screenshots/`

## Часть 6: Отчёт и финальный коммит

### Шаг 6.1: Отчёт спринта

Создать `mm-bot/docs/sprint_reports/sprint_1_report.md`:

```markdown
# Sprint 1 Report: Bybit Adapter MVP + Manual Trading

## Что сделано

### bybit-adapter
- Реализованные endpoints: [список]
- WebSocket subscriptions: [список]
- Tests coverage: [%]
- Структура: см. https://github.com/anymasoft/bybit-adapter

### astras-bybit-ui
- Branch: `bybit-integration`
- Изменения: [список файлов]
- Pull request с upstream: нет (наш fork)

### Manual trading smoke test
- Все 11 шагов сценария: [PASSED / partial / failed]
- Скриншоты: см. mm-bot/screenshots/sprint_1_*

## Не сделано / отложено

[Список того что планировали но отложили на потом]

## Проблемы и решения

[Что сломалось, как фиксили]

## Обнаруженные нюансы ALOR API / Astras внутренностей

[Полезные находки для будущих спринтов]

## Архитектурные вопросы для следующего спринта

1. [Вопросы которые блокируют Sprint 2 или требуют решения]

## Метрики

- Часов работы: [N]
- Строк кода в bybit-adapter: [N]
- Файлов изменено в astras-bybit-ui: [N]
- Размер dev bundle Astras: [MB]
- Bybit API rate limit hit count: [N или 0]

## Следующий шаг

Готовы к Sprint 2: Tauri 2.0 wrap + extended Astras adaptation.
```

### Шаг 6.2: Коммиты во все три репо

В `bybit-adapter`:
- Все source files
- README с инструкцией запуска
- .gitignore (уже есть)
- .env.example
- НЕ коммитить: .env с реальными ключами

В `astras-bybit-ui` branch `bybit-integration`:
- Изменения environment files
- Изменения auth bypass
- Hardcoded BYBIT exchange
- Push в origin

В `mm-bot`:
- `docs/sprint_reports/sprint_1_alor_endpoints_audit.md`
- `docs/sprint_reports/sprint_1_report.md`
- `screenshots/sprint_1_*.png`

### Шаг 6.3: Чек-лист безопасности перед каждым push

См. `sprint_0_git_setup.md` Часть 5. Главное:
- `git diff --staged` глазами в каждом репо
- Нет API keys, secrets, токенов в diff
- `.env` НЕ в git

### Шаг 6.4: URL последнего коммита в каждом репо

В отчёте указать:
- bybit-adapter: https://github.com/anymasoft/bybit-adapter/commit/<hash>
- astras-bybit-ui: https://github.com/anymasoft/astras-bybit-ui/commit/<hash>
- mm-bot: https://github.com/anymasoft/mm-bot/commit/<hash>

## Acceptance criteria для всего Sprint 1

- [ ] Документ audit ALOR endpoints создан и закоммичен
- [ ] bybit-adapter имплементирован с минимальным набором endpoints
- [ ] Все REST endpoints отвечают через curl с валидным JSON
- [ ] WebSocket subscriptions работают
- [ ] astras-bybit-ui запускается, подключается к localhost:3000
- [ ] Auto-auth работает (нет SSO redirect)
- [ ] В UI виден список инструментов Bybit
- [ ] BTCUSDT chart обновляется в реальном времени
- [ ] BTCUSDT orderbook обновляется в реальном времени
- [ ] Testnet баланс виден в Account Manager
- [ ] Можно разместить лимитный ордер через UI и увидеть его в стакане
- [ ] Можно отменить ордер через UI
- [ ] Скриншоты всех ключевых экранов сохранены
- [ ] Sprint 1 report создан и закоммичен
- [ ] Все три репо обновлены на GitHub

## Важные замечания для Claude Code

1. **Vertical slice approach** — не стремись реализовать "идеально все endpoints" в этом спринте. MVP = только то что нужно для smoke test'а. Остальные endpoints можно отвечать заглушками (404 или пустой массив) пока Astras не сломается без них.

2. **Если Astras падает потому что какой-то endpoint не реализован** — реализовать минимальную заглушку чтобы UI не падал. Записать в audit как "needs full implementation in later sprint".

3. **Не пытайся починить ВСЁ в Astras** — какие-то фичи могут не работать корректно с Bybit данными (например арбитраж между биржами не имеет смысла когда биржа одна). Это OK. Фокус на 11 шагах smoke test'а.

4. **MOEX-specific код в Astras не удалять.** Просто переключить runtime на BYBIT exchange. MOEX останется dormant для будущей ALOR интеграции.

5. **Translators критичны** — не упрощай types, не пропускай fields. Better быть verbose в типах чем потом гадать почему frontend не парсит response.

6. **Не использовать Hummingbot в этом спринте.** Он установлен в WSL, оставить как есть.

7. **API keys** — единственное место их хранения это `bybit-adapter/.env`. НИКОГДА в astras-bybit-ui и не в коммитах. Если frontend нужны какие-то credentials — он получает их через JWT от adapter, реальные ключи не покидают backend.

8. **Если возникнут проблемы с rate limits Bybit** во время разработки — использовать testnet endpoint, у него мягче лимиты чем у mainnet.

9. **TypeScript strict mode обязателен** — никаких `any` без комментария почему.

10. **Логирование через pino** — все запросы к Bybit, все WS subscriptions, все ошибки. Логи в stdout, читать через `npm run dev`.

## Расчётный timeline

10-14 рабочих дней full-time. Может быть быстрее если Astras frontend окажется проще чем ожидаем, или дольше если найдём 50+ endpoints вместо 10.

## Риски

- **ALOR API сложнее чем выглядит** — может оказаться 30-50 endpoints вместо 10. Mitigation: priority list, заглушки для non-critical.
- **Astras делает что-то нестандартное в auth** — может потребоваться больше hacks чем mock JWT. Mitigation: в крайнем случае патчить конкретные сервисы в frontend.
- **Format mismatches которые невозможно translate 1:1** — Bybit и ALOR не идентичны по domain model. Mitigation: документировать compromises в comments кода + sprint report.
- **WebSocket multiplexing сложнее REST** — может занять больше времени чем планировалось. Mitigation: начать с REST, WS отдельным under-sprint если нужно.

## Что НЕ делать в Sprint 1

- Не подключать Hummingbot
- Не делать Tauri wrap (Sprint 2)
- Не оптимизировать UI Astras (Sprint 2-3)
- Не реализовывать complex order types (stop loss, take profit) — только limit orders
- Не делать production-grade auth (Sprint 3)
- Не пытаться поддержать multi-account (Sprint 5+)
- Не интегрировать MOEX через ALOR (отложено, dormant)
