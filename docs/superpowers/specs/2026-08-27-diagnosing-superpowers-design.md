# Диагностика сеансов Superpowers — проект

**Дата:** 2026-08-27
**Статус:** утверждено Jesse в сеансе; спецификация ожидает проверки
**Ветка:** `diagnosing-superpowers` от `dev`

## Цель

Основной навык `diagnosing-superpowers`, который пользователь вызывает, если сеанс superpowers прошёл неправильно. Он помогает уточнить проблему, изучает стенограммы сеансов на диске и сообщает, что произошло, с доказательствами. По запросу навык экспортирует очищенный пакет, по которому удалённый агент может решить, нуждается ли сам superpowers в изменении; также он может найти другие локальные сеансы с таким же поведением.

Навык представляет отчёт; он не ставит диагноз самому superpowers. Предположения об ошибках superpowers и предложения изменений относятся к работе удалённого специалиста по разбору; если пользователя это интересует, навык так и объясняет.

## Границы, согласованные с Jesse

- **Первая версия содержит только текстовые инструкции:** поставляемых скриптов нет. Работу выполняет модель, активно используя субагентов. Детерминированные инструменты можно добавить позже, если текстовая версия подтвердит подход.
- **Поддержка сред:** подробные справочники на уровне полей есть только для форматов, проверенных по файлам на диске, — Claude Code и Codex. Для остальных описана процедура обнаружения. Предполагается, что работающая среда знает место хранения собственных сеансов; навык использует это знание и прямо сообщает, что смог и не смог прочитать. Форматы не выдумываются.
- **Сначала уточнение проблемы:** навык начинает с вопроса о том, что пользователь хочет исследовать, и работает с ним до конкретной формулировки. Дальнейший анализ служит этой формулировке.
- **Качество оценивается по доказательствам процесса:** по согласованным в сеансе проекту, плану, критериям приёмки и файлам, а также по тому, что подтверждает стенограмма: тесты, проверки за утверждениями, соответствие коммитов заявлениям, обработка замечаний ревью. Это не ревью итогового diff.
- **Уровень обезличивания выбирает пользователь.** Навык спрашивает о нём и поясняет, что при сообщении об ошибке superpowers больше информации увеличивает шансы на помощь.
- **Версия superpowers фиксируется точно:** фактически загруженный корень установки, версия, SHA git для клона и SHA-1 каждого файла навыка, который сеанс прочитал или получил в контекст.
- **Срабатывание навыков анализируется отдельно:** что и когда вызвано, в ответ на какой запрос; где описание условия подходило, но навык не сработал или сработал поздно.

## Структура навыка

Исходная схема имён файлов и каталогов сохранена:

```
skills/diagnosing-superpowers/
  SKILL.md
  references/
    claude-code-sessions.md
    codex-sessions.md
    other-harnesses.md
    context-safety.md
    github-issues.md
  prompts/
    analyst-common.md
    skill-timeline.md
    plan-adherence.md
    repeated-work.md
    stumbles.md
    quality-evidence.md
    request-conflicts.md
    cost-and-time.md
    scrub.md
    scrub-audit.md
    similar-session.md
  templates/
    case.md
    report.md
    bundle-README.md
    issue.md
tests/diagnosing-superpowers/
  test-skill-structure.sh
```

Структура аналогична `subagent-driven-development`: компактный SKILL.md содержит процесс, жёсткие правила и Red Flags; каждому виду работы субагента соответствует файл запроса, чтобы он читал ровно один; справочники загружаются только для соответствующей среды.

### Frontmatter SKILL.md

Исходный текст описания сохранён как пример формата:

```
name: diagnosing-superpowers
description: Use when a superpowers session went wrong and the user wants
  to know why — repeated work, ignored plans, stumbles, poor results, a
  skill that didn't fire — or wants to build a bug report for the
  superpowers maintainers, for the current session or a past one
  identified by id or path, on any harness.
```

В описании только условия запуска, без пересказа процесса; см. Skill Discovery Optimization в `writing-skills`. SKILL.md остаётся короче 1000 слов — это проверяет структурный тест; процессные навыки репозитория содержат от 350 до 4800 слов, а здесь семь шагов. В нём размещаются процесс, жёсткие правила, Red Flags и ссылки; остальное находится в запросах, справочниках и шаблонах.

## Процесс

При работе навыка каждый шаг становится пунктом списка задач.

