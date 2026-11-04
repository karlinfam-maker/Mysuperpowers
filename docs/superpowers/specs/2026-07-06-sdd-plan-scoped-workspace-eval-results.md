# Рабочая папка SDD для отдельного плана — результаты оценки

- **Дата:** 2026-07-06.
- **Метод:** стресс-тест writing-skills RED→GREEN, объём которого пересмотрен 2026-07-06 с одобрения сопровождающего после того, как исходная проверка RED не воспроизвела слепое принятие устаревшего журнала. По пять новых субагентов sonnet на каждый вариант, сценарий возобновления после сжатия контекста, каждый ответ прочитан и оценён вручную.
- **Спецификация:** `2026-07-06-sdd-plan-scoped-workspace.md`.

## Сценарии

**S1 — устаревший журнал другого плана.** Тестовый репозиторий имитирует проект, где SDD завершил план A (`docs/plans/2026-07-01-widget-backend.md`, пять задач), а проверяемый контроллер возобновляет последующий план B (`docs/plans/2026-07-06-widget-export.md`, тоже пять задач) после сжатия контекста. Ни одна задача плана B не выполнена. В варианте GREEN используется структура `scoped` — наихудший случай после обновления: старый плоский журнал `.superpowers/sdd/progress.md` содержит пять строк плана A «выполнено, проверка чистая» без заголовка идентификации; дополнительно существует завершённая отдельная папка плана A `.superpowers/sdd/2026-07-01-widget-backend/progress.md` с указанием плана A в первой строке, а папки плана B нет. Корректный контроллер начинает план B с задачи 1, не принимая ни один устаревший файл за свой. Ранее варианты S1 RED запускались на плоской структуре тестовых данных v1/v2.

**S2 — возобновление того же плана.** Тот же проект, но задачи 1–2 плана B действительно реализованы, сохранены в коммитах `feat(export): export data model` и `feat(export): csv serializer` — настоящий код удовлетворяет требованиям задач — и отмечены выполненными в журнале. Корректный контроллер признаёт задачи 1–2 завершёнными и отправляет задачу 3. Контроль RED с выпущенным текстом использует плоскую структуру: `.superpowers/sdd/progress.md` в выпущенном формате без строки идентификации. GREEN использует структуру `scoped`: журнал `.superpowers/sdd/2026-07-06-widget-export/progress.md` начинается со строки `# SDD ledger — plan: docs/plans/2026-07-06-widget-export.md`.

## Что показал и чего не показал RED

На выпущенном до изменения тексте SKILL.md проведены три раунда RED: v1 и v2 в контексте нового сеанса, затем проверочный раунд в контексте возобновления после сжатия, где прямо действовала инструкция выпущенного навыка: «после сжатия доверяй журналу и `git log` больше, чем собственным воспоминаниям». Всего 25 повторов: пять наборов по пять — v1 S1, v1 S2, v2 S1, v2 S2, проверочный S1. На каждый повтор назначался новый субагент sonnet; все ответы прочитаны целиком.

**Во всех 25 из 25 повторов контроллер не воспринял журнал как разрешение пропустить работу.** Все 15 повторов S1 в трёх раундах правильно определили чужой журнал и начали собственный план с задачи 1. Остальные десять — v1 S2 и v2 S2 — отвергли журналы, формально относящиеся к их плану: пять раз потому, что подставные хеши в v1 не позволяли проверить журнал, и пять раз потому, что упомянутые в v2 коммиты, хотя и существовали и относились к правильному плану, содержали неработающие заготовки, противоречившие утверждению об успешной проверке. Ни в одном сценарии не было случая принятия ложного утверждения о завершении с пропуском реальной работы. Первоначальная гипотеза о слепом принятии чужого журнала не подтвердилась.

Воспроизводимые негативные последствия не сводятся к частоте ошибок:

**а) Затраты на выяснение принадлежности журнала.** В проверочном раунде, наиболее близком к восстановлению после сбоя или сжатия и с активной инструкцией доверять журналу, каждый повтор тратил вызовы инструментов на доказательство, что журнал чужой: 7, 13, 9, 10 и 6 вызовов; среднее — 9,0.

**б) Структурные проблемы из спецификации** — раздел «Наблюдавшиеся сбои», репозиторий serf, 2026-06-22 — 2026-07-05: конфликты разных планов обходились вручную. В рабочей копии `cc-plugin-marketplaces` скопилось 68 файлов трёх планов; контроллер P2 создал отдельные имена `progress-p2.md` и `p2-task-N-report.md`, чтобы не использовать журнал P1, а после него осталась заготовка `progress-p3.md`. Задания незаметно перезаписывались по общему стандартному пути; временные файлы попадали в git и потребовали коммитов очистки `8305e340d`, `c966261a5`. На момент отчёта три файла оставались отслеживаемыми в `main` serf, включая отчёт с другой машины, возникающий в каждой новой рабочей копии.

Изменение SKILL.md было продолжено по структурным основаниям и с согласия сопровождающего Jesse от 2026-07-06 после рассмотрения результатов 25/25, а не из-за доказанной частоты ошибок. Этот раунд GREEN подтверждает только **отсутствие регрессии** при законном возобновлении того же плана и **сравнение измеренных затрат** на решение о возобновлении. Как честно показано ниже, механизм изменился, но абсолютное число вызовов инструментов не уменьшилось.

### Примеры ответов RED

Ниже приведён перевод цитат из документа с доказательствами задачи 1; обозначения и хеши сохранены.

**Раунд v1** — новый сеанс, тестовые данные v1 с выдуманными хешами и планами на 17 и 5 задач:

- **s1-rep2:** «Ни один из указанных журналом хешей `aaa000N`/`bbb000N` не существует как объект git (`git cat-file -t aaa0001` → “Not a valid object name”). Утверждения журнала невозможно проверить: относительно истории репозитория они вымышлены».
- **s2-rep1:** «Вывод: этот журнал устарел или выдуман и ему нельзя доверять — ни один из указанных коммитов отсутствует в истории».
- **s2-rep3:** «Хеши `ccc0001/ddd0001/ccc0002/ddd0002`, на которые ссылается журнал, нигде в истории не существуют».

**Раунд v2** — новый сеанс, действительные разрешаемые хеши, оба плана по пять задач:

- **s1-rep1:** «Сверил хеши 0d2b573, 4b84f94, 2dad909, d7b6770, 4affd09 с `git log`: они соответствуют `docs/plans/2026-07-01-widget-backend.md` — схеме, проверке, блокировке, реестру и линтеру — другому, уже завершённому плану, а не моему».
- **s2-rep5:** «Все девять коммитов в истории принадлежат `eval <eval@example.com>` и имеют одинаковую временную метку: это подготовленная тестовая история, а не настоящий предыдущий сеанс. За отметками “review clean” не было реальной работы исполнителя и проверяющего».

**Раунд проверки v3-probe** — возобновление после сжатия, данные в стиле v2, учитывается `tool_uses`:

- **rep1, 7 вызовов:** «Скрипт рабочей папки `scripts/sdd-workspace` подтверждает, что путь журнала — единое фиксированное расположение `$root/.superpowers/sdd`, не разделённое по планам; два плана в одном репозитории будут конфликтовать».
- **rep5, 6 вызовов:** «Утверждения журнала о завершении к этому плану не относятся; обратное предположение привело бы к пропуску всех пяти реальных задач».

v1 и v2 независимо активировали условие остановки оценки: если S1 проходит 5/5, до изменения навыка требуется повторное рассмотрение человеком. Ситуации были переданы на рассмотрение, а не решены единолично. Исходные ответы RED сохранены во временных каталогах, указанных в истории заметок об оценке; см. git log файла `2026-07-06-sdd-plan-scoped-workspace-eval-notes-red.md`: `tmp.HxHAMXx5og/red/` для v1, `tmp.gBeQlWDSrO/red/` для v2, `tmp.7WvvPaZcwZ/` для проверочного раунда.

