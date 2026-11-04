# План реализации поддержки OpenCode

> **Для агентов-исполнителей:** ОБЯЗАТЕЛЬНЫЙ ПОДНАВЫК: используйте superpowers:executing-plans для выполнения плана по задачам.

**Цель:** обеспечить полную поддержку superpowers в OpenCode.ai через нативный плагин JavaScript с общей функциональностью существующей реализации Codex.

**Архитектура:** вынести общую логику обнаружения и разбора навыков в `lib/skills-core.js`, перевести на неё Codex и создать плагин OpenCode через нативный API с пользовательскими инструментами и хуками сеанса.

**Технологии:** Node.js, JavaScript, OpenCode Plugin API, рабочие копии Git.

---

## Этап 1: создать общий базовый модуль

### Задача 1: выделить разбор frontmatter

**Файлы:**
- Создать: `lib/skills-core.js`
- Источник: `.codex/superpowers-codex` (строки 40-74)

**Шаг 1: создать lib/skills-core.js с функцией extractFrontmatter**

```javascript
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Extract YAML frontmatter from a skill file.
 * Current format:
 * ---
 * name: skill-name
 * description: Use when [condition] - [what it does]
 * ---
 *
 * @param {string} filePath - Path to SKILL.md file
 * @returns {{name: string, description: string}}
 */
function extractFrontmatter(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.split('\n');

        let inFrontmatter = false;
        let name = '';
        let description = '';

        for (const line of lines) {
            if (line.trim() === '---') {
                if (inFrontmatter) break;
                inFrontmatter = true;
                continue;
            }

            if (inFrontmatter) {
                const match = line.match(/^(\w+):\s*(.*)$/);
                if (match) {
                    const [, key, value] = match;
                    switch (key) {
                        case 'name':
                            name = value.trim();
                            break;
                        case 'description':
                            description = value.trim();
                            break;
                    }
                }
            }
        }

        return { name, description };
    } catch (error) {
        return { name: '', description: '' };
    }
}

module.exports = {
    extractFrontmatter
};
```

**Шаг 2: проверить создание файла**

Выполнить: `ls -l lib/skills-core.js`
Ожидается: файл существует

**Шаг 3: создать коммит**

```bash
git add lib/skills-core.js
git commit -m "feat: create shared skills core module with frontmatter parser"
```

---

### Задача 2: выделить логику обнаружения навыков

**Файлы:**
- Изменить: `lib/skills-core.js`
- Источник: `.codex/superpowers-codex` (строки 97-136)

**Шаг 1: добавить функцию findSkillsInDir в skills-core.js**

Добавить перед `module.exports`:

```javascript
/**
 * Find all SKILL.md files in a directory recursively.
 *
 * @param {string} dir - Directory to search
 * @param {string} sourceType - 'personal' or 'superpowers' for namespacing
 * @param {number} maxDepth - Maximum recursion depth (default: 3)
 * @returns {Array<{path: string, name: string, description: string, sourceType: string}>}
 */
function findSkillsInDir(dir, sourceType, maxDepth = 3) {
    const skills = [];

    if (!fs.existsSync(dir)) return skills;

    function recurse(currentDir, depth) {
        if (depth > maxDepth) return;

        const entries = fs.readdirSync(currentDir, { withFileTypes: true });

        for (const entry of entries) {
            const fullPath = path.join(currentDir, entry.name);

            if (entry.isDirectory()) {
                // Check for SKILL.md in this directory
                const skillFile = path.join(fullPath, 'SKILL.md');
                if (fs.existsSync(skillFile)) {
                    const { name, description } = extractFrontmatter(skillFile);
                    skills.push({
                        path: fullPath,
                        skillFile: skillFile,
                        name: name || entry.name,
                        description: description || '',
                        sourceType: sourceType
                    });
                }

                // Recurse into subdirectories
                recurse(fullPath, depth + 1);
            }
        }
    }

    recurse(dir, 0);
    return skills;
}
```

**Шаг 2: обновить module.exports**

Заменить строку экспорта на:

```javascript
module.exports = {
    extractFrontmatter,
    findSkillsInDir
};
```

**Шаг 3: проверить синтаксис**