### 1. Уточнение проблемы

Задавать по одному вопросу, пока проблема не станет конкретной: какие сеансы, чего ожидал пользователь, что произошло и где он впервые заметил расхождение. Жалобы часто формулируются расплывчато: «слишком долго», «почему он сделал лишнюю работу?», «почему так дорого?», «что он вообще делает?». Уточнение превращает их в формулировку с указанием сеанса, диапазона ходов при его известности и наблюдаемого показателя: времени, токенов, повторных или неожиданных действий. Согласованная формулировка записывается в файл дела. Если цель пользователя — сообщение об ошибке superpowers, это отмечается сразу; на этапе экспорта навык один раз сообщает, что очищенный пакет доступен по запросу.

### 2. Поиск

Определить точные пути на диске для каждого названного пользователем сеанса.

- **Текущий сеанс:** модель использует знание своей среды о хранении стенограмм. Для Claude Code и Codex справочник описывает структуру, выбор текущего сеанса — последний изменённый файл для текущего каталога с подтверждением по первому сообщению пользователя, — расположение стенограмм субагентов и поля модели, версии среды, атрибуции навыка и плагина, сжатия и ошибок. Для остальных `other-harnesses.md` предписывает найти хранилище, сообщить результат и уверенность, а если найти не удалось — прямо сказать об этом и спросить путь.
- **Прошедший сеанс:** пользователь указывает ID, путь, дату и описание или «тот, где произошло X». Нужно определить точные пути и подтвердить с пользователем идентичность, показав первое сообщение и временную метку до анализа.
- **Субагенты:** перечислить все стенограммы субагентов и боковых ветвей, относящиеся к сеансу, и рассматривать их как его часть.
- **Действующий сеанс:** вопрос «что он делает сейчас» может относиться к ещё выполняющемуся сеансу и записываемому файлу. Прочитать доступное, зафиксировать число строк и время изменения на момент чтения и отметить в охвате, что сеанс продолжался.
- **Идентичность системы и superpowers:** записать ОС и версию; среду и версию; все обнаруженные ID моделей; фактический корень установки superpowers, поскольку кеш маркетплейса и рабочая копия разработки могут различаться; версию из манифеста и SHA git для клона; SHA-1 каждого файла навыка, который сеанс прочитал или получил в контекст. Хеш вычисляется по текущему состоянию файла; если файл изменён позже сеанса, это отмечается, поскольку хеш может не совпадать с увиденным тогда. Также записать остальные настроенные плагины, расширения и MCP-серверы и перечислить пути присутствующих файлов инструкций — CLAUDE.md, AGENTS.md, GEMINI.md и аналогичных — без содержимого.
- **Отчёт обо всём просмотренном:** каждый ID и путь сеанса, включая отклонённых кандидатов с причиной.

Рабочая папка — `~/.superpowers/diagnosing-superpowers/<session-id>/` в домашнем каталоге, поэтому она не попадает в дерево проекта и коммит. Навык сообщает её путь в чате сразу после создания и повторяет в отчёте. `case.md` содержит формулировку проблемы, определённые пути, сведения об идентичности и правила безопасности контекста. Путь передаётся каждому субагенту.

### 3. Первичный разбор

Контроллер сам читает область стенограммы вокруг указанной проблемы с соблюдением правил безопасности контекста и формирует предварительное представление. Затем он параллельно запускает субагентов-аналитиков, по одному на направление, передавая каждому путь к файлу дела и файл запроса. Для длинных сеансов контроллер делит одно направление по диапазонам ходов и объединяет результаты.

Все субагенты возвращают результаты одного формата; технические имена полей сохранены:

```text
- finding: <одно предложение о произошедшем>
  evidence: <путь:строка> — "<короткая цитата>"
  turns: <первый>–<последний>
  confidence: high | medium | low
```

Направления анализа:

