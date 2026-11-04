---
name: subagent-driven-development
description: Используй при выполнении планов реализации с независимыми задачами в текущей сессии, когда использование субагентов разрешено.
---

# Разработка с субагентами

## Приоритет правил проекта

В проектах Валерия СУИИР и прямые указания пользователя имеют приоритет. Используй субагентов только когда это разрешено текущими инструкциями и пользовательским поручением. Если пользователь выбрал самостоятельную работу, соблюдай его выбор. Уже разрешённые действия не согласовывай повторно; защищай пользовательские данные и существующий код.

Выполняй план, привлекая для каждой задачи нового субагента-исполнителя, после каждой задачи проверяя соответствие спецификации и качество кода, а в конце — всю ветку целиком.

**Зачем субагенты:** задачи передаются специализированным агентам с изолированным контекстом. Точно подготовленные инструкции позволяют им сосредоточиться. Они не должны наследовать историю текущей сессии: передавай ровно необходимое. Это также сохраняет твой контекст для координации.

**Главный принцип:** новый субагент на задачу + проверка задачи на соответствие и качество + общая итоговая проверка = качественная и быстрая работа.

**Сообщения по ходу:** между вызовами инструментов давай не более одной короткой строки: журнал и результаты инструментов сохраняют подробности.

**Непрерывная работа:** не останавливайся после каждой задачи, чтобы спросить пользователя, продолжать ли. Выполняй все задачи плана. Исходный процесс разрешает остановку только по четырём основаниям ниже либо после выполнения всех задач. Вопросы «продолжать?» и избыточные сводки расходуют время пользователя.

**Принимай обычные решения самостоятельно.** Проверяй план по спецификации и фактам проекта; фиксируй существенные решения и отклонения. При стоп-условиях СУИИР, включая противоречие архитектуре, неизвестного владельца логики или риск для production, останови зависимую работу и обратись к владельцу. Независимые разрешённые задачи продолжай.

Исходный навык выделяет четыре основания остановиться: необратимое или разрушительное действие; действие, затрагивающее безопасность; внешнее по отношению к worktree действие, для которого необходимо разрешение, например слияние, push в общую ветку или публикация; план настолько сломан, что любой путь вперёд будет догадкой. Учитывай разрешения, уже данные пользователем, и правила СУИИР.

## Когда применять

```dot
digraph when_to_use {
    "Have implementation plan?" [shape=diamond];
    "Tasks mostly independent?" [shape=diamond];
    "Partner chose inline, or no subagent tool?" [shape=diamond];
    "subagent-driven-development" [shape=box];
    "executing-plans" [shape=box];
    "Manual execution or brainstorm first" [shape=box];

    "Have implementation plan?" -> "Tasks mostly independent?" [label="yes"];
    "Have implementation plan?" -> "Manual execution or brainstorm first" [label="no"];
    "Tasks mostly independent?" -> "Partner chose inline, or no subagent tool?" [label="yes"];
    "Tasks mostly independent?" -> "Manual execution or brainstorm first" [label="no - tightly coupled"];
    "Partner chose inline, or no subagent tool?" -> "executing-plans" [label="yes"];
    "Partner chose inline, or no subagent tool?" -> "subagent-driven-development" [label="no"];
}
```

**По сравнению с `executing-plans`:**
- Новый субагент на каждую задачу вместо одного общего контекста.
- Проверка соответствия спецификации и качества после каждой задачи вместо проверки только в конце.
- Отдельный контекст исполнителя и ревьюера для каждой задачи расходует больше ресурсов; при самостоятельной работе нужен один контекст и один финальный проверяющий.
- Оба подхода выполняются в текущей сессии, используют общую рабочую область и журнал плана и не требуют остановок между задачами.

## Процесс

```dot
digraph process {
    rankdir=TB;

    subgraph cluster_per_task {
        label="Per Task";
        "Dispatch implementer subagent (./implementer-prompt.md)" [shape=box];
        "Implementer asks questions?" [shape=diamond];
        "Answer questions, provide context" [shape=box];
        "Implementer implements, tests, commits, self-reviews" [shape=box];
        "Generate review package, dispatch task reviewer (./task-reviewer-prompt.md)" [shape=box];
        "Spec ✅ and quality approved?" [shape=diamond];
        "Fix loop: read references/fix-loop.md before every round" [shape=box];
        "Append completion to ledger, mark todo complete" [shape=box];
    }

    "Setup: worktree, ledger check, read plan, pre-flight review" [shape=box];
    "More tasks remain?" [shape=diamond];
    "Final review and finish: read references/final-review.md" [shape=box];
    "Final review clean: delete this plan's workspace" [shape=box];
    "Use superpowers:finishing-a-development-branch" [shape=box style=filled fillcolor=lightgreen];

    "Setup: worktree, ledger check, read plan, pre-flight review" -> "Dispatch implementer subagent (./implementer-prompt.md)";
    "Dispatch implementer subagent (./implementer-prompt.md)" -> "Implementer asks questions?";
    "Implementer asks questions?" -> "Answer questions, provide context" [label="yes"];
    "Answer questions, provide context" -> "Implementer implements, tests, commits, self-reviews";
    "Implementer asks questions?" -> "Implementer implements, tests, commits, self-reviews" [label="no"];
    "Implementer implements, tests, commits, self-reviews" -> "Generate review package, dispatch task reviewer (./task-reviewer-prompt.md)";
    "Generate review package, dispatch task reviewer (./task-reviewer-prompt.md)" -> "Spec ✅ and quality approved?";
    "Spec ✅ and quality approved?" -> "Append completion to ledger, mark todo complete" [label="yes"];
    "Spec ✅ and quality approved?" -> "Fix loop: read references/fix-loop.md before every round" [label="no"];
    "Fix loop: read references/fix-loop.md before every round" -> "Append completion to ledger, mark todo complete" [label="addressed, or parked at the cap"];
    "Append completion to ledger, mark todo complete" -> "More tasks remain?";
    "More tasks remain?" -> "Dispatch implementer subagent (./implementer-prompt.md)" [label="yes"];
    "More tasks remain?" -> "Final review and finish: read references/final-review.md" [label="no"];
    "Final review and finish: read references/final-review.md" -> "Final review clean: delete this plan's workspace";
    "Final review clean: delete this plan's workspace" -> "Use superpowers:finishing-a-development-branch";
}
```

