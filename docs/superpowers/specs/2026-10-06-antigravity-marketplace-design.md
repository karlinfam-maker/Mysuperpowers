# Плагин для Antigravity Marketplace

## Цель

Разместить Superpowers в магазине плагинов Google Antigravity Marketplace в рамках партнёрства с Google. Для этого необходимы собственный манифест плагина Antigravity с полями представления в магазине, логотип и начальная загрузка сеанса, работающая при установке нативного плагина.

Источники: «Antigravity Plugin Marketplace Publishing Guide» — PDF от Google — и приведённые ниже проверки `agy` 1.3.1.

## Текущее состояние на agy 1.3.1

- `agy plugin install https://github.com/obra/superpowers` выполняется успешно, но только через резервный механизм расширений Gemini: `agy plugin list` показывает `"source": "gemini-cli"`. Начальная загрузка использует строки с `@` в `GEMINI.md`, которые модель воспринимает как подсказки и открывает через `view_file`. Приёмочный тест на этом пути проходит.
- agy копирует `hooks/hooks.json` в формате Claude в корень установки под именем `hooks.json` и при каждом сеансе не может его разобрать: `invalid hook "hooks": command hook must specify 'command'`.
- `agy plugin validate .` в репозитории завершается ошибкой `missing plugin.json`.

## Результаты исследований agy 1.3.1

Для каждой проверки устанавливался временный плагин, запускался `agy -p`, затем плагин удалялся.

1. События хуков agy: `PreToolUse`, `PostToolUse`, `PreInvocation`, `PostInvocation` и `Stop`. `SessionStart` отсутствует. Встроенная документация agy использует именованные хуки верхнего уровня (`{"<name>": {"PreToolUse": [...]}}`), что отличается от примера `{"hooks": {...}}` в PDF.
2. `rules/AGENTS.md` плагина загружается как постоянно действующее правило в каждом сеансе.
3. В правиле путь с `@`, относительный к файлу правила, преобразуется в абсолютный путь установки: `@../skills/x/SKILL.md` становится `@/Users/<u>/.gemini/config/plugins/<plugin>/skills/x/SKILL.md`. Содержимое по ссылке не вставляется автоматически. `${PLUGIN_ROOT}` в правилах не подставляется. Путь, который нельзя разрешить относительно файла правила, остаётся без изменений.
4. При наличии `.antigravity-plugin/plugin.json` agy устанавливает плагин с `"source": "antigravity"`, находит все 15 навыков и пропускает хуки, поскольку корневой `hooks.json` отсутствует; предупреждение разбора исчезает.
5. Подготовленная копия репозитория с нативным манифестом и однострочным `rules/AGENTS.md` (`@../skills/using-superpowers/SKILL.md`) прошла приёмочный тест: модель прочитала `using-superpowers`, затем `antigravity-tools.md`, затем `brainstorming` и ответила «Using superpowers:brainstorming…» с уточняющим вопросом. Код не создавался.
6. Корневой `AGENTS.md` репозитория с правилами участников копируется при установке, но не загружается как правило. Загружается только `rules/AGENTS.md`.

## Решение

### 1. Нативный манифест: `.antigravity-plugin/plugin.json`

Руководство допускает расположение манифеста в `.antigravity-plugin/plugin.json`, что согласуется с другими скрытыми каталогами сред. Поля:

| Поле | Значение |
|---|---|
| `name` | `superpowers` |
| `displayName` | `Superpowers` |
| `version` | Текущая версия выпуска, поддерживаемая через `.version-bump.json` |
| `description` | `Make your coding agent a better engineer` — текст Jesse; короче рекомендованных руководством 120–160 символов, не более 160 |
| `logo` | `assets/antigravity-logo.png` |
| `suggestedPrompts` | `I've got an idea for something I'd like to build`, `Let's figure out why this broke` — текст Jesse |
| `category` | `Developer Tools` |
| `keywords` | Строчные буквы, соответствуют ключевым словам в `.claude-plugin/plugin.json` |
| `author` | `{ "name": "Jesse Vincent", "email": "jesse@fsck.com" }`, как в `.claude-plugin/plugin.json` |
| `homepage`, `repository` | `https://github.com/obra/superpowers` |
| `license` | `MIT` |

Поля `skills` и `mcpServers` не нужны: значения по умолчанию — `skills/` и отсутствие конфигурации MCP — соответствуют задаче; проверка 4 подтвердила обнаружение всех навыков.

### 2. Начальная загрузка: обнаружение навыка без дополнительных файлов

agy показывает описания установленных навыков; формулировка `using-superpowers` «Use when starting any conversation» побуждает модель загрузить его. Плагин не поставляет `rules/` и `hooks.json`.

Это заменило первоначальный вариант с однострочной ссылкой в `rules/AGENTS.md`: итоговая проверка показала, что Cursor тоже загружает все `rules/*.md`, поставляемые плагином из того же корня репозитория. На agy 1.3.1 исследованы и отклонены альтернативы:

- Хук `PreInvocation` запускается перед каждым вызовом модели, а `hooks.json` должен лежать в корне плагина. `ephemeralMessage` исчезает при следующем вызове; `userMessage` сохраняется, а условие `invocationNum == 0` и `initialNumSteps == 1` добавляет его ровно один раз за разговор. Тем не менее agy всё равно запускает процесс хука при каждом вызове.
- Ни одно поле манифеста не позволяет перенести `hooks.json` или `rules/`.

