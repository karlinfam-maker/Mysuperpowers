#!/usr/bin/env bash
# Bisection script to find which test creates unwanted files/state
# Использование: ./find-polluter.sh <file_or_dir_to_check> <test_pattern>
# Пример: ./find-polluter.sh '.git' 'src/**/*.test.ts'

set -e

if [ $# -ne 2 ]; then
  echo "Использование: $0 <file_to_check> <test_pattern>"
  echo "Пример: $0 '.git' 'src/**/*.test.ts'"
  exit 1
fi

POLLUTION_CHECK="$1"
TEST_PATTERN="$2"

echo "🔍 Поиск теста, который создаёт: $POLLUTION_CHECK"
echo "Шаблон тестов: $TEST_PATTERN"
echo ""

# Get list of test files (find . emits ./-prefixed paths, so accept the
# pattern written with or without a leading ./)
TEST_PATTERN="${TEST_PATTERN#./}"
# find -path can't match '**/' against zero directory levels, so a pattern
# like src/**/*.test.ts would skip src/top.test.ts; also try the pattern
# with '**/' collapsed to cover files directly under the base directory.
TEST_FILES=$(find . \( -path "./$TEST_PATTERN" -o -path "./${TEST_PATTERN//\*\*\//}" \) | sort -u)
if [ -z "$TEST_FILES" ]; then
  TOTAL=0
else
  TOTAL=$(printf '%s\n' "$TEST_FILES" | wc -l | tr -d ' ')
fi

echo "Найдено файлов тестов: $TOTAL"
echo ""

COUNT=0
for TEST_FILE in $TEST_FILES; do
  COUNT=$((COUNT + 1))

  # Skip if pollution already exists
  if [ -e "$POLLUTION_CHECK" ]; then
    echo "⚠️  Лишние файлы уже существуют перед тестом $COUNT/$TOTAL"
    echo "   Пропущен: $TEST_FILE"
    continue
  fi

  echo "[$COUNT/$TOTAL] Проверка: $TEST_FILE"

  # Run the test
  npm test "$TEST_FILE" > /dev/null 2>&1 || true

  # Check if pollution appeared
  if [ -e "$POLLUTION_CHECK" ]; then
    echo ""
    echo "🎯 НАЙДЕН ИСТОЧНИК ЛИШНИХ ФАЙЛОВ!"
    echo "   Тест: $TEST_FILE"
    echo "   Создано: $POLLUTION_CHECK"
    echo ""
    echo "Сведения о лишних файлах:"
    ls -la "$POLLUTION_CHECK"
    echo ""
    echo "Для изучения:"
    echo "  npm test $TEST_FILE    # Запустить только этот тест"
    echo "  cat $TEST_FILE         # Посмотреть код теста"
    exit 1
  fi
done

echo ""
echo "✅ Источник лишних файлов не найден — все тесты чистые!"
exit 0
