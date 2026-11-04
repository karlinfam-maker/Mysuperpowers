# План реализации визуального помощника для мозгового штурма

> **Для агентов-исполнителей:** ОБЯЗАТЕЛЬНЫЙ ПОДНАВЫК: используйте superpowers:executing-plans для последовательного выполнения задач плана.

**Цель:** предоставить Claude визуального помощника в браузере для мозгового штурма: показывать макеты, прототипы и интерактивные варианты во время общения в терминале.

**Архитектура:** Claude записывает HTML во временный файл. Локальный сервер Node.js отслеживает файл и отдаёт его с автоматически подключённой вспомогательной библиотекой. Действия пользователя поступают по WebSocket в stdout сервера, который Claude видит в выводе фоновой задачи.

**Технологии:** Node.js, Express, ws (WebSocket), chokidar (отслеживание файлов).

---

## Задача 1: создать основу сервера

**Файлы:**
- Создать: `lib/brainstorm-server/index.js`
- Создать: `lib/brainstorm-server/package.json`

**Шаг 1: создать package.json**

```json
{
  "name": "brainstorm-server",
  "version": "1.0.0",
  "description": "Visual brainstorming companion server for Claude Code",
  "main": "index.js",
  "dependencies": {
    "chokidar": "^3.5.3",
    "express": "^4.18.2",
    "ws": "^8.14.2"
  }
}
```

**Шаг 2: создать минимальный запускаемый сервер**

```javascript
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const chokidar = require('chokidar');
const fs = require('fs');
const path = require('path');

const PORT = process.env.BRAINSTORM_PORT || 3333;
const SCREEN_FILE = process.env.BRAINSTORM_SCREEN || '/tmp/brainstorm/screen.html';
const SCREEN_DIR = path.dirname(SCREEN_FILE);

// Ensure screen directory exists
if (!fs.existsSync(SCREEN_DIR)) {
  fs.mkdirSync(SCREEN_DIR, { recursive: true });
}

// Create default screen if none exists
if (!fs.existsSync(SCREEN_FILE)) {
  fs.writeFileSync(SCREEN_FILE, `<!DOCTYPE html>
