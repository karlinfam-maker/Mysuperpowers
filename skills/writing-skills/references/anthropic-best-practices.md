# Рекомендации по созданию навыков

> Как создавать навыки, которые агенты смогут находить и успешно применять.

Хорошие навыки кратки, структурированы и проверены на реальном использовании. Это руководство помогает принимать практические решения при их создании.

Общие сведения о работе навыков: [обзор Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview).

**Примечание к переводу:** это справочный материал Anthropic, включённый в оригинальный Superpowers. В проектах Валерия приоритет имеют СУИИР, прямые указания пользователя и действующие инструкции среды. Названия полей, пути, команды и программный код сохраняются для совместимости.

## Основные принципы

### Краткость важна

[Окно контекста](https://platform.claude.com/docs/en/build-with-claude/context-windows) — общий ресурс. Навык делит его со всем остальным, что нужно агенту:

* Системным запросом.
* Историей разговора.
* Метаданными других навыков.
* Непосредственным запросом пользователя.

Не каждый токен навыка расходуется сразу. При запуске предварительно загружаются только метаданные всех навыков — имя и описание. SKILL.md читается, когда навык становится применимым, а дополнительные файлы — по необходимости. Тем не менее краткость SKILL.md важна: после загрузки каждый токен конкурирует с историей разговора и другим контекстом.

**Исходное предположение:** агент уже хорошо разбирается во многих вопросах.

Добавляй только тот контекст, которого у агента нет. Для каждой детали спрашивай:

* «Действительно ли агенту нужно это объяснение?»
* «Можно ли предположить, что он это знает?»
* «Оправдывает ли абзац расход токенов?»

**Хороший пример: кратко**, примерно 50 токенов:

````markdown  theme={null}
## Извлечение текста PDF

Используй pdfplumber:

```python
import pdfplumber

with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```
````

**Плохой пример: слишком подробно**, примерно 150 токенов:

```markdown  theme={null}
## Извлечение текста PDF

PDF — распространённый формат файлов, которые могут содержать текст,
изображения и другое содержимое. Для извлечения текста нужна библиотека.
Библиотек для работы с PDF много, но мы рекомендуем pdfplumber, потому
что она проста и подходит для большинства задач. Сначала установи её с
помощью pip. Затем можно использовать следующий код…
```

Краткий вариант исходит из того, что агент уже знает, что такое PDF и как работают библиотеки.

### Подбирай уровень свободы

Соотноси точность инструкций с хрупкостью и вариативностью задачи.

**Высокая свобода** — текстовые указания:

Применяй, когда:

* Допустимы разные подходы.
* Решение зависит от контекста.
* Подход определяется практическими ориентирами.

Пример:

```markdown  theme={null}
## Проверка кода

1. Изучи структуру и организацию кода.
2. Проверь возможные ошибки и крайние случаи.
3. Предложи улучшения читаемости и поддержки.
4. Проверь соблюдение соглашений проекта.
```

**Средняя свобода** — псевдокод или скрипты с параметрами:

Применяй, когда:

* Есть предпочтительный подход.
* Допустимы некоторые варианты.
* Настройки влияют на поведение.

Пример:

````markdown  theme={null}
## Формирование отчёта

Используй шаблон и адаптируй его:

```python
def generate_report(data, format="markdown", include_charts=True):
    # Process data
    # Generate output in specified format
    # Optionally include visualizations
```
````

**Низкая свобода** — точные скрипты с небольшим числом параметров или без них:

Применяй, когда:

* Операция хрупкая и легко ошибиться.
* Критична одинаковость выполнения.
* Необходимо соблюдать определённую последовательность.

Пример:

````markdown  theme={null}
## Миграция базы данных

Выполни строго эту команду:

```bash
python scripts/migrate.py --verify --backup
```

Не изменяй команду и не добавляй параметры.
````

**Аналогия:** представь агента роботом, который ищет путь:

* **Узкий мост с обрывами:** безопасный путь только один. Нужны точные инструкции и ограничения — низкая свобода. Пример: миграция базы с обязательным порядком действий.
* **Открытое поле без опасностей:** есть много успешных путей. Достаточно общего направления и самостоятельного выбора агента — высокая свобода. Пример: проверка кода, где решение зависит от контекста.

### Проверяй на всех моделях, которые планируешь использовать

Навыки дополняют модели, поэтому их результат зависит от выбранной модели. Проверяй навык на всех моделях, которые планируешь использовать.

**Вопросы по моделям, приведённым в исходном документе:**

* **Claude Haiku** — быстрый и экономичный: достаточно ли указаний?
* **Claude Sonnet** — сбалансированный: ясна и экономична ли инструкция?
* **Claude Opus** — мощные рассуждения: нет ли избыточных объяснений?

То, что идеально подходит Opus, может требовать подробностей для Haiku. Если навык используется на разных моделях, стремись к инструкции, которая хорошо работает на каждой.

## Структура навыка

<Note>
  **Заголовок YAML:** SKILL.md требует два поля:

  * `name` — понятное название навыка, не более 64 символов.
  * `description` — описание того, что делает навык и когда его использовать, не более 1024 символов.

  Полное описание структуры: [обзор Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#skill-structure).
</Note>

### Соглашения об именах

Придерживайся единого подхода к названиям, чтобы на навыки было проще ссылаться и их было удобнее обсуждать. В английских технических именах исходный документ рекомендует форму глагола с `-ing`, поскольку она описывает действие.

**Хорошие примеры английских названий:**

* «Processing PDFs» — обработка PDF.
* «Analyzing spreadsheets» — анализ таблиц.
* «Managing databases» — управление базами данных.
* «Testing code» — проверка кода.
* «Writing documentation» — написание документации.

**Допустимые альтернативы:**

* Именные сочетания: «PDF Processing», «Spreadsheet Analysis».
* Формулировки действия: «Process PDFs», «Analyze Spreadsheets».

**Избегай:**

* Расплывчатых названий: «Helper», «Utils», «Tools».
* Слишком общих: «Documents», «Data», «Files».
* Разных несогласованных подходов внутри одной библиотеки навыков.

Единые названия помогают:

* Ссылаться на навыки в документации и разговорах.
* Сразу понимать назначение.
* Организовывать и искать навыки.
* Поддерживать целостную библиотеку.

При переводе существующих навыков сохраняй их технические идентификаторы, чтобы не нарушить связи.

### Как писать понятные описания

Поле `description` помогает найти навык. В рекомендациях Anthropic оно должно содержать и назначение навыка, и условия применения.

<Warning>
  **Пиши от третьего лица.** Описание добавляется в системный контекст; разные точки зрения могут мешать обнаружению.

  * **Хорошо:** «Обрабатывает файлы Excel и формирует отчёты».
  * **Избегай:** «Я помогу тебе обработать Excel».
  * **Избегай:** «Ты можешь использовать это для обработки Excel».
</Warning>

**Будь конкретен и используй ключевые слова:** укажи действия навыка и конкретные ситуации или признаки его применения.

У каждого навыка одно поле description. Оно критично при выборе: агент может выбирать из сотни и более навыков. Описание должно давать достаточно сведений для выбора, а подробности реализации находятся в SKILL.md.

**Примеры удачных описаний:**

Навык работы с PDF:

```yaml  theme={null}
description: Извлекает текст и таблицы из PDF, заполняет формы и объединяет документы. Используй при работе с PDF, формами и извлечением документов.
```

Навык анализа Excel:

```yaml  theme={null}
description: Анализирует таблицы Excel, создаёт сводные таблицы и графики. Используй при анализе Excel, табличных данных или файлов .xlsx.
```

Навык подготовки коммитов Git:

```yaml  theme={null}
description: Создаёт содержательные сообщения коммитов по git diff. Используй, когда пользователь просит написать сообщение коммита или проверить подготовленные изменения.
```

**Избегай неопределённых описаний:**

```yaml  theme={null}
description: Помогает с документами
```

```yaml  theme={null}
description: Обрабатывает данные
```

```yaml  theme={null}
description: Выполняет действия с файлами
```

### Постепенное раскрытие информации

SKILL.md служит обзором и направляет агента к дополнительным материалам по необходимости — как оглавление руководства. См. [как работают навыки](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#how-skills-work).

**Практические рекомендации:**

* Для оптимальной работы держи основной текст SKILL.md в пределах 500 строк.
* При приближении к пределу выноси содержание в отдельные файлы.
* Организуй инструкции, код и материалы по подходам ниже.

#### От простого к сложному

Базовый навык начинается с одного SKILL.md с метаданными и инструкциями:

<img src="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=87782ff239b297d9a9e8e1b72ed72db9" alt="Simple SKILL.md file showing YAML frontmatter and markdown body" data-og-width="2048" width="2048" data-og-height="1153" height="1153" data-path="images/agent-skills-simple-file.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=280&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=c61cc33b6f5855809907f7fda94cd80e 280w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=560&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=90d2c0c1c76b36e8d485f49e0810dbfd 560w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=840&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=ad17d231ac7b0bea7e5b4d58fb4aeabb 840w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=1100&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=f5d0a7a3c668435bb0aee9a3a8f8c329 1100w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=1650&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=0e927c1af9de5799cfe557d12249f6e6 1650w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-simple-file.png?w=2500&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=46bbb1a51dd4c8202a470ac8c80a893d 2500w" />

По мере роста можно добавлять материалы, которые агент загружает только при необходимости:

<img src="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=a5e0aa41e3d53985a7e3e43668a33ea3" alt="Bundling additional reference files like reference.md and forms.md." data-og-width="2048" width="2048" data-og-height="1327" height="1327" data-path="images/agent-skills-bundling-content.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=280&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=f8a0e73783e99b4a643d79eac86b70a2 280w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=560&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=dc510a2a9d3f14359416b706f067904a 560w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=840&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=82cd6286c966303f7dd914c28170e385 840w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=1100&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=56f3be36c77e4fe4b523df209a6824c6 1100w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=1650&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=d22b5161b2075656417d56f41a74f3dd 1650w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-bundling-content.png?w=2500&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=3dd4bdd6850ffcc96c6c45fcb0acd6eb 2500w" />

Полный каталог навыка может выглядеть так:

```
pdf/
├── SKILL.md              # Main instructions (loaded when triggered)
├── FORMS.md              # Form-filling guide (loaded as needed)
├── reference.md          # API reference (loaded as needed)
├── examples.md           # Usage examples (loaded as needed)
└── scripts/
    ├── analyze_form.py   # Utility script (executed, not loaded)
    ├── fill_form.py      # Form filling script
    └── validate.py       # Validation script
```

#### Подход 1: общий обзор со ссылками

````markdown  theme={null}
---
name: PDF Processing
description: Извлекает текст и таблицы из PDF, заполняет формы и объединяет документы. Используй при работе с PDF, формами и извлечением документов.
---

# Работа с PDF

## Быстрый старт

Извлечение текста с помощью pdfplumber:
```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```

## Расширенные возможности

**Заполнение форм:** полное руководство — [FORMS.md](FORMS.md).
**Справочник API:** все методы — в [REFERENCE.md](REFERENCE.md).
**Примеры:** распространённые приёмы — в [EXAMPLES.md](EXAMPLES.md).
````

Агент загружает FORMS.md, REFERENCE.md или EXAMPLES.md только при необходимости.

#### Подход 2: организация по предметным областям

Для навыка с несколькими областями разделяй материалы, чтобы не загружать лишний контекст. При вопросе о продажах агенту нужны схемы продаж, а не финансы или маркетинг. Это уменьшает расход токенов и удерживает внимание на задаче.

```
bigquery-skill/
├── SKILL.md (overview and navigation)
└── reference/
    ├── finance.md (revenue, billing metrics)
    ├── sales.md (opportunities, pipeline)
    ├── product.md (API usage, features)
    └── marketing.md (campaigns, attribution)
```

````markdown SKILL.md theme={null}
# Анализ данных BigQuery

## Доступные наборы данных

**Финансы:** выручка, ARR, счета → [reference/finance.md](reference/finance.md).
**Продажи:** возможности, воронка, клиенты → [reference/sales.md](reference/sales.md).
**Продукт:** использование API, функции, внедрение → [reference/product.md](reference/product.md).
**Маркетинг:** кампании, атрибуция, email → [reference/marketing.md](reference/marketing.md).

## Быстрый поиск

Найдите нужные метрики через grep:

```bash
grep -i "revenue" reference/finance.md
grep -i "pipeline" reference/sales.md
grep -i "api usage" reference/product.md
```
````

#### Подход 3: условное подключение деталей

Покажи основные сведения и добавь ссылки на расширенные:

```markdown  theme={null}
# Работа с DOCX

## Создание документов

Для новых документов используйте docx-js. См. [DOCX-JS.md](DOCX-JS.md).

## Редактирование документов

Для простых изменений редактируйте XML напрямую.

**Для отслеживания изменений:** [REDLINING.md](REDLINING.md).
**Подробности OOXML:** [OOXML.md](OOXML.md).
```

Агент прочитает REDLINING.md или OOXML.md только тогда, когда пользователю понадобятся эти функции.

### Избегай глубоко вложенных ссылок

Агент может прочитать файл лишь частично, если он указан внутри другого справочного файла. При вложенных ссылках он может использовать, например, `head -100` для предварительного просмотра и пропустить важные сведения.

**Размещай ссылки на один уровень от SKILL.md.** Связывай справочники непосредственно с основным файлом, чтобы агент мог прочитать нужные материалы полностью.

**Плохой пример: глубокая вложенность:**

```markdown  theme={null}
# SKILL.md
See [advanced.md](advanced.md)...

# advanced.md
See [details.md](details.md)...

# details.md
Here's the actual information...
```

**Хороший пример: один уровень:**

```markdown  theme={null}
# SKILL.md

**Basic usage**: [instructions in SKILL.md]
**Advanced features**: See [advanced.md](advanced.md)
**API reference**: See [reference.md](reference.md)
**Examples**: See [examples.md](examples.md)
```

### Добавляй содержание в длинные справочники

Если справочник длиннее 100 строк, добавь оглавление в начале. Тогда агент увидит полный перечень доступной информации даже при частичном чтении.

**Пример:**

```markdown  theme={null}
# API Reference

## Contents
- Authentication and setup
- Core methods (create, read, update, delete)
- Advanced features (batch operations, webhooks)
- Error handling patterns
- Code examples

## Authentication and setup
...

## Core methods
...
```

После этого агент может прочитать файл целиком или перейти к нужным разделам.

Подробнее о раскрытии информации через файловую систему — в разделе [«Среда выполнения»](#runtime-environment) ниже.

## Процессы и обратная связь

### Используй процессы для сложных задач

Разбивай сложные действия на последовательные понятные шаги. Для особенно сложного процесса дай контрольный список, который агент сможет скопировать в ответ и отмечать по мере выполнения.

**Пример 1: обобщение исследования**, навык без кода:

````markdown  theme={null}
## Research synthesis workflow

Copy this checklist and track your progress:

```
Research Progress:
- [ ] Step 1: Read all source documents
- [ ] Step 2: Identify key themes
- [ ] Step 3: Cross-reference claims
- [ ] Step 4: Create structured summary
- [ ] Step 5: Verify citations
```

**Step 1: Read all source documents**

Review each document in the `sources/` directory. Note the main arguments and supporting evidence.

**Step 2: Identify key themes**

Look for patterns across sources. What themes appear repeatedly? Where do sources agree or disagree?

**Step 3: Cross-reference claims**

For each major claim, verify it appears in the source material. Note which source supports each point.

**Step 4: Create structured summary**

Organize findings by theme. Include:
- Main claim
- Supporting evidence from sources
- Conflicting viewpoints (if any)

**Step 5: Verify citations**

Check that every claim references the correct source document. If citations are incomplete, return to Step 3.
````

Этот пример показывает процесс анализа без кода. Контрольные списки подходят для любых сложных многоэтапных задач.

**Пример 2: заполнение формы PDF**, навык с кодом:

````markdown  theme={null}
## PDF form filling workflow

Copy this checklist and check off items as you complete them:

```
Task Progress:
- [ ] Step 1: Analyze the form (run analyze_form.py)
- [ ] Step 2: Create field mapping (edit fields.json)
- [ ] Step 3: Validate mapping (run validate_fields.py)
- [ ] Step 4: Fill the form (run fill_form.py)
- [ ] Step 5: Verify output (run verify_output.py)
```

**Step 1: Analyze the form**

Run: `python scripts/analyze_form.py input.pdf`

This extracts form fields and their locations, saving to `fields.json`.

**Step 2: Create field mapping**

Edit `fields.json` to add values for each field.

**Step 3: Validate mapping**

Run: `python scripts/validate_fields.py fields.json`

Fix any validation errors before continuing.

**Step 4: Fill the form**

Run: `python scripts/fill_form.py input.pdf fields.json output.pdf`

**Step 5: Verify output**

Run: `python scripts/verify_output.py output.pdf`

If verification fails, return to Step 2.
````

Чёткие шаги не дают пропустить важную проверку. Контрольный список помогает пользователю и агенту следить за прогрессом.

### Используй циклы обратной связи

**Типичный порядок:** запусти проверку → исправь ошибки → повтори. Этот подход помогает улучшить качество результата.

**Пример 1: соблюдение редакционных правил**, навык без кода:

```markdown  theme={null}
## Content review process

1. Draft your content following the guidelines in STYLE_GUIDE.md
2. Review against the checklist:
   - Check terminology consistency
   - Verify examples follow the standard format
   - Confirm all required sections are present
3. If issues found:
   - Note each issue with specific section reference
   - Revise the content
   - Review the checklist again
4. Only proceed when all requirements are met
5. Finalize and save the document
```

Здесь цикл проверки использует справочный документ вместо скрипта. Роль проверяющего играет STYLE_GUIDE.md: агент читает его и сравнивает с результатом.

**Пример 2: редактирование документа**, навык с кодом:

```markdown  theme={null}
## Document editing process

1. Make your edits to `word/document.xml`
2. **Validate immediately**: `python ooxml/scripts/validate.py unpacked_dir/`
3. If validation fails:
   - Review the error message carefully
   - Fix the issues in the XML
   - Run validation again
4. **Only proceed when validation passes**
5. Rebuild: `python ooxml/scripts/pack.py unpacked_dir/ output.docx`
6. Test the output document
```

Цикл валидации помогает рано обнаруживать ошибки.

## Рекомендации к содержанию

### Избегай быстро устаревающих сведений

Не включай сведения, которые вскоре станут неверными.

**Плохой пример: привязка ко времени:**

```markdown  theme={null}
If you're doing this before August 2025, use the old API.
After August 2025, use the new API.
```

**Хороший пример: отдельный раздел старых подходов:**

```markdown  theme={null}
## Current method

Use the v2 API endpoint: `api.example.com/v2/messages`

## Old patterns

<details>
<summary>Legacy v1 API (deprecated 2025-08)</summary>

The v1 API used: `api.example.com/v1/messages`

This endpoint is no longer supported.
</details>
```

Так исторический контекст сохраняется, не засоряя основные инструкции.

### Используй единые термины

Выбери один термин и применяй его во всём навыке.

**Хорошо — единообразно:**

* Всегда «API endpoint».
* Всегда «field».
* Всегда «extract».

**Плохо — непоследовательно:**

* Смешиваются «API endpoint», «URL», «API route», «path».
* Смешиваются «field», «box», «element», «control».
* Смешиваются «extract», «pull», «get», «retrieve».

Единая терминология помогает агенту понимать и выполнять инструкции.

## Типовые подходы

### Шаблон результата

Давай шаблон выходного формата. Степень строгости должна соответствовать задаче.

**Для строгих требований**, например ответа API или формата данных:

````markdown  theme={null}
## Структура отчёта

ВСЕГДА используйте следующую структуру шаблона:

```markdown
# [Название анализа]

## Краткое содержание
[Ключевые выводы одним абзацем]

## Основные выводы
- Вывод 1 с подтверждающими данными
- Вывод 2 с подтверждающими данными
- Вывод 3 с подтверждающими данными

## Рекомендации
1. Конкретная практическая рекомендация
2. Конкретная практическая рекомендация
```
````

**Для гибких рекомендаций**, когда нужна адаптация:

````markdown  theme={null}
## Структура отчёта

Ниже предложен стандартный формат; адаптируйте его по результатам анализа:

```markdown
# [Название анализа]

## Краткое содержание
[Обзор]

## Основные выводы
[Адаптируйте разделы по результатам исследования]

## Рекомендации
[Адаптируйте к конкретной ситуации]
```

При необходимости меняйте разделы с учётом вида анализа.
````

### Примеры входа и выхода

Если качество результата зависит от примеров, показывай пары «вход → выход», как в обычном запросе:

````markdown  theme={null}
## Commit message format

Generate commit messages following these examples:

**Example 1:**
Input: Added user authentication with JWT tokens
Output:
```
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware
```

**Example 2:**
Input: Fixed bug where dates displayed incorrectly in reports
Output:
```
fix(reports): correct date formatting in timezone conversion

Use UTC timestamps consistently across report generation
```

**Example 3:**
Input: Updated dependencies and refactored error handling
Output:
```
chore: update dependencies and refactor error handling

- Upgrade lodash to 4.17.21
- Standardize error response format across endpoints
```

Follow this style: type(scope): brief description, then detailed explanation.
````

Примеры помогают понять желаемый стиль и детализацию яснее, чем одно описание.

### Условный процесс

Показывай агенту точки выбора:

```markdown  theme={null}
## Процесс изменения документа

1. Определите тип изменения:

   **Создаёте новый материал?** → Следуйте процессу создания ниже.
   **Редактируете существующий материал?** → Следуйте процессу редактирования ниже.

2. Процесс создания:
   - Используйте библиотеку docx-js.
   - Создайте документ с нуля.
   - Экспортируйте в .docx.

3. Процесс редактирования:
   - Распакуйте существующий документ.
   - Измените XML напрямую.
   - Проверяйте после каждого изменения.
   - После завершения упакуйте документ обратно.
```

<Tip>
  Если процесс становится большим или сложным, вынеси части в отдельные файлы и укажи, какой файл читать для конкретной задачи.
</Tip>

## Оценка и улучшение

### Сначала создавай проверки

**Создавай проверки ДО написания объёмной документации.** Это помогает убедиться, что навык решает реальные, а не воображаемые проблемы.

**Разработка на основе оценки:**

1. **Найди пробелы:** дай агенту типичные задачи без навыка. Зафиксируй конкретные ошибки или недостающий контекст.
2. **Создай проверки:** подготовь три сценария, проверяющих эти пробелы.
3. **Установи исходный уровень:** измерь результат агента без навыка.
4. **Напиши минимум инструкций:** создай достаточно содержания, чтобы устранить пробелы и пройти проверки.
5. **Улучшай:** запускай проверки, сравнивай с исходным уровнем и уточняй навык.

Так решаются существующие проблемы, а не предполагаемые требования, которые могут не возникнуть.

**Структура проверки:**

```json  theme={null}
{
  "skills": ["pdf-processing"],
  "query": "Extract all text from this PDF file and save it to output.txt",
  "files": ["test-files/document.pdf"],
  "expected_behavior": [
    "Successfully reads the PDF file using an appropriate PDF processing library or command-line tool",
    "Extracts text content from all pages in the document without missing any pages",
    "Saves the extracted text to a file named output.txt in a clear, readable format"
  ]
}
```

<Note>
  Этот пример показывает оценку по данным с простыми критериями. На момент написания исходного материала встроенного запуска таких проверок не предоставлялось; пользователь может создать собственную систему. Проверки служат основанием для оценки эффективности навыка.
</Note>

### Разрабатывай навыки вместе с агентом

Авторы рекомендуют включать агента в разработку навыка. Одна копия — «агент A» — помогает создать и улучшить навык для другой — «агента B». Агент A разрабатывает инструкции, агент B проверяет их на реальных задачах. Способ опирается на знание моделями как формы инструкций, так и информации, необходимой агенту.

**Создание нового навыка:**

1. **Выполни задачу без навыка.** Работай с агентом A обычными запросами. По ходу передавай контекст, предпочтения и знания о процессе; обрати внимание, что приходится сообщать неоднократно.
2. **Найди повторно используемый подход.** После завершения определи, какой переданный контекст пригодится в похожих задачах. Например, при анализе BigQuery это могут быть имена таблиц, определения полей, правило «исключать тестовые аккаунты» и типичные запросы.
3. **Попроси агента A создать навык.** Например: «Создай навык для только что использованного анализа BigQuery. Включи схемы таблиц, правила имён и фильтрацию тестовых аккаунтов».

   <Tip>
     В исходном материале отмечается, что современные агенты обычно понимают формат навыков: можно попросить их подготовить структурированный SKILL.md с заголовком и основным текстом. Доступность и порядок создания зависят от конкретной среды.
   </Tip>

4. **Проверь краткость.** Убери лишние объяснения. Например: «Убери объяснение значения win rate: агенту это уже известно».
5. **Улучши организацию информации.** Например: «Вынеси схему таблицы в отдельный справочник: позже могут добавиться таблицы».
6. **Проверь на похожих задачах.** Используй навык с агентом B — новой копией с загруженным навыком. Посмотри, находит ли он нужное, соблюдает ли правила и успешно ли выполняет задачу.
7. **Улучшай по наблюдениям.** Если агент B ошибается, сообщи агенту A конкретику: «Агент забыл фильтрацию дат за Q4. Добавить раздел о фильтрах дат?»

**Улучшение существующих навыков:**

Чередуй работу с агентом A, который помогает улучшить навык, проверку с агентом B и наблюдение за поведением B:

1. Давай агенту B реальные рабочие задачи с загруженным навыком, а не только искусственные сценарии.
2. Отмечай, где он затрудняется, преуспевает или делает неожиданный выбор. Например, подготовил запрос региональных продаж, но не исключил тестовые аккаунты, хотя правило есть в навыке.
3. Передай агенту A текущий SKILL.md и наблюдение. Например: «Агент не исключил тестовые аккаунты при региональном отчёте. Возможно, правило недостаточно заметно?»
4. Рассмотри предложения агента A: перестановку разделов, более сильную формулировку «ОБЯЗАТЕЛЬНО фильтровать» или изменение процесса.
5. Внеси подходящие изменения и снова проверь с агентом B на похожих запросах.
6. Повторяй цикл наблюдения, улучшения и проверки при новых сценариях. Изменения основываются на поведении, а не догадках.

**Обратная связь команды:**

1. Передай навыки коллегам и наблюдай применение.
2. Спроси: срабатывает ли навык вовремя, понятны ли инструкции, чего не хватает?
3. Учти ответы для устранения слепых зон.

**Почему подход может работать:** агент A понимает потребности агентов, пользователь предоставляет предметную экспертизу, агент B показывает пробелы в реальном использовании, а повторные улучшения основываются на наблюдениях.

### Наблюдай, как агенты используют навыки

При улучшении обращай внимание:

* **Неожиданный путь изучения:** агент читает файлы в необычном порядке? Возможно, структура не так понятна.
* **Пропущенные связи:** агент не переходит к важным файлам? Возможно, ссылки должны быть явнее или заметнее.
* **Чрезмерное обращение к отдельным разделам:** агент постоянно читает один файл? Возможно, содержание стоит перенести в SKILL.md.
* **Игнорируемые материалы:** агент ни разу не открыл включённый файл? Возможно, он не нужен или в главной инструкции плохо обозначен.

Улучшай структуру по наблюдениям. Метаданные `name` и `description` особенно важны: агент использует их при решении, вызывать ли навык. Они должны ясно показывать назначение и условия применения.

## Антипаттерны

### Не используй пути в стиле Windows

Даже в Windows в примерах используй прямую косую черту:

* ✓ **Хорошо:** `scripts/helper.py`, `reference/guide.md`.
* ✗ **Плохо:** `scripts\helper.py`, `reference\guide.md`.

Пути в стиле Unix работают на разных платформах; обратные косые черты вызывают ошибки в Unix.

### Не предлагай слишком много вариантов

Не перечисляй несколько подходов без необходимости:

````markdown  theme={null}
**Bad example: Too many choices** (confusing):
"You can use pypdf, or pdfplumber, or PyMuPDF, or pdf2image, or..."

**Good example: Provide a default** (with escape hatch):
"Use pdfplumber for text extraction:
```python
import pdfplumber
```

For scanned PDFs requiring OCR, use pdf2image with pytesseract instead."
````

<a id="advanced-skills-with-executable-code"></a>
## Дополнительно: навыки с исполняемым кодом

Следующие разделы относятся к навыкам со скриптами. Если навык содержит только Markdown-инструкции, переходи к [контрольному списку](#checklist-for-effective-skills).

### Решай проблемы в скрипте

При написании скриптов навыка обрабатывай ошибки, не перекладывая их на агента.

**Хороший пример: явная обработка ошибок:**

```python  theme={null}
def process_file(path):
    """Process a file, creating it if it doesn't exist."""
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        # Create file with default content instead of failing
        print(f"File {path} not found, creating default")
        with open(path, 'w') as f:
            f.write('')
        return ''
    except PermissionError:
        # Provide alternative instead of failing
        print(f"Cannot access {path}, using default")
        return ''
```

**Плохой пример: ошибка оставлена агенту:**

```python  theme={null}
def process_file(path):
    # Just fail and let the agent figure it out
    return open(path).read()
```

Параметры конфигурации тоже следует обосновывать и документировать, чтобы избежать «магических констант» — закон Аустерхаута. Если автор не знает нужное значение, как его определит агент?

**Хороший пример: значение объяснено:**

```python  theme={null}
# HTTP requests typically complete within 30 seconds
# Longer timeout accounts for slow connections
REQUEST_TIMEOUT = 30

# Three retries balances reliability vs speed
# Most intermittent failures resolve by the second retry
MAX_RETRIES = 3
```

**Плохой пример: непонятные числа:**

```python  theme={null}
TIMEOUT = 47  # Why 47?
RETRIES = 5   # Why 5?
```

### Предоставляй вспомогательные скрипты

Даже если агент может написать скрипт, готовый инструмент даёт преимущества:

* Может быть надёжнее сгенерированного кода.
* Экономит токены: код не обязательно загружать в контекст.
* Экономит время на генерацию.
* Обеспечивает одинаковость повторных применений.

<img src="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=4bbc45f2c2e0bee9f2f0d5da669bad00" alt="Bundling executable scripts alongside instruction files" data-og-width="2048" width="2048" data-og-height="1154" height="1154" data-path="images/agent-skills-executable-scripts.png" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=280&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=9a04e6535a8467bfeea492e517de389f 280w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=560&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=e49333ad90141af17c0d7651cca7216b 560w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=840&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=954265a5df52223d6572b6214168c428 840w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=1100&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=2ff7a2d8f2a83ee8af132b29f10150fd 1100w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=1650&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=48ab96245e04077f4d15e9170e081cfb 1650w, https://mintcdn.com/anthropic-claude-docs/4Bny2bjzuGBK7o00/images/agent-skills-executable-scripts.png?w=2500&fit=max&auto=format&n=4Bny2bjzuGBK7o00&q=85&s=0301a6c8b3ee879497cc5b5483177c90 2500w" />

Схема показывает совместную работу скриптов и инструкций. Файл инструкции `forms.md` ссылается на скрипт; агент может выполнить его без загрузки содержимого в контекст.

**Важное различие:** явно укажи агенту, что нужно:

* **Выполнить скрипт**, чаще всего: «Запусти `analyze_form.py`, чтобы извлечь поля».
* **Прочитать как справку** для сложной логики: «Посмотри алгоритм извлечения полей в `analyze_form.py`».

Для большинства утилит предпочтительно выполнение: оно надёжнее и экономичнее. Подробности — ниже в [описании среды](#runtime-environment).

**Пример:**

````markdown  theme={null}
## Utility scripts

**analyze_form.py**: Extract all form fields from PDF

```bash
python scripts/analyze_form.py input.pdf > fields.json
```

Output format:
```json
{
  "field_name": {"type": "text", "x": 100, "y": 200},
  "signature": {"type": "sig", "x": 150, "y": 500}
}
```

**validate_boxes.py**: Check for overlapping bounding boxes

```bash
python scripts/validate_boxes.py fields.json
# Returns: "OK" or lists conflicts
```

**fill_form.py**: Apply field values to PDF

```bash
python scripts/fill_form.py input.pdf fields.json output.pdf
```
````

### Используй визуальный анализ

Если входные данные можно показать как изображения, агент может анализировать их визуально:

````markdown  theme={null}
## Form layout analysis

1. Convert PDF to images:
   ```bash
   python scripts/pdf_to_images.py form.pdf
   ```

2. Analyze each page image to identify form fields
3. The agent can see field locations and types visually
````

<Note>
  Для этого примера потребуется создать скрипт `pdf_to_images.py`.
</Note>

Визуальные возможности агента помогают понять расположение и структуру.

### Создавай проверяемые промежуточные результаты

В сложных открытых задачах агенты могут ошибаться. Подход «спланировать → проверить → выполнить» помогает обнаружить ошибки раньше: агент сначала создаёт структурированный план, затем проверяет его скриптом и только после этого выполняет.

**Пример:** нужно обновить 50 полей формы PDF по таблице. Без проверки агент может указать несуществующие поля, создать противоречивые значения, пропустить обязательные поля или неверно применить изменения.

**Решение:** используй описанный выше процесс заполнения PDF и добавь промежуточный `changes.json`, проверяемый до применения: анализ → **файл плана** → **проверка плана** → выполнение → итоговая проверка.

**Преимущества:**

* **Раннее обнаружение ошибок:** проблемы находятся до изменений.
* **Машинная проверка:** скрипты дают объективный результат.
* **Обратимость планирования:** можно уточнять план, не меняя оригиналы.
* **Понятная отладка:** сообщения указывают конкретную проблему.

**Когда применять:** пакетные операции, разрушительные изменения, сложные правила проверки и задачи с высокой ценой ошибки.

**Совет:** выводи конкретные сообщения, например «Поле signature_date не найдено. Доступные поля: customer_name, order_total, signature_date_signed», чтобы агент мог исправить ошибку.

### Зависимости пакета

Навыки работают в среде выполнения с ограничениями платформы. Исходный документ указывает:

* **claude.ai:** возможна установка пакетов npm и PyPI и получение репозиториев GitHub.
* **Anthropic API:** сетевой доступ и установка пакетов во время работы недоступны.

Перечисли необходимые пакеты в SKILL.md и проверь их доступность в [документации инструмента выполнения кода](https://platform.claude.com/docs/en/agents-and-tools/tool-use/code-execution-tool). Возможности зависят от используемой среды и могут меняться.

<a id="runtime-environment"></a>
<a id="runtime-environment"></a>

### Среда выполнения

Навыки работают в среде с доступом к файлам, командам bash и выполнению кода. Общая архитектура описана в [обзоре Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#the-skills-architecture).

**Как агент получает доступ к навыкам:**

1. **Метаданные заранее загружены:** при старте имена и описания из YAML-frontmatter навыков добавляются в системный контекст.
2. **Файлы читаются по необходимости:** агент использует инструменты чтения для SKILL.md и других файлов.
3. **Скрипты выполняются экономно:** утилиты запускаются через bash без обязательной загрузки всего кода в контекст; токены расходуются на вывод.
4. **Большие файлы не расходуют контекст до чтения:** справочники, данные и документация учитываются после обращения к ним.

**Следствия для автора:**

* **Пути важны:** агент перемещается по каталогу навыка. Используй прямые косые черты `reference/guide.md`, а не обратные.
* **Давай понятные имена:** `form_validation_rules.md`, а не `doc2.md`.
* **Организуй поиск по области или функции:** хорошо `reference/finance.md`, `reference/sales.md`; плохо `docs/file1.md`, `docs/file2.md`.
* **Включай полные материалы:** справочники API, большие примеры и наборы данных не расходуют контекст до чтения.
* **Для детерминированных операций предпочитай скрипты:** создай `validate_form.py`, а не проси каждый раз генерировать проверку.
* **Явно различай выполнение и чтение:** «запусти `analyze_form.py`» означает выполнение; «посмотри алгоритм в `analyze_form.py`» — чтение.
* **Проверяй доступ к файлам:** убедись на реальных запросах, что агент находит нужные материалы.

**Пример:**

```
bigquery-skill/
├── SKILL.md (overview, points to reference files)
└── reference/
    ├── finance.md (revenue metrics)
    ├── sales.md (pipeline data)
    └── product.md (usage analytics)
```

При запросе о выручке агент читает SKILL.md, видит ссылку на `reference/finance.md` и читает только его. `sales.md` и `product.md` остаются в файловой системе и не расходуют контекст до обращения. Такой подход позволяет загружать ровно необходимое для задачи.

Подробнее об архитектуре — [как работают Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#how-skills-work).

### Ссылки на инструменты MCP

Если навык использует MCP — Model Context Protocol, — указывай полные имена инструментов, чтобы избежать ошибки «инструмент не найден».

**Формат:** `ServerName:tool_name`.

**Пример:**

```markdown  theme={null}
Use the BigQuery:bigquery_schema tool to retrieve table schemas.
Use the GitHub:create_issue tool to create issues.
```

Здесь `BigQuery` и `GitHub` — имена серверов MCP; `bigquery_schema` и `create_issue` — инструменты внутри них. Без префикса сервера агент может не найти инструмент, особенно при нескольких серверах.

### Не предполагай, что инструменты установлены

Не считай пакеты заведомо доступными:

````markdown  theme={null}
**Bad example: Assumes installation**:
"Use the pdf library to process the file."

**Good example: Explicit about dependencies**:
"Install required package: `pip install pypdf`

Then use it:
```python
from pypdf import PdfReader
reader = PdfReader("file.pdf")
```"
````

## Технические примечания

### Требования к YAML frontmatter

Для SKILL.md нужны поля `name` — до 64 символов — и `description` — до 1024 символов. Подробности — в [обзоре Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#skill-structure).

### Объём контекста

Для оптимальной работы автор рекомендует держать тело SKILL.md в пределах 500 строк. Если объём больше, разделяй материалы на файлы по описанным выше подходам постепенного раскрытия. Архитектура: [обзор Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#how-skills-work).

<a id="checklist-for-effective-skills"></a>
<a id="checklist-for-effective-skills"></a>

## Контрольный список эффективного навыка

До публикации проверь:

### Основное качество

* [ ] Описание конкретно и содержит ключевые слова.
* [ ] Описание указывает назначение и условия применения.
* [ ] Тело SKILL.md занимает менее 500 строк.
* [ ] Дополнительные детали вынесены в файлы при необходимости.
* [ ] Нет быстро устаревающих сведений либо они находятся в разделе старых подходов.
* [ ] Термины используются единообразно.
* [ ] Примеры конкретны, а не абстрактны.
* [ ] Ссылки на файлы находятся на один уровень от основного файла.
* [ ] Дополнительные материалы подключаются по необходимости.
* [ ] Процессы имеют чёткие шаги.

### Код и скрипты

* [ ] Скрипты решают проблемы, а не перекладывают их на агента.
* [ ] Ошибки обрабатываются явно и полезно.
* [ ] Нет необоснованных «магических констант».
* [ ] Необходимые пакеты перечислены и проверена их доступность.
* [ ] Скрипты понятно документированы.
* [ ] Пути используют прямые косые черты.
* [ ] Для критичных операций предусмотрена валидация.
* [ ] Для задач, где важно качество, предусмотрены циклы обратной связи.

### Проверка

* [ ] Созданы как минимум три проверки.
* [ ] Навык проверен на Haiku, Sonnet и Opus, если они предусмотрены.
* [ ] Проверен на реальных сценариях.
* [ ] При необходимости учтена обратная связь команды.

## Следующие шаги

<CardGroup cols={2}>
  <Card title="Начало работы с Agent Skills" icon="rocket" href="https://platform.claude.com/docs/en/agents-and-tools/agent-skills/quickstart">
    Создай первый навык
  </Card>

  <Card title="Навыки в Claude Code" icon="terminal" href="https://code.claude.com/docs/en/skills">
    Создавай навыки и управляй ими в Claude Code
  </Card>

  <Card title="Навыки через API" icon="code" href="https://platform.claude.com/docs/en/build-with-claude/skills-guide">
    Загружай и используй навыки программно
  </Card>
</CardGroup>
