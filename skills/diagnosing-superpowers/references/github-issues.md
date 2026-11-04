# Обращения в GitHub

Используй `gh`, если он установлен и авторизован: он обрабатывает авторизацию, ограничения запросов и JSON. Иначе используй публичный API через curl, а если и он недоступен — передай URL пользователю.

## Поиск

```bash
gh search issues --repo obra/superpowers --limit 10 "<terms>" \
  --json number,state,title --jq '.[] | "\(.number)\t\(.state)\t\(.title)"'
```

Без `gh`: неавторизованный доступ, десять запросов в минуту:

```bash
curl -s -H "Accept: application/vnd.github+json" \
  "https://api.github.com/search/issues?q=repo:obra/superpowers+is:issue+<url-encoded terms>&per_page=10" \
  | jq -r '.items[] | "\(.number)\t\(.state)\t\(.title)"'
```

Без curl передай пользователю `https://github.com/obra/superpowers/issues?q=<terms>`.

## Создание обращения

Запиши заполненный `templates/issue.md` в рабочую область и покажи точный текст. После одобрения:

```bash
gh issue create --repo obra/superpowers --title "<title>" --body-file <path> \
  --label bug --label automated-issue-report
```

GitHub молча отбрасывает метки, если у автора нет прав push, поэтому они добавляются только участникам с доступом. При этом в нижней части шаблона указывается, что обращение создано навыком. `gh` не прикрепляет файлы: после создания обращения передай пользователю путь к комплекту для прикрепления через браузер.

Без `gh` передай заполненную ссылку на шаблон `bug_report.md`, который добавляет метку `bug` любому автору:

```text
https://github.com/obra/superpowers/issues/new?template=bug_report.md&title=<url-encoded title>&body=<url-encoded body>
```

GitHub отклоняет URL длиннее приблизительно 8000 символов. В этом случае передай ссылку только с заголовком и попроси пользователя вставить текст из файла.