<html>
<head>
  <title>Brainstorm Companion</title>
  <style>
    body { font-family: system-ui, sans-serif; padding: 2rem; max-width: 800px; margin: 0 auto; }
    h1 { color: #333; }
    p { color: #666; }
  </style>
</head>
<body>
  <h1>Brainstorm Companion</h1>
  <p>Waiting for Claude to push a screen...</p>
</body>
</html>`);
}

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Track connected browsers for reload notifications
const clients = new Set();

wss.on('connection', (ws) => {
  clients.add(ws);
  ws.on('close', () => clients.delete(ws));

  ws.on('message', (data) => {
    // User interaction event - write to stdout for Claude
    const event = JSON.parse(data.toString());
    console.log(JSON.stringify({ type: 'user-event', ...event }));
  });
});

// Serve current screen with helper.js injected
app.get('/', (req, res) => {
  let html = fs.readFileSync(SCREEN_FILE, 'utf-8');

  // Inject helper script before </body>
  const helperScript = fs.readFileSync(path.join(__dirname, 'helper.js'), 'utf-8');
  const injection = `<script>\n${helperScript}\n</script>`;

  if (html.includes('</body>')) {
    html = html.replace('</body>', `${injection}\n</body>`);
  } else {
    html += injection;
  }

  res.type('html').send(html);
});

// Watch for screen file changes
chokidar.watch(SCREEN_FILE).on('change', () => {
  console.log(JSON.stringify({ type: 'screen-updated', file: SCREEN_FILE }));
  // Notify all browsers to reload
  clients.forEach(ws => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'reload' }));
    }
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(JSON.stringify({ type: 'server-started', port: PORT, url: `http://localhost:${PORT}` }));
});
```

**Шаг 3: выполнить npm install**

Выполнить: `cd lib/brainstorm-server && npm install`
Ожидается: зависимости установлены.

**Шаг 4: проверить запуск сервера**

Выполнить: `cd lib/brainstorm-server && timeout 3 node index.js || true`
Ожидается: JSON с `server-started` и сведениями о порте.

**Шаг 5: создать коммит**

```bash
git add lib/brainstorm-server/
git commit -m "feat: add brainstorm server foundation"
```

---

## Задача 2: создать вспомогательную библиотеку

**Файлы:**
- Создать: `lib/brainstorm-server/helper.js`

**Шаг 1: создать helper.js с автоматическим сбором событий**

```javascript
(function() {
  const WS_URL = 'ws://' + window.location.host;
  let ws = null;
  let eventQueue = [];

  function connect() {
    ws = new WebSocket(WS_URL);

    ws.onopen = () => {
      // Send any queued events
      eventQueue.forEach(e => ws.send(JSON.stringify(e)));
      eventQueue = [];
    };

    ws.onmessage = (msg) => {
      const data = JSON.parse(msg.data);
      if (data.type === 'reload') {
        window.location.reload();
      }
    };

    ws.onclose = () => {
      // Reconnect after 1 second
      setTimeout(connect, 1000);
    };
  }

  function send(event) {
    event.timestamp = Date.now();
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(event));
    } else {
      eventQueue.push(event);
    }
  }

  // Auto-capture clicks on interactive elements
  document.addEventListener('click', (e) => {
    const target = e.target.closest('button, a, [data-choice], [role="button"], input[type="submit"]');
    if (!target) return;

    // Don't capture regular link navigation
    if (target.tagName === 'A' && !target.dataset.choice) return;

    e.preventDefault();

    send({
      type: 'click',
      text: target.textContent.trim(),
      choice: target.dataset.choice || null,
      id: target.id || null,
      className: target.className || null
    });
  });

  // Auto-capture form submissions
  document.addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.target;
    const formData = new FormData(form);
    const data = {};
    formData.forEach((value, key) => { data[key] = value; });

    send({
      type: 'submit',
      formId: form.id || null,
      formName: form.name || null,
      data: data
    });
  });

  // Auto-capture input changes (debounced)
  let inputTimeout = null;
  document.addEventListener('input', (e) => {
    const target = e.target;
    if (!target.matches('input, textarea, select')) return;

    clearTimeout(inputTimeout);
    inputTimeout = setTimeout(() => {
      send({
        type: 'input',
        name: target.name || null,
        id: target.id || null,
        value: target.value,
        inputType: target.type || target.tagName.toLowerCase()
      });
    }, 500); // 500ms debounce
  });

  // Expose for explicit use if needed
  window.brainstorm = {
    send: send,
    choice: (value, metadata = {}) => send({ type: 'choice', value, ...metadata })
  };

  connect();
})();
```

**Шаг 2: проверить синтаксис helper.js**

Выполнить: `node -c lib/brainstorm-server/helper.js`
Ожидается: синтаксических ошибок нет.

**Шаг 3: создать коммит**

```bash
git add lib/brainstorm-server/helper.js
git commit -m "feat: add browser helper library for event capture"
```

---

## Задача 3: написать тесты сервера

**Файлы:**
- Создать: `tests/brainstorm-server/server.test.js`
- Создать: `tests/brainstorm-server/package.json`

**Шаг 1: создать package.json для тестов**

```json
{
  "name": "brainstorm-server-tests",
  "version": "1.0.0",
  "scripts": {
    "test": "node server.test.js"
  }
}
```

**Шаг 2: написать тесты сервера**

```javascript
const { spawn } = require('child_process');
const http = require('http');
const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const SERVER_PATH = path.join(__dirname, '../../lib/brainstorm-server/index.js');
const TEST_PORT = 3334;
const TEST_SCREEN = '/tmp/brainstorm-test/screen.html';

// Clean up test directory
function cleanup() {
  if (fs.existsSync(path.dirname(TEST_SCREEN))) {
    fs.rmSync(path.dirname(TEST_SCREEN), { recursive: true });
  }
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetch(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    }).on('error', reject);
  });
}

