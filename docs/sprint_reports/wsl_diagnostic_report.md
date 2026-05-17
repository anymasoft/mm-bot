# Отчёт диагностики WSL2

## Состояние ДО

- **Windows версия:** 10.0.19045 (build 19045) — Корпоративная
- **Виртуализация в BIOS:** Enabled (гипервизор обнаружен системой)
- **RAM:** 15.42 GB
- **WSL был установлен:** YES (WSL kernel 2.6.3.0)
- **WSL версия:** 2 (по умолчанию)
- **Установленные дистрибутивы:** Ubuntu-24.04 был зарегистрирован, но в **повреждённом** состоянии: VHDX-файл `ext4.vhdx` отсутствовал на диске.
- **Canonical Store packages:** установлены (Ubuntu, Ubuntu 22.04 LTS, Ubuntu 24.04 LTS), но все LocalState папки были пустыми

## Найденные проблемы

### Проблема 1: WSL не запускался — `0x800705aa Insufficient system resources`

Hyper-V не мог выделить память для VM. Из 15.42 GB RAM свободно было только ~3 GB (заняты PyCharm 1.8 GB, Claude 1.5 GB, Opera 1.9 GB, прочее).

WSL2 по умолчанию пытается захватить до 50% RAM хоста (~7.7 GB), что превышало доступное.

### Проблема 2: VHDX-файл Ubuntu-24.04 отсутствовал

`C:\Users\User\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu24.04LTS_79rhkp1fndgsc\LocalState\ext4.vhdx` не существовал, хотя реестр в `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\{2bd4f362-...}` содержал валидную регистрацию.

Причина неизвестна (мог быть удалён вручную, или утилитой очистки, или после Windows update).

## Действия

1. **Создан `C:\Users\User\.wslconfig`** с лимитами для систем <16 GB RAM:
   ```ini
   [wsl2]
   memory=4GB
   processors=2
   swap=2GB
   ```
   Это решило `0x800705aa`.

2. **Развернут broken Ubuntu-24.04:** `wsl --unregister Ubuntu-24.04`.

3. **Свежая установка Ubuntu-24.04:** `wsl --install -d Ubuntu-24.04 --no-launch`.

4. **Через root mode создан non-interactive пользователь:**
   - Команда: `useradd -m -s /bin/bash -G sudo dev && echo 'dev:111' | chpasswd`
   - UNIX user: `dev` (uid=1000)
   - Пароль: `111` (по решению пользователя — для локального dev WSL без сетевого доступа)
   - Добавлено `/etc/sudoers.d/90-dev` с `dev ALL=(ALL) NOPASSWD:ALL` → passwordless sudo

5. **Настроен `/etc/wsl.conf`:**
   ```ini
   [user]
   default=dev
   [boot]
   systemd=true
   ```

6. **Перезапущена Ubuntu** через `wsl --terminate Ubuntu-24.04`, чтобы `/etc/wsl.conf` вступил в силу.

7. **Установлены apt-зависимости:** `build-essential`, `git`, `curl`, `wget`, `ca-certificates`.

8. **Установлен Miniconda 26.3.2** в `~/miniconda3`, выполнен `conda init bash`, отключено `auto_activate_base`.

## Состояние ПОСЛЕ

| Параметр | Значение |
|---------|---------|
| WSL2 рабочий | YES |
| Дистрибутив | Ubuntu 24.04.4 LTS |
| WSL kernel | 6.6.87.2-microsoft-standard-WSL2 |
| WSL version | 2.6.3.0 |
| UNIX user | dev (uid=1000) |
| Sudo | NOPASSWD enabled |
| Свободно места в VHDX | 955 GB из 1007 GB |
| Сеть | работает (ping 8.8.8.8: 43 ms, github.com: 75 ms) |
| `.wslconfig` | применён (memory=4GB, processors=2, swap=2GB) |
| Miniconda | 26.3.2 (`~/miniconda3`) |
| Системные пакеты | build-essential, git 2.43.0, curl, wget, ca-certificates |

## Готовность к Спринту 0

**YES** — можно переходить к основному промпту Спринта 0 (установка Hummingbot и Quantower).

Все pre-checks выполнены. Сетевая связность, дисковое пространство, RAM-лимиты и conda — в порядке.
