# Проект поддержки OpenCode

**Дата:** 2025-11-22
**Авторы:** Bot и Jesse
**Статус:** проект завершён, ожидает реализации

## Обзор

Добавить полную поддержку superpowers для OpenCode.ai через нативную архитектуру плагинов OpenCode с общей основной функциональностью с существующей реализацией Codex.

## Предпосылки

OpenCode.ai — агент разработки, похожий на Claude Code и Codex. Предыдущие попытки переноса superpowers на OpenCode, PR #93 и PR #116, основывались на копировании файлов. В этом проекте предлагается другой подход: создать нативный плагин через систему JavaScript/TypeScript-плагинов OpenCode и совместно использовать код с реализацией Codex.

### Основные различия платформ

- **Claude Code:** нативная система плагинов Anthropic и навыки в файлах.
- **Codex:** отсутствует система плагинов → Markdown для начальной загрузки и скрипт CLI.
- **OpenCode:** плагины JavaScript/TypeScript с хуками событий и API пользовательских инструментов.

### Система агентов OpenCode

- **Основные агенты:** Build — по умолчанию, с полным доступом; Plan — ограниченный режим только для чтения.
- **Субагенты:** General для исследований, поиска и многоэтапных задач.
- **Вызов:** автоматическое направление задачи основными агентами или ручное упоминание `@mention`.
- **Конфигурация:** пользовательские агенты в `opencode.json` или `~/.config/opencode/agent/`.

## Архитектура

### Общая структура

1. **Общий базовый модуль** `lib/skills-core.js`: логика обнаружения и разбора навыков, используемая Codex и OpenCode.
2. **Обёртки конкретных платформ:** скрипт CLI `.codex/superpowers-codex` для Codex и модуль плагина `.opencode/plugin/superpowers.js` для OpenCode.
3. **Каталоги навыков:** базовые — `~/.config/opencode/superpowers/skills/` или место установки; личные — `~/.config/opencode/skills/`, имеют приоритет перед базовыми.

### Повторное использование кода

Вынести общие возможности из `.codex/superpowers-codex` в общий модуль. В техническом примере ниже сохранены исходные идентификаторы и комментарии:

```javascript
// lib/skills-core.js
module.exports = {
  extractFrontmatter(filePath),      // Parse name + description from YAML
  findSkillsInDir(dir, maxDepth),    // Recursive SKILL.md discovery
  findAllSkills(dirs),                // Scan multiple directories
  resolveSkillPath(skillName, dirs), // Handle shadowing (personal > core)
  checkForUpdates(repoDir)           // Git fetch/status check
};
```

### Формат frontmatter навыков

Текущий формат без поля `when_to_use`:

```yaml
---
name: skill-name
description: Use when [condition] - [what it does]; [additional context]
---
```

## Реализация плагина OpenCode

### Пользовательские инструменты

**Инструмент 1: `use_skill`.** Загружает в разговор содержимое конкретного навыка; соответствует инструменту Skill в Claude.

```javascript
{
  name: 'use_skill',
  description: 'Load and read a specific skill to guide your work',
  schema: z.object({
    skill_name: z.string().describe('Name of skill (e.g., "superpowers:brainstorming")')
  }),
  execute: async ({ skill_name }) => {
    const { skillPath, content, frontmatter } = resolveAndReadSkill(skill_name);
    const skillDir = path.dirname(skillPath);

    return `# ${frontmatter.name}
# ${frontmatter.description}
# Supporting tools and docs are in ${skillDir}
# ============================================

${content}`;
  }
}
```

**Инструмент 2: `find_skills`.** Перечисляет доступные навыки вместе с метаданными.

```javascript
{
  name: 'find_skills',
  description: 'List all available skills',
  schema: z.object({}),
  execute: async () => {
    const skills = discoverAllSkills();
    return skills.map(s =>
      `${s.namespace}:${s.name}
  ${s.description}
  Directory: ${s.directory}
`).join('\n');
  }
}
```

### Хук начала сеанса

При начале нового сеанса, событие `session.started`:

1. **Добавить содержимое using-superpowers:** полный текст навыка устанавливает обязательные рабочие процессы.
2. **Автоматически запустить find_skills:** сразу показать полный список навыков с каталогом каждого.
3. **Добавить инструкции сопоставления инструментов:** `TodoWrite` заменяется на `update_plan`, `Task` с субагентами — системой субагентов OpenCode через `@mention`, `Skill` — пользовательским `use_skill`; Read, Write, Edit и Bash заменяются нативными аналогами. Каталоги навыков содержат скрипты для bash, дополнительную документацию и специфичные утилиты. Исходный блок инструкции:

   ```markdown
   **Tool Mapping for OpenCode:**
   When skills reference tools you don't have, substitute:
   - `TodoWrite` → `update_plan`
   - `Task` with subagents → Use OpenCode subagent system (@mention)
   - `Skill` tool → `use_skill` custom tool
   - Read, Write, Edit, Bash → Your native equivalents

   **Skill directories contain:**
   - Supporting scripts (run with bash)
   - Additional documentation (read with read tool)
   - Utilities specific to that skill
   ```

