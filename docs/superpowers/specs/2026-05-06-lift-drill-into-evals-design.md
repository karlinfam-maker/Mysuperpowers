# Перенос drill в superpowers как `evals/` — проект

## Предпосылки

Drill — Python-бенчмарк соблюдения инструкций навыков из отдельного репозитория `obra/drill`. Он управляет реальными сеансами tmux, запускает LLM-актёра в роли пользователя и LLM-проверяющего для полученной стенограммы, после чего сообщает успех или неуспех каждого сценария. Поддерживаются Claude Code, Codex, Gemini CLI и, согласно недавним коммитам, OpenCode и Copilot CLI.

Drill уже фактически служит средой оценки superpowers. Серия коммитов PRI-1397 в репозитории drill перенесла около 22 bash-тестов superpowers в сценарии drill; последний на тот момент коммит superpowers `a2292c5` явно удалил дублирующий bash-тест с сообщением «заменён поведенческим покрытием drill». Перенос уже начался; спецификация предлагает его завершить.

Работа переносит drill в `evals/` superpowers, удаляет дублирующие bash-тесты после пофайловой проверки покрытия сценариями и обновляет документацию, чтобы участники находили новую структуру.

## Цели

1. `evals/` становится основной средой оценки superpowers и содержит полный исходный код drill, сценарии, тестовые данные, запросы, конфигурации серверных частей и тесты.
2. Bash-тесты в `superpowers/tests/` удаляются только при индивидуально подтверждённом полном покрытии сценариями drill; остальные сохраняются.
3. Различие между `tests/` — интеграционные тесты инфраструктуры плагина на bash, Node и Python — и `evals/` — поведение LLM с актёром и проверяющим — становится осмысленным и документируется.
4. Корневые `README.md`, `CLAUDE.md` и `docs/testing.md` направляют участников в нужное место.
5. Отдельный репозиторий `obra/drill` сохраняется, данным PR не затрагивается и архивируется вручную отдельным действием после слияния.

## Что не входит в цели

- **Интеграция с CI:** в этом PR только ручной запуск. Возможное развитие — быстрый набор на каждом PR и полный прогон ночью и по запросу; потребуются решения по бюджету API, секреты GitHub Actions и образ исполнителя с `tmux`, `node`, `python`, CLI `claude`, `codex`, `gemini`.
- **Размещение сценариев рядом с навыками:** сценарии остаются в `evals/scenarios/`. Возможный будущий перенос к отдельным навыкам потребует переименования путей, формат YAML менять не придётся.
- **Переименование внутреннего пакета Python** с `drill` на `evals`: пользовательский каталог называется `evals/`, а пакет сохраняет `drill` для небольшого diff. Пояснить это в `evals/README.md`.
- **Архивирование репозитория drill:** этот PR его не затрагивает. После слияния архивировать вручную с переводом GitHub в режим чтения и ссылкой README на `obra/superpowers/evals/`.
- **Перенос `tests/claude-code/analyze-token-usage.py` в `evals/bin/`:** это полезная утилита, а не тест; её можно перенести позднее, данный PR этого не требует.

## Ветка

Ответвиться от `dev` как `f/evals-lift`. Работа независима от открытого PR `f/cross-platform`: общих изменений файлов нет, кроме возможного небольшого конфликта `README.md`, который можно разрешить при слиянии.

## Архитектура после переноса

Ниже сохранена исходная схема каталогов. `evals/` — полная копия drill с Python 3.11, `uv`, исходным кодом, конфигурациями, 32 и более сценариями, 15 вспомогательными скриптами, тестовыми данными, запросами и собственным набором pytest. В `tests/` по умолчанию сохраняются тесты инфраструктуры; проверка поведения навыков относится к `evals/`. `docs/testing.md`, README и CLAUDE.md получают ссылки и описание этого разделения.

