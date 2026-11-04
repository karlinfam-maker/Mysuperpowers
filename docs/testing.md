# Проверка Superpowers

В Superpowers есть два разных вида проверок, каждый в своём каталоге:

- **`tests/`** — работает ли код плагина без обращения к языковой модели? Интеграционные тесты на Bash, Node и Python проверяют JavaScript-сервер обсуждения, загрузку плагина OpenCode, синхронизацию codex-plugin и аналитические утилиты.
- **`evals/`** — правильно ли ведут себя агенты в реальных сессиях с языковой моделью? Python-среда управляет настоящими сессиями Claude Code, Codex и Gemini CLI в tmux; языковая модель исполняет задачу, а проверяющий оценивает соблюдение навыков.

## Тесты плагина

Находятся в `tests/`. По описанию оригинального проекта:

- `tests/brainstorm-server/` — тесты Node для JavaScript-кода сервера обсуждения.
- `tests/opencode/` — тесты Bash для загрузки плагина OpenCode, кеширования начальных инструкций и регистрации инструментов.
- `tests/codex-plugin-sync/` — проверка синхронизации на Bash.
- `tests/kimi/` — проверки Bash/Python подключения манифеста плагина Kimi.
- `tests/claude-code/test-helpers.sh`, `analyze-token-usage.py` — утилиты остальных тестов Bash.
- `tests/claude-code/test-subagent-driven-development.sh` — проверка того, может ли агент описать SDD; аналога в quorum нет. Проверяет воспроизведение описания, а не фактическое поведение.
- `tests/claude-code/test-subagent-driven-development-integration.sh` — расширенная интеграционная проверка SDD с анализом токенов. Quorum покрывает часть YAGNI; тест Bash дополнительно проверяет число коммитов, отслеживание задач Claude Code и телеметрию токенов.
- `tests/claude-code/test-worktree-native-preference.sh` — проверка RED–GREEN–REFACTOR навыка worktree. Quorum покрывает этап PRESSURE; тест Bash дополнительно проверяет исходные состояния RED и GREEN.
- `tests/explicit-skill-requests/` — специфичные для Haiku, многоходовые и вызванные именем навыка тесты, не покрытые quorum.
- `tests/diagnosing-superpowers/test-skill-structure.sh` — структурная проверка навыка diagnosing-superpowers: frontmatter, связанные файлы, поиск утечек и ограничение объёма. Записи проверок поведения хранит сопровождающий вне репозитория.

Запускай тесты плагина через соответствующий `run-*.sh` каталога или `npm test`.

## Проверка поведения навыков

Находится в `evals/` — лаборатории [superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals/), ранее называвшейся Drill. Quorum — CLI одной из частей системы: он управляет реальными CLI агентов разработки через QA-агента Gauntlet и оценивает результаты по критериям сценария и детерминированным итоговым проверкам. Сценарии находятся в `evals/scenarios/<name>/`. Настройку, контейнерную среду и модель безопасности см. в `evals/README.md`. Быстрый запуск локальной проверки:

```bash
cd evals
bun install
export SUPERPOWERS_ROOT=/path/to/superpowers
bun run quorum run scenarios/triggering-test-driven-development --coding-agent claude
bun run quorum show <run-dir>
```

Сценарии Quorum медленные — от 3 до 30 и более минут каждый — и запускают реальные сессии языковых моделей с расширенными разрешениями. Сначала прочитай раздел Live Eval Risk в `evals/README.md`. Для публичного CI, по описанию авторов, безопасны только статические проверки `bun run check` и `bun run quorum check`. Предлагаемый режим — статические проверки в PR и реальные прогоны по расписанию ночью и по запросу.
