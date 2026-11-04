# Диагностика сессии: <session-id>

Report path: ~/.superpowers/diagnosing-superpowers/<session-id>/report.md
Written: <ISO timestamp>

## 1. Постановка проблемы — ОБЯЗАТЕЛЬНО

<Скопировать из файла случая.>

## 2. Вывод разбора — ОБЯЗАТЕЛЬНО

<Что доказательства показывают о произошедшем вокруг проблемы. Текст с `path:line` после каждого утверждения. Укажи уверенность: high / medium / low, и что её повысило бы. Не указывай, что следует делать Superpowers.>

## 3. Окружение — ОБЯЗАТЕЛЬНО

- OS:
- Harness and version:
- Models seen:
- Superpowers install root / version / git sha:
- Skill files read or injected (sha1 table from the case file):
- Other plugins, extensions, MCP servers:
- Instruction files present (paths only):

Каждое поле окружения и наблюдение о навыках пометь как историческое доказательство, непроверенный снимок, текущее наблюдение или неизвестно; укажи местоположение подтверждения.

## 4. Изученные сессии — ОБЯЗАТЕЛЬНО

| Role | Session id | Absolute path | Lines | Bytes |
|---|---|---|---|---|

Отклонённые кандидаты: <id — путь — причина> или "none".

## 5. Хронология — ОБЯЗАТЕЛЬНО

По одной строке на каждый запрос, введённый человеком. Столбец событий содержит вызванные навыки, запущенных субагентов, сжатие контекста, ошибки, возобновления и прерывания.

| Turn | Line | Time | Request (one line) | Events |
|---|---|---|---|---|

## 6. Находки — ОБЯЗАТЕЛЬНО, отдельный подраздел на направление

Каждый вывод:
```text
- finding: <одно предложение>
  evidence: <path:line> — "<короткая цитата>"
  turns: <first>–<last>
  confidence: high | medium | low
```
Если в направлении нечего сообщить: `none found — checked: <что проверено>`.

### 6.1 Хронология навыков
### 6.2 Соблюдение плана
### 6.3 Повторная работа
### 6.4 Затруднения
### 6.5 Доказательства качества
### 6.6 Противоречия запросов
### 6.7 Расходы и время
### 6.8 Другие использованные плагины и навыки

## 7. Причастность Superpowers — ОБЯЗАТЕЛЬНО

not indicated | possible | likely

Строки доказательств: <path:line list>. Этот раздел сообщает только о причастности, не называет дефект и не предлагает изменение.

## 8. Охват проверки — ОБЯЗАТЕЛЬНО

- Not read: <диапазоны, файлы и причины>
- Harness features unavailable: <список или none>
- Session was in progress at read time: yes/no
- For your human partner to double-check: <список или none>

## 9. Похожие сессии — только по запросу

| Session id | Path | Date | Harness | Matched | Did not match |
|---|---|---|---|---|---|
