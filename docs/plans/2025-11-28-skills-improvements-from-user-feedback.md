# Улучшение навыков по отзывам пользователей

**Дата:** 2025-11-28
**Статус:** черновик
**Источник:** два экземпляра Claude, использовавших superpowers в реальной разработке

---

## Краткое содержание

Два экземпляра Claude подробно описали опыт реальных сеансов разработки. Отзывы показывают **системные пробелы** навыков, из-за которых предотвратимые ошибки попадали в результат даже при соблюдении навыков.

**Основной вывод:** это сообщения о проблемах, а не только предложения решений. Проблемы реальны; решения требуют тщательной оценки.

Основные темы:

1. **Пробелы проверки:** подтверждается успех операции, но не достижение нужного результата.
2. **Порядок работы процессов:** фоновые процессы накапливаются и мешают субагентам.
3. **Оптимизация контекста:** субагенты получают слишком много лишних сведений.
4. **Отсутствие самопроверки:** перед передачей результата нет просьбы критически оценить свою работу.
5. **Безопасность моков:** моки могут расходиться с интерфейсами незаметно для тестов.
6. **Вызов навыков:** навыки существуют, но их не читают и не используют.

---

## Обнаруженные проблемы

### Проблема 1: не проверяется результат изменения конфигурации

**Что произошло:** субагент проверял интеграцию OpenAI, установил переменную `OPENAI_API_KEY`, получил ответы 200 и сообщил, что интеграция работает. Однако ответ содержал `"model": "claude-sonnet-4-20250514"`: фактически использовался Anthropic.

**Причина:** `verification-before-completion` проверяет успех операции, но не соответствие результата задуманному изменению конфигурации.

**Влияние:** высокое — ложная уверенность в интеграционных тестах и попадание ошибок в эксплуатацию.

**Примеры:** переключение провайдера LLM проверяется статусом 200 без имени модели; включение флага функции — отсутствием ошибок без проверки самой функции; смена окружения — успехом развёртывания без проверки переменных.

---

### Проблема 2: накопление фоновых процессов

**Что произошло:** несколько субагентов запускали фоновые серверы; накопилось не менее четырёх процессов, старые продолжали занимать порты. Последующий E2E-тест обратился к устаревшему серверу с неверной конфигурацией и дал запутанный или неверный результат.

**Причина:** субагенты не сохраняют состояние и не знают о процессах предшественников; протокола очистки нет.

**Влияние:** от среднего до высокого — тесты обращаются к неправильному серверу, возникают ложные успехи и ошибки и усложняется отладка.

---

### Проблема 3: избыточный контекст запросов субагентам

**Что произошло:** вместо стандартной передачи полного плана в эксперименте субагенту дали только задачу, образец, файл и команду проверки. Результат: более быстрая и сосредоточенная работа, чаще с завершением с первой попытки.

**Причина:** субагенты тратят токены и внимание на не относящиеся к задаче разделы плана.

**Влияние:** среднее — замедление и увеличение числа неудачных попыток.

**Пример сработавшего запроса.** Субагенту поручается добавить один E2E-тест `TestE2E_FeaturePrivilegedMode` в `pkg/runner/e2e_test.go`, проверить запуск контейнера с `--privileged` при `"privileged": true`, следовать существующему образцу и выполнить указанную команду. Исходный запрос сохранён для воспроизводимости:

```
You are adding a single E2E test to packnplay's test suite.

**Your task:** Add `TestE2E_FeaturePrivilegedMode` to `pkg/runner/e2e_test.go`

**What to test:** A local devcontainer feature that requests `"privileged": true`
in its metadata should result in the container running with `--privileged` flag.

**Follow the exact pattern of TestE2E_FeatureOptionValidation** (at the end of the file)

**After writing, run:** `go test -v ./pkg/runner -run TestE2E_FeaturePrivilegedMode -timeout 5m`
```

---

### Проблема 4: нет самопроверки до передачи результата

**Что произошло:** добавили вопрос «Посмотрите на свою работу свежим взглядом: что можно улучшить?». Исполнитель задачи 5 определил, что тест не проходит из-за ошибки реализации, а не теста, и нашёл строку 99: `strings.Join(metadata.Entrypoint, " ")` формировала неверный синтаксис Docker. Без самопроверки он сообщил бы лишь о падении теста, не выяснив причину.