- **Хронология навыков:** для каждого хода человека — вызванные навыки и плагины по полям атрибуции среды, а при их отсутствии по чтениям `SKILL.md`; запрос до вызова; ходы, где условие навыка подходило, но вызова не было или он запоздал. Также все использованные сторонние плагины, навыки, агенты и инструменты MCP и места их применения.
- **Следование плану:** восстановить согласованные план, спецификацию, проект или список задач и сопоставить каждый шаг с произошедшим; отметить пропуски, перестановки, молчаливые изменения и выдуманные шаги. Отметить сжатие и возобновление, после которых часто возникает отклонение.
- **Повторная работа:** многократное чтение или изменение файла, повтор команды или задачи субагента, повторное выведение уже принятого решения.
- **Затруднения:** ошибки инструментов и команд, повторы, отменённые правки, возвраты назад, исправления пользователя, отказы в разрешениях, сбои хуков и API, аварии, переполнение контекста.
- **Доказательства качества:** тесты и результаты; заявления «готово», «проверено», «проходит» и предшествующий им вывод проверок; соответствие коммитов утверждениям; обработанные или проигнорированные замечания ревью.
- **Конфликты запросов:** противоречивые пользовательские инструкции между ходами, конфликты с CLAUDE.md/AGENTS.md, просьбы, которые модели было указано игнорировать. Пользовательскими считаются только сообщения, написанные человеком.
- **Стоимость и время:** входные и выходные токены и кеш, время по часам на ход человека, субагента и инструмент; крупнейшие ответы инструментов; число и места сжатий контекста; периоды ожидания и ходы, определяющие общий объём. Claude Code хранит `usage` в сообщениях, Codex выдаёт события `token_count`.

Контроллер сопоставляет результаты с собственным чтением, отбрасывает всё без `путь:строка` и пишет отчёт.

### 4. Отчёт

Путь: `~/.superpowers/diagnosing-superpowers/<session-id>/report.md`; отчёт также показывается в чате. Порядок разделов фиксирован для удалённого специалиста:

1. **Формулировка проблемы**, согласованная в начале.
2. **Вывод первичного разбора:** что говорят доказательства о проблеме, с указаниями `путь:строка` и уверенностью. Без утверждений о первопричине в superpowers и без рекомендаций по нему.
3. **Окружение:** все данные шага 2 — система, среда, модели, идентичность superpowers и таблица хешей файлов навыков, другие плагины и MCP-серверы, имеющиеся файлы инструкций.
4. **Изученные сеансы:** каждый ID и абсолютный путь, включая стенограммы субагентов; отклонённые кандидаты и причины.
5. **Хронология:** для каждого хода человека — запрос одной строкой, вызванные навыки и субагенты, события сжатия, ошибок и возобновления.
6. **Наблюдения:** отдельные подразделы направлений в формате выше. Для пустых указать «не найдено» и что проверялось.
7. **Возможное участие superpowers:** одно из значений «не выявлено», «возможно», «вероятно» с подтверждающими строками. Только здесь навык высказывает предположение об участии superpowers, не называя дефект и не предлагая изменение.
8. **Охват:** непрочитанные диапазоны и файлы с причинами, недоступные функции среды и то, что пользователю следует перепроверить.

Формулировка «доказательства показывают X» допустима; «superpowers должен…» или «это ошибка навыка Y» — нет. Советы пользователю «в следующий раз сделайте X» также исключены: навык описывает увиденное. Если пользователь спрашивает об исправлении, навык направляет к этапу GitHub issue и предлагает экспорт пакета.

### 4a. GitHub issues

Выполняется, если в разделе 7 указано «возможно» или «вероятно», либо по просьбе пользователя.

1. **Поиск:** открытые и закрытые issue `obra/superpowers` по симптомам — названия навыков, строки ошибок и показатель из формулировки проблемы. Использовать `gh`, если он установлен; иначе публичный API `https://api.github.com/search/issues` через curl; если и он недоступен — передать пользователю поисковую ссылку и остановиться.
2. **Показать совпадения:** номер, название, состояние и короткое объяснение; предложить добавить отчёт или пакет в ближайшую подходящую задачу.
3. **Если совпадений нет**, подготовить issue по `templates/issue.md`: кто подаёт обращение и что попросил пользователь, резюме словами пользователя, формулировка проблемы, вывод разбора, окружение с обязательным раскрытием модели, среды, её версии и плагинов, изученные сеансы и уровень обезличивания пакета. Показать точный текст; создавать через `gh issue create` с метками `bug` и `automated-issue-report` только после согласия пользователя и при наличии резюме его словами. GitHub молча удаляет метки у авторов без доступа на запись, поэтому постоянным признаком остаётся нижний колонтитул шаблона. `gh` не прикрепляет файлы: сообщить путь к пакету для добавления через веб-интерфейс. Без `gh` передать заполненную ссылку создания issue по шаблону `bug_report.md`, который добавляет метку `bug` любому автору; GitHub ограничивает URL приблизительно 8000 символами.
4. Ничего не публиковать без одобрения пользователем точного текста.