```
superpowers/
  evals/                              ← NEW (full drill copy)
    pyproject.toml                    (Python 3.11, uv-managed)
    uv.lock
    .gitignore                        (drill's own; results/, .venv/, .env)
    README.md                         (was drill's README; install instructions updated)
    CLAUDE.md                         (was drill's CLAUDE.md; paths updated)
    docs/
      design.md                       (drill's design — preserved verbatim, cross-linked from this spec)
      manual-testing.md
      pressure-and-red-testing.md
    drill/                            (Python package; name kept; cli, engine, actor, verifier, etc.)
    backends/                         (claude-*.yaml, codex.yaml, gemini.yaml)
    scenarios/                        (32+ YAML scenarios)
    setup_helpers/                    (15 Python helpers; create_base_repo, sdd_*, spec_*, worktree, etc.)
    fixtures/                         (template-repo, sdd-go-fractals, sdd-svelte-todo)
    prompts/                          (actor.md, verifier.md)
    bin/                              (assertion helper scripts: tool-called, tool-count, etc.)
    tests/                            (drill's own pytest suite)

  tests/                              ← bash tests preserved by default
    brainstorm-server/                ← KEEP (node tests for brainstorm-server JS code)
    opencode/                         ← KEEP (plugin loading tests)
    codex-plugin-sync/                ← KEEP (sync verification)
    claude-code/                      ← MOSTLY KEEP — see deletion gate
    explicit-skill-requests/          ← KEEP unless verified replaced
    skill-triggering/                 ← KEEP unless verified replaced
    subagent-driven-dev/              ← KEEP unless verified replaced

  docs/
    testing.md                        ← UPDATED (split into "Plugin tests" + "Skill behavior evals")
    superpowers/
      specs/
        2026-05-06-lift-drill-into-evals-design.md   ← THIS SPEC

  README.md                           ← small Contributing-section pointer to evals/
  CLAUDE.md                           ← one-line "Eval harness lives at evals/" pointer
```

После PR роли каталогов различаются:

- **`tests/`:** работает ли код плагина без LLM? Модульные и интеграционные тесты JavaScript brainstorm-server, загрузки плагина OpenCode и синхронизации codex-plugin-sync. Bash, Node и Python.
- **`evals/`:** корректно ли ведут себя агенты в реальных LLM-сеансах? Сценарии drill с актёром и проверяющим. Только Python; используются настоящие сеансы tmux.

## Условие удаления каждого bash-теста

Удалять bash-тест **только если** сценарий drill проверяемым образом покрывает каждое его утверждение. План реализации документирует проверку каждого файла: прочитать bash-тест, перечислить его проверки, найти сценарий drill и убедиться, что каждой соответствует запись `verify.assertions` или `verify.criteria`. Если отсутствует хотя бы одна проверка, нужно расширить сценарий drill или сохранить bash-тест; по умолчанию тест сохраняется.

**Предварительная карта покрытия** основана на сообщениях коммитов и требует пофайловой проверки до любого удаления:

| Bash-тест | Предполагаемая замена drill | Статус |
|---|---|---|
| `tests/skill-triggering/prompts/*`, шесть файлов запросов | `triggering-*.yaml`, шесть сценариев | Кандидаты; проверить каждый запрос до удаления |
| `tests/skill-triggering/run-test.sh`, `run-all.sh` | Не применяется: это средства запуска | **Сохранить** |
| `tests/explicit-skill-requests/prompts/please-use-brainstorming.txt` | Необходима проверка; очевидного аналога пока нет | Вероятно, **сохранить**, если не добавлен сценарий |
| `tests/explicit-skill-requests/prompts/use-systematic-debugging.txt` | Необходима проверка; очевидного аналога нет | Вероятно, **сохранить**, если не добавлен сценарий |
| `tests/explicit-skill-requests/run-claude-describes-sdd.sh` | Частично `mid-conversation-skill-invocation.yaml` | Кандидат; проверить скрипт |
| `tests/explicit-skill-requests/run-haiku-test.sh` | Нет сценария поведения именно Haiku | **Сохранить** |
| `tests/explicit-skill-requests/run-multiturn-test.sh`, `run-extended-multiturn-test.sh` | Нет сценария постепенного развития многоходового разговора | **Сохранить**, если сценарии не добавлены |
| `tests/explicit-skill-requests/run-test.sh`, `run-all.sh` | Средства запуска | **Сохранить** |
| `tests/subagent-driven-dev/go-fractals/`, `tests/subagent-driven-dev/svelte-todo/` | `sdd-go-fractals.yaml`, `sdd-svelte-todo.yaml` | Кандидаты; проверить до удаления, поскольку содержат реальные проверки прохождения наборов тестов |
| `tests/claude-code/test-document-review-system.sh` | `spec-reviewer-catches-planted-flaws.yaml` | Кандидат; проверить |
| `tests/claude-code/test-requesting-code-review.sh` | `code-review-catches-planted-bugs.yaml` | Кандидат; проверить |
| `tests/claude-code/test-subagent-driven-development-integration.sh` | `sdd-rejects-extra-features.yaml`, подмножество YAGNI | **Частично:** bash дополнительно проверяет не менее трёх коммитов, `npm test` и запускает `analyze-token-usage.py`; drill проверяет запрещённые экспорты и обязательность проверяющего. Покрытие в основном различается: почти наверняка **сохранить и расширить drill** |
| `tests/claude-code/test-subagent-driven-development.sh` | Метатест документации: агенту предлагается описать SDD; аналогов в drill нет | **Сохранить**, если сценарий не добавлен |
| `tests/claude-code/test-worktree-native-preference.sh` | `worktree-creation-under-pressure.yaml` | Кандидат; проверить |
| `tests/claude-code/test-helpers.sh`, `run-skill-tests.sh`, `analyze-token-usage.py` | Библиотеки и инструменты, а не тесты | **Сохранить** |

## Протокол проверки с субагентами

Каждое изменение плана реализации до коммита перепроверяется независимым субагентом.

| Категория изменения | Проверка |
|---|---|
| Удаление каждого bash-теста | Передать субагенту файл теста, YAML предполагаемого сценария drill и запрос: «Перечисли все проверки bash-теста и все записи verify сценария drill. Для каждой проверки найди соответствующую запись drill или укажи, что совпадения нет. Выведи таблицу по каждой проверке». Удаление разрешено только при полном совпадении. |
| Первоначальное копирование в `evals/` | Проверить запись SHA drill в сообщении коммита для отслеживания происхождения; **SHA-256 каждого файла**, а не только их число; отсутствие исключённых `.git/`, `.venv/`, `results/`, `.env`, `__pycache__/`, `*.egg-info/`, `.private-journal/`; существование всех путей из YAML серверных частей после переноса; сохранность `pyproject.toml`, `uv.lock`, `.gitignore`. |
| Собственный pytest drill | После изменения стандартных путей запустить `cd evals && uv run pytest`. Набор `evals/tests/` включает `test_backend.py` для поведения переменной `SUPERPOWERS_ROOT`; тесты необходимо согласовать с новым помощником и сохранить проходящими. |
| Поиск ссылок после удаления | Найти по всему дереву superpowers ссылки на удалённые bash-тесты, исключив `node_modules/`, `.venv/`, `evals/`. Проверить `docs/`, `docs/superpowers/plans/`, `RELEASE-NOTES.md`, `CLAUDE.md`, `GEMINI.md`, `AGENTS.md`, `README.md`, `.github/`, `scripts/`, `.opencode/INSTALL.md`, `.codex-plugin/INSTALL.md`, `lefthook.yml`. Каждое совпадение обновить либо выявить пропущенную зависимость. |
| Стандартное значение `SUPERPOWERS_ROOT` | После изменений путей запустить хотя бы один недорогой сценарий drill, например `triggering-test-driven-development`, и подтвердить успех реальным запуском, а не только ревью кода. |
| Финальная проверка до PR | Два параллельных субагента, постановка «пять очков тому, кто найдёт больше всего обоснованных проблем», как в PR cross-platform. Проверить исходный код и поведение. |