**Причина:** исполнители не всегда останавливаются для критической оценки работы перед сообщением о завершении.

**Влияние:** среднее — проверяющему передаются ошибки, которые исполнитель мог обнаружить сам.

---

### Проблема 5: расхождение мока и интерфейса

**Что произошло:** интерфейс определял `close()`, ошибочный код вызывал `cleanup()`, а мок повторял ошибку и тоже определял `cleanup()`. Тесты прошли, но выполнение завершилось ошибкой «adapter.cleanup is not a function». Исходный пример сохранён:

```typescript
// Interface defines close()
interface PlatformAdapter {
  close(): Promise<void>;
}

// Code (BUGGY) calls cleanup()
await adapter.cleanup();

// Mock (MATCHES BUG) defines cleanup()
vi.mock('web-adapter', () => ({
  WebAdapter: vi.fn().mockImplementation(() => ({
    cleanup: vi.fn().mockResolvedValue(undefined),  // Wrong!
  })),
}));
```

**Причина:** мок создавался по вызовам ошибочного кода, а не по определению интерфейса. TypeScript не обнаруживает неверные имена методов в таких встроенных моках.

**Влияние:** высокое — ложная уверенность в тестах и сбой при выполнении.

**Почему `testing-anti-patterns` не предотвратил ошибку:** навык обсуждал проверку поведения моков и создание моков без понимания, но не конкретное правило выводить мок из интерфейса, а не реализации.

---

### Проблема 6: доступ проверяющего к файлам

**Что произошло:** субагент ревью сообщил, что тестового файла нет в репозитории, хотя файл существовал; проверяющий не знал, что его нужно сначала явно прочитать.

**Причина:** запросы проверяющему не содержат явных инструкций чтения файлов.

**Влияние:** от низкого до среднего — неудачные или неполные проверки.

---

### Проблема 7: задержка исправлений

**Что произошло:** исполнитель обнаружил ошибку при самопроверке и знал исправление, но процесс требовал отчёта контроллеру, запуска отдельного исправляющего агента, его работы и последующей проверки. Дополнительная передача увеличивала задержку без пользы.

**Причина:** жёсткое разделение исполнителя и исправляющего даже при уже выявленной причине.

**Влияние:** низкое — увеличивается время, но проблема корректности не возникает.

---

### Проблема 8: навыки не читаются

**Что произошло:** навык `testing-anti-patterns` существовал, но ни человек, ни субагенты не прочитали его до написания тестов. Он предотвратил бы часть проблем, хотя не все, см. проблему 5.

**Причина:** нет требования субагентам читать соответствующие навыки и указания на это в запросах.

**Влияние:** среднее — работа над навыками не приносит пользы, если их не используют.

---

## Proposed Improvements

### 1. verification-before-completion: Add Configuration Change Verification

**Add new section:**

```markdown
## Verifying Configuration Changes

When testing changes to configuration, providers, feature flags, or environment:

**Don't just verify the operation succeeded. Verify the output reflects the intended change.**

### Common Failure Pattern

Operation succeeds because *some* valid config exists, but it's not the config you intended to test.

### Examples

| Change | Insufficient | Required |
|--------|-------------|----------|
| Switch LLM provider | Status 200 | Response contains expected model name |
| Enable feature flag | No errors | Feature behavior actually active |
| Change environment | Deploy succeeds | Logs/vars reference new environment |
| Set credentials | Auth succeeds | Authenticated user/context is correct |

### Gate Function

```
BEFORE claiming configuration change works:

1. IDENTIFY: What should be DIFFERENT after this change?
2. LOCATE: Where is that difference observable?
   - Response field (model name, user ID)
   - Log line (environment, provider)
   - Behavior (feature active/inactive)
3. RUN: Command that shows the observable difference
4. VERIFY: Output contains expected difference
5. ONLY THEN: Claim configuration change works

Red flags:
  - "Request succeeded" without checking content
  - Checking status code but not response body
  - Verifying no errors but not positive confirmation
```

**Why this works:**
Forces verification of INTENT, not just operation success.

---

### 2. subagent-driven-development: Add Process Hygiene for E2E Tests

**Add new section:**

```markdown
## Process Hygiene for E2E Tests