Выполнить: `node -c lib/skills-core.js`
Ожидается: нет вывода, успех

**Шаг 4: создать коммит**

```bash
git add lib/skills-core.js
git commit -m "feat: add skill discovery function to core module"
```

---

### Задача 3: выделить логику определения пути навыка

**Файлы:**
- Изменить: `lib/skills-core.js`
- Источник: `.codex/superpowers-codex` (строки 212-280)

**Шаг 1: добавить функцию resolveSkillPath**

Добавить перед `module.exports`:

```javascript
/**
 * Resolve a skill name to its file path, handling shadowing
 * (personal skills override superpowers skills).
 *
 * @param {string} skillName - Name like "superpowers:brainstorming" or "my-skill"
 * @param {string} superpowersDir - Path to superpowers skills directory
 * @param {string} personalDir - Path to personal skills directory
 * @returns {{skillFile: string, sourceType: string, skillPath: string} | null}
 */
function resolveSkillPath(skillName, superpowersDir, personalDir) {
    // Strip superpowers: prefix if present
    const forceSuperpowers = skillName.startsWith('superpowers:');
    const actualSkillName = forceSuperpowers ? skillName.replace(/^superpowers:/, '') : skillName;

    // Try personal skills first (unless explicitly superpowers:)
    if (!forceSuperpowers && personalDir) {
        const personalPath = path.join(personalDir, actualSkillName);
        const personalSkillFile = path.join(personalPath, 'SKILL.md');
        if (fs.existsSync(personalSkillFile)) {
            return {
                skillFile: personalSkillFile,
                sourceType: 'personal',
                skillPath: actualSkillName
            };
        }
    }

    // Try superpowers skills
    if (superpowersDir) {
        const superpowersPath = path.join(superpowersDir, actualSkillName);
        const superpowersSkillFile = path.join(superpowersPath, 'SKILL.md');
        if (fs.existsSync(superpowersSkillFile)) {
            return {
                skillFile: superpowersSkillFile,
                sourceType: 'superpowers',
                skillPath: actualSkillName
            };
        }
    }

    return null;
}
```

**Шаг 2: обновить module.exports**

```javascript
module.exports = {
    extractFrontmatter,
    findSkillsInDir,
    resolveSkillPath
};
```

**Шаг 3: проверить синтаксис**

Выполнить: `node -c lib/skills-core.js`
Ожидается: нет вывода

**Шаг 4: создать коммит**

```bash
git add lib/skills-core.js
git commit -m "feat: add skill path resolution with shadowing support"
```

---

### Задача 4: выделить логику проверки обновлений

**Файлы:**
- Изменить: `lib/skills-core.js`
- Источник: `.codex/superpowers-codex` (строки 16-38)

**Шаг 1: добавить функцию checkForUpdates**

Добавить в начале после requires:

```javascript
const { execSync } = require('child_process');
```

Добавить перед `module.exports`:

```javascript
/**
 * Check if a git repository has updates available.
 *
 * @param {string} repoDir - Path to git repository
 * @returns {boolean} - True if updates are available
 */
function checkForUpdates(repoDir) {
    try {
        // Quick check with 3 second timeout to avoid delays if network is down
        const output = execSync('git fetch origin && git status --porcelain=v1 --branch', {
            cwd: repoDir,
            timeout: 3000,
            encoding: 'utf8',
            stdio: 'pipe'
        });

        // Parse git status output to see if we're behind
        const statusLines = output.split('\n');
        for (const line of statusLines) {
            if (line.startsWith('## ') && line.includes('[behind ')) {
                return true; // We're behind remote
            }
        }
        return false; // Up to date
    } catch (error) {
        // Network down, git error, timeout, etc. - don't block bootstrap
        return false;
    }
}
```

**Шаг 2: обновить module.exports**

```javascript
module.exports = {
    extractFrontmatter,
    findSkillsInDir,
    resolveSkillPath,
    checkForUpdates
};
```

**Шаг 3: проверить синтаксис**

Выполнить: `node -c lib/skills-core.js`
Ожидается: нет вывода

**Шаг 4: создать коммит**

```bash
git add lib/skills-core.js
git commit -m "feat: add git update checking to core module"
```