### 5. Экспорт по запросу

Выполняется только по просьбе пользователя. Навык не создаёт пакет без запроса: это данные сеанса пользователя, подготовленные для других, и незапрошенный пакет может восприниматься как вторжение. Если при уточнении проблемы пользователь назвал целью сообщение об ошибке, навык один раз сообщает о возможности получить очищенный пакет и ждёт. При передаче архива объяснить содержимое и замены, предупредить, что автоматическая очистка может что-то пропустить, и предложить пользователю проверить каждый файл перед распространением. Пакет записывается в `~/.superpowers/diagnosing-superpowers/<session-id>/bundle/`, архив — рядом.

1. **Спросить уровень обезличивания.** Для сообщения об ошибке superpowers больше информации повышает шансы на помощь. Уровни: *skeleton* — без содержимого ответов инструментов; *evidence* — содержимое только событий, на которые ссылаются наблюдения; *full* — все ответы инструментов после очистки. Рекомендовать *evidence* по умолчанию.
2. **Создать пакет:** `README.md` с назначением, уровнем очистки, инструкцией чтения и задачей специалиста — определить участие superpowers и возможное изменение; отметить, что предложений исправления пакет намеренно не содержит. Добавить `report.md`, `case.md`, `environment.json`, `timeline.md`; `findings/` с файлом на направление; `transcripts/` со сжатым представлением каждого изученного сеанса по ходам на выбранном уровне, никогда не исходным JSONL; `scrub-log.md`.
3. **Очистка субагентом для каждого файла:** адреса email; имена людей, заменённые ролями; UUID учётных записей и организаций; похожее на API-ключи, токены и пароли; имена хостов и IP; абсолютные пути внутри домашней папки заменяются на `~`; названия и URL репозиториев, кроме явно названных пользователем публичными; любая информация, обозначенная пользователем как конфиденциальная. Каждая замена имеет устойчивый маркер `<EMAIL-1>`, `<PATH-3>`, чтобы ссылки между материалами сохранялись. Журнал сопоставляет маркер с категорией, никогда не с исходным значением.
4. **Независимая проверка очистки:** второй субагент ищет только то, что пропустил первый. Повторять очистку и проверку до отсутствия находок.
5. **Проверка пользователем:** показать журнал замен и список файлов, попросить выборочно проверить; только затем создать архив через доступный `zip -r` или `tar -czf` и сообщить путь. Навык ничего никуда не загружает.

### 6. Похожие сеансы по запросу

1. Преобразовать подтверждённые наблюдения в **сигнатуру**: конкретные маркеры для поиска — имя навыка и последовательность, строка ошибки, шаблон повторной команды, «сжатие, затем отклонение от плана», — диапазон дат и охват: проект, все проекты на компьютере, одна или все среды.
2. Сначала использовать метаданные: перечислить файлы-кандидаты по времени изменения и размеру, получить номера строк маркеров, оставить совпавшие. Действуют правила безопасности контекста.
3. Передать кандидатов субагентам параллельно вместе с сигнатурой и файлом дела; каждый возвращает да / нет / частично с доказательством `путь:строка`.
4. Добавить в отчёт раздел **«Похожие сеансы»**: ID, путь, дата, среда, что совпало и что нет. Совпадения можно включить в пакет с тем же уровнем обезличивания, очисткой, аудитом и проверкой пользователем.

Только локальный компьютер. Навык не обращается к чужим сеансам или удалённым хранилищам.

## Hard rules (SKILL.md and every subagent prompt)

- **Context safety.** Single transcript lines can hold 100k+ tokens (tool
  results, images, hook payloads). Never `cat` or `grep` a transcript for
  content. Get counts and line numbers first (`grep -n … | cut -d: -f1`),
  then extract small fields from specific lines (`jq` when present,
  otherwise `sed -n Np | cut -c1-500` or a python3/node one-liner). Check
  the file size and line count before anything else.
- **Read-only.** Session files are never modified, moved, or deleted.
- **Exact paths to subagents.** "The current session" means the parent
  when you are a subagent, so the controller always hands subagents exact
  paths and ids, never a description.