When dispatching subagents that start services (servers, databases, message queues):

### Problem

Subagents are stateless - they don't know about processes started by previous subagents. Background processes persist and can interfere with later tests.

### Solution

**Before dispatching E2E test subagent, include cleanup in prompt:**

```
BEFORE starting any services:
1. Kill existing processes: pkill -f "<service-pattern>" 2>/dev/null || true
2. Wait for cleanup: sleep 1
3. Verify port free: lsof -i :<port> && echo "ERROR: Port still in use" || echo "Port free"

AFTER tests complete:
1. Kill the process you started
2. Verify cleanup: pgrep -f "<service-pattern>" || echo "Cleanup successful"
```

### Example

```
Task: Run E2E test of API server

Prompt includes:
"Before starting the server:
- Kill any existing servers: pkill -f 'node.*server.js' 2>/dev/null || true
- Verify port 3001 is free: lsof -i :3001 && exit 1 || echo 'Port available'

After tests:
- Kill the server you started
- Verify: pgrep -f 'node.*server.js' || echo 'Cleanup verified'"
```

### Why This Matters

- Stale processes serve requests with wrong config
- Port conflicts cause silent failures
- Process accumulation slows system
- Confusing test results (hitting wrong server)
```

**Trade-off analysis:**
- Adds boilerplate to prompts
- But prevents very confusing debugging
- Worth it for E2E test subagents

---

### 3. subagent-driven-development: Add Lean Context Option

**Modify Step 2: Execute Task with Subagent**

**Before:**
```
Read that task carefully from [plan-file].
```

**After:**
```
## Context Approaches

**Full Plan (default):**
Use when tasks are complex or have dependencies:
```
Read Task N from [plan-file] carefully.
```

**Lean Context (for independent tasks):**
Use when task is standalone and pattern-based:
```
You are implementing: [1-2 sentence task description]

File to modify: [exact path]
Pattern to follow: [reference to existing function/test]
What to implement: [specific requirement]
Verification: [exact command to run]

[Do NOT include full plan file]
```