Для каждой задачи субагента в плане реализации создаётся отдельный пункт с явными входными данными и критериями. Результат кратко отражается в сообщении соответствующего коммита — «Subagent verification: …», — чтобы ход проверки можно было проследить.

## Конкретные изменения путей и конфигурации

**Проверено до написания спецификации.** В `drill/cli.py` задано `PROJECT_ROOT = Path(__file__).parent.parent`. После переноса `cli.py` находится в `evals/drill/cli.py`, поэтому `PROJECT_ROOT` указывает на `evals/`, а `PROJECT_ROOT.parent` — на корень репозитория superpowers. Именно это значение по умолчанию должен получать `SUPERPOWERS_ROOT`.

**Аудит подстановок YAML.** Только четыре конфигурации `claude*.yaml` подставляют `${SUPERPOWERS_ROOT}` в `args` для флага `--plugin-dir`. `codex.yaml` и `gemini.yaml` лишь перечисляют `SUPERPOWERS_ROOT` в `required_env`; затем код `engine.py:233` и `setup.py:25` обращается к `os.environ["SUPERPOWERS_ROOT"]` в хуках до и после запуска. Изменение `os.environ` вспомогательной функцией покрывает оба пути.

| Файл | Сейчас | После изменения |
|---|---|---|
| `drill/cli.py` | `load_dotenv(PROJECT_ROOT / ".env")` при импорте модуля; `SUPERPOWERS_ROOT` не задан | После `load_dotenv` вызвать новую `_set_superpowers_root_default()`: установить `os.environ["SUPERPOWERS_ROOT"]` в `str(PROJECT_ROOT.parent)`, только если переменной ещё нет. Порядок: `load_dotenv` → значение по умолчанию → определения группы click. |
| `drill/engine.py:233`, `drill/setup.py:25` | Прямой доступ к `os.environ["SUPERPOWERS_ROOT"]`, KeyError при отсутствии | Без изменений: запуск CLI гарантирует наличие переменной до выполнения engine/setup. |
| `backends/claude*.yaml`, пять файлов | `${SUPERPOWERS_ROOT}` подставляется в `args` для `--plugin-dir` | Без изменений: подстановка читает `os.environ` при загрузке серверной части после запуска CLI. |
| `backends/codex.yaml`, `backends/gemini.yaml` | `SUPERPOWERS_ROOT` только в `required_env` | Убрать из `required_env`, поскольку значение задаёт помощник; в `claude*.yaml` оставить для обратной совместимости и возможности переопределения. |
| `evals/tests/test_backend.py` | Проверки наличия `SUPERPOWERS_ROOT` в `required_env` и разрешения путей | Обновить контракт: стандартное значение задаёт помощник, переменная окружения по-прежнему переопределяет его, в `required_env` codex/gemini она больше не обязательна. |
| `evals/README.md` | Инструкция `export SUPERPOWERS_ROOT=/path/to/superpowers` | Убрать экспорт, указать автоматическое значение — родитель `evals/` — и необходимость только `ANTHROPIC_API_KEY`, либо `OPENAI_API_KEY` или авторизации Gemini. |
| `evals/CLAUDE.md` | То же | То же |
| `evals/.gitignore` | Шаблоны drill: `results/`, `.venv/`, `__pycache__/`, `.env`, `*.pyc`, `*.egg-info/`, `dist/`, `build/`, `.claude/` | Копировать без изменений: пути относятся к расположению файла и правильно действуют в `evals/`. |
| `evals/lefthook.yml` | В drill определён `pre-commit: uv run ruff check && uv run ty check` | Перенести в `evals/lefthook.yml`. Варианты: установить lefthook в корне и связать с конфигурацией evals или описать ручной `cd evals && lefthook run pre-commit`. **При реализации выбран второй вариант** как более простой; корневой процесс superpowers не меняется. |

