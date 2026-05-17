# Sprint 1: Manual Trading Walkthrough

Пошаговая инструкция как руками протестировать торговлю через Astras → bybit-adapter → Bybit Demo.
Этот документ — то, что в Sprint 1 промпте обозначено как Часть 5. Скриншоты по ходу теста складываются в `mm-bot/screenshots/sprint_1_*.png`.

> **Предупреждение.** Sprint 1 — это manual MVP. Часть фич Astras работать не будет (арбитраж между биржами, ALOR-специфичный риск-менеджмент, дивиденды, etc) — это **ожидаемо**. Цель — пройти 11 шагов smoke-теста. Всё остальное доберём в Sprint 2-3.

---

## 0. Подготовка

### 0.1 Bybit Demo Trading: пополнить тестовый баланс

1. Зайти на https://www.bybit.com/ под своим аккаунтом
2. В правом верхнем меню переключиться на **Demo Trading** (логотип меняется на жёлтый)
3. В **Assets → Demo Trading Account** нажать **Request Demo Funds** — Bybit выдаёт $50,000 USDT
4. Убедиться что USDT появилось в **Derivatives → UTA** (Unified Trading Account)

Без этого шага adapter будет возвращать нулевой баланс, и Astras Account Manager покажет пустоту.

### 0.2 Ключи в `C:\BUFFER\mm-bot\.env`

Должны быть:
```
MM_BOT_BYBIT_DEMO_API_KEY=...
MM_BOT_BYBIT_DEMO_API_SECRET=...
```

Adapter их берёт автоматически (см. `bybit-adapter/.env`, сгенерирован при первом запуске).

---

## 1. Запуск адаптера

```powershell
cd C:\BUFFER\mm-bot\bybit-adapter
npm run dev
```

Ожидаемый вывод (последние 4 строки):
```
INFO: Bybit REST client initialised  env=demo
INFO: bybit-adapter listening  addr=http://127.0.0.1:3000
  REST: http://127.0.0.1:3000
  WS (data feed): ws://127.0.0.1:3000/ws
  WS (commands):  ws://127.0.0.1:3000/cws
```

Окно с adapter оставить открытым — туда будут идти логи всех запросов от Astras.

**Быстрая проверка адаптера** (в отдельном окне PowerShell):
```powershell
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/md/v2/Securities/BYBIT/BTCUSDT
```

Первый ответит `{"ok":true,...}`. Второй — JSON с описанием BTCUSDT (live данные с Bybit).

---

## 2. Запуск Astras

В новом окне PowerShell:
```powershell
cd C:\BUFFER\mm-bot\astras-bybit-ui
pnpm start
```

Сборка занимает 1-3 минуты при первом запуске. Когда увидишь:
```
Local:   http://localhost:4200/
```
— открой эту ссылку в **Chrome** (другие браузеры не тестировал в этом спринте, могут быть quirks).

---

## 3. Smoke test — 11 шагов

### Шаг 1: Загрузка без SSO redirect

✅ **Ожидается:** Astras грузится и НЕ редиректит на `login-dev.alor.ru`. Должен открыться главный дашборд.

В DevTools (F12) → Network — должен быть один запрос `POST /auth/actions/refresh` в самом начале (это наш auth shim из `main.ts`). В Application → Local Storage → `http://localhost:4200` должен лежать ключ `sso` со значением вида `{"jwt":"eyJ...","refreshToken":"mock-refresh-token"}`.

🚨 **Если редирект всё-таки случился** — открой `localhost:4200`, в DevTools Console очисти localStorage (`localStorage.clear()`), перезагрузи страницу. Если повторяется — смотри лог adapter'а: должен быть запрос `POST /auth/actions/refresh`. Если запроса нет — adapter не запущен или не на 3000 порту.

📸 Скриншот: `sprint_1_astras_main.png`

### Шаг 2: Watchlist — найти BTCUSDT

В верхнем меню → виджет **Watchlist** (или **Список инструментов**).
- В поиске ввести `BTCUSDT`
- Должна появиться единственная строка с биржей BYBIT