## Подготовка

Работай в изолированной области: создай её или проверь существующую с помощью `superpowers:using-git-worktrees`. Не начинай реализацию в main/master без явного разрешения пользователя.

История разговора не всегда переживает сжатие контекста. В реальных сессиях координаторы, потерявшие место, повторно запускали целые последовательности уже завершённых задач — это один из самых дорогих сбоев. Веди журнал прогресса, а не только список задач.

- Для каждого плана есть собственная рабочая область. В начале запусти `bash scripts/sdd-workspace PLAN_FILE` этого навыка по абсолютному пути из рабочего дерева. Скрипт покажет каталог, игнорируемый git, внутри `<repo-root>/.superpowers/sdd/`: в нём лежат журнал, задания, отчёты и пакеты проверки ЭТОГО плана. Не читай и не изменяй каталог другого плана.
- Проверь `<workspace>/progress.md`. Если журнал существует, сначала прочитай [references/resuming.md](references/resuming.md): там описано, кому принадлежит журнал и с какого места продолжить.
- Первая строка нового журнала: `# SDD ledger — plan: <plan file path>`.
- Журнал — карта восстановления: его коммиты остаются в git, даже когда ты не помнишь, как их создал. После сжатия контекста доверяй журналу и `git log`, а не воспоминаниям.
- `git clean -fdx` уничтожит рабочую область, так как она игнорируется git. Если это произошло, восстанавливай сведения по `git log`.

Один раз прочитай план, отметь контекст и Global Constraints и создай задачу на каждый пункт. Если план указывает Spec, прочитай и её: спецификация определяет требования и разрешает противоречия плана. Если спецификация недоступна или не указана, отметь это в журнале: решения без неё предварительны.

До запуска задачи 1 прочитай [references/preflight.md](references/preflight.md) и проверь противоречия согласно инструкции. Таблицу и принятые решения запиши в журнал.

## Выбор модели

Для каждой роли выбирай наименее мощную модель, которая справится с работой, если выбор моделей разрешён средой.

- **Механическая реализация:** отдельные функции, ясная спецификация, 1–2 файла — быстрая недорогая модель. При хорошем плане таких задач большинство.
- **Интеграция и суждение:** координация нескольких файлов, сопоставление подходов, отладка — стандартная модель.
- **Архитектура и проектирование:** наиболее способная доступная модель. Итоговая проверка всей ветки относится к этой группе; исходный навык рекомендует выбирать для неё наиболее способную модель.
- **Проверка:** учитывай размер, сложность и риск diff. Маленькой механической правке не нужна сильнейшая модель, тонкому изменению конкурентного поведения — нужна. Повторная проверка небольших исправлений подходит недорогой или средней модели.
- **Эскалация исправлений, раунды 4–5:** модель как минимум на уровень выше застрявшего исполнителя.

Исходный навык предлагает явно указывать модель при каждом вызове субагента: иначе наследуется модель сессии, которая может быть самой дорогой. Соблюдай ограничения своей среды на выбор моделей.

**Количество ходов важнее цены токена.** Время и расход контекста растут с числом ходов; дешёвым моделям для многоэтапной работы нередко нужно в 2–3 раза больше вызовов, что повышает общую стоимость. Для проверяющих и исполнителей по текстовому описанию используй модель не ниже средней. Когда план уже содержит весь код, реализация — перенос и тестирование: можно выбрать самый недорогой уровень. Он подходит и для механического исправления одного файла.

**Признаки сложности реализации:**
- 1–2 файла и полная спецификация → недорогая модель.
- Несколько файлов и интеграционные зависимости → стандартная модель.
- Архитектурные решения или широкое понимание проекта → наиболее способная модель.

## Выполнение задач и итоговая проверка

Обязательно прочитай [task-loop.md](task-loop.md): в нём описаны передача задания, ожидание, обработка отчёта, проверка и цикл исправлений, а также завершение и типичные ошибки. Соблюдай приоритет СУИИР и разрешений пользователя в начале этого файла.