async function runTests() {
  cleanup();

  // Start server
  const server = spawn('node', [SERVER_PATH], {
    env: { ...process.env, BRAINSTORM_PORT: TEST_PORT, BRAINSTORM_SCREEN: TEST_SCREEN }
  });

  let stdout = '';
  server.stdout.on('data', (data) => { stdout += data.toString(); });
  server.stderr.on('data', (data) => { console.error('Server stderr:', data.toString()); });

  await sleep(1000); // Wait for server to start

  try {
    // Test 1: Server starts and outputs JSON
    console.log('Test 1: Server startup message');
    assert(stdout.includes('server-started'), 'Should output server-started');
    assert(stdout.includes(TEST_PORT.toString()), 'Should include port');
    console.log('  PASS');

    // Test 2: GET / returns HTML with helper injected
    console.log('Test 2: Serves HTML with helper injected');
    const res = await fetch(`http://localhost:${TEST_PORT}/`);
    assert.strictEqual(res.status, 200);
    assert(res.body.includes('brainstorm'), 'Should include brainstorm content');
    assert(res.body.includes('WebSocket'), 'Should have helper.js injected');
    console.log('  PASS');

    // Test 3: WebSocket connection and event relay
    console.log('Test 3: WebSocket relays events to stdout');
    stdout = ''; // Reset stdout capture
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}`);
    await new Promise(resolve => ws.on('open', resolve));

    ws.send(JSON.stringify({ type: 'click', text: 'Test Button' }));
    await sleep(100);

    assert(stdout.includes('user-event'), 'Should relay user events');
    assert(stdout.includes('Test Button'), 'Should include event data');
    ws.close();
    console.log('  PASS');

    // Test 4: File change triggers reload notification
    console.log('Test 4: File change notifies browsers');
    const ws2 = new WebSocket(`ws://localhost:${TEST_PORT}`);
    await new Promise(resolve => ws2.on('open', resolve));

    let gotReload = false;
    ws2.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      if (msg.type === 'reload') gotReload = true;
    });

    // Modify the screen file
    fs.writeFileSync(TEST_SCREEN, '<html><body>Updated</body></html>');
    await sleep(500);

    assert(gotReload, 'Should send reload message on file change');
    ws2.close();
    console.log('  PASS');

    console.log('\nAll tests passed!');

  } finally {
    server.kill();
    cleanup();
  }
}

runTests().catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
```

**Шаг 3: запустить тесты**

Выполнить: `cd tests/brainstorm-server && npm install ws && node server.test.js`
Ожидается: все тесты прошли.

**Шаг 4: создать коммит**

```bash
git add tests/brainstorm-server/
git commit -m "test: add brainstorm server integration tests"
```

---

## Задача 4: добавить визуального помощника к навыку мозгового штурма

**Файлы:**
- Изменить: `skills/brainstorming/SKILL.md`
- Создать: `skills/brainstorming/visual-companion.md` (supporting doc)

**Шаг 1: создать вспомогательную документацию**

Создать `skills/brainstorming/visual-companion.md`:

```markdown
# Справочник визуального помощника

## Запуск сервера

Запустить как фоновую задачу:

```bash
node ${PLUGIN_ROOT}/lib/brainstorm-server/index.js
```

Сообщить пользователю: «Я запустил визуального помощника по адресу http://localhost:3333 — откройте его в браузере».

## Публикация экранов

Запишите HTML в `/tmp/brainstorm/screen.html`. Сервер отслеживает файл и автоматически обновляет страницу браузера.

## Чтение ответов пользователя

Проверьте вывод фоновой задачи на наличие событий JSON:

```json
{"type":"user-event","type":"click","text":"Option A","choice":"optionA","timestamp":1234567890}
{"type":"user-event","type":"submit","data":{"notes":"My feedback"},"timestamp":1234567891}
```