✅ **Ожидается:** список не пустой; видна цена ~$78000 (или текущая рыночная).

🚨 Если список пустой → DevTools Network: посмотри запрос `GET /md/v2/Securities?...`. Если 502 — adapter упал, смотри его лог. Если пустой массив — символ не нашёлся; убедись что adapter дефолтная категория = `linear`.

📸 `sprint_1_watchlist.png`

### Шаг 3: Chart widget — BTCUSDT свечи

Кликнуть по BTCUSDT в watchlist → должен открыться (или раскрыться существующий) **Chart** виджет.

✅ **Ожидается:** TradingView-стайл свечной график, в правом нижнем углу — текущая цена обновляется. Видны свечи как минимум за последний час.

🚨 Свечи не появились → запрос `GET /md/v2/history?...`. Должен вернуть `{history: [...]}` с 50-200 элементами.
🚨 График пустой и не обновляется → WS-подписка `BarsGetAndSubscribe` не сработала. В adapter логе должно быть `data WS client connected`.

📸 `sprint_1_btcusdt_chart.png`

### Шаг 4: OrderBook (DOM) widget

Добавить виджет **Стакан** (OrderBook) → выбрать BTCUSDT.

✅ **Ожидается:** колонки bids/asks, цены ~$78000 диапазон, видна live-обновляемость (числа меняются каждую секунду-две).

🚨 Стакан пустой → WS `OrderBookGetAndSubscribe`. Adapter лог покажет subscription и updates. Если по WS приходят данные, но Astras не рендерит — формат `slim` vs `full`: см. `bybit-adapter/src/ws/data-handler.ts:OrderBookGetAndSubscribe`.

📸 `sprint_1_orderbook.png`

### Шаг 5: Account Manager — баланс

Виджет **Управление счетом** (Account Manager) или **Портфель**.

✅ **Ожидается:** видно ~$50,000 USDT (если выполнил шаг 0.1), портфель = `bybit_demo`, биржа = BYBIT.