Файл окружения остаётся `evals/.env`, исключённым из git. Участники загружают его оттуда или задают `ANTHROPIC_API_KEY` в окружении оболочки.

**Небольшие дополнения в корневых файлах:**

- `superpowers/.gitignore`: добавить `evals/results/`, `evals/.venv/`, `evals/.env` как дополнительную защиту, хотя локальный `evals/.gitignore` их уже покрывает.
- `superpowers/CLAUDE.md`: добавить строку «Среда оценки находится в `evals/`, см. `evals/README.md`».
- `superpowers/docs/testing.md`: разделить на «Plugin tests» с существующим описанием `tests/` и удалёнными ссылками на удалённые тесты и «Skill behavior evals» с кратким описанием и ссылкой на `evals/`.
- `superpowers/README.md`: добавить в Contributing одну строку со ссылкой на `evals/` для проверки поведения навыков.

## Порядок переноса

Каждый шаг — отдельный коммит или небольшая группа. Крупнейший отдельный коммит — дословное копирование drill на шаге 2; остальные небольшие и атомарные. Исходная схема ниже сохранена вместе с командами:

```
1. Branch off `dev` (f/evals-lift)

2. Copy drill repo into evals/ (single commit, easy to revert)
   ├─ Record drill SHA at copy time → commit message
   ├─ Use `rsync -a --exclude=.git --exclude=.venv --exclude=results
   │  --exclude=.env --exclude=__pycache__ --exclude='*.egg-info'
   │  --exclude=.private-journal /path/to/drill/ evals/`
   │  (rsync chosen over `cp -r` for explicit excludes; verify with
   │  `find evals -name '.git' -type d` returns nothing)
   ├─ Subagent gate: per-file SHA-256 checksum matches drill repo for every
   │  non-excluded file; excluded paths absent from evals/
   └─ Smoke check: `cd evals && uv sync` succeeds (proves install only;
      not a behavioral test)

3. Update path defaults
   ├─ Add _set_superpowers_root_default() helper to drill/cli.py
   ├─ Wire it after load_dotenv, before click group definition
   ├─ Update evals/README.md and evals/CLAUDE.md (drop SUPERPOWERS_ROOT install step)
   ├─ Drop SUPERPOWERS_ROOT from required_env in codex.yaml/gemini.yaml
   │  (keep in claude*.yaml as override)
   └─ Update evals/tests/test_backend.py to match new contract

4. Validate from new location (TWO checks)
   ├─ Run drill's own pytest: `cd evals && uv run pytest` — must pass
   └─ Run cheap drill scenario: `cd evals && uv run drill run
      triggering-test-driven-development -b claude` — must pass.
      Real behavioral validation, not just code review.

5. Bash test deletion phase — per-file with subagent gate
   For each file in the candidate-deletion list:
   a. Subagent compares bash test assertions vs drill scenario verify block
   b. Pass criterion: every bash assertion has a matching drill check
   c. If pass → delete the bash test file (one commit per file or per
      coherent group)
   d. If fail → either extend drill scenario (separate commit + verify) or
      keep the bash test (no commit)

6. Stale-reference scrub
   ├─ Subagent greps the superpowers tree (excluding node_modules/, .venv/,
   │  evals/) for deleted file paths
   ├─ Search targets: docs/, docs/superpowers/plans/, RELEASE-NOTES.md,
   │  CLAUDE.md, GEMINI.md, AGENTS.md, README.md, .github/, scripts/,
   │  .opencode/INSTALL.md, .codex-plugin/INSTALL.md, lefthook.yml
   ├─ Update active references (e.g., docs/testing.md, README.md install)
   └─ Historical references in docs/superpowers/plans/*.md and
      RELEASE-NOTES.md are PRESERVED with a brief annotation
      ("(test removed; behavior covered by drill scenario X)") rather
      than rewritten — these are dated artifacts, not living docs.

7. Top-level docs
   ├─ docs/testing.md split
   ├─ CLAUDE.md pointer
   └─ README.md Contributing section

8. Re-run smoke checks (regression gate)
   ├─ `cd evals && uv run pytest`
   └─ `cd evals && uv run drill run triggering-test-driven-development -b claude`

9. Final adversarial review
   └─ Two parallel subagents, full diff, "5 points to whoever finds the
      most legitimate issues" framing. Address findings before push.

10. Push branch + open PR against dev
    └─ PR description includes: drill SHA pinned at copy, archival action
       item ("after merge: archive obra/drill, add README pointer to
       obra/superpowers/evals/"), per-deleted-file coverage receipts.
```

