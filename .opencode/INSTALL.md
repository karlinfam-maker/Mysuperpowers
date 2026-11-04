# Установка Superpowers для OpenCode

## Предварительные требования

- Установлен [OpenCode.ai](https://opencode.ai).

## Установка

Для OpenCode V2 требуется версия 2.0.4 или новее. Конфигурации ниже указывают на оригинальный репозиторий `obra/superpowers`, а не автоматически на русскую копию Валерия.

### OpenCode V1

Используй существующую конфигурацию плагина V1:

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git"]
}
```

### OpenCode V2 — 2.0.4 или новее

Используй конфигурацию плагина V2:

```json
{
  "plugins": ["superpowers@git+https://github.com/obra/superpowers.git"]
}
```

Для локальной установки V2 укажи каталог репозитория с `index.js`. OpenCode 2.0.4 и 2.0.7 отклоняют прямой путь к JavaScript-файлу в конфигурации. Найденные символические ссылки на плагин поддерживаются.

Перезапусти OpenCode. В V2 используется команда `opencode`; `opencode2` может быть доступна как псевдоним. Плагин устанавливается через менеджер OpenCode и регистрирует все навыки.

Проверь запросом: «Расскажи о своих superpowers».

OpenCode использует собственную установку плагинов. Если также используешь Claude Code, Codex или другую среду, Superpowers устанавливается отдельно для каждой.

## Переход со старой установки через символические ссылки

Если ранее Superpowers был установлен через `git clone` и символические ссылки, авторы оригинала предлагают удалить старую установку приведёнными ниже командами. Перед удалением проверь файлы и получи необходимые разрешения; команда удаления клонированного репозитория необязательна.

```bash
# Remove old symlinks
rm -f ~/.config/opencode/plugins/superpowers.js
rm -rf ~/.config/opencode/skills/superpowers

# Optionally remove the cloned repo
rm -rf ~/.config/opencode/superpowers

# Remove skills.paths from opencode.json if you added one for superpowers
```

Затем следуй шагам установки выше.

## Использование

Используй встроенный инструмент OpenCode `skill`:

```
use skill tool to list skills
use skill tool to load brainstorming
```

## Обновление

OpenCode устанавливает Superpowers через спецификацию пакета на основе git. Некоторые версии OpenCode и Bun фиксируют разрешённую git-зависимость в файле блокировки или кеше, поэтому перезапуск может не получить новый коммит Superpowers. Если обновления не появились, очисти кеш пакетов OpenCode или переустанови плагин.

Чтобы закрепить конкретную версию, добавь тег или коммит к спецификации. Форма одинакова для ключа `plugin` в V1 и `plugins` в V2:

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git#v7.0.2"]
}
```

Для V2 закрепляй `v6.4.1` или новее; `v6.3.0` и более ранние версии загружаются только в V1.

## Устранение проблем

### Плагин не загружается

1. Проверь журнал. V1: `opencode run --print-logs "hello" 2>&1 | grep -i superpowers`. В V2 плагины загружает фоновый сервер, поэтому добавь `--standalone`: `opencode run --standalone --print-logs "hello" 2>&1 | grep -i superpowers`, либо изучи `~/.local/share/opencode/log/opencode.log` с фильтром `role=server`.
2. Проверь строку плагина в `opencode.json`.
3. Убедись, что используешь актуальную версию OpenCode.

### Проблемы установки в Windows

У некоторых сборок OpenCode для Windows есть проблемы установки пакетов на основе git: пути кеша для URL `git+https` и невозможность Bun найти `git.exe`, хотя он работает в обычном терминале. Если OpenCode не устанавливает плагин, авторы предлагают использовать системный npm и затем указать локальный пакет:

```powershell
npm install superpowers@git+https://github.com/obra/superpowers.git --prefix "$HOME\.config\opencode"
```

Затем укажи абсолютный путь установленного пакета в `opencode.json` согласно своей версии OpenCode. OpenCode не раскрывает `~`: запись `~/...` воспринимается как имя пакета, а не локальный каталог.

**V1:**

```json
{
  "plugin": ["C:\\Users\\<you>\\.config\\opencode\\node_modules\\superpowers"]
}
```

**V2, 2.0.4 или новее:**

```json
{
  "plugins": ["C:\\Users\\<you>\\.config\\opencode\\node_modules\\superpowers"]
}
```

### Навыки не найдены

1. Выведи найденные навыки через инструмент `skill`.
2. Проверь загрузку плагина, как описано выше.

### Соответствие инструментов

Навыки описывают действия: «создать задачу», «привлечь субагента», «прочитать файл». Плагин передаёт соответствия для конкретной версии OpenCode.

**V1 — `opencode` 1.x:**
- Создать задачу или отметить её выполненной → `todowrite`.
- Шаблон `Subagent (general-purpose):` → инструмент `task` с `subagent_type: "general"` или `"explore"` для изучения кода.
- Вызвать навык → встроенный инструмент OpenCode `skill`.
- Прочитать файл → `read`.
- Создать, изменить или удалить файл → `apply_patch`.
- Выполнить команду оболочки → `bash`.
- Искать текст или файлы по имени → `grep`, `glob`.
- Получить URL → `webfetch`.

**V2 — `opencode` 2.0.4 или новее; `opencode2` может быть псевдонимом:**
- Создать задачу → инструмента задач нет; веди план в Markdown.
- Шаблон `Subagent (general-purpose):` → `subagent` с `agent: "general"` или `"explore"`; для продолжения прежнего субагента передавай `sessionID`.
- Вызвать навык → встроенный `skill`.
- Прочитать файл → `read`.
- Создать, изменить или удалить файлы → при наличии используй `patch` с `patchText`; иначе `write` для создания и перезаписи, `edit` для точечных изменений и `shell` для удаления.
- Выполнить команду оболочки → `shell` с параметрами `command`, `workdir`, `timeout`, `background`.
- Искать текст или файлы по имени → `grep`, `glob`.
- Получить URL → `webfetch`.
- Искать в интернете → `websearch`.

Используй делегирование и удаление только в пределах инструкций пользователя и среды.

## Помощь

- Сообщить об ошибке: https://github.com/obra/superpowers/issues
- Полная документация: https://github.com/obra/superpowers/blob/main/docs/README.opencode.md
