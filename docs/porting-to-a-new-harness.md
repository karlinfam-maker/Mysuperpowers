# Перенос Superpowers в новую среду

Руководство объясняет, как добавить поддержку новой среды — IDE, CLI или средства запуска агента помимо Claude Code — чтобы навыки Superpowers автоматически вызывались в ней так же, как в исходной среде.

Документ состоит из двух уровней. **Части 1–3** описывают систему и помогают определить, возможна ли поддержка среды; их следует прочитать до начала изменений. **Части 4–8** содержат пошаговую процедуру для агента под контролем человека: от переноса до распространения. В приложении перечислены существующие интеграции, чтобы выбрать ближайший образец.

Механизмы интеграции различаются и продолжают меняться. Поэтому руководство объясняет **неизменные требования**, действующие независимо от механизма, и указывает на работающие реализации для примера. При расхождении документа и кода ориентируйтесь на код и исправляйте руководство.

## Перед началом

Поддержка новой среды — один из наиболее ответственных видов вклада в исходный проект. Прежде чем что-либо писать:

- Полностью прочитайте `CLAUDE.md` и `.github/PULL_REQUEST_TEMPLATE.md`: правила участников и требования к PR для новой среды обязательны.
- Найдите **открытые и закрытые** PR с предыдущими попытками поддержки этой среды. Если они есть, выясните причины остановки до начала собственной работы.

---

## Часть 1 — Как Superpowers работает в разных средах

Содержимое Superpowers одинаково во всех средах. Меняется тонкий слой, который передаёт его модели и сопоставляет инструкции с нативными инструментами. Три компонента:

1. **Навыки, независимые от среды.** Всё в `skills/` — единый источник, одинаковый для всех сред. Навыки описывают *действия*: «вызвать навык», «прочитать файл», «запустить субагента», «создать задачу», — не называя конкретный инструмент. Поэтому один текст работает в Claude Code, Codex, Gemini, pi и других средах без изменений.
2. **Сопоставление инструментов для каждой среды.** Словарь действий переводится в реальные имена инструментов в `skills/using-superpowers/references/<harness>-tools.md` и/или в механизме начальной загрузки, см. часть 5. Например: «запустить субагента» → вызвать `task` с `subagent_type`.
3. **Начальная загрузка для каждой среды.** В начале каждого сеанса полный `skills/using-superpowers/SKILL.md` добавляется в контекст модели внутри тегов `<EXTREMELY_IMPORTANT>` вместе с сопоставлением инструментов. Он сообщает модели о существовании навыков и необходимости проверять их применимость до действия. **Начальная загрузка — основа всей интеграции.** Без неё файлы навыков просто находятся на диске и не вызываются.

### Два основных правила

**1. Навыки называют действия, а не инструменты.** Не редактируйте текст навыка под конкретную среду. Перенос добавляет справочник сопоставлений и механизм загрузки, но не заменяет имена инструментов внутри `skills/*/SKILL.md`. Правила участников исходного проекта рассматривают тщательно настроенное содержание навыков как инструкции, определяющие поведение; переписывание только ради формального «соответствия» отклоняется.

**2. Всё доставляется штатным установщиком среды. Не изменяйте файлы пользователя.** Начальная загрузка, навыки и сопоставления поставляются как часть устанавливаемого плагина, расширения, записи маркетплейса или включённого в расширение файла контекста. Перенос **не должен** внедрять изменения в глобальную или личную конфигурацию пользователя: `~/.gemini/config/AGENTS.md`, `settings.json`, `trustedFolders.json`, вручную изменяемый `~/.bashrc` и другие файлы. Среда управляет загрузкой; запись разрешена только в составе устанавливаемого артефакта. Если штатный механизм действительно не может передать начальную загрузку, это ограничение следует сообщить, см. часть 6, а не обходить правкой пользовательской конфигурации.

Форма C не является исключением: файл контекста Gemini допустим, поскольку поставляется **внутри установленного расширения** и объявлен в `contextFileName` манифеста. Среда загружает собственный файл расширения, а не файл, изменённый в домашнем каталоге пользователя.

---

## Часть 2 — Можно ли поддерживать эту среду?

Для поддержки Superpowers среда должна выполнять перечисленные требования. Проверьте их до написания кода; если первое не выполняется, остановитесь.

### Обязательное требование: автоматическая загрузка при начале сеанса

Среда должна добавлять текст в контекст модели **в начале каждого сеанса, без отдельного включения человеком каждый раз**. Это принципиальное условие. Возможные формы:

- **Хуки и события**, запускающие shell-команду при начале сеанса и читающие stdout: Claude Code, Cursor, Copilot CLI.
- **Плагин или расширение внутри процесса** с обработчиком начала сеанса или сообщений, способным менять массив сообщений: OpenCode, pi.
- **Файл инструкций**, который среда загружает из *установленного расширения*: например, `contextFileName` Gemini указывает на собственный `GEMINI.md` расширения. Это не файл, который вы вручную редактируете в домашнем каталоге пользователя.

Если Superpowers попадает к модели только после отдельного действия человека в каждом сеансе — вставки запроса, запуска команды или включения режима, — надёжная поддержка невозможна. Приёмочная проверка части 3 не пройдёт, а PR будет закрыт. Это самая частая причина, по которой предполагаемый перенос не является полноценной интеграцией.

### Остальные возможности

| Возможность | Зачем нужна | Если отсутствует |
|---|---|---|
| **Обнаружение и вызов навыков** | Модель должна загружать полное содержание навыка по запросу | При отсутствии нативного инструмента допускается напрямую прочитать нужный `SKILL.md`, см. часть 5. Без инструмента навыков и чтения файлов поддержка невозможна. |
| **Чтение, запись и изменение файлов** | Почти каждый навык работает с файлами | Обязательно, запасного варианта нет. |
| **Выполнение shell-команд** | TDD, проверка, процессы git | Обязательно. |
| **Запуск субагентов и задач** | `dispatching-parallel-agents`, `subagent-driven-development` | Возможно упрощение: при отсутствии эти навыки предписывают выполнить работу самостоятельно или сообщить об ограничении, но никогда не выдумывать вызов `Task`. Иногда нужна настройка: например, мультиагентный режим Codex необходимо включить. |
| **Отслеживание списка задач** | Контроль прогресса в нескольких навыках | Можно использовать файл плана или `TODO.md`. |
| **Получение страниц и поиск в интернете** | Некоторые навыки | Возможно упрощение. |
| **Запуск shell- или полиглотных скриптов Windows** | Только для формы shell-хука при необходимости поддержки Windows | См. часть 7. Плагины внутри процесса обходят эту проблему. |