---

## Этап 2: перевести Codex на общий базовый модуль

### Задача 5: добавить импорт общего модуля в Codex

**Файлы:**
- Изменить: `.codex/superpowers-codex` (добавить импорт в начале)

**Шаг 1: добавить импорт**

После существующих requires в начале файла, примерно на строке 6, добавить:

```javascript
const skillsCore = require('../lib/skills-core');
```

**Шаг 2: проверить синтаксис**

Выполнить: `node -c .codex/superpowers-codex`
Ожидается: нет вывода

**Шаг 3: создать коммит**

```bash
git add .codex/superpowers-codex
git commit -m "refactor: import shared skills core in codex"
```

---

### Задача 6: заменить extractFrontmatter на общую версию

**Файлы:**
- Изменить: `.codex/superpowers-codex` (строки 40–74)

**Шаг 1: удалить локальную функцию extractFrontmatter**

Удалить строки 40–74 — полное определение функции extractFrontmatter.

**Шаг 2: обновить все вызовы extractFrontmatter**

Заменить все вызовы `extractFrontmatter(` на `skillsCore.extractFrontmatter(`.

Примерные затронутые строки: 90 и 310.

**Шаг 3: проверить работу скрипта после изменений**

Выполнить: `.codex/superpowers-codex find-skills | head -20`
Ожидается: показан список навыков

**Шаг 4: создать коммит**

```bash
git add .codex/superpowers-codex
git commit -m "refactor: use shared extractFrontmatter in codex"
```

---

### Задача 7: заменить findSkillsInDir на общую версию

**Файлы:**
- Изменить: `.codex/superpowers-codex` (примерно строки 97–136)

**Шаг 1: удалить локальную функцию findSkillsInDir**

Удалить полное определение функции `findSkillsInDir`, примерно строки 97–136.

**Шаг 2: обновить все вызовы findSkillsInDir**

Заменить вызовы `findSkillsInDir(` на `skillsCore.findSkillsInDir(`.

**Шаг 3: проверить работу скрипта после изменений**

Выполнить: `.codex/superpowers-codex find-skills | head -20`
Ожидается: показан список навыков

**Шаг 4: создать коммит**

```bash
git add .codex/superpowers-codex
git commit -m "refactor: use shared findSkillsInDir in codex"
```

---

### Задача 8: заменить checkForUpdates на общую версию

**Файлы:**
- Изменить: `.codex/superpowers-codex` (примерно строки 16–38)

**Шаг 1: удалить локальную функцию checkForUpdates**

Удалить полное определение функции `checkForUpdates`.

**Шаг 2: обновить все вызовы checkForUpdates**

Заменить вызовы `checkForUpdates(` на `skillsCore.checkForUpdates(`.

**Шаг 3: проверить работу скрипта после изменений**

Выполнить: `.codex/superpowers-codex bootstrap | head -50`
Ожидается: показан текст загрузки

**Шаг 4: создать коммит**

```bash
git add .codex/superpowers-codex
git commit -m "refactor: use shared checkForUpdates in codex"
```

---

## Этап 3: создать плагин OpenCode

### Задача 9: создать структуру каталогов плагина OpenCode

**Файлы:**
- Создать: `.opencode/plugin/superpowers.js`

**Шаг 1: создать каталог**

Выполнить: `mkdir -p .opencode/plugin`

**Шаг 2: создать базовый файл плагина**

```javascript
#!/usr/bin/env node

/**
 * Superpowers plugin for OpenCode.ai
 *
 * Provides custom tools for loading and discovering skills,
 * with automatic bootstrap on session start.
 */

const skillsCore = require('../../lib/skills-core');
const path = require('path');
const fs = require('fs');
const os = require('os');

const homeDir = os.homedir();
const superpowersSkillsDir = path.join(homeDir, '.config/opencode/superpowers/skills');
const personalSkillsDir = path.join(homeDir, '.config/opencode/skills');

/**
 * OpenCode plugin entry point
 */
export const SuperpowersPlugin = async ({ project, client, $, directory, worktree }) => {
  return {
    // Custom tools and hooks will go here
  };
};
```