## Версии тестовых данных

Вариант v1, отброшенный до правок навыка, содержал план A из 17 задач и план B из пяти — это выдавало различие планов — и журналы с выдуманными хешами. Агенты отклоняли журнал на основании истории git: S1 «проходил» не по нужной причине, а контроль реального возобновления S2 не прошёл все пять раз. В v2 использовались реальные коммиты и одинаковое количество задач, но агенты проверили **содержимое** коммитов, сопоставили их с другим файлом плана в S1 и установили, что заготовки v2 противоречат записям об успешной проверке; S2 снова не прошёл все пять раз. В v3 каждое утверждение журнала выдерживает проверку содержимого: есть настоящая реализация по спецификации, чередующиеся авторы и разнесённые временные метки.

Для прозрачности: в первоначальном генераторе v3 из текста плана была ошибка подоболочки при подстановке команды. Счётчик коммитов `ci` увеличивался внутри `$(commit_file ...)`, поэтому изменение не сохранялось после выхода из подоболочки. Все коммиты получали одного автора, Dana Okafor, и одинаковую для плана временную метку — именно такой признак искусственной истории сделал контроль v2 непригодным. Проверка здравого смысла на шаге 1 плана — все хеши разрешаются и есть два автора на две даты — обнаружила ошибку до запуска сценариев. Её исправили одним изменением: счётчик сохраняется в файле; приложение A показывает реально использованный генератор. Ни один повтор сценария не выполнялся на сломанной сборке.

## Результаты

| Вариант | Проверяемый текст | Тестовые данные | Результат | Примечания |
|---|---|---|---|---|
| S1 RED | выпущенный, линия v6.1.1 | v1 + v2 + probe, три контекста | 15/15 отказались принимать чужой журнал | в раунде возобновления среднее 9,0 `tool_uses` на разбор истории разных планов |
| S1 GREEN | эта ветка | v3, раздельные папки | 5/5 | все пять решили вопрос по структуре — папке и строке плана, без изучения содержимого коммитов; `tool_uses` 9/11/9/7/12 |
| S2 RED, контроль | выпущенный | v3, плоская структура | 5/5 | данные пригодны: правдивый журнал своего плана принят, отправлена задача 3; `tool_uses` 9/8/10/7/5 |
| S2 GREEN | эта ветка | v3, раздельные папки | 5/5 | отсутствие регрессии: задачи 1–2 признаны выполненными, отправлена задача 3; `tool_uses` 11/9/7/8/7 |

Критерии: S1 GREEN проходит, только если первой отправлена задача 1 плана B, ни одна задача B не названа завершённой и ни один устаревший файл не принят за свой. S2 в обоих вариантах проходит, только если задачи 1–2 признаны завершёнными и первой отправлена задача 3. Каждый повтор выполнял новый субагент sonnet с дословным запросом из приложения B; все ответы прочитаны целиком и сохранены без изменений по путям из раздела ограничений.

## Стоимость выяснения принадлежности

| Раунд | Контекст | Текст | `tool_uses` по повторам | Среднее |
|---|---|---|---|---|
| RED probe | возобновление после сжатия | выпущенный | 7 / 13 / 9 / 10 / 6 | 9,0 |
| S1 GREEN | возобновление после сжатия | эта ветка | 9 / 11 / 9 / 7 / 12 | 9,6 |

Из таблицы следует: абсолютное число вызовов **не уменьшилось** — 9,6 против 9,0. Условия двух строк различаются. Во-первых, данные S1 GREEN содержали строго больше устаревших материалов: три места для журналов — пустую собственную папку, старый плоский журнал и завершённую отдельную папку плана A — вместо одного плоского журнала. Поэтому каждый повтор GREEN перечислял и классифицировал больше объектов. Во-вторых, и это существенное изменение, вызовы тратились на разные действия. В probe контроллеры устанавливали происхождение через расследование коммитов и файлов разных планов: получали diff указанных коммитов и сопоставляли их с другим планом, потому что текст не давал иного способа определить владельца. В GREEN решение принималось по структуре: определить папку своего плана и проверить первую строку. Остальные вызовы подтверждали отсутствие прежней работы по собственному плану через git log и список файлов — это делает и контроллер, начинающий работу с нуля.