Возможность упрощения означает, что навык уже описывает запасной вариант при отсутствии инструмента. В сопоставлении нужно указать реальный инструмент, когда он есть, и использовать существующий запасной вариант, когда его нет.

### Новый каталог может быть не нужен

Некоторые «новые среды» фактически используют существующие интеграции через другой установщик. Например, Factory Droid загружает плагин Claude Code собственной командой `plugin install` и не требует новых файлов. До разработки проверьте, может ли среда загрузить существующий манифест. Одного абзаца в README иногда достаточно для полноценного переноса.

---

## Часть 3 — Критерии завершения

Перенос закончен, когда выполнены **все** условия:

1. Начальная загрузка `using-superpowers` происходит в начале каждого сеанса без дополнительного включения.
2. Для среды существует сопоставление инструментов в `references/<harness>-tools.md`, внутри загрузки или в обоих местах, см. часть 5.
3. Навыки действительно можно вызвать нативно либо через документированное чтение `SKILL.md`, а модель следует их инструкциям.
4. **Приёмочный тест проходит:** в чистом сеансе сообщение пользователя

   > Let's make a react todo list

   автоматически вызывает `brainstorming` **до написания кода**. Нужно сохранить полную стенограмму для PR.
5. Интеграция покрыта тестами из части 5, и они проходят.
6. Реальный пользователь может установить её штатным механизмом среды, а не ручным копированием файлов; версия отслеживается в `.version-bump.json`, когда применимо, см. часть 6. Некоторые установщики переписывают или сокращают установленный манифест, например до `{"name": …}`. Поэтому установленный файл не всегда сообщает версию репозитория; отслеживайте версию исходного манифеста и не считайте переписанный установленный манифест ошибкой.

Быстрая проверка перед полной приёмкой: начните сеанс и попросите модель описать свои superpowers. При успешной загрузке она знает об их наличии. Инструкция OpenCode использует `opencode run --print-logs "hello" 2>&1 | grep -i superpowers` для той же цели через поиск в журналах. Перенаправление `2>&1` важно, поскольку журналы идут в stderr. Найдите аналог для своей среды.

---

## Часть 4 — Выбор формы интеграции

Есть три формы по способу доставки начальной загрузки модели. Выберите соответствующую возможностям среды и используйте ближайшую реализацию как образец. Форма определяет большую часть шагов части 5.

### Как определить форму

Сначала изучите *фактический* механизм среды; не предполагайте, что документация полна или поведение совпадает с родительским проектом.

**Найдите точку интеграции:**

- Поищите документацию среды в интернете по расширениям, плагинам, хукам, навыкам, MCP, файлам контекста и правилам. Инструменты быстро меняются; поиск надёжнее памяти модели.
- Найдите и прочитайте существующее стороннее расширение или плагин. Работающий пример показывает формат манифеста, команду установки и действительно загружаемые компоненты.
- Проверьте, что среда загружает при старте: настройки, каталог расширений, проектный или глобальный файл инструкций `AGENTS.md`, `<NAME>.md`.

**Если документация недостаточна, исследуйте поведение:**

- Изучите бинарный файл через `strings` или выполните поиск по дереву установки для имён событий хуков, путей конфигурации и файла инструкций.
- Попросите работающую модель перечислить точные машинные имена доступных инструментов. Это надёжный способ получить названия без выдумывания, см. шаг 4.
- Подтвердите каждое предположение **уникальным маркером**: добавьте бессмысленный токен предполагаемым механизмом, начните новый сеанс и проверьте, что токен дошёл до модели.

**Производная среда не обязана наследовать поведение исходной.** Например, CLI на основе Gemini может предоставлять те же поля манифеста и синтаксис `@`, но обрабатывать их иначе. Проверяйте маркером, не предполагайте совместимость.

Выбор формы:

- Shell-команда при начале сеанса с чтением stdout → **форма A**.
- Модуль плагина или расширения с исполняемыми обработчиками жизненного цикла → **форма B**.
- Только постоянно действующий файл инструкций, без хука и плагина с кодом → **форма C**.

**Формы можно сочетать.** Обнаружение навыков и начальная загрузка не обязаны использовать один механизм, но **оба должны поставляться через установщик**, согласно правилу 2. Отдельно определите, где обнаруживаются навыки и как загрузка попадает в каждый сеанс. Например, навыки могут устанавливаться плагином, а загрузка — передаваться другим штатным способом: файлом контекста, объявленным расширением, или описанием установленного `using-superpowers`, которое среда показывает при старте. Если автоматически работают несколько штатных механизмов, предпочтителен наиболее надёжный. Заполнять пробел правкой глобальной конфигурации пользователя нельзя.

### Форма A — shell-хук

Среда запускает shell-команду при начале сеанса и читает JSON из stdout. Настроенная команда вызывает полиглотную обёртку `run-hook.cmd`, которая находит bash и запускает нужный скрипт. Скрипт `hooks/session-start` или его вариант читает `using-superpowers/SKILL.md` и выводит JSON, **название и вложенность поля которого зависят от среды**.

- Образцы: `hooks/session-start`, `hooks/run-hook.cmd`, конфигурации `hooks/hooks.json` для Claude Code и `hooks/hooks-cursor.json` для Cursor.
- Манифест формы A: `.cursor-plugin/plugin.json` указывает на `./skills/` и нужный `hooks-*.json`. Манифест Claude Code `.claude-plugin/plugin.json` не задаёт ни одно поле: среда по соглашению сама обнаруживает `skills/` и `hooks/hooks.json`. Не копируйте `.codex-plugin/plugin.json` для формы A: он намеренно содержит пустой объект `hooks`, подавляющий автоматическое обнаружение Codex, поскольку Codex показывает навыки нативно и не запускает хук начала сеанса.