Типы событий:
- **click**: пользователь нажал кнопку или элемент `data-choice`.
- **submit**: пользователь отправил форму; событие содержит все данные формы.
- **input**: пользователь ввёл данные в поле; события объединяются с задержкой 500 мс.

## Примеры HTML

### Карточки выбора

```html
<div class="options">
  <button data-choice="optionA">
    <h3>Option A</h3>
    <p>Description</p>
  </button>
  <button data-choice="optionB">
    <h3>Option B</h3>
    <p>Description</p>
  </button>
</div>
```

### Интерактивный макет

```html
<div class="mockup">
  <header data-choice="header">App Header</header>
  <nav data-choice="nav">Navigation</nav>
  <main data-choice="main">Content</main>
</div>
```

### Форма с заметками

```html
<form>
  <label>Priority: <input type="range" name="priority" min="1" max="5"></label>
  <textarea name="notes" placeholder="Additional thoughts..."></textarea>
  <button type="submit">Submit</button>
</form>
```

### Явный вызов JavaScript

```html
<button onclick="brainstorm.choice('custom', {extra: 'data'})">Custom</button>
```
```

**Шаг 2: добавить раздел о визуальном помощнике в навык мозгового штурма**

Добавить после раздела «Key Principles» в `skills/brainstorming/SKILL.md`:

```markdown

## Визуальный помощник (необязательно)

Если мозговой штурм связан с визуальными элементами — макетами интерфейса, схемами или интерактивными прототипами, — используйте визуального помощника в браузере.

**Когда использовать:**
- Представление вариантов UI/UX, которые полезно сравнить визуально.
- Показ схем или вариантов компоновки.
- Сбор структурированной обратной связи: оценок, форм.
- Прототипирование взаимодействий по щелчку.

**Как это работает:**
1. Запустите сервер как фоновую задачу.
2. Предложите пользователю открыть http://localhost:3333.
3. Запишите HTML в `/tmp/brainstorm/screen.html`; страница обновится автоматически.
4. Проверьте вывод фоновой задачи на события пользователя.

Терминал остаётся основным каналом общения. Браузер служит визуальным дополнением.

**Справочник:** примеры HTML и подробности API находятся в `visual-companion.md` в каталоге навыка.
```

**Шаг 3: проверить изменения**

Выполнить: `grep -A5 "Visual Companion" skills/brainstorming/SKILL.md`
Ожидается: показан новый раздел.

**Шаг 4: создать коммит**

```bash
git add skills/brainstorming/
git commit -m "feat: add visual companion to brainstorming skill"
```

---

## Задача 5: исключить сервер из отслеживания плагина (необязательная очистка)

**Файлы:**
- Проверить, нужно ли исключить node_modules для lib/brainstorm-server в `.gitignore`.

**Шаг 1: проверить текущий gitignore**

Выполнить: `cat .gitignore 2>/dev/null || echo "No .gitignore"`

**Шаг 2: при необходимости добавить node_modules**

Если запись отсутствует, добавить:
```
lib/brainstorm-server/node_modules/
```

**Шаг 3: создать коммит при наличии изменений**

```bash
git add .gitignore
git commit -m "chore: ignore brainstorm-server node_modules"
```

---

## Итог

После выполнения всех задач:

1. **Сервер** в `lib/brainstorm-server/`: сервер Node.js отслеживает HTML-файл и передаёт события.
2. **Вспомогательная библиотека** подключается автоматически и собирает щелчки, отправки форм и ввод.
3. **Тесты** в `tests/brainstorm-server/` проверяют поведение сервера.
4. **Навык brainstorming** дополнен разделом о визуальном помощнике и справочным документом `visual-companion.md`.

**Использование:**
1. Запустить сервер в фоновом режиме: `node lib/brainstorm-server/index.js &`.
2. Предложить пользователю открыть `http://localhost:3333`.
3. Записать HTML в `/tmp/brainstorm/screen.html`.
4. Проверить вывод задачи на наличие пользовательских событий.
