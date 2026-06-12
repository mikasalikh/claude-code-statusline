# claude-code-statusline

> Модель · git-ветка · занятость контекста · потраченные токены · лимиты — аккуратная цветная статус-строка для [Claude Code](https://claude.com/claude-code).

![demo](assets/demo.svg)

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell: bash](https://img.shields.io/badge/shell-bash-89e051.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-lightgrey.svg)

[English version →](README.md)

Один лёгкий bash-скрипт. Без демонов, без Node, без обращений к API — всё берётся из JSON,
который Claude Code и так передаёт хуку статус-строки, плюс транскрипт сессии на диске.

## Что показывает

| Сегмент | Пример | Смысл |
|---|---|---|
| Модель | `Fable 5` | Модель, обслуживающая сессию |
| Ветка | `⎇ develop*` | Git-ветка в рабочем каталоге сессии; `*` = незакоммиченные изменения; в detached HEAD — короткий хеш |
| Контекст | `ctx 41.9k/1M · left 958.1k` | Контекстное окно: занято / всего и сколько токенов осталось |
| Spent | `spent 166.2k` | «Новые» токены за сессию: вход (без кэш-чтений) + выход |
| 5-часовой лимит | `5h 2%→01:10` | Скользящий 5-часовой лимит: использовано % и локальное время сброса |
| Недельный лимит | `7d 52%→Wed 05:00` | Недельный лимит: использовано % и день/время сброса |

Сегменты контекста и лимитов окрашены как светофор: **зелёный** < 60%, **жёлтый** 60–84%,
**красный** ≥ 85% — то, что требует внимания, бросается в глаза само.

Деградация мягкая: чего ваша версия Claude Code или тип логина не отдаёт — просто исчезает
из строки, ничего не ломая.

## Установка

Одной командой:

```bash
curl -fsSL https://raw.githubusercontent.com/mikasalikh/claude-code-statusline/main/install.sh | bash
```

Из исходников:

```bash
git clone https://github.com/mikasalikh/claude-code-statusline.git
cd claude-code-statusline && ./install.sh
```

Инсталлер кладёт `statusline.sh` в `~/.claude/statusline.sh` и подключает его в
`~/.claude/settings.json` (сначала пишется бэкап `settings.json.bak`; остальные настройки
не трогаются). Рестарт не нужен — строка появится при следующем обновлении диалога.

Ручная установка, если хочется видеть каждый шаг:

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/mikasalikh/claude-code-statusline/main/statusline.sh \
  -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

…и добавить в `~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
```

## Требования

- **bash**, **jq**, **awk** — скорее всего не хватает только `jq`
  (`brew install jq` / `apt install jq`)
- **git** — опционально, только для сегмента ветки
- **Claude Code ≥ 2.1.x** для полного набора сегментов (см. совместимость)

## Как это работает

Claude Code вызывает команду `statusLine` при каждом обновлении диалога (не чаще раза в
300 мс) и передаёт JSON на stdin. Скрипт читает:

- `model.display_name` — сегмент модели
- `workspace.current_dir` — где спрашивать git про ветку
- `context_window.*` — размер окна, занятые токены, процент
- `rate_limits.five_hour` / `rate_limits.seven_day` — % использования и время сброса
- `transcript_path` — транскрипт сессии (JSONL); счётчик **spent** суммирует по нему
  `input + cache_creation + output`. Кэш-*чтения* исключены сознательно: они стоят ~10%
  обычной цены и раздули бы цифру примерно в десять раз.

Все поля достаются одним проходом `jq` (`@sh`-квотирование, безопасный `eval`) — скрипт
остаётся быстрым.

## Совместимость

| Окружение | Статус |
|---|---|
| macOS (BSD `date`) | ✅ |
| Linux (GNU `date`) | ✅ |
| Windows через WSL / Git Bash | ✅ |
| Claude Code ≥ 2.1.x | все сегменты |
| Старые Claude Code | модель · ветка · spent (в payload нет `context_window` / `rate_limits`) |
| Логин по подписке (Pro / Max) | все сегменты |
| Логин по API-ключу | сегменты лимитов скрыты (их нет в payload) |

## Настройка под себя

Это bash-скрипт на ~100 строк — правьте смело, в этом и смысл.

- **Отключить цвета:** стандартная переменная [`NO_COLOR`](https://no-color.org).
- **Пороги:** границы зелёный/жёлтый/красный — в `pct_color()`.
- **Переставить / убрать сегменты:** строка собирается в конце скрипта, по одному блоку
  `line="$line$sep..."` на сегмент — удаляйте и меняйте порядок свободно.
- **Формат времени:** вызовы `fmt_ts` используют `%H:%M` (5h) и `%a %H:%M` (7d).

Чтобы увидеть, что реально шлёт ваша версия Claude Code (состав полей меняется между
релизами), задампите payload и проектируйте от него:

```bash
# добавить в начало statusline.sh, посмотреть файл, убрать
printf '%s' "$input" > /tmp/cc-payload.json
```

## Если что-то не так

- **Строки нет вообще** — проверьте `statusLine` в `~/.claude/settings.json`, `chmod +x`
  на скрипте и запустите вручную: `echo '{}' | ~/.claude/statusline.sh` (должно напечатать хотя бы `?`).
- **Нет сегментов лимитов** — вы вошли по API-ключу, либо Claude Code старее поля
  `rate_limits` (`claude --version`).
- **`spent` тормозит на очень длинных сессиях** — он сканирует весь JSONL-транскрипт;
  если мешает — удалите блок `spent`.
- **Время сброса выглядит неверно** — метки рендерятся в вашей локальной таймзоне через
  `date`; скрипт пробует GNU-синтаксис, затем BSD.

## Удаление

```bash
./install.sh --uninstall
# или без клона:
curl -fsSL https://raw.githubusercontent.com/mikasalikh/claude-code-statusline/main/install.sh | bash -s -- --uninstall
```

Убирает ключ `statusLine` из настроек (бэкап остаётся) и удаляет скрипт.

## Лицензия

[MIT](LICENSE)