🚨 Если 0 — проверь что в Bybit Demo действительно есть funds (https://www.bybit.com/user/assets/home/account-overview), переключившись на Demo. Иногда баланс лежит на SPOT, а не UNIFIED — adapter сейчас читает только UNIFIED.

📸 `sprint_1_account_manager.png`

### Шаг 6: Разместить лимитный ордер

Виджет **Order Form** (форма заявки).

- Инструмент: BTCUSDT
- Side: **Buy**
- Type: **Limit**
- Price: `60000` (значительно ниже рынка ~78000 — чтобы не заполнился)
- Quantity: `0.001` (минимум для BTCUSDT-linear)
- Submit

В adapter логе должно появиться сообщение про cws (если используется WS) или POST `/commandapi/...` (если REST).

✅ **Ожидается:** в **Working Orders** появляется новая строка с этим ордером. В UI могут появиться зеленые маркеры на графике.

🚨 Ошибка валидации Bybit → текст ошибки в adapter логе. Часто причины: precision (qty или price не кратны step), отсутствие позиции для leveraging, баланс ниже маржи.

📸 `sprint_1_my_order_placed.png`

### Шаг 7: Ордер в стакане

В виджете OrderBook посмотри на уровень $60000.

✅ **Ожидается:** этот уровень либо подсвечен (если Astras это умеет для BYBIT), либо просто виден в bids как обычный уровень. Главное — order ID совпадает с тем что в Working Orders.

📸 `sprint_1_my_order_in_dom.png`

### Шаг 8: Изменить ордер (опционально, не критично)

В Working Orders → правой кнопкой → Edit → поменять цену на 61000 → Submit.

✅ **Ожидается:** строка в Working Orders обновилась, в логе adapter — submit + cancel пара (Bybit V5 amend не у всех типов поддерживается; adapter в Sprint 1 может делать cancel+place).

🚨 В Sprint 1 это может не работать — это известное ограничение, OK пропустить.

### Шаг 9: Отменить ордер

В Working Orders → правой кнопкой → Cancel (или иконка крестика).

✅ **Ожидается:** строка исчезает, в стакане уровень $60000 возвращается к "чужой" ликвидности.

📸 `sprint_1_order_cancelled.png`

### Шаг 10: Market ордер (опционально — РЕАЛЬНАЯ позиция на demo!)

Если хочешь увидеть полный цикл с позицией:
- Order Form → BTCUSDT → Buy → Market → Quantity 0.001 → Submit
- Должна открыться позиция, видна в Account Manager
- Через Order Form → Sell → Market → 0.001 → закрыть

Это создаст 2 ордера + 1 позицию в логе. Если всё прошло — adapter полностью функционален.

📸 `sprint_1_position_opened.png` + `sprint_1_position_closed.png`

### Шаг 11: Reload страницы

F5 на http://localhost:4200.

✅ **Ожидается:** страница загружается без редиректа на SSO, токен из localStorage переиспользуется. Дашборд восстанавливает виджеты.

🚨 Если редирект — наш main.ts shim не дотянул. Очисти localStorage и попробуй ещё раз; если упорно — проблема в adapter не отвечает на `/auth/actions/refresh`.

---

## 4. Чек-лист скриншотов (положить в `mm-bot/screenshots/`)

- [ ] `sprint_1_astras_main.png` — главная Astras после загрузки
- [ ] `sprint_1_watchlist.png` — Watchlist с BTCUSDT
- [ ] `sprint_1_btcusdt_chart.png` — свечной график
- [ ] `sprint_1_orderbook.png` — стакан с live обновлениями
- [ ] `sprint_1_account_manager.png` — баланс
- [ ] `sprint_1_my_order_placed.png` — ордер в Working Orders
- [ ] `sprint_1_my_order_in_dom.png` — ордер в стакане
- [ ] `sprint_1_order_cancelled.png` — после отмены
- [ ] (опц) `sprint_1_position_opened.png` / `sprint_1_position_closed.png`

Минимум 4 скриншота для отчёта архитектору: main, chart, orderbook, order_placed.

---

## 5. Если что-то пошло не так

| Симптом | Где смотреть | Типовая причина |
|---|---|---|
| Astras редиректит на login-dev.alor.ru | DevTools Network → есть ли POST /auth/actions/refresh? | adapter не отвечает; либо `environment.ts` не обновился (нужна перезагрузка ng serve) |
| Все запросы → CORS error | DevTools Console | в adapter `.env` поставь `CORS_ORIGIN=http://localhost:4200` (уже стоит) |
| Watchlist пустой / "instrument not found" | adapter лог | Bybit возвращает 404 — символ не из категории `linear`. Поменяй `BYBIT_DEFAULT_CATEGORY=spot` в `.env` adapter и перезапусти. |
| WS подписки молчат | adapter лог | проверь Bybit env: `BYBIT_ENV=demo` для demo trading, `=testnet` для отдельного testnet env |
| Order rejected с "qty error" | adapter лог + curl Bybit minOrderQty | Bybit V5 имеет minOrderQty (для BTCUSDT-linear обычно 0.001). Меньше — отказ. |
| Order rejected "insufficient balance" | Bybit Demo UI | дозапросить demo funds |
| Реактивные обновления не идут | adapter лог "data WS client connected"? | WS соединение от Astras не дошло; проверь `environment.wsUrl=ws://localhost:3000/ws` |

Если совсем застрял — скопируй последние 30 строк adapter лога + что в DevTools Console + что в Network для последнего запроса, и пришли архитектору.

---

## 6. Что НЕ работает в Sprint 1 (это OK)

- ✘ Stop-orders / Take Profit / Stop Loss — Bybit V5 имеет, но adapter в Sprint 1 не translate'ит
- ✘ Multi-account — портфель один, `bybit_demo`
- ✘ Dividends / payments / arbitrage widgets — не имеют смысла для crypto
- ✘ News / AI Chat — не подключены
- ✘ Some advanced charts (Spectra, IceBerg orders) — Bybit нет такого концепта
- ✘ ALOR-стиль auth с проверкой ролей и permissions — мок

Всё это в дорожке Sprint 2-3.
