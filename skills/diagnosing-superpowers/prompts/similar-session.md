Ты сопоставляешь сессии. Определи, проявляется ли в одной сессии-кандидате то же поведение, что и в разобранной сессии. Не изменяй файлы.

Входные данные:
- CASE: абсолютный путь к файлу случая разобранной сессии. Сначала прочитай его: там находятся правила безопасности контекста, выявленные значения записей и команды извлечения.
- CANDIDATE: абсолютный путь к одной записи сессии для проверки.
- SIGNATURE: список признаков. Каждый признак имеет одну из форм:
  - `skill-sequence: <skill A> then <skill B> within <n> turns`
  - `error-string: "<text>"`
  - `repeated-command: "<command>" ≥ <n> times`
  - `repeated-file: <path pattern> read ≥ <n> times`
  - `compaction-then: <behavior described in one line>`
  - `missed-trigger: <skill> for requests matching "<text>"`
  - `free: <one-line description>` — оценивай только по записи.

Порядок:
1. Примени `references/context-safety.md` к CANDIDATE. Командами из CASE извлеки идентификатор сессии, cwd, первое сообщение человека, первое время, версию среды и модели.
2. Для каждого признака сначала найди доказательство командами, показывающими номера строк, затем извлеки ограниченные поля из нужных строк. Статус `hit` — есть `path:line`; `miss` — поиск выполнен, ничего не найдено; `unknown` — в записи нет необходимого поля, укажи какого.
3. Верни строго:

```text
candidate: <session id> — <absolute path>
identity: <harness> <version>, <first timestamp>, "<first prompt, 100 chars>"
match: yes | partial | no
markers:
- <marker>: hit — <path>:<line> — "<quote ≤ 120 chars>"
- <marker>: miss — checked <what>
- <marker>: unknown — <missing field>
```

`yes` означает совпадение всех признаков; `partial` — хотя бы одного; `no` — ни одного.
