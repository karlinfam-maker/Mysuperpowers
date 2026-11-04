# Многоуровневая проверка

## Обзор

При исправлении ошибки из-за неверных данных одной проверки может казаться достаточно. Однако её могут обойти другие ветви кода, рефакторинг или имитации.

**Главный принцип:** проверяй данные на КАЖДОМ уровне, через который они проходят. Сделай ошибку невозможной на уровне структуры.

## Зачем несколько уровней

Одна проверка: «Мы исправили ошибку». 
Несколько уровней: «Мы сделали ошибку невозможной». 

Разные уровни обнаруживают разные случаи:
- Проверка на входе обнаруживает большинство ошибок.
- Бизнес-логика обнаруживает крайние случаи.
- Ограничения окружения предотвращают опасные действия в определённых условиях.
- Диагностический журнал помогает, если остальные уровни не сработали.

## Четыре уровня

### Уровень 1: проверка на входе
**Цель:** отклонить заведомо неверные данные на границе API.

```typescript
function createProject(name: string, workingDirectory: string) {
  if (!workingDirectory || workingDirectory.trim() === '') {
    throw new Error('workingDirectory cannot be empty');
  }
  if (!existsSync(workingDirectory)) {
    throw new Error(`workingDirectory does not exist: ${workingDirectory}`);
  }
  if (!statSync(workingDirectory).isDirectory()) {
    throw new Error(`workingDirectory is not a directory: ${workingDirectory}`);
  }
  // ... proceed
}
```

### Уровень 2: проверка бизнес-логики
**Цель:** убедиться, что данные имеют смысл для данной операции.

```typescript
function initializeWorkspace(projectDir: string, sessionId: string) {
  if (!projectDir) {
    throw new Error('projectDir required for workspace initialization');
  }
  // ... proceed
}
```

### Уровень 3: ограничения окружения
**Цель:** предотвратить опасные операции в определённых условиях.

```typescript
async function gitInit(directory: string) {
  // In tests, refuse git init outside temp directories
  if (process.env.NODE_ENV === 'test') {
    const normalized = normalize(resolve(directory));
    const tmpDir = normalize(resolve(tmpdir()));

    if (!normalized.startsWith(tmpDir)) {
      throw new Error(
        `Refusing git init outside temp dir during tests: ${directory}`
      );
    }
  }
  // ... proceed
}
```

### Уровень 4: диагностические средства
**Цель:** сохранить контекст для последующего расследования.

```typescript
async function gitInit(directory: string) {
  const stack = new Error().stack;
  logger.debug('About to git init', {
    directory,
    cwd: process.cwd(),
    stack,
  });
  // ... proceed
}
```

## Применение подхода

Обнаружив ошибку:

1. **Проследи поток данных:** где появляется неверное значение и где оно используется?
2. **Определи все контрольные точки:** перечисли все места, через которые проходят данные.
3. **Добавь проверку на каждом уровне:** вход, бизнес-логика, окружение, диагностика.
4. **Проверь каждый уровень:** попробуй обойти первый и убедись, что второй обнаруживает проблему.

## Пример из сессии

Ошибка: пустой `projectDir` приводил к выполнению `git init` в каталоге исходного кода.

**Поток данных:**
1. Подготовка теста → пустая строка
2. `Project.create(name, '')`
3. `WorkspaceManager.createWorkspace('')`
4. `git init` выполняется в `process.cwd()`

**Добавлены четыре уровня:**
- Уровень 1: `Project.create()` проверяет, что путь не пуст, существует и доступен для записи.
- Уровень 2: `WorkspaceManager` проверяет, что projectDir не пуст.
- Уровень 3: `WorktreeManager` отказывает в git init вне tmpdir во время тестов.
- Уровень 4: запись стека вызовов перед git init.

**Результат исходного примера:** все 1847 тестов прошли; ошибку не удалось воспроизвести.

## Главный вывод

Все четыре уровня оказались необходимы. При тестировании каждый находил ошибки, пропущенные другими:
- Разные пути кода обходили проверку на входе.
- Имитации обходили проверки бизнес-логики.
- Крайние случаи на разных платформах требовали ограничений окружения.
- Диагностический журнал выявлял ошибки использования структуры.

**Не ограничивайся одной точкой проверки.** Добавляй проверки на каждом уровне.