> **Система хуков не гарантирует события начала сеанса.** В среде может существовать `hooks.json` и даже строка `SessionStart` в бинарном файле, но отсутствовать событие начала сеанса, которое добавляет контекст. В одной реальной среде были только события до/после инструмента и остановки, а строки `SessionStart` относились к телеметрии. До выбора формы A подтвердите существование и возможность передачи контекста конкретным событием. Иначе загрузка относится к файлу инструкций, форма C.

### Форма B — плагин или расширение внутри процесса

Среда загружает модуль JS/TS с обработчиками жизненного цикла. Каталог навыков регистрируется через API среды, а начальная загрузка добавляется изменением массива сообщений.

Образцы: `.opencode/plugins/superpowers.js` на JavaScript и `.pi/extensions/superpowers.ts` на TypeScript. Для среды **без нативного инструмента навыков** ближе всего pi.

### Форма C — файл инструкций

В среде нет shell-хука и плагина с кодом; при начале сеанса используется файл контекста, который **поставляется установленным расширением и объявлен манифестом**. Пример: `contextFileName` Gemini → собственный `GEMINI.md` расширения. Код запускать и сообщения изменять нельзя; файл контекста ссылается на начальную загрузку. Нет механизма сборки строки или удаления frontmatter: среда загружает содержимое как есть. Это работает, только если файл входит в установленное расширение; нельзя заменять его редактированием глобального `GEMINI.md` или `AGENTS.md` пользователя.

- Образцы: `gemini-extension.json` с `contextFileName`, `GEMINI.md` с двумя включениями `@` — навык загрузки и справочник инструментов, — `skills/using-superpowers/references/gemini-tools.md`.
- Включение `@` — особенность Gemini. Если среда загружает файл инструкций, но не поддерживает включения, содержимое загрузки нужно вставить в файл напрямую.
- **Проверьте фактическое раскрытие `@`, не доверяйте синтаксису.** Среда на основе Gemini может принимать `@./path` как подсказку, которую модель *может* прочитать отдельным вызовом, а не гарантированное включение в контекст. Это различие между надёжной загрузкой и возможным чтением. Используйте уникальный маркер: если он не появляется в контексте без вызова инструмента, вставьте содержимое напрямую вместо `@`.

### Таблица выбора

| Возможности среды | Форма | Образец |
|---|---|---|
| Запускает shell-команду при начале сеанса и читает stdout | A, shell-хук | Cursor: `hooks/session-start`, `hooks/hooks-cursor.json`, `.cursor-plugin/` |
| Размещает плагин JS/TS с обработчиками сеанса или сообщений | B, внутри процесса | OpenCode `.opencode/`; при отсутствии нативного инструмента навыков — pi `.pi/` |
| Всегда загружает файл контекста, объявленный расширением | C, файл инструкций | Gemini: `gemini-extension.json`, `GEMINI.md`, `references/gemini-tools.md` |
| Показывает описание каждого установленного навыка, но не имеет события начала сеанса и поля файла контекста | Начальная загрузка через индекс навыков, часть 5, шаг 5, запасной вариант случая 2 | Antigravity: только `.antigravity-plugin/plugin.json` и `skills/` |

Большинство сред однозначно соответствует одной строке; последняя — менее надёжный случай, см. оговорки шага 5. Правило 2 сохраняется: конфигурацию пользователя не редактировать.

---

## Часть 5 — Процедура переноса

### Шаг 1 — Изучить ближайшую реализацию

Полностью прочитайте файлы образца для выбранной формы из части 4. Ниже приведены краткие схемы; основным описанием служит код.

### Шаг 2 — Создать манифест или точку входа

Создайте то, по чему среда распознаёт плагин, ориентируясь на существующие реализации:

- **Форма A:** `*-plugin/plugin.json`, см. `.cursor-plugin/plugin.json`, с `name`, `version`, `description`, автором, лицензией, ключевыми словами, `"skills": "./skills/"` и `"hooks": "./hooks/hooks-<harness>.json"`. Дополнительно создаётся `hooks-<harness>.json`, регистрирующий хук начала сеанса с вызовом `run-hook.cmd`.
- **Форма B:** загружаемый модуль, например `.<harness>/plugins/*.js`, и необходимые метаданные пакета. Отслеживаемый источник метаданных — **корневой `package.json`**: `main` указывает на плагин OpenCode, поля `pi.extensions`, `pi.skills` и ключевое слово `pi-package` объявляют расширение pi. Локальные манифесты и lock-файлы отдельных сред не сохраняются в git: `.opencode/.gitignore` исключает `node_modules`, `package.json` и lock-файлы. Аналогично исключайте *локальные* артефакты своей среды, но никогда не исключайте корневой отслеживаемый `package.json`.
  - **Проверка сборки и зависимостей:** определите, запускает ли среда исходный модуль напрямую — pi ссылается на `.ts` из `package.json`, OpenCode поставляет обычный `.js` — или требует транспиляции и сборки. У Superpowers нет зависимостей времени выполнения. `import type { ExtensionAPI }` pi работает именно потому, что среда напрямую запускает `.ts`, предоставляет тип при загрузке, а репозиторий не проверяет типы файла в CI; импорт даже не объявлен зависимостью. Если ваша среда проверяет типы или собирает плагин, неуказанный импорт типа вызовет ошибку. Правила PR допускают для новых сред исключение только для зависимостей времени выполнения, а не пакетов разработки и типов. При такой проблеме согласуйте подход с сопровождающим, не добавляя зависимость незаметно. Результаты сборки не включайте в git, команду документируйте.