4. **Проверить обновления без блокировки:** быстро выполнить git fetch с тайм-аутом и уведомить о доступных обновлениях.

### Структура плагина

```javascript
// .opencode/plugin/superpowers.js
const skillsCore = require('../../lib/skills-core');
const path = require('path');
const fs = require('fs');
const { z } = require('zod');

export const SuperpowersPlugin = async ({ client, directory, $ }) => {
  const superpowersDir = path.join(process.env.HOME, '.config/opencode/superpowers');
  const personalDir = path.join(process.env.HOME, '.config/opencode/skills');

  return {
    'session.started': async () => {
      const usingSuperpowers = await readSkill('using-superpowers');
      const skillsList = await findAllSkills();
      const toolMapping = getToolMappingInstructions();

      return {
        context: `${usingSuperpowers}\n\n${skillsList}\n\n${toolMapping}`
      };
    },

    tools: [
      {
        name: 'use_skill',
        description: 'Load and read a specific skill',
        schema: z.object({
          skill_name: z.string()
        }),
        execute: async ({ skill_name }) => {
          // Implementation using skillsCore
        }
      },
      {
        name: 'find_skills',
        description: 'List all available skills',
        schema: z.object({}),
        execute: async () => {
          // Implementation using skillsCore
        }
      }
    ]
  };
};
```

## Структура файлов

В исходной схеме `skills-core.js` — новый общий модуль, `superpowers-codex` обновляется, `superpowers.js` и `.opencode/INSTALL.md` создаются, каталог `skills/` остаётся без изменений:

```
superpowers/
├── lib/
│   └── skills-core.js           # NEW: Shared skill logic
├── .codex/
│   ├── superpowers-codex        # UPDATED: Use skills-core
│   ├── superpowers-bootstrap.md
│   └── INSTALL.md
├── .opencode/
│   ├── plugin/
│   │   └── superpowers.js       # NEW: OpenCode plugin
│   └── INSTALL.md               # NEW: Installation guide
└── skills/                       # Unchanged
```

## План реализации

### Этап 1: переработать общую основу

1. Создать `lib/skills-core.js`:
   - вынести разбор frontmatter из `.codex/superpowers-codex`;
   - вынести логику обнаружения навыков и определения путей с учётом приоритета личных навыков;
   - использовать только `name` и `description`, без `when_to_use`.
2. Обновить `.codex/superpowers-codex` для использования общей основы:
   - импортировать из `../lib/skills-core.js`;
   - удалить дублирующий код;
   - сохранить логику обёртки CLI.
3. Проверить работу Codex после изменений: команды начальной загрузки, use-skill и find-skills.

### Этап 2: создать плагин OpenCode

1. Создать `.opencode/plugin/superpowers.js`: импортировать общую основу из `../../lib/skills-core.js`, реализовать функцию плагина, пользовательские инструменты use_skill и find_skills и хук session.started.
2. Создать `.opencode/INSTALL.md` с инструкциями установки, настройки каталогов и конфигурации.
3. Проверить реализацию OpenCode: начальную загрузку сеанса, работу use_skill и find_skills и доступность каталогов навыков.

### Этап 3: документация и завершение

1. Обновить README, добавив поддержку OpenCode.
2. Добавить установку OpenCode в основную документацию.
3. Обновить RELEASE-NOTES.
4. Проверить корректную работу Codex и OpenCode.

## Следующие шаги

1. **Создать изолированную рабочую копию** через git worktrees, ветка `feature/opencode-support`.
2. **Применять TDD, где это уместно:** проверить общие функции, обнаружение и разбор навыков, интеграцию обеих платформ.
3. **Реализовать поэтапно:** сначала общая основа и Codex, затем проверка Codex, после неё — плагин OpenCode и документация.
4. **Стратегия проверки:** вручную проверить реальную установку OpenCode, загрузку навыков, каталоги, скрипты и сопоставление инструментов; отдельно сопоставить работу Codex и OpenCode.
5. **PR и слияние:** создать PR с полной реализацией, проверить его в чистой среде и слить в main.

## Преимущества

- **Повторное использование кода:** единый источник логики обнаружения и разбора навыков.
- **Сопровождение:** исправления ошибок применяются к обеим платформам.
- **Расширяемость:** проще добавлять будущие платформы, например Cursor и Windsurf.
- **Нативная интеграция:** корректное использование системы плагинов OpenCode.
- **Единообразие:** одинаковый опыт работы с навыками на разных платформах.
