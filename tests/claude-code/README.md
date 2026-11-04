# Тесты навыков Claude Code

Автоматические проверки навыков superpowers с использованием интерфейса командной строки Claude Code.

## Что проверяется

Набор проверяет загрузку навыков и выполнение их инструкций. Тесты запускают Claude Code без интерактивного интерфейса (`claude -p`) и проверяют поведение.

## Требования

- Установленный Claude Code CLI, доступный через PATH: команда `claude --version` должна работать.
- Установленный локальный плагин superpowers; инструкция находится в основном README.

## Запуск

Все быстрые тесты (рекомендуется):

```bash
./run-skill-tests.sh
```


Интеграционные тесты (медленные, 10–30 минут):

```bash
./run-skill-tests.sh --integration
```


Отдельный тест:

```bash
./run-skill-tests.sh --test test-subagent-driven-development.sh
```


Подробный вывод:

```bash
./run-skill-tests.sh --verbose
```


Свой тайм-аут:

```bash
./run-skill-tests.sh --timeout 1800  # 30 minutes for integration tests
```


## Структура тестов

### test-helpers.sh

Общие функции:

- `run_claude "prompt" [timeout]` — запустить Claude с запросом.
- `assert_contains output pattern name` — проверить наличие шаблона.
- `assert_not_contains output pattern name` — проверить отсутствие шаблона.
- `assert_count output pattern count name` — проверить точное количество совпадений.
- `assert_order output pattern_a pattern_b name` — проверить порядок.
- `create_test_project` — создать временную папку тестового проекта.
- `create_test_plan project_dir` — создать пример плана.

Каждый файл теста подключает `test-helpers.sh`, запускает Claude Code с определёнными запросами, проверяет ожидаемое поведение и возвращает 0 при успехе либо ненулевой код при ошибке.

## Пример теста

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: My Skill ==="

# Ask Claude about the skill
output=$(run_claude "What does the my-skill skill do?" 30)

# Verify response
assert_contains "$output" "expected behavior" "Skill describes behavior"

echo "=== All tests passed ==="
```


## Существующие тесты

### Быстрые тесты — запускаются по умолчанию

#### test-subagent-driven-development.sh

Проверяет содержание и требования навыка (около двух минут): загрузку и доступность, порядок проверок соответствия спецификации и качества кода, требования к самопроверке, эффективность чтения плана, критичность проверяющего спецификацию, циклы проверки и передачу контекста задачи.

### Интеграционные тесты — флаг `--integration`

#### test-subagent-driven-development-integration.sh

Проверка полного процесса (около 10–30 минут): создаёт тестовый проект Node.js и план из двух задач, выполняет план с помощью `subagent-driven-development`, затем проверяет, что план прочитан один раз в начале, субагентам передан полный текст задач, исполнители выполнили самопроверку, соответствие спецификации проверено до качества кода, проверяющий самостоятельно прочитал код, получена работающая реализация, тесты прошли и созданы надлежащие коммиты.

Проверка охватывает весь процесс, применение предусмотренных улучшений, следование навыку субагентами и работоспособность итогового кода.

#### test-worktree-native-preference.sh

Проверка RED-GREEN-REFACTOR для `using-git-worktrees` (около пяти минут):

- RED: навык без шага 1a — агент должен использовать `git worktree add`.
- GREEN: навык со шагом 1a — агент должен использовать встроенный инструмент EnterWorktree.
- PRESSURE: то же, что GREEN, при срочности и уже существующей `.worktrees/`.
- Сценарий `worktree-creation-under-pressure.yaml` охватывает только этап PRESSURE.

## Добавление тестов

1. Создайте файл `test-<skill-name>.sh`.
2. Подключите `test-helpers.sh`.
3. Напишите проверки с использованием `run_claude` и утверждений.
4. Добавьте тест в список в `run-skill-tests.sh`.
5. Разрешите выполнение: `chmod +x test-<skill-name>.sh`.

## Тайм-ауты

По умолчанию на каждый тест отводится пять минут. Ответ Claude Code может занять время; при необходимости измените значение с помощью `--timeout`. Делайте тесты достаточно узкими, чтобы они не выполнялись слишком долго.

## Разбор ошибок

С `--verbose` виден полный вывод Claude:

```bash
./run-skill-tests.sh --verbose --test test-subagent-driven-development.sh
```


Без подробного режима вывод показывается только при ошибках.

## Запуск в CI/CD

```bash
# Run with explicit timeout for CI environments
./run-skill-tests.sh --timeout 900

# Exit code 0 = success, non-zero = failure
```


## Примечания

- Тесты проверяют инструкции навыков, а не полное выполнение всех процессов.
- Полные проверки процессов занимают много времени.
- Проверяйте основные требования навыка; тесты должны давать воспроизводимый результат.
- Не привязывайте тесты к деталям реализации.