- **Форма C:** небольшой манифест, см. `gemini-extension.json` с `name`, `description`, `version`, `contextFileName`, и сам файл контекста. `GEMINI.md` содержит два включения `@`: навык загрузки и справочник инструментов. Поля `skills` в манифесте Gemini нет: каталог `skills/` установленного расширения обнаруживается автоматически. Если нативный инструмент навыков есть, но манифест не позволяет зарегистрировать каталог, найдите соглашение обнаружения в документации расширений и проверьте опытным путём: попросите модель перечислить навыки; отсутствие поставляемых означает, что обнаружение ещё не работает.

### Шаг 3 — Подключить начальную загрузку

Это основная часть переноса. Общая цель: при начале сеанса передать модели содержимое `using-superpowers` внутри тегов `<EXTREMELY_IMPORTANT>` и сопоставление инструментов, указав, что навык уже активен и повторно загружать его не нужно. Способ сборки и содержимое, загружаемое средой напрямую, зависят от формы. Не переносите рецепт одной формы на другую.

**Форма A — скрипт читает `SKILL.md` и выводит JSON среды.** `hooks/session-start` читает файл целиком, включая frontmatter, что допустимо при дословной передаче, добавляет вступление «у вас есть superpowers… для остальных навыков используйте Skill», экранирует и выводит JSON. Сопоставление инструментов здесь не вставляется: оно находится в `references/<harness>-tools.md`, шаг 4. Формат JSON должен точно совпадать. `hooks/session-start` определяет среду по переменным и выдаёт одну из трёх форм:

- Cursor, если задан `CURSOR_PLUGIN_ROOT`: `{ "additional_context": "…" }`.
- Claude Code, если задан `CLAUDE_PLUGIN_ROOT`, но не `COPILOT_CLI`: `{ "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "…" } }`.
- Copilot CLI или стандарт SDK в остальных случаях: `{ "additionalContext": "…" }`.

Неправильное или лишнее поле приводит к пропуску либо двойной загрузке. Claude Code читает `additional_context` и `hookSpecificOutput` без удаления дубликатов, поэтому выдача обоих добавляет контекст дважды. Установите точные поле, вложенность и значения сопоставления события. Затем добавьте четвёртую ветвь в `hooks/session-start` или отдельный `hooks/session-start-<harness>`, если нужны другое сообщение или переменные. Если среда задаёт также переменную, проверяемую более ранней ветвью, например `CLAUDE_PLUGIN_ROOT`, расположите новую ветвь раньше. Используйте собственные строки события среды: Claude Code — `startup|clear|compact`, Cursor — `sessionStart`; неверное значение приводит к незаметному пропуску хука.

**Схема самой конфигурации хуков различается.** Сравните `hooks/hooks.json` и `hooks/hooks-cursor.json`: Cursor использует `"version": 1`, ключ `sessionStart` с маленькой буквы и относительную команду `./hooks/run-hook.cmd`, опуская поля `matcher`, `type`, `async` Claude Code. Выбирайте ближайший существующий образец.

**Строка команды ссылается на корень плагина среды**, причём механизм различается: `hooks.json` использует `${CLAUDE_PLUGIN_ROOT}`, `hooks-cursor.json` — относительный путь. Используйте доступное в вашей среде. Сам `session-start` повторно определяет корень через `dirname`, поэтому его тело не зависит от этой переменной, но команда манифеста зависит.

**Как выяснить контракт среды:** переменная окружения, поле и вложенность JSON и строки сопоставления события принадлежат среде, а не Superpowers. Изучите документацию хуков или проверьте опытным путём: временный хук начала сеанса выводит своё окружение и маркер, после чего можно определить переменную среды и обработку stdout. Установите эти факты до написания настоящей ветви.

**Форма B — собрать строку кодом и внедрить как пользовательское сообщение.** Прочитайте `SKILL.md`, удалите YAML frontmatter и соберите `<EXTREMELY_IMPORTANT>` + короткое вступление о том, что навык уже загружен и его не нужно вызывать повторно + текст без frontmatter + сопоставление инструментов + `</EXTREMELY_IMPORTANT>`. Образцы различаются: OpenCode пишет «не используйте инструмент навыков…», предполагая его наличие, а pi — «не пытайтесь снова загрузить using-superpowers». Если инструмента навыков нет, используйте формулировку pi.