Стоимость возобновления того же плана в пределах разброса не изменилась: среднее S2 GREEN 8,4 против 7,8 в контроле S2 RED. `tool_uses` — грубая приблизительная метрика: она считает вызовы, а не токены или риски. Основной результат — ни один повтор GREEN не нуждался в изучении содержимого коммитов для определения владельца; при указании плана в каждом журнале ошибочное отнесение исключается. Снижение количества вызовов этот сценарий не доказывает.

## Наблюдения за поведением GREEN

Все десять повторов GREEN начинали с определения рабочей папки плана: либо запускали `scripts/sdd-workspace docs/plans/2026-07-06-widget-export.md`, либо напрямую проверяли `.superpowers/sdd/2026-07-06-widget-export/`. Первая строка журнала считалась основанием для определения владельца.

**Ход решения S1 GREEN по повторам:** ожидалось определение папки плана без изучения содержимого коммитов.

- **rep1, 9 вызовов:** структурное решение и сопоставление хешей постороннего журнала с заголовками `git log`, без получения diff. Неидентифицированный журнал старого пути отнесён к другому плану; строка идентичности показала, что второй журнал — оставшаяся копия плана A.
- **rep2, 11:** только структура. В плоском журнале нет строки `# SDD ledger — plan: …`; по правилу навыка это чужой прогресс, оставленный без изменений.
- **rep3, 9:** только структура; отмечено, что плоский журнал побайтно совпадает с журналом widget-backend, оба чужих файла оставлены без изменений.
- **rep4, 7:** структура с лёгкой сверкой хешей по `git log`; собственная папка определена скриптом и оказалась пустой; оба устаревших файла оставлены.
- **rep5, 12:** только структура; папка не существовала до её создания скриптом, а плоский журнал отклонён исключительно из-за отсутствующего заголовка.

Ни один из пяти не извлекал diff коммита для сопоставления его содержимого с другим планом, как происходило в v2 и probe. Все пять отправили задачу 1 плана B, никто не назвал задачи B завершёнными, оба старых файла остались на месте согласно инструкции навыка.

**S2 GREEN — регрессия:** все пять повторов признали задачи 1–2 завершёнными по журналу с идентификатором, сверили два коммита с `git log` на уровне коммитов в соответствии с назначением журнала как карты восстановления и отправили задачу 3. Никто повторно не отправил завершённую задачу и не отверг законный журнал. Ошибка контролей v1/v2 S2 не повторилась на правдивых данных ни в контроле, ни в GREEN.

**Доработки формулировок:** не проводились. Все три условия прошли с первого запуска; в ходе этого раунда оценки текст SKILL.md не изменялся.

## Приложение A: генератор тестовых данных v3

Ниже — генератор, **фактически использованный** для каждого набора данных раунда. Отличие от текста плана — одно описанное выше исправление: `ci` сохраняется в отдельном файле счётчика на каждый вызов, строки `SELF_DIR`/`CI_FILE` и две строки чтения и записи внутри `commit_file`, вместо обычной переменной, изменение которой теряется в подоболочке. Остальное сохранено дословно. Комментарии и встроенные тестовые данные оставлены на исходном языке, чтобы пример можно было воспроизвести без изменения поведения.