**Шаг 3: проверить создание файла**

Выполнить: `ls -l .opencode/plugin/superpowers.js`
Ожидается: файл существует

**Шаг 4: создать коммит**

```bash
git add .opencode/plugin/superpowers.js
git commit -m "feat: create opencode plugin scaffold"
```

---

### Задача 10: реализовать инструмент use_skill

**Файлы:**
- Изменить: `.opencode/plugin/superpowers.js`

**Шаг 1: добавить реализацию use_skill**

Заменить возвращаемое значение плагина на:

```javascript
export const SuperpowersPlugin = async ({ project, client, $, directory, worktree }) => {
  // Import zod for schema validation
  const { z } = await import('zod');

  return {
    tools: [
      {
        name: 'use_skill',
        description: 'Load and read a specific skill to guide your work. Skills contain proven workflows, mandatory processes, and expert techniques.',
        schema: z.object({
          skill_name: z.string().describe('Name of the skill to load (e.g., "superpowers:brainstorming" or "my-custom-skill")')
        }),
        execute: async ({ skill_name }) => {
          // Resolve skill path (handles shadowing: personal > superpowers)
          const resolved = skillsCore.resolveSkillPath(
            skill_name,
            superpowersSkillsDir,
            personalSkillsDir
          );

          if (!resolved) {
            return `Error: Skill "${skill_name}" not found.\n\nRun find_skills to see available skills.`;
          }

          // Read skill content
          const fullContent = fs.readFileSync(resolved.skillFile, 'utf8');
          const { name, description } = skillsCore.extractFrontmatter(resolved.skillFile);

          // Extract content after frontmatter
          const lines = fullContent.split('\n');
          let inFrontmatter = false;
          let frontmatterEnded = false;
          const contentLines = [];

          for (const line of lines) {
            if (line.trim() === '---') {
              if (inFrontmatter) {
                frontmatterEnded = true;
                continue;
              }
              inFrontmatter = true;
              continue;
            }

            if (frontmatterEnded || !inFrontmatter) {
              contentLines.push(line);
            }
          }

          const content = contentLines.join('\n').trim();
          const skillDirectory = path.dirname(resolved.skillFile);

          // Format output similar to Claude Code's Skill tool
          return `# ${name || skill_name}
# ${description || ''}
# Supporting tools and docs are in ${skillDirectory}
# ============================================

${content}`;
        }
      }
    ]
  };
};
```

**Шаг 2: проверить синтаксис**

Выполнить: `node -c .opencode/plugin/superpowers.js`
Ожидается: нет вывода

**Шаг 3: создать коммит**

```bash
git add .opencode/plugin/superpowers.js
git commit -m "feat: implement use_skill tool for opencode"
```

---

### Задача 11: реализовать инструмент find_skills

**Файлы:**
- Изменить: `.opencode/plugin/superpowers.js`

**Шаг 1: добавить find_skills в массив tools**

Добавить после определения use_skill, до закрытия массива tools:

```javascript
      {
        name: 'find_skills',
        description: 'List all available skills in the superpowers and personal skill libraries.',
        schema: z.object({}),
        execute: async () => {
          // Find skills in both directories
          const superpowersSkills = skillsCore.findSkillsInDir(
            superpowersSkillsDir,
            'superpowers',
            3
          );
          const personalSkills = skillsCore.findSkillsInDir(
            personalSkillsDir,
            'personal',
            3
          );

          // Combine and format skills list
          const allSkills = [...personalSkills, ...superpowersSkills];

          if (allSkills.length === 0) {
            return 'No skills found. Install superpowers skills to ~/.config/opencode/superpowers/skills/';
          }

          let output = 'Available skills:\n\n';

          for (const skill of allSkills) {
            const namespace = skill.sourceType === 'personal' ? '' : 'superpowers:';
            const skillName = skill.name || path.basename(skill.path);

            output += `${namespace}${skillName}\n`;
            if (skill.description) {
              output += `  ${skill.description}\n`;
            }
            output += `  Directory: ${skill.path}\n\n`;
          }

          return output;
        }
      }
```

**Шаг 2: проверить синтаксис**