Вставляйте результат как **сообщение с ролью user, а не system**: повторяющиеся системные сообщения увеличивают расход токенов (#750), а несколько системных сообщений ломают некоторые модели (#894). Необходимо воспроизвести:

- **Защиту от дублей:** обработчик может срабатывать неоднократно — transform OpenCode на каждом шаге агента, `context` pi на каждом ходу. Перед вставкой проверяйте наличие маркера загрузки. Образцы используют разные маркеры: у pi собственная строка, у OpenCode тег `EXTREMELY_IMPORTANT`; совпадение по тегу надёжнее, поскольку не требует отдельной константы среды. Кешируйте загрузку на уровне модуля, чтобы не перечитывать и не разбирать `SKILL.md` при каждом вызове (#1202).
- **Сжатие контекста:** если среда сжимает историю, после этого загрузка вставляется снова. pi делает это на каждом вызове `context` и помещает сообщение после начальных резюме сжатия. OpenCode опирается на повторную вставку при каждом шаге и защиту от дублей.
- **Формат объекта сообщения зависит от среды.** Образцы несовместимы: pi создаёт `{ role, content: [{ type, text }], timestamp }`; OpenCode использует `message.info.role` и `message.parts[]`. Найдите формат в API своей среды: дословное копирование чужого объекта приведёт к незаметному сбою.

**Форма C — файл контекста расширения указывает на загрузку; сборка не выполняется.** Механизма вставки нет, поэтому frontmatter не удаляется и строка в обёртке не создаётся. Поставляемый расширением и объявленный манифестом файл контекста, не глобальный файл пользователя, подключает навык `using-superpowers` и справочник сопоставления инструментов. `GEMINI.md` делает это двумя включениями `@`: `@./skills/using-superpowers/SKILL.md` и `@./skills/using-superpowers/references/<harness>-tools.md`. Среда загружает их как есть, включая frontmatter; внутри SKILL.md уже есть блок `<EXTREMELY-IMPORTANT>`. Если синтаксиса включений нет, вставьте содержимое напрямую.

Gemini не добавляет вступление «уже загружено, не вызывайте повторно»: при `@` содержимое является активными инструкциями, а не навыком для повторной загрузки. Если ваша среда всё же пытается вызвать навык снова, добавьте эту пометку буквальной строкой файла инструкций, поскольку кодового механизма для неё нет.

### Step 4 — Write the tool mapping

Translate the action vocabulary into the harness's real tools. Cover every one
of these actions (omit only what genuinely doesn't apply):

- read a file
- create / edit / delete a file (one `apply_patch`-style tool, or separate
  write/edit?)
- run a shell command
- search file contents / find files by name (grep, glob)
- fetch a URL / web search
- **dispatch a subagent**, including how to pass the agent type — and any config
  flag needed to enable it
- **create / update todos** (treat older `TodoWrite` references as this action)
- **invoke a skill** — see Step 5

**Get the real tool names from the harness; never invent them.** If the docs
don't list them, the authoritative source is the harness itself: in a live
session, ask the model to "list the exact machine names of every tool you can
call, one per line" and use what it reports.

**How the harness finds the `skills/` directory is itself per-harness** — confirm
it, don't assume. Possibilities: a manifest `skills` path field (Codex's
`"skills": "./skills/"`); a *co-located* `skills/` the harness auto-scans (where a
path field is **ignored** — one real harness only scanned a `skills/` sitting next
to `plugin.json`); an API/registration call (OpenCode, pi); or you stage an
install dir that pairs the manifest with a **symlink to the repo's `skills/`** and
point the installer at the staging dir (verify the installer *dereferences* the
symlink and copies the real files — confirm with `agy plugin validate`/`install`
or the equivalent before relying on it). A `skills` path field is *not* portable.

Where the mapping lives depends on shape:

- **Shape A:** put it in `skills/using-superpowers/references/<harness>-tools.md`.
  The agent reaches it from the bootstrap — `SKILL.md`'s "Platform Adaptation"
  section links the per-harness references files. (Shape A harnesses have no
  instructions file; the mapping is *not* inlined into the hook output.)
- **Shape B:** the mapping is typically inlined into the bootstrap string you
  inject (see the `toolMapping` constant in `superpowers.js`). pi keeps it in
  *both* places — `piToolMapping()` inline **and** `references/pi-tools.md`. If
  you maintain it in two places, update both, or the port is half-done.
- **Shape C:** put it in `references/<harness>-tools.md` and pull it into the
  always-loaded instructions file (e.g. `GEMINI.md` `@`-includes
  `gemini-tools.md`).

You may also add a one-line pointer to your harness in `SKILL.md`'s "Platform
Adaptation" section so an agent reading the bootstrap knows where its mapping
lives. This is the one edit to a `SKILL.md` a port may make — and only because
that section is a pointer list, not behavior-shaping content. It does not violate
the "don't edit skill bodies" rule (Part 1); do not touch anything else in any
skill. (The list is a convenience pointer, not an exhaustive registry — not every
harness is listed.)

### Step 5 — Handle a harness with no native skill tool

`using-superpowers/SKILL.md` tells the model to *never read skill files manually
with file tools — always use your platform's skill-loading mechanism.* The point
is "don't bypass the mechanism," not "never use file-read." What counts as "your
platform's mechanism" depends on the harness — and for a harness with no skill
tool, the documented mechanism *is* reading `SKILL.md`. So reading it there
honors the rule rather than breaking it. Distinguish three cases:

1. **Native `Skill`-style tool** (Claude Code, Copilot CLI, Gemini's
   `activate_skill`): point the mapping at that tool.
2. **Native skill *discovery* but no `Skill` tool** (pi, Antigravity): the harness
   can find and list skills, but the model can't call a tool to load one. Get the
   skills installed where the harness scans (pi declares them in the package
   manifest's `pi.skills`; OpenCode via its `config` hook; `agy plugin install` copies
   them in), and tell the model to load a skill by **reading its `SKILL.md` with
   the file-read tool when the skill applies** — the sanctioned mechanism here,
   the way `references/pi-tools.md` states it.

   **For the bootstrap itself, prefer something the harness loads every
   session (Part 6)** — a declared context file where the manifest has a
   `contextFileName`-style field. Antigravity has none, and its other options
   cost more than they buy, so it uses the surfaced skill index below:
   - Its hooks have no session-start event. `PreInvocation` runs before every
     model call; an `ephemeralMessage` it injects is dropped on the next call,
     and `invocationNum` resets on each user turn. A `userMessage` gated on
     `invocationNum == 0` and `initialNumSteps == 1` injects exactly once per
     conversation, but agy still starts the hook process on every model call.
     `${PLUGIN_ROOT}` is not set in hooks (they run from the plugin root).
     `hooks.json` must sit at the plugin root; no manifest field moves it.
   - It loads `rules/*.md` from a plugin every session, but harnesses that
     install from the git repo share its root, and Cursor is one of them: it
     also loads any `rules/*.md` a plugin ships. A file in a shared plugin root
     is visible to every harness that reads that root — check before adding
     one.

   **Fallback — the surfaced skill index.** If there's no context-file field but
   the harness surfaces each installed skill's name + description at session start,
   you need *neither* a built index nor a runtime-list instruction — the harness
   is the index, and `using-superpowers`'s own surfaced description can be what
   triggers the model to load it. This is softer than a declared context file;
   two things it does **not** give you, versus a context file / hook / in-process
   injector — account for both:
   - **It bootstraps *triggering*, not the *tool mapping*.** An injector prepends
     `<harness>-tools.md` alongside `using-superpowers` every session. Here nothing
     injects the mapping — the model only sees skill *descriptions* and must *read*
     your `references/<harness>-tools.md` when it needs tool names. It works
     because skills name actions (the model reads the mapping when it acts), but
     it's softer than injection. Make sure the mapping is reachable from what the
     model loads — e.g. linked from `SKILL.md`'s Platform Adaptation section and
     installed alongside the skills — not just sitting in the repo.
   - **There's no structural guarantee the trigger fires.** No `<EXTREMELY_IMPORTANT>`
     wrapper, no dedup, no re-injection after compaction — firing depends on the
     model choosing to act on a description it sees in the index. This is exactly
     why the acceptance test is mandatory here: it is the *only* guarantee, so run
     it on the model(s) your users will actually use, not just the strongest one.
3. **No skill system at all:** there is nothing to register, and the *only*
   mechanism is the model reading `SKILL.md` on demand. But the model can't read
   what it can't find: `using-superpowers/SKILL.md` does **not** enumerate the
   available skills, so on its own the model won't know which skills exist or
   their triggers. You must supply a discovery path. Two options, and they differ
   in durability: (a) generate a skill index (each `skills/*/SKILL.md`'s `name` +
   `description` frontmatter) and place it *inside* the `<EXTREMELY_IMPORTANT>`
   wrapper alongside the tool mapping (Shape B recipe above) so it's covered by
   the dedup guard — but a build-time index goes stale as skills are added; or
   (b) instruct the model to list `skills/*/SKILL.md` at runtime and read their
   frontmatter to find a match — slower but never stale. Prefer (b) unless you
   have a reason not to. Without either, a no-skill-system port loads the
   bootstrap but silently never triggers any other skill.

In cases 2 and 3, say plainly in your tool mapping that reading `SKILL.md` is the
blessed path, so the model doesn't think it's violating the "never read skill
files" rule. Don't go hunting for a `skillPaths`-style registration API in a
harness that has no skill system — case 3 has none.

### Step 6 — Add tests

Match the existing per-harness test style:

- **Shape A:** assert the hook's stdout has the exact JSON shape your harness
  consumes, and that it contains the bootstrap. See `tests/hooks/test-session-start.sh`,
  which validates each harness's output shape.
- **Shape B:** a unit test that fakes the harness's plugin API and asserts the
  lifecycle handlers register, the bootstrap injects once, the dedup guard
  works, and (if relevant) compaction re-injection works. See
  `tests/pi/test-pi-extension.mjs`. Add an isolated-install integration check in
  the style of `tests/opencode/`.
- If the bootstrap is cached, test that the cache behaves when the file is
  missing (see the OpenCode caching tests).

These automated tests cover the wiring; the live tmux run in Step 7 is what
proves the integration actually triggers skills.

### Step 7 — Install locally, then drive a live instance to verify

You cannot confirm a port works by reading code. You have to run the harness with
your in-progress port loaded and watch a real session — which is also how you
produce the transcript the PR requires.

**Install locally.** Point a *local* instance of the harness at your working
tree, not a published build:

- **Shape A / C:** install the plugin/extension from this repo's local path (or
  symlink its directory into wherever the harness looks). Find the harness's
  "install from a local directory / git checkout" path in its docs.
- **Shape B:** register the local module — e.g. an `opencode.json` `plugin`
  entry pointing at the local path, or pi resolving the `package.json` fields
  from the repo.

Reinstall after each change and restart the harness, since the bootstrap loads at
startup.

**Drive it with tmux.** Most harnesses are interactive REPLs/TUIs that can't be
driven by piping stdin, so run the harness inside a detached tmux session and
control it with `send-keys` / `capture-pane`. A harness may advertise a
non-interactive "run one prompt" mode (e.g. `opencode run "..."`) — try it for the
quick smoke check, but **don't depend on it**: these modes are frequently flaky,
auth-gated, or trust-gated (one real harness's `--print` mode hung and timed out
with no output every time). Be ready to do *everything*, including the smoke
check, through tmux.

**Clear the gates first, or tmux stalls silently.** Many harnesses block on
first-run onboarding, a "do you trust this folder?" prompt, a sandbox mode, or a
permission gate — and a detached tmux session will just sit there with no error
while it waits. Before the run, pre-trust your scratch directory (in the harness's
settings/config) or be prepared to answer those prompts via `send-keys`, and
account for the harness's startup time in your first `sleep`.

```bash
# 1. Launch the harness detached, in a throwaway project dir
mkdir -p /tmp/port-smoke
tmux new-session -d -s port-test -c /tmp/port-smoke '<harness-launch-command>'

# 2. Let it initialize — real TUIs take longer than you think (10s+ with a model
#    handshake); tune this. THEN capture and clear any blocking modal before you
#    type a prompt: first-run onboarding and "trust this folder?" are modal, so
#    keystrokes sent during them select menu items instead of typing your prompt.
sleep 12
tmux capture-pane -t port-test -p          # onboarding / trust prompt? answer it via send-keys first
# (e.g. tmux send-keys -t port-test Enter   # to accept a trust prompt — inspect before assuming)

# 3. Smoke check: does the model know it has superpowers?
#    Send the text and Enter as SEPARATE send-keys with a beat between them —
#    sending them together races on some TUIs (Enter arrives before the text lands).
tmux send-keys -t port-test 'What are your superpowers?'; sleep 0.4; tmux send-keys -t port-test Enter
sleep 5
tmux capture-pane -t port-test -p          # reply should show it knows its skills

# 4. Acceptance test: exact prompt (note the escaped apostrophe), fresh session
tmux send-keys -t port-test 'Let'\''s make a react todo list'; sleep 0.4; tmux send-keys -t port-test Enter
# poll until the turn finishes — re-capture every few seconds, don't capture once
sleep 8
tmux capture-pane -t port-test -p          # PASS = brainstorming triggers BEFORE any code

# 5. Save the transcript for the PR, then clean up
tmux capture-pane -t port-test -p > /tmp/port-smoke/transcript.txt
tmux kill-session -t port-test
```

tmux gotchas that bite here: wait after launch before the first capture; send the
prompt text and `Enter` as *separate* `send-keys` calls with a short `sleep`
between them (sending them together races on some TUIs), and `Enter` is a key name
not `\n`; the agent's turn takes time, so **poll `capture-pane` in a loop** rather
than capturing once; `capture-pane` shows only the visible pane, so for a long
conversation use the harness's own transcript/log file as the record of truth;
always `kill-session` when done.

If the smoke check shows the model *doesn't* know it has superpowers, the
bootstrap isn't loading — fix that before bothering with the acceptance test.

---

## Part 6 — Distribution and release

A working integration in this repo isn't usable until a real user can install
it. Distribution differs per harness ecosystem — find yours:

| Channel | Example | What you do |
|---|---|---|
| Native plugin marketplace | Claude Code | Register in `.claude-plugin/marketplace.json`; users `/plugin install`. The external `superpowers-marketplace` repo is the source of truth users install from — see the release steps in `CLAUDE.md`. |
| External marketplace fork, synced by script | Codex | `scripts/sync-to-codex-plugin.sh` rsyncs the tracked plugin files into a separate fork repo and opens a PR. Read its include/exclude list so you ship the right tree (it deliberately drops repo-internal dirs and other harnesses' dotdirs). |
| Git-URL extension install | Gemini, Kimi Code, OpenCode | Users install from a git URL (`gemini extensions install …`; Kimi Code `/plugins install …`; an `opencode.json` `plugin` array entry). Document the exact command. |
| Package-manifest fields | pi | Declared through fields in the repo-root `package.json`; users install via the harness's package command. |
| Git-URL plugin install + marketplace | Antigravity (`agy`) | Users run `agy plugin install https://github.com/obra/superpowers`. agy reads `.antigravity-plugin/plugin.json`, whose Marketplace fields (`displayName`, `logo`, `suggestedPrompts`, `version`, `author`) also drive the Antigravity Marketplace listing. Without that manifest, agy falls back to importing `gemini-extension.json`. |

Then:

- **A plugin installer may silently strip *undeclared* files — so make the
  bootstrap a file the installer *recognizes*, never a user-config edit.** A
  `plugin install` typically copies only the components it knows about
  (skills/agents/commands/mcp/hooks/context) and discards anything else, so a
  context file the manifest doesn't declare just vanishes from the install. The
  fix is **not** to give up and write into the user's config (**rule 2**) — it's
  to declare the bootstrap as a recognized component. In escalation order:
  - **Ship a context file the manifest declares.** If the harness has a
    `contextFileName`-style field (an extension-declared file it loads every
    session), that is the strongest clean bootstrap: declare it, and the installer
    preserves it *and* the harness loads it. Generate it at install time from the
    live `using-superpowers/SKILL.md` + the tool mapping (wrapped in
    `<EXTREMELY_IMPORTANT>`) so the installed bootstrap never drifts.
    **Verify with a marker** that the installer keeps the file and the
    harness loads it: a file the manifest doesn't declare can be stripped as
    unrecognized.
  - **Otherwise lean on the installed `using-superpowers` skill itself.** If the
    harness surfaces each installed skill's name + description at session start,
    the `using-superpowers` description ("Use when starting any conversation…")
    can prompt the model to load it — installing the skill *is* the bootstrap.
    Softer (no guaranteed wrapper; it carries triggering but not the tool mapping
    — see Step 5), so prefer the declared context file when available.
  - If neither works, the harness cannot be cleanly supported yet — **say so**
    and raise it, rather than hand-editing the user's config.

- **Packagers can strip executable bits — skill prose invokes bundled scripts
  through their interpreter.** Some marketplace packaging and install paths
  lose Unix file modes: the Codex marketplace cache delivered the SDD helpers
  as `0644` (#2040, #2134), and the MiniMax Code marketplace ships every file
  as mode `600`. A bare `scripts/foo.sh` or `./foo.js` in a skill then fails
  with `Permission denied` on that harness even though the repo's tree records
  `100755`. So every script invocation in `skills/**/*.md` is spelled through
  its interpreter — `bash scripts/start-server.sh …`, `bash
  scripts/review-package …`, `node ./render-graphs.js …` — and a script that
  runs a sibling script needs the same treatment (#2134). Don't "tidy" the
  prefixes away, and don't reach for a packaging-side `chmod`: the mode loss
  happens on the consumer's side, so only the invocation form survives it.
- **Write install docs.** A `docs/README.<harness>.md` and/or a
  `.<harness>/INSTALL.md` (see `docs/README.opencode.md` and
  `.opencode/INSTALL.md`), plus an install section in the top-level `README.md`.
  The only supported install action is **running the harness's own install
  command** (`agy plugin install`, `gemini extensions install`, `/plugin
  install`, etc.). Hand-copying skill files and editing the user's global/personal
  config are *both* off-limits (rule 2 / the PR rules). If the harness has no
  install command at all — its only surface is a user-owned config file — then it
  fails the "deliver via install mechanism" rule, and you should raise that rather
  than ship an installer that edits the user's files.
- **Register the version.** If your harness introduces a *new* versioned
  manifest, add its path and version field to `.version-bump.json` so
  `scripts/bump-version.sh` keeps it in lockstep (read that file to see what's
  currently tracked). A new manifest that isn't registered there will ship a
  stale version. If your harness instead rides an already-tracked file — pi
  declares itself in the repo-root `package.json`, which is already listed —
  there's nothing new to add.
- **If no existing channel fits, you're standing up a new one.** None of the four
  rows may match your harness. If it needs a Codex-style external fork sync,
  `scripts/sync-to-codex-plugin.sh` is the template to clone (note its anchored
  include/exclude list and its PR automation). And whenever you add a new
  per-harness directory, add it to the *other* harnesses' sync excludes (e.g. the
  EXCLUDES list in `sync-to-codex-plugin.sh`) so your dotdir doesn't leak into
  their distributions.

---

## Part 7 — Cross-platform / Windows

Only relevant to the shell-hook shape. `hooks/run-hook.cmd` is a polyglot: a
single file that's valid as both a Windows batch script and a Unix shell script.
On Windows, `cmd.exe` runs the batch portion, which locates `bash` (Git for
Windows, then `bash` on PATH) and runs the named hook script; if no bash is
found it exits cleanly so the harness still works, just without injection. On
Unix, the leading `:` makes the batch block a no-op and the shell runs the
script directly.

Two rules this enforces, which you must respect:

- **Hook scripts are extensionless** (`session-start`, not `session-start.sh`).
  Claude Code's Windows handling prepends `bash` to any command containing
  `.sh`, which would double-invoke. Name your hook script without an extension.
- Don't write per-OS variants of the hook script. One extensionless bash script
  plus the polyglot wrapper covers all three platforms.

`hooks/run-hook.cmd` itself is the authoritative implementation — read it. See
`docs/windows/polyglot-hooks.md` for the background and rationale behind the
dispatcher pattern.

---

## Part 8 — Submitting the PR

- Target the **`dev`** branch. One harness per PR.
- Fill in the PR template's **"New harness support"** section and paste the
  complete acceptance-test transcript (the "Let's make a react todo list"
  session showing `brainstorming` auto-triggering). A PR without this proof will
  be closed.
- Superpowers is a zero-dependency plugin. Don't add a third-party runtime
  dependency. Adding a new harness is the one carve-out the contributor rules
  allow, and even then keep it to what the integration strictly requires —
  type-only imports that compile away are fine; runtime packages are not.
- Don't touch skill bodies (Part 1). If you found yourself editing a `SKILL.md`
  to make the port work, the fix belongs in your tool mapping instead.

---

## Appendix A — Reference integrations (current)

Use this as the live index; when in doubt, read the files, not this table.

| Harness | Entry point | Bootstrap mechanism | Tool mapping | Tests | Distribution |
|---|---|---|---|---|---|
| Antigravity (`agy`) | `.antigravity-plugin/plugin.json` | surfaced skill index: `using-superpowers`' description triggers it (no session-start hook event exists) | `references/antigravity-tools.md` | `tests/antigravity/` | `agy plugin install` git URL; Antigravity Marketplace |
| Claude Code | `.claude-plugin/plugin.json` + `hooks/hooks.json` | shell hook → `hooks/session-start` (`hookSpecificOutput.additionalContext`) | native `Skill` tool; no adapter file needed | `tests/hooks/` | marketplace |
| Codex | `.codex-plugin/plugin.json` (declares empty `hooks`) | native skill discovery (no session-start hook) | `references/codex-tools.md` | `tests/codex/`, `tests/codex-plugin-sync/` | fork sync (`scripts/sync-to-codex-plugin.sh`) |
| Cursor | `.cursor-plugin/plugin.json` + `hooks/hooks-cursor.json` | shell hook → `hooks/session-start` (`additional_context`) | none needed (Claude Code–compatible tool surface) | `tests/hooks/` | hand-authored |
| Copilot CLI | (shares Claude Code hook path; `COPILOT_CLI` env) | shell hook → `hooks/session-start` (`additionalContext`) | none needed (Claude Code–compatible tool surface) | `tests/hooks/` | — |
| Gemini CLI | `gemini-extension.json` + `GEMINI.md` | instructions file `@`-includes bootstrap + mapping | `references/gemini-tools.md` | — | `gemini extensions install` |
| Kimi Code | `.kimi-plugin/plugin.json` | manifest `sessionStart.skill` loads `using-superpowers` | inline `skillInstructions` in manifest | `tests/kimi/` | marketplace or `/plugins install` GitHub URL |
| OpenCode | `.opencode/plugins/superpowers.js` (root `package.json` `main` for package installs; root `index.js` re-export for the V2 directory form) | in-process: `config` hook registers skills dir; `experimental.chat.messages.transform` (V1) / `session.hook` on `context`/`compaction`/`generate` (V2) injects user message | inline in `superpowers.js` | `tests/opencode/` | `opencode.json` `plugin` (V1) / `plugins` (V2) git URL |
| pi | `.pi/extensions/superpowers.ts` | in-process: package manifest registers skills; `context` event injects user message; lifecycle-flag + compaction-aware | `piToolMapping()` inline **and** `references/pi-tools.md` | `tests/pi/` | repo-root `package.json` fields |

## Appendix B — Gotchas that have bitten porters

- **Opt-in isn't a port.** If your human partner has to do anything per session
  to get Superpowers, the acceptance test fails. Re-read Part 2.
- **Wrong JSON field → silent failure or double injection.** Shape A only.
  Confirm the exact field/nesting; Claude Code reads two fields without dedup.
- **Hook-config schema varies per harness.** Shape A. Cursor's `hooks-cursor.json`
  looks nothing like the Claude Code one (`version`, lowercase `sessionStart`,
  relative command, no `matcher`/`type`/`async`). Match the closest existing file.
- **Plugin-root env var differs per harness.** Shape A. The hook command uses
  `${CLAUDE_PLUGIN_ROOT}` (Claude) or a relative path
  (Cursor). Use what your harness exports; the script re-derives the root itself.
- **System-message injection.** Shape B injects a *user* message on purpose
  (#750, #894). Don't "fix" it to a system message.
- **Disarming injection after the first prompt.** If your harness's transform
  output is not saved to session history (pi's `context` result is not), the
  bootstrap must be injected into every provider request. A flag cleared on a
  per-prompt event such as pi's `agent_end` drops the bootstrap after the first
  prompt (#2083).
- **Message-object shape is per-harness.** Shape B. pi and OpenCode use
  incompatible shapes; discover yours, don't copy a reference's object literal.
- **Hunting for a skill-registration API that doesn't exist.** A harness with no
  skill system (not just no `Skill` tool) has nothing to register — the model
  reads `SKILL.md` on demand. Don't assume a `skillPaths` equivalent exists.
- **Mapping in two places.** For in-process plugins the mapping may live both
  inline and in a `references/` file (pi). Update both.
- **The "never read skill files" line.** It means "don't bypass your platform's
  skill-loading mechanism," not "never use file-read." On a no-skill-tool harness
  that mechanism *is* reading `SKILL.md` — say so explicitly in the mapping
  (Part 5).
- **`.sh` on Windows.** Keep hook scripts extensionless (Part 7).
- **Bare `scripts/foo.sh` in skill prose.** Packagers can strip exec bits
  (Part 6). Invoke bundled scripts as `bash scripts/foo.sh` / `node scripts/foo.js`.
- **Unregistered version.** A new manifest not added to `.version-bump.json`
  ships stale (Part 6).
- **Editing skills to fit the harness.** Never. The fix goes in the tool mapping.