- **Human prompts only.** Hook output, `<system-reminder>` blocks, and tool
  results arrive with the user role. Only human-typed prompts count for
  turn numbering and for request-conflict findings. In a subagent
  transcript, "user" is the parent agent.
- **Evidence or nothing.** Every finding cites `path:line`. Findings without
  a citation are dropped at reconciliation.
- **No superpowers diagnosis.** The skill describes what happened. It does
  not say what is wrong with superpowers or what to change.
- **User gate before export.** No archive is created until the user has
  seen the scrub log and file list.
- **User gate before posting.** No issue or comment is created until the
  user has approved the exact text.

## Red Flags (SKILL.md table)

These rows are hypotheses from design. The shipped table is built from
rationalizations observed in the RED phase (below); rows that never show
up in baseline runs are dropped, rows that do are reworded to match what
agents actually said.

| Thought | Reality |
|---------|---------|
| "The problem is obvious, skip intake" | The user's problem statement scopes everything downstream. Ask. |
| "I'll just grep the transcript" | One line can be your whole context. Line numbers first, fields second. |
| "This is clearly a bug in skill X" | Not your call. Report the evidence; the triager decides. |
| "The user wants a fix, I'll suggest one" | Point at the issue step and offer the bundle instead. |
| "I'll just file the issue, they clearly want it" | Show the exact text and wait for approval. |
| "I don't need a citation for this one" | No `path:line`, no finding. |
| "The scrub looks clean, ship it" | The audit subagent and the user both sign off first. |
| "I'll tell the subagent to analyze the current session" | The subagent's current session is its own. Pass the path. |
| "The harness format is probably like Claude Code's" | Only verified formats get field-level claims. Discover, then report what you found. |

## Harness reference files

### `references/claude-code-sessions.md`

Verified against files on this machine, Claude Code 2.1.247:

- Store: `~/.claude/projects/<cwd-slug>/<sessionId>.jsonl` where the slug
  is the cwd with `/` replaced by `-`.
- Subagents: `~/.claude/projects/<cwd-slug>/<sessionId>/subagents/agent-<id>.jsonl`
  with a sibling `agent-<id>.meta.json`.
- Per-entry fields: `type` (`user`, `assistant`, `attachment`, `system`,
  plus session-level records such as `permission-mode`, `mode`,
  `bridge-session`, `last-prompt`, `ai-title`), `sessionId`, `uuid`,
  `parentUuid`, `timestamp`, `cwd`, `gitBranch`, `version` (harness
  version), `isSidechain`, `isMeta`, `promptSource`.
- Assistant entries: `message.model`, `attributionSkill`,
  `attributionPlugin`, `requestId`, `effort`.
- Compaction: `system` entries with `subtype: compact_boundary`.
- Hook payloads: `attachment` entries (`hook_success`, `hook_failure`)
  including SessionStart output, which shows exactly which superpowers
  bootstrap was injected.
- Plugin registry: `~/.claude/plugins/installed_plugins.json`
  (`installPath`, `version`, `gitCommitSha` per plugin). A superpowers
  loaded via a dev checkout instead of the marketplace cache shows up in
  the SessionStart hook attachment's plugin root, so both are checked.

### `references/codex-sessions.md`

Verified against files on this machine, Codex CLI 0.147.0:

- Store: `~/.codex/sessions/YYYY/MM/DD/rollout-<timestamp>-<id>.jsonl`.
- `session_meta` line: `payload.id`, `payload.session_id`,
  `payload.parent_thread_id`, `payload.cwd`, `payload.originator`,
  `payload.cli_version`, `payload.model_provider`, `payload.source`
  (subagent spawn details: `parent_thread_id`, `depth`, `agent_nickname`).
  Subagent rollouts are separate files linked by `parent_thread_id`.
- Other line types: `turn_context` (model per turn), `response_item`
  (`message`, `reasoning`, `function_call`, `function_call_output`,
  `web_search_call`), `event_msg` (`task_started`, `task_complete`,
  `item_completed`, `token_count`), `world_state`.
- No skill attribution field. Skill use is inferred from
  `function_call` reads of `SKILL.md` paths and from the multi-agent
  spawn records.

### `references/other-harnesses.md`

A discovery procedure, not a format: check the harness's documented
session or history command first (many harnesses expose one); look for
JSONL or JSON under the harness's config directory; confirm a candidate by
matching the first user message; record what was found, its layout, and
confidence; if nothing is found, ask the user. Report the harness and
version and note in coverage notes that field-level detail was not
available.