Выполнить: `node -c .opencode/plugin/superpowers.js`
Ожидается: нет вывода

**Шаг 3: создать коммит**

```bash
git add .opencode/plugin/superpowers.js
git commit -m "feat: implement find_skills tool for opencode"
```

---

### Задача 12: реализовать хук начала сеанса

**Файлы:**
- Изменить: `.opencode/plugin/superpowers.js`

**Шаг 1: добавить хук session.started**

После массива tools добавить:

```javascript
    'session.started': async () => {
      // Read using-superpowers skill content
      const usingSuperpowersPath = skillsCore.resolveSkillPath(
        'using-superpowers',
        superpowersSkillsDir,
        personalSkillsDir
      );

      let usingSuperpowersContent = '';
      if (usingSuperpowersPath) {
        const fullContent = fs.readFileSync(usingSuperpowersPath.skillFile, 'utf8');
        // Strip frontmatter
        const lines = fullContent.split('\n');
        let inFrontmatter = false;
        let frontmatterEnded = false;
        const contentLines = [];

        for (const line of lines) {
          if (line.trim() === '---') {
            if (inFrontmatter) {
              frontmatterEnded = true;
              continue;
            }
            inFrontmatter = true;
            continue;
          }

          if (frontmatterEnded || !inFrontmatter) {
            contentLines.push(line);
          }
        }

        usingSuperpowersContent = contentLines.join('\n').trim();
      }

      // Tool mapping instructions
      const toolMapping = `
**Tool Mapping for OpenCode:**
When skills reference tools you don't have, substitute OpenCode equivalents:
- \`TodoWrite\` → \`update_plan\` (your planning/task tracking tool)
- \`Task\` tool with subagents → Use OpenCode's subagent system (@mention syntax or automatic dispatch)
- \`Skill\` tool → \`use_skill\` custom tool (already available)
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → Use your native tools

**Skill directories contain supporting files:**
- Scripts you can run with bash tool
- Additional documentation you can read
- Utilities and helpers specific to that skill

**Skills naming:**
- Superpowers skills: \`superpowers:skill-name\` (from ~/.config/opencode/superpowers/skills/)
- Personal skills: \`skill-name\` (from ~/.config/opencode/skills/)
- Personal skills override superpowers skills when names match
`;

      // Check for updates (non-blocking)
      const hasUpdates = skillsCore.checkForUpdates(
        path.join(homeDir, '.config/opencode/superpowers')
      );

      const updateNotice = hasUpdates ?
        '\n\n⚠️ **Updates available!** Run `cd ~/.config/opencode/superpowers && git pull` to update superpowers.' :
        '';

      // Return context to inject into session
      return {
        context: `<EXTREMELY_IMPORTANT>
You have superpowers.

**Below is the full content of your 'superpowers:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'use_skill' tool:**

${usingSuperpowersContent}

${toolMapping}${updateNotice}
</EXTREMELY_IMPORTANT>`
      };
    }
```

**Шаг 2: проверить синтаксис**

Выполнить: `node -c .opencode/plugin/superpowers.js`
Ожидается: нет вывода

**Шаг 3: создать коммит**

```bash
git add .opencode/plugin/superpowers.js
git commit -m "feat: implement session.started hook for opencode"
```

---

## Этап 4: документация

### Задача 13: создать руководство по установке OpenCode

**Файлы:**
- Создать: `.opencode/INSTALL.md`

**Шаг 1: создать руководство по установке**

```markdown
# Установка Superpowers для OpenCode

## Требования

