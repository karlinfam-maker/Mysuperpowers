# Случай: <session-id>

Workspace: ~/.superpowers/diagnosing-superpowers/<session-id>/
Created: <ISO timestamp>

## Постановка проблемы — согласована с пользователем

<Один абзац: сессия или сессии, диапазон ходов, если известен, ожидаемое и фактическое поведение, важный показатель: время, токены, повторы или конкретное неожиданное действие.>

Goal is a superpowers bug report: yes | no

## Сессии

| Role | Session id | Absolute path | Lines | Bytes | Longest line (bytes) | First prompt (first 120 chars) | First timestamp |
|---|---|---|---|---|---|---|---|
| main | | | | | | | |
| subagent | | | | | | | |

Отклонённые кандидаты: <id — путь — причина> или "none".

Session still running at read time: yes | no (mtime <ISO>, lines <N>)

## Окружение

- OS: <название и версия>
- Harness: <название> <версия>
- Models seen: <id модели — место: main / id субагента>
- Superpowers install root: <путь>; version <x.y.z>; git sha <sha or "not a checkout">
- Прочитанные или добавленные в сессию файлы навыков:

| Skill / source path | sha1 or unavailable | Provenance | Supporting location |
|---|---|---|---|

Отмечай сведения об окружении и навыках как историческое доказательство, непроверенный снимок, текущее наблюдение или неизвестно. До признания исторических сведений недоступными проверь переданные заметки об источниках, архивы и сохранённые тексты навыков. Отсутствие исходного пути не отменяет сохранённую копию. Текущие версии и время изменения не доказывают исторические версии; один сохранённый текст не удостоверяет всю установку.

- Other plugins / extensions / MCP servers configured: <список или "none found">
- Instruction files present (paths only): <список>

## Правила безопасности контекста для всех читателей

- До чтения каждого указанного файла соблюдай `references/context-safety.md`.
- В записи субагента "user" означает родительского агента.

## Выявленные источники и смысл записей

- Sources consulted: <абсолютный путь, инструмент, справка или документация>
- Extraction commands or queries: <ограниченные команды или запросы для каждого источника>
- Target identity evidence: <id сессии, рабочий каталог, время, совпадающее содержимое и расположение подтверждений>
- Associated sessions: <id сессии, связь и расположение подтверждений либо "none found">
- Human messages: <форма записи и подтверждение её значения>
- Injected messages and parent dispatches: <форма записи и подтверждение её значения>
- Assistant messages: <форма записи и подтверждение её значения>
- Tool calls and results: <формы записей, их сопоставление и подтверждения значений>
- Usage counters: <поля, приростные или накопительные значения, единицы, доказательства либо "unavailable">
- Timing: <поля, единицы, границы событий и доказательства либо "unavailable">
- Other relevant records: <модели, версии, сжатия контекста или другие сведения и доказательства>
- Unresolved information: <отсутствующие, недоступные, неоднозначные сведения либо "none">