Последовательность: создать ветку; скопировать drill с фиксированием SHA, исключениями и пофайловой сверкой SHA-256; настроить пути и переменные; запустить pytest и реальный сценарий; рассмотреть удаление каждого кандидата только после проверки всех утверждений; удалить или аннотировать устаревшие ссылки; обновить документацию; повторить проверки; провести две независимые проверки полного diff; затем отправить ветку и открыть PR в `dev`. В описании PR указать SHA drill, доказательства покрытия для каждого удалённого файла и отдельное действие по архивированию после слияния.

## Проверка после реализации

План реализации должен показать:

- Все неисключённые файлы drill находятся в `evals/` после шага 2; субагент сравнивает **SHA-256 каждого файла** с `obra/drill@<recorded-sha>`.
- Исключённые `.git/`, `.venv/`, `results/`, `.env`, `__pycache__/`, `*.egg-info/`, `.private-journal/` отсутствуют в `evals/`.
- Сообщение коммита шага 2 содержит SHA источника drill.
- `cd evals && uv sync` выполняется без заданного `SUPERPOWERS_ROOT`.
- `cd evals && uv run pytest` проходит собственный набор pytest drill.
- `cd evals && uv run drill list` возвращает такое же количество сценариев, как отдельный drill на записанном SHA.
- `cd evals && uv run drill run triggering-test-driven-development -b claude` проходит и подтверждает работу стандартных путей сквозным запуском.
- Для каждого удалённого bash-теста сообщение коммита содержит таблицу проверки субагента, сопоставляющую каждое утверждение с проверкой drill.
- Поиск удалённых путей после шага 6 не находит их в актуальной документации superpowers; исторические ссылки в `docs/superpowers/plans/*.md` и `RELEASE-NOTES.md` снабжены пояснениями, но не переписаны.
- `docs/testing.md` содержит разделы «Plugin tests» и «Skill behavior evals».
- История drill не изменена; PR не затрагивает `obra/drill`.
- В описании PR названо последующее архивирование `obra/drill` после слияния.

## Открытые вопросы

Открытых вопросов нет; все уточнения согласованы:

| Вопрос | Решение |
|---|---|
| Где размещается drill внутри superpowers? | `evals/`; отдельный репозиторий архивируется отдельным шагом |
| Что делать с дублирующими bash-тестами? | Удалять пофайлово после проверки покрытия субагентом; по умолчанию сохранять |
| Как размещать сценарии? | Централизованно в `evals/scenarios/` |
| Где находится инструментарий Python? | Самостоятельно внутри `evals/` |
| Интеграция CI? | В этом PR только вручную; будущий путь описывается |
| Механика переноса? | Простое копирование; история drill сохраняется в архивированном репозитории, а не переносится в дерево |
| Имя внутреннего пакета Python? | Сохранить `drill`, каталог называется `evals/` |
| Стратегия ветки? | Независимо от `dev`, без зависимости от `f/cross-platform` |