- Установленный [OpenCode.ai](https://opencode.ai).
- Установленный Node.js.
- Установленный Git.

## Шаги установки

### 1. Установка навыков Superpowers

```bash
# Clone superpowers skills to OpenCode config directory
mkdir -p ~/.config/opencode/superpowers
git clone https://github.com/obra/superpowers.git ~/.config/opencode/superpowers
```

### 2. Установка плагина

Плагин находится в только что клонированном репозитории superpowers.

OpenCode автоматически обнаружит его по пути:
- `~/.config/opencode/superpowers/.opencode/plugin/superpowers.js`

Либо создайте ссылку в каталоге плагинов проекта:

```bash
# In your OpenCode project
mkdir -p .opencode/plugin
ln -s ~/.config/opencode/superpowers/.opencode/plugin/superpowers.js .opencode/plugin/superpowers.js
```

### 3. Перезапуск OpenCode

Перезапустите OpenCode для загрузки плагина. В следующем сеансе появится:

```
You have superpowers.
```

## Использование

### Поиск навыков

Используйте `find_skills` для списка доступных навыков:

```
use find_skills tool
```

### Загрузка навыка

Используйте `use_skill` для загрузки нужного навыка:

```
use use_skill tool with skill_name: "superpowers:brainstorming"
```

### Личные навыки

Создавайте личные навыки в `~/.config/opencode/skills/`:

```bash
mkdir -p ~/.config/opencode/skills/my-skill
```

Создайте `~/.config/opencode/skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
description: Use when [condition] - [what it does]
---

# My Skill

[Your skill content here]
```

Личные навыки имеют приоритет над навыками superpowers с тем же именем.

## Обновление

```bash
cd ~/.config/opencode/superpowers
git pull
```

## Устранение неполадок

### Плагин не загружается

1. Проверьте наличие файла: `ls ~/.config/opencode/superpowers/.opencode/plugin/superpowers.js`.
2. Проверьте ошибки в журналах OpenCode.
3. Проверьте Node.js: `node --version`.

### Навыки не найдены

1. Проверьте каталог навыков: `ls ~/.config/opencode/superpowers/skills`.
2. Посмотрите обнаруженные навыки через `find_skills`.
3. Проверьте структуру: у каждого навыка должен быть `SKILL.md`.

### Проблемы сопоставления инструментов

Если навык ссылается на отсутствующий инструмент Claude Code:
- `TodoWrite` → используйте `update_plan`.
- `Task` с субагентами → вызывайте субагентов OpenCode через `@mention`.
- `Skill` → используйте `use_skill`.
- Операции с файлами → используйте собственные инструменты среды.

## Помощь

- Сообщения об ошибках: https://github.com/obra/superpowers/issues
- Документация: https://github.com/obra/superpowers
```

**Шаг 2: проверить создание файла**

Выполнить: `ls -l .opencode/INSTALL.md`
Ожидается: файл существует

**Шаг 3: создать коммит**

```bash
git add .opencode/INSTALL.md
git commit -m "docs: add opencode installation guide"
```

---

### Задача 14: обновить основной README

**Файлы:**
- Изменить: `README.md`

**Шаг 1: добавить раздел OpenCode**

Найти раздел поддерживаемых платформ, например поиском «Codex», и добавить после него:

```markdown
### OpenCode

Superpowers работает с [OpenCode.ai](https://opencode.ai) через нативный плагин JavaScript.

**Установка:** см. [.opencode/INSTALL.md](.opencode/INSTALL.md).

**Возможности:**
- Пользовательские инструменты `use_skill` и `find_skills`.
- Автоматическая начальная загрузка сеанса.
- Личные навыки с приоритетом перед базовыми.
- Доступ к вспомогательным файлам и скриптам.
```

**Шаг 2: проверить оформление**

Выполнить: `grep -A 10 "### OpenCode" README.md`
Ожидается: показан добавленный раздел

**Шаг 3: создать коммит**

```bash
git add README.md
git commit -m "docs: add opencode support to readme"
```

---

### Задача 15: обновить историю выпусков

**Файлы:**
- Изменить: `RELEASE-NOTES.md`

**Шаг 1: добавить запись о поддержке OpenCode**

В начале файла после заголовка добавить:

```markdown
## [Ещё не выпущено]

### Добавлено

- **Поддержка OpenCode:** нативный плагин JavaScript для OpenCode.ai.
  - Инструменты `use_skill` и `find_skills`.
  - Автоматическая начальная загрузка сеанса с сопоставлением инструментов.
  - Общий модуль `lib/skills-core.js` для повторного использования кода.
  - Руководство по установке `.opencode/INSTALL.md`.

### Изменено

- **Реализация Codex переработана:** используется общий модуль `lib/skills-core.js`.
  - Устраняется дублирование кода Codex и OpenCode.
  - Единый источник обнаружения и разбора навыков.

---

```

**Шаг 2: проверить оформление**

Выполнить: `head -30 RELEASE-NOTES.md`
Ожидается: показан новый раздел

**Шаг 3: создать коммит**

```bash
git add RELEASE-NOTES.md
git commit -m "docs: add opencode support to release notes"
```

---

## Этап 5: итоговая проверка

### Задача 16: проверить, что Codex работает

**Файлы:**
- Проверить: `.codex/superpowers-codex`

**Шаг 1: проверить команду find-skills**

Выполнить: `.codex/superpowers-codex find-skills | head -20`
Ожидается: показан список навыков с именами и описаниями

**Шаг 2: проверить команду use-skill**

Выполнить: `.codex/superpowers-codex use-skill superpowers:brainstorming | head -20`
Ожидается: показано содержимое навыка brainstorming

**Шаг 3: проверить команду bootstrap**

Выполнить: `.codex/superpowers-codex bootstrap | head -30`
Ожидается: показан текст загрузки с инструкциями

**Шаг 4: если все проверки прошли, зафиксировать успех**

Коммит не требуется: это только проверка.

---

### Задача 17: проверить структуру файлов

**Файлы:**
- Проверить: все новые файлы существуют

**Шаг 1: убедиться, что все файлы созданы**

Выполнить:
```bash
ls -l lib/skills-core.js
ls -l .opencode/plugin/superpowers.js
ls -l .opencode/INSTALL.md
```

Ожидается: все файлы существуют

**Шаг 2: проверить структуру каталогов**

Выполнить: `tree -L 2 .opencode/` (или `find .opencode -type f`, если tree недоступен)
Ожидается:
```
.opencode/
├── INSTALL.md
└── plugin/
    └── superpowers.js
```

**Шаг 3: если структура верна, продолжить**

Коммит не требуется: это только проверка.

---

### Задача 18: итоговый коммит и отчёт

**Файлы:**
- Проверить: `git status`

**Шаг 1: проверить состояние git**

Выполнить: `git status`
Ожидается: рабочее дерево чистое, все изменения сохранены в коммитах

**Шаг 2: проверить журнал коммитов**

Выполнить: `git log --oneline -20`
Ожидается: показаны все коммиты реализации

**Шаг 3: создать итоговый документ**

Создать итоговый отчёт с указанием:
- Общего числа созданных коммитов.
- Созданных файлов: `lib/skills-core.js`, `.opencode/plugin/superpowers.js`, `.opencode/INSTALL.md`.
- Изменённых файлов: `.codex/superpowers-codex`, `README.md`, `RELEASE-NOTES.md`.
- Проведённого тестирования: проверены команды Codex.
- Готовности к проверке с реальной установкой OpenCode.

**Шаг 4: сообщить о завершении**

Показать отчёт пользователю и предложить:
1. Отправить изменения в удалённый репозиторий.
2. Создать pull request.
3. Проверить на реальной установке OpenCode.

---

## Руководство по тестированию вручную — требуется OpenCode

Эти шаги требуют установленного OpenCode и не входят в автоматическую реализацию:

1. **Установить навыки:** следовать `.opencode/INSTALL.md`.
2. **Начать сеанс OpenCode:** проверить появление начальной загрузки.
3. **Проверить find_skills:** должны перечисляться все навыки.
4. **Проверить use_skill:** загрузить навык и проверить его содержимое.
5. **Проверить вспомогательные файлы:** пути каталогов навыков доступны.
6. **Проверить личные навыки:** создать личный и проверить его приоритет над базовым.
7. **Проверить сопоставление инструментов:** TodoWrite → update_plan.

## Критерии успеха

- [ ] Создан `lib/skills-core.js` со всеми основными функциями.
- [ ] `.codex/superpowers-codex` использует общий модуль.
- [ ] Команды Codex find-skills, use-skill и bootstrap работают.
- [ ] Создан `.opencode/plugin/superpowers.js` с инструментами и хуками.
- [ ] Создано руководство по установке.
- [ ] Обновлены README и RELEASE-NOTES.
- [ ] Все изменения внесены в коммиты.
- [ ] Рабочее дерево чистое.