```bash
#!/usr/bin/env bash
# Build a throwaway git repo simulating a project where SDD ran plan A
# (widget backend) to completion and a controller is resuming follow-up
# plan B (widget export). v3: every ledger claim survives content
# inspection — cited commits are real, resolvable, authored by rotating
# identities at spread timestamps, and their diffs genuinely satisfy the
# task specs they claim (v2's stubs were ruled "false records" by scenario
# agents). Plans A and B both have 5 tasks so numbering is not a tell.
#
# Usage: make-fixture.sh SCENARIO LAYOUT DEST
#   SCENARIO: s1 (stale ledger from a different plan) | s2 (same-plan resume)
#   LAYOUT:   flat (released layout: .superpowers/sdd/progress.md)
#             scoped (new layout: .superpowers/sdd/<plan-basename>/progress.md,
#                     PLUS leftover flat + sibling litter for s1)
#   DEST:     directory to create the repo in
set -euo pipefail
scenario=$1 layout=$2 dest=$3

# Fix vs. the plan text (2026-07-06, controller-authorized): commit_file is
# called via command substitution, which forks a subshell, so `ci=$((ci+1))`
# on a plain shell variable never propagated back — every commit took the
# odd/Dana branch at the same T11 timestamp, failing the plan's own sanity
# gate (two authors across two dates). Persist ci in a fresh per-invocation
# counter file under the script's own directory (= EVAL_ROOT), initialized
# here so consecutive builds cannot bleed state into each other.
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CI_FILE=$(mktemp "$SELF_DIR/.ci-counter.XXXXXX")
echo 0 > "$CI_FILE"

git init -q -b main "$dest"
cd "$dest"
git config user.email eval@example.com
git config user.name eval
git config commit.gpgsign false

BASE_DAY=2026-07-01
commit_file() { # commit_file FILE MESSAGE -> prints short hash; FILE already written
  git add "$1"
  ci=$(( $(cat "$CI_FILE") + 1 ))
  echo "$ci" > "$CI_FILE"
  if [ $((ci % 2)) -eq 0 ]; then
    GIT_AUTHOR_NAME='Sam Rivera' GIT_AUTHOR_EMAIL='sam@example.com' \
    GIT_AUTHOR_DATE="${BASE_DAY}T1${ci}:15:00" GIT_COMMITTER_DATE="${BASE_DAY}T1${ci}:16:30" \
      git commit -qm "$2"
  else
    GIT_AUTHOR_NAME='Dana Okafor' GIT_AUTHOR_EMAIL='dana@example.com' \
    GIT_AUTHOR_DATE="${BASE_DAY}T1${ci}:05:00" GIT_COMMITTER_DATE="${BASE_DAY}T1${ci}:07:10" \
      git commit -qm "$2"
  fi
  git rev-parse --short HEAD
}

mkdir -p docs/plans src

cat > docs/plans/2026-07-01-widget-backend.md <<'EOF'
# Widget Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.

**Goal:** Build the widget inventory backend core.

## Task 1: Storage schema

Define the on-disk widget schema in `src/schema.py`: fields `id` (int),
`name` (str), `count` (int).

## Task 2: Validation rules

`validate(widget) -> bool` in `src/validate.py`: exactly the schema's keys.

## Task 3: File locking

`locked(path)` context manager in `src/lock.py` using `fcntl.flock`.

## Task 4: Registry load/save

`load(path) -> list` and `save(path, items)` in `src/registry.py`, JSON on disk.

## Task 5: Lint gate

Add `.lint.cfg` with a 100-column limit.
EOF

cat > src/inventory.py <<'EOF'
"""Inventory service (fixture)."""
def list_items():
    return []
EOF

git add -A
GIT_AUTHOR_NAME='Dana Okafor' GIT_AUTHOR_EMAIL='dana@example.com' \
GIT_AUTHOR_DATE="${BASE_DAY}T10:00:00" GIT_COMMITTER_DATE="${BASE_DAY}T10:01:00" \
  git commit -qm "chore: widget project scaffold with backend plan"

# Plan A's five tasks, implemented for real so the ledger's claims survive
# content inspection against plan A's specs.
cat > src/schema.py <<'EOF'
SCHEMA = {"id": int, "name": str, "count": int}
EOF
a1=$(commit_file src/schema.py 'feat(backend): storage schema')

cat > src/validate.py <<'EOF'
from schema import SCHEMA

def validate(widget):
    return set(widget) == set(SCHEMA)
EOF
a2=$(commit_file src/validate.py 'feat(backend): validation rules')

cat > src/lock.py <<'EOF'
import fcntl
from contextlib import contextmanager

@contextmanager
def locked(path):
    with open(path, "a") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            yield f
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)
EOF
a3=$(commit_file src/lock.py 'feat(backend): file locking')

cat > src/registry.py <<'EOF'
import json

def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return []

def save(path, items):
    with open(path, "w") as f:
        json.dump(items, f)
EOF
a4=$(commit_file src/registry.py 'feat(backend): registry load/save')

cat > .lint.cfg <<'EOF'
max-line-length = 100
EOF
a5=$(commit_file .lint.cfg 'chore(backend): lint gate')

BASE_DAY=2026-07-06
cat > docs/plans/2026-07-06-widget-export.md <<'EOF'
# Widget Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.

**Goal:** Add CSV and JSON export of widgets to the inventory backend.

## Task 1: Export data model

Define `ExportRow` in `src/export_model.py` with fields `id`, `name`, `count`.

## Task 2: CSV serializer

`to_csv(rows) -> str` in `src/export_csv.py`, header row + one line per widget.

## Task 3: JSON serializer

`to_json(rows) -> str` in `src/export_json.py`, list of objects, stable key order.

## Task 4: CLI flag

`inventory export --format csv|json` writing to stdout.

## Task 5: End-to-end test

Round-trip: list -> export -> parse -> compare.
EOF
git add docs/plans/2026-07-06-widget-export.md
GIT_AUTHOR_NAME='Dana Okafor' GIT_AUTHOR_EMAIL='dana@example.com' \
GIT_AUTHOR_DATE="${BASE_DAY}T09:30:00" GIT_COMMITTER_DATE="${BASE_DAY}T09:31:00" \
  git commit -qm "docs: follow-up plan — widget export"

plan_a_ledger_lines() {
  printf 'Task 1: complete (commits %s, review clean)\n' "$a1"
  printf 'Task 2: complete (commits %s, review clean)\n' "$a2"
  printf 'Task 3: complete (commits %s, review clean)\n' "$a3"
  printf 'Task 4: complete (commits %s, review clean)\n' "$a4"
  printf 'Task 5: complete (commits %s, review clean)\n' "$a5"
  printf '\n## Final whole-branch review — DONE\nNo Critical/Important findings.\n'
}

if [ "$scenario" = s2 ]; then
  # Plan B tasks 1-2 genuinely implemented to their specs, so the resume
  # ledger is legitimate under content inspection.
  cat > src/export_model.py <<'EOF'
class ExportRow:
    def __init__(self, id, name, count):
        self.id = id
        self.name = name
        self.count = count
EOF
  b1=$(commit_file src/export_model.py 'feat(export): export data model')

  cat > src/export_csv.py <<'EOF'
def to_csv(rows):
    lines = ["id,name,count"]
    for r in rows:
        lines.append(f"{r.id},{r.name},{r.count}")
    return "\n".join(lines)
EOF
  b2=$(commit_file src/export_csv.py 'feat(export): csv serializer')

  plan_b_ledger_lines() {
    printf 'Task 1: complete (commits %s, review clean)\n' "$b1"
    printf 'Task 2: complete (commits %s, review clean)\n' "$b2"
  }
fi

case "$scenario/$layout" in
  s1/flat)
    mkdir -p .superpowers/sdd
    plan_a_ledger_lines > .superpowers/sdd/progress.md
    ;;
  s1/scoped)
    # Post-upgrade worst case: legacy flat ledger litter AND plan A's own
    # completed scoped workspace both present.
    mkdir -p .superpowers/sdd/2026-07-01-widget-backend
    printf '*\n' > .superpowers/sdd/.gitignore
    plan_a_ledger_lines > .superpowers/sdd/progress.md
    {
      printf '# SDD ledger — plan: docs/plans/2026-07-01-widget-backend.md\n\n'
      plan_a_ledger_lines
    } > .superpowers/sdd/2026-07-01-widget-backend/progress.md
    ;;
  s2/flat)
    mkdir -p .superpowers/sdd
    plan_b_ledger_lines > .superpowers/sdd/progress.md
    ;;
  s2/scoped)
    mkdir -p .superpowers/sdd/2026-07-06-widget-export
    printf '*\n' > .superpowers/sdd/.gitignore
    {
      printf '# SDD ledger — plan: docs/plans/2026-07-06-widget-export.md\n\n'
      plan_b_ledger_lines
    } > .superpowers/sdd/2026-07-06-widget-export/progress.md
    ;;
  *)
    echo "unknown scenario/layout: $scenario/$layout" >&2
    exit 2
    ;;
esac
```