**Use lean context when:**
- Task follows existing pattern (add similar test, implement similar feature)
- Task is self-contained (doesn't need context from other tasks)
- Pattern reference is sufficient (e.g., "follow TestE2E_FeatureOptionValidation")

**Use full plan when:**
- Task has dependencies on other tasks
- Requires understanding of overall architecture
- Complex logic that needs context
```

**Example:**
```
Lean context prompt:

"You are adding a test for privileged mode in devcontainer features.

File: pkg/runner/e2e_test.go
Pattern: Follow TestE2E_FeatureOptionValidation (at end of file)
Test: Feature with `"privileged": true` in metadata results in `--privileged` flag
Verify: go test -v ./pkg/runner -run TestE2E_FeaturePrivilegedMode -timeout 5m

Report: Implementation, test results, any issues."
```

**Why this works:**
Reduces token usage, increases focus, faster completion when appropriate.

---

### 4. subagent-driven-development: Add Self-Reflection Step

**Modify Step 2: Execute Task with Subagent**

**Add to prompt template:**

```
When done, BEFORE reporting back:

Take a step back and review your work with fresh eyes.

Ask yourself:
- Does this actually solve the task as specified?
- Are there edge cases I didn't consider?
- Did I follow the pattern correctly?
- If tests are failing, what's the ROOT CAUSE (implementation bug vs test bug)?
- What could be better about this implementation?

If you identify issues during this reflection, fix them now.

Then report:
- What you implemented
- Self-reflection findings (if any)
- Test results
- Files changed
```

**Why this works:**
Catches bugs implementer can find themselves before handoff. Documented case: identified entrypoint bug through self-reflection.

**Trade-off:**
Adds ~30 seconds per task, but catches issues before review.

---

### 5. requesting-code-review: Add Explicit File Reading

**Modify the code-reviewer template:**

**Add at the beginning:**

```markdown
## Files to Review

BEFORE analyzing, read these files:

1. [List specific files that changed in the diff]
2. [Files referenced by changes but not modified]

Use Read tool to load each file.

If you cannot find a file:
- Check exact path from diff
- Try alternate locations
- Report: "Cannot locate [path] - please verify file exists"

DO NOT proceed with review until you've read the actual code.
```

**Why this works:**
Explicit instruction prevents "file not found" issues.

---

### 6. testing-anti-patterns: Add Mock-Interface Drift Anti-Pattern

**Add new Anti-Pattern 6:**

```markdown
## Anti-Pattern 6: Mocks Derived from Implementation

**The violation:**
```typescript
// Code (BUGGY) calls cleanup()
await adapter.cleanup();

// Mock (MATCHES BUG) has cleanup()
const mock = {
  cleanup: vi.fn().mockResolvedValue(undefined)
};

// Interface (CORRECT) defines close()
interface PlatformAdapter {
  close(): Promise<void>;
}
```

**Why this is wrong:**
- Mock encodes the bug into the test
- TypeScript can't catch inline mocks with wrong method names
- Test passes because both code and mock are wrong
- Runtime crashes when real object is used

**The fix:**
```typescript
// ✅ GOOD: Derive mock from interface

// Step 1: Open interface definition (PlatformAdapter)
// Step 2: List methods defined there (close, initialize, etc.)
// Step 3: Mock EXACTLY those methods

const mock = {
  initialize: vi.fn().mockResolvedValue(undefined),
  close: vi.fn().mockResolvedValue(undefined),  // From interface!
};

// Now test FAILS because code calls cleanup() which doesn't exist
// That failure reveals the bug BEFORE runtime
```

### Gate Function

```
BEFORE writing any mock:

  1. STOP - Do NOT look at the code under test yet
  2. FIND: The interface/type definition for the dependency
  3. READ: The interface file
  4. LIST: Methods defined in the interface
  5. MOCK: ONLY those methods with EXACTLY those names
  6. DO NOT: Look at what your code calls

  IF your test fails because code calls something not in mock:
    ✅ GOOD - The test found a bug in your code
    Fix the code to call the correct interface method
    NOT the mock

  Red flags:
    - "I'll mock what the code calls"
    - Copying method names from implementation
    - Mock written without reading interface
    - "The test is failing so I'll add this method to the mock"
```

**Detection:**

When you see runtime error "X is not a function" and tests pass:
1. Check if X is mocked
2. Compare mock methods to interface methods
3. Look for method name mismatches
```

**Why this works:**
Directly addresses the failure pattern from feedback.

---

### 7. subagent-driven-development: Require Skills Reading for Test Subagents

**Add to prompt template when task involves testing:**

```markdown
BEFORE writing any tests:

1. Read testing-anti-patterns skill:
   Use Skill tool: superpowers:testing-anti-patterns

2. Apply gate functions from that skill when:
   - Writing mocks
   - Adding methods to production classes
   - Mocking dependencies

This is NOT optional. Tests that violate anti-patterns will be rejected in review.
```

**Why this works:**
Ensures skills are actually used, not just exist.

**Trade-off:**
Adds time to each task, but prevents entire classes of bugs.

---

### 8. subagent-driven-development: Allow Implementer to Fix Self-Identified Issues

**Modify Step 2:**

**Current:**
```
Subagent reports back with summary of work.
```

**Proposed:**
```
Subagent performs self-reflection, then:

IF self-reflection identifies fixable issues:
  1. Fix the issues
  2. Re-run verification
  3. Report: "Initial implementation + self-reflection fix"

ELSE:
  Report: "Implementation complete"

Include in report:
- Self-reflection findings
- Whether fixes were applied
- Final verification results
```

**Why this works:**
Reduces latency when implementer already knows the fix. Documented case: would have saved one round-trip for entrypoint bug.

**Trade-off:**
Slightly more complex prompt, but faster end-to-end.

---

## План реализации

### Этап 1: высокая значимость, низкий риск — выполнить сначала

1. **verification-before-completion: проверка изменения конфигурации.** Понятное дополнение без изменения существующего текста; устраняет значимую проблему ложной уверенности в тестах. Файл `skills/verification-before-completion/SKILL.md`.
2. **testing-anti-patterns: расхождение мока и интерфейса.** Добавляет антипаттерн без изменения существующих; устраняет серьёзную причину сбоев выполнения. Файл `skills/testing-anti-patterns/SKILL.md`.
3. **requesting-code-review: явное чтение файлов.** Простое дополнение шаблона для ситуации, когда проверяющий не находит файлы. Файл `skills/requesting-code-review/SKILL.md`.

### Этап 2: умеренные изменения — тщательно проверить

4. **subagent-driven-development: порядок процессов.** Новый раздел без изменения процесса; улучшает надёжность тестов.
5. **subagent-driven-development: самопроверка.** Меняет шаблон запроса и потому рискованнее, но зафиксировано обнаружение ошибок.
6. **subagent-driven-development: требование читать навыки.** Увеличивает объём запроса, но обеспечивает фактическое использование навыков.

Все три относятся к `skills/subagent-driven-development/SKILL.md`.

### Этап 3: оптимизация — сначала проверить

7. **subagent-driven-development: сокращённый контекст.** Два подхода усложняют процесс; необходимо убедиться, что они не вызывают путаницу.
8. **subagent-driven-development: исправление исполнителем.** Изменяет процесс и более рискованно; это оптимизация, а не исправление ошибки.

Оба пункта относятся к `skills/subagent-driven-development/SKILL.md`.

---

## Открытые вопросы

1. **Сокращённый контекст:** делать ли его стандартом для задач по образцу; как выбирать подход; не приведёт ли чрезмерное сокращение к потере важного контекста?
2. **Самопроверка:** насколько она замедлит простые задачи; нужна ли только для сложных; как предотвратить превращение в формальность из-за усталости?
3. **Порядок процессов:** включить в subagent-driven-development или отдельный навык; нужен ли он вне E2E; как обрабатывать процессы, которые должны оставаться работающими, например серверы разработки?
4. **Обязательное чтение навыков:** требовать ли его от всех субагентов; как не раздувать запросы; не приведёт ли чрезмерная документация к потере фокуса?

---

## Показатели успеха

1. **Проверка конфигурации:** нет случаев «тест прошёл, но использовалась не та конфигурация»; Jesse не указывает, что проверяется не то, что предполагалось.
2. **Порядок процессов:** тесты не обращаются к неправильному серверу; при E2E нет конфликтов портов.
3. **Расхождение моков:** нет случаев «тесты прошли, но выполнение упало из-за отсутствующего метода»; имена методов моков соответствуют интерфейсам.
4. **Самопроверка:** измеряется наличие её результатов в отчётах и качественно оценивается уменьшение числа ошибок, доходящих до ревью.
5. **Чтение навыков:** субагенты ссылаются в отчётах на проверочные функции навыков; при ревью реже обнаруживаются антипаттерны.

---

## Риски и меры

### Раздувание запросов

**Проблема:** все требования вместе могут перегрузить запросы.
**Меры:** внедрять поэтапно; делать некоторые дополнения условными, например порядок процессов только для E2E; рассмотреть шаблоны для разных задач.

### Избыточный анализ

**Проблема:** слишком много самопроверок замедляет работу.
**Меры:** проверочные функции должны занимать секунды, а не минуты; сначала предлагать сокращённый контекст по выбору; отслеживать время задач.

### Ложная уверенность

**Проблема:** выполнение списка не гарантирует корректность.
**Меры:** подчёркивать, что проверочные функции задают минимум, а не предел; сохранять требование применять суждение; указывать, что навыки предотвращают распространённые, но не все ошибки.

### Расхождение навыков

**Проблема:** разные навыки могут давать противоречивые советы.
**Меры:** проверять согласованность всех изменений, документировать взаимодействие в разделах Integration, проверять на реальных сценариях до развёртывания.

---

## Рекомендация

**Сразу приступить к этапу 1:** проверка изменения конфигурации в verification-before-completion, расхождение мока и интерфейса в testing-anti-patterns, явное чтение файлов в requesting-code-review.

**Этап 2 проверить с Jesse до завершения:** получить отзыв о влиянии самопроверки, проверить порядок процессов и убедиться, что обязательное чтение навыков оправдывает накладные расходы.

**Этап 3 отложить до проверки:** сокращённому контексту нужны реальные испытания, изменение процесса исправлений исполнителем требует осторожной оценки.

Эти изменения направлены на реальные проблемы из отзывов и одновременно снижают риск ухудшить навыки.