Без файла начальной загрузки прошли все 12 проверок: для запросов «Let's make a react todo list» и «add a settings page» — по три запуска — brainstorming загружался до написания кода; «this test is failing, can you fix it?» — три запуска — вызывал systematic-debugging до правок; запрос списка задач React во втором ходе после несвязанного первого — ещё три запуска — вызывал brainstorming. Модель: Gemini 3.8 Flash. Риск: вызов зависит от соблюдения моделью описания навыка; если это не сработает, запасной вариант — хук, действующий один раз за разговор.

### 3. Логотип: `assets/antigravity-logo.png`

PNG 512×512 с прозрачным фоном. Белый квадрат со скруглёнными углами — отступ 31 пиксель, радиус углов 100 — содержит знак из `assets/superpowers-small.svg` цветом `#1a1a1a`, отмасштабированный примерно до 70% ширины квадрата и расположенный по центру. Рамки нет; в светлой теме знак выглядит просто как знак на белом фоне, что допустимо.

`scripts/render-antigravity-logo.sh` собирает SVG на основе `superpowers-small.svg` и преобразует его в растровое изображение с помощью `rsvg-convert`. Только этот скрипт пересоздаёт PNG; он содержит справку и выдаёт понятную ошибку при отсутствии `rsvg-convert`.

### 4. Обновление версии

Добавить `{ "path": ".antigravity-plugin/plugin.json", "field": "version" }` в `.version-bump.json`.

### 5. Синхронизация Codex

Добавить `/.antigravity-plugin/` и `/assets/antigravity-logo.png` в `EXCLUDES` скрипта `scripts/sync-to-codex-plugin.sh` и покрыть их проверками в `tests/codex-plugin-sync/test-sync-to-codex-plugin.sh`.

### 6. README

Команда установки Antigravity остаётся `agy plugin install https://github.com/obra/superpowers`. Текст о запуске хука начала сеанса заменить описанием обнаружения навыков. Способ установки из Marketplace добавить после его появления; до этого ничего о нём не утверждать.

### 7. Тесты: `tests/antigravity/`

- `test-plugin-manifest.sh` — безопасен для CI, по образцу `tests/kimi/test-plugin-manifest.sh`:
  - манифест разбирается, `name` соответствует шаблону kebab-case и равно `superpowers`;
  - каждое обязательное для Marketplace поле присутствует и не пусто: `name`, `description`, `displayName`, `logo`, `suggestedPrompts` — от одной до трёх непустых строк, — `version`, `author`;
  - `description` не превышает 160 символов;
  - `version` совпадает с версией в `.claude-plugin/plugin.json`;
  - файл `logo` существует, является квадратным PNG размером не менее 128×128;
  - `.version-bump.json` содержит манифест;
  - описание `using-superpowers` по-прежнему содержит «Use when starting any conversation», на что опирается начальная загрузка;
  - в корне нет `plugin.json`, `hooks.json` или `rules/`.
- Когда `agy` доступен в `PATH`, дополнительно выполнить `agy plugin validate` в репозитории и потребовать результат `[ok]` с обработанными навыками.
- Обновить комментарий в заголовке `test-antigravity-tools.sh`, где всё ещё говорится, что agy запускает хук SessionStart.

Живая приёмочная проверка вне CI: установить дерево ветки в agy, не менее трёх раз запустить «Let's make a react todo list» в чистых рабочих папках и каждый раз убедиться, что brainstorming запускается до написания кода. После проверки удалить плагин.

### 8. Руководство по переносу: отдельный коммит

`docs/porting-to-a-new-harness.md` описывает `.antigravity-plugin/install.sh` и генерируемый `ANTIGRAVITY.md`, которых не существует. Исправить отдельным коммитом:

- В таблице маршрутизации указать, что Antigravity использует доступный индекс навыков.
- В разделе об отсутствии инструмента `Skill` заменить совет о `contextFileName` для Antigravity на начальную загрузку через индекс навыков и зафиксировать выводы о хуках и правилах: нет события начала сеанса, `PreInvocation` выполняется при каждом вызове, в хуках нет `${PLUGIN_ROOT}`, общие корни плагинов приводят к загрузке `rules/` в Cursor.
- В таблице распространения указать установку Antigravity по git URL (`agy plugin install <url>`) и размещение в Marketplace.
- В разделе удаления установщиков убрать пример `install.sh` / `ANTIGRAVITY.md`.
- Добавить отсутствующую строку Antigravity в таблицу сред: манифест, начальная загрузка, сопоставление инструментов, тесты и установка.

## За пределами задачи

- Механизм отправки в Marketplace: руководство его не описывает; он осуществляется через контакт Jesse в Google.
- Antigravity 2.0 и IDE: в данной среде они не установлены и не проверялись; README не делает о них утверждений.
- Открытый PR #2350, копирующий `using-superpowers` в сгенерированное правило: Jesse решит, как ответить после включения этого изменения; автор подготовит проект ответа.
- Отсутствие `.hermes-plugin/` и `.muse-plugin/` в исключениях синхронизации Codex: несвязанная проблема, отмечена для отдельного исправления.