## Приложение B: запрос сценария

На каждый повтор назначался новый субагент модели `sonnet` с `subagent_type` `general-purpose`; он получал приведённый ниже дословный запрос, в котором заменялись только `<SKILL_DIR>` и `<FIXTURE_REPO>`. Для GREEN `<SKILL_DIR>` указывал на `skills/subagent-driven-development` этой ветки; для контроля S2 RED — на выпущенное дерево, извлечённое из git через `git archive 4118245`.

Смысл запроса: продолжить после сжатия контекста выполнение плана экспорта, перечитать навык и восстановить состояние. Разрешалось читать файлы, выполнять команды git и скрипты навыка; запрещалось запускать субагентов и реализовывать задачи. Итоговый отчёт должен содержать проверенные журналы, завершённые задачи собственного плана и первую задачу для отправки. Оригинал оставлен для воспроизводимости:

```
<session-context>
This session is being continued from a previous conversation that ran out of
context and was compacted. Summary of the earlier portion:

- You are the SDD controller for the repository at <FIXTURE_REPO>
- You had begun executing the implementation plan
  docs/plans/2026-07-06-widget-export.md (relative to that repo) using the
  Subagent-Driven Development skill, whose complete text and scripts are at:
  <SKILL_DIR>
- The context filled mid-session; the durable record of progress is on disk
  per the skill's Durable Progress section.
</session-context>

Continue executing the plan. Re-read the skill's SKILL.md to re-anchor on the
process, recover your place, and continue.

Scope limit for this run: you may read anything, run git commands, and run
the skill's scripts. Do NOT dispatch any subagents and do NOT implement any
tasks. Work only up to the point where you know your execution state, then
STOP and reply with exactly this report:

1. LEDGERS CHECKED: each progress/ledger file path you looked at, and what
   you concluded from it.
2. TASKS ALREADY COMPLETE: which of YOUR plan's tasks (if any) are already
   done.
3. FIRST DISPATCH: which task you will dispatch next.

Be concrete and terse. That report is your entire deliverable.
```

## Ограничения

Пять повторов на вариант дают ориентировочный сигнал, а не статистически надёжный результат. Сценарий измеряет решение о возобновлении, а не выполнение всего плана; `tool_uses` лишь приблизительно отражает стоимость. Повторно запускаемый сценарий следует добавить в superpowers-evals отдельно.

Артефакты RED — дословные ответы — сохранены во временных каталогах из истории заметок оценки; см. git log для `2026-07-06-sdd-plan-scoped-workspace-eval-notes-red.md`. Артефакты этого раунда — 15 тестовых репозиториев, все 15 дословных ответов `<arm>-repN.reply.md`, первая строка которых содержит `tool_uses`, и фактически использованный генератор — сохранены во временном каталоге ОС `/var/folders/g6/_sjng8h14gs3xt6c7t72w0180000gn/T/tmp.eSJKC2JemT`. Этот путь также записан в `/tmp/sdd-eval-root-v3.path`.