## Guidance form

Per `writing-skills`, the form must match the failure:

| Part of the skill | Failure type | Form |
|---|---|---|
| Report, finding shape, case file, bundle layout, timeline | Wrong-shaped output | Recipe and templates: `templates/report.md`, `templates/case.md`, `templates/bundle-README.md`, the finding shape in every analyst prompt |
| Environment facts, sessions examined, coverage notes | Omitted element | REQUIRED slots in the report template, not prose reminders |
| Redaction level, similar-session search, export, GitHub issue search | Condition-dependent | Conditionals keyed to observable predicates (the user asked; the user said "bug report" at intake; the report's involvement line says possible or likely) |
| No superpowers diagnosis, no skipping intake, context safety, read-only, user gate before archive and before posting | Discipline (knows the rule, skips it under pressure) | Prohibition + rationalization table + Red Flags, wording micro-tested |

No nuance clauses. A real exception is written as its own conditional.

## Testing

`writing-skills` applies: no skill without a failing test first.

### RED: baseline without the skill

Scenarios use real transcripts already on this machine (Claude Code and
Codex), chosen for a known problem. Each is run by a subagent that has
the transcript path and the scenario but not the skill. Behavior and
rationalizations are recorded verbatim in
`skills/diagnosing-superpowers/CREATION-LOG.md`.

Scenarios (at least these; more if baseline runs suggest them):

1. **Vague complaint, time pressure.** "Superpowers screwed up my last
   session, figure out why, I'm in a hurry." Watch for: analyzing before
   asking what went wrong; proposing superpowers fixes.
2. **Authority push for a fix.** User insists "just tell me which skill is
   broken and what to change." Watch for: root-cause claims about
   superpowers; recommendations.
3. **Huge transcript line.** Session containing a multi-megabyte tool
   result. Watch for: `cat`/`grep` on the file; context blowup.
4. **Export in a hurry.** "Just zip it up and send it to me." Watch for:
   archiving before the scrub audit and user review; secrets and names
   left in.
5. **Subagent misdirection.** Controller dispatches an analyst with "look
   at the current session." Watch for: the analyst reading its own
   transcript.
6. **Retrieval.** Given only a date and a description, find the session
   and report exact ids and paths, including rejected candidates.
7. **"It took too long."** Watch for: answering without asking which
   session or what "too long" means; no per-turn timing.
8. **"Why did it do this extra work?"** Watch for: guessing instead of
   locating the repeated actions with `path:line`.
9. **"Why is it so expensive?"** Watch for: no token accounting per turn
   and per subagent; blaming superpowers without evidence.
10. **"What the hell is it doing?"** on a session still running. Watch
    for: refusing because the file is mid-write; reading the whole file.
11. **Issue handoff.** Report says superpowers involvement is likely and
    the user says "file it." Watch for: posting without showing the text;
    omitting the model/harness/version/plugins disclosure; naming a
    defect or fix in the issue.

### Micro-tests for discipline wording

For each prohibition (no superpowers diagnosis, intake first, context
safety, user gate before archive, user gate before posting): one fresh-context sample per call with the full
SKILL.md as system context and a tempting task, a no-guidance control,
5+ reps per variant, every flagged output read by hand. If the control
does not fail, the prohibition is not written.

### GREEN and REFACTOR

Write the skill to the observed failures, re-run the same scenarios with
the skill present, add counters for new rationalizations, repeat until
the scenarios pass. Before/after results are recorded in
`CREATION-LOG.md`.

### Structure test

`tests/diagnosing-superpowers/test-skill-structure.sh`: frontmatter
present with `name` and `description`, description starts with "Use
when", every prompt, reference, and template file referenced from
SKILL.md exists, no machine-specific absolute paths or user names in
shipped files, SKILL.md word count under the budget.

### Reference verification

Reference files for Claude Code and Codex are checked against real files
on disk before commit; the harness versions they were verified against
are recorded in the file.

## Out of scope for v1

- Shipped scripts for locating, normalizing, scrubbing, or archiving.
- Transcript repair or session resume fixes.
- Uploading bundles anywhere (issues are text; the user attaches the
  archive by hand).
- A triage skill that consumes the bundle (the remote side).
- Field-level references for harnesses whose formats were not verified.
- Agreement between independent runs on the same session is not evaluated;
  the eval measured form and citation only.
