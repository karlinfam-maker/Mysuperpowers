import os
import re
from pathlib import Path

BOOTSTRAP_MARKER = "superpowers:using-superpowers bootstrap for hermes"


def _skills_dir() -> str:
    """Locate the stock skills/ tree for either supported install layout.

    - git-clone install (`hermes plugins install obra/superpowers`): the plugin
      dir is the repo root, so `.hermes-plugin/` and `skills/` are siblings and
      this module resolves `../skills`.
    - flattened install (plugin files copied to the plugin dir root): `skills/`
      sits next to this module.

    Raises loudly when neither matches — a bootstrap that silently skips is how
    a broken install masquerades as a working one.
    """
    here = os.path.dirname(os.path.realpath(__file__))
    candidates = (
        os.path.realpath(os.path.join(here, "..", "skills")),
        os.path.realpath(os.path.join(here, "skills")),
    )
    for cand in candidates:
        if os.path.isfile(os.path.join(cand, "using-superpowers", "SKILL.md")):
            return cand
    raise RuntimeError(
        "Плагин Superpowers: каталог skills/ не найден "
        f"(проверены пути {candidates}). Проверьте комплектность и источник "
        "установленной русской версии."
    )


def _strip_frontmatter(content: str) -> str:
    match = re.match(r"^---\n[\s\S]*?\n---\n([\s\S]*)$", content)
    return (match.group(1) if match else content).strip()


def _frontmatter_value(content: str, key: str) -> str:
    """Return a flat ``key: value`` scalar from a SKILL.md frontmatter block.

    Hermes reads a skill's description from ``register_skill``'s ``description``
    argument, which defaults to "" — registering only the path left every stock
    skill with a blank description in the skill catalogue, so the model had
    nothing to select on. Stock frontmatter is a flat block of single-line
    scalars, so a line scan covers it without a YAML dependency.
    """
    match = re.match(r"^---\n([\s\S]*?)\n---\n", content)
    if not match:
        return ""
    for line in match.group(1).splitlines():
        name, sep, value = line.partition(":")
        if sep and name.strip() == key:
            return value.strip().strip("\"'")
    return ""


def _build_bootstrap(skills_dir: str) -> str:
    with open(
        os.path.join(skills_dir, "using-superpowers", "SKILL.md"),
        encoding="utf-8",
    ) as f:
        body = _strip_frontmatter(f.read())

    tools_path = os.path.join(
        skills_dir, "using-superpowers", "references", "hermes-tools.md"
    )
    with open(tools_path, encoding="utf-8") as f:
        tool_mapping = f.read().strip()

    return (
        f"<EXTREMELY_IMPORTANT>\n"
        f"{BOOTSTRAP_MARKER}\n\n"
        f"You have superpowers.\n\n"
        f"Инструкция using-superpowers приведена ниже и уже загружена "
        f"для этой сессии Hermes. Следуй ей; "
        f"не загружай using-superpowers повторно.\n\n"
        f"{body}\n\n"
        f"## Загрузка навыков Superpowers в Hermes\n\n"
        f"Навыки Superpowers зарегистрированы во встроенной системе Hermes: "
        f'вызывай их через `skill_view("superpowers:skill-name")` '
        f'(например, `skill_view("superpowers:brainstorming")`). '
        f"Если поиск с пространством имён возвращает 'not found', прочитай "
        f"файл навыка напрямую:\n"
        f'`read_file("{skills_dir}/skill-name/SKILL.md")`\n\n'
        f"Каталог навыков Superpowers: `{skills_dir}`\n\n"
        f"{tool_mapping}\n"
        f"</EXTREMELY_IMPORTANT>"
    )


def register(ctx):
    skills_dir = _skills_dir()
    bootstrap = _build_bootstrap(skills_dir)

    # Register every stock skill with Hermes' native loader so skill_view can
    # load them on demand. Standard markdown; no conversion (plugin guide).
    # register_skill requires a pathlib.Path — a str raises AttributeError and
    # hermes silently disables the whole plugin (verified 2026-07-23).
    for name in sorted(os.listdir(skills_dir)):
        skill_md = os.path.join(skills_dir, name, "SKILL.md")
        if os.path.isfile(skill_md):
            with open(skill_md, encoding="utf-8") as f:
                description = _frontmatter_value(f.read(), "description")
            ctx.register_skill(name, Path(skill_md), description=description)

    # pre_llm_call returning {"context": ...} is the documented injection path
    # (on_session_start return values are ignored, and ctx.inject_message
    # refuses from that hook — verified empirically 2026-07-23). The context is
    # appended to the first turn's user message. delegate_task children run
    # with platform="subagent" and an empty history, so every child's first
    # turn would otherwise get the controller bootstrap too.
    def pre_llm_call(
        session_id=None,
        user_message=None,
        conversation_history=None,
        is_first_turn=None,
        model=None,
        platform=None,
        **kwargs,
    ):
        if is_first_turn and platform != "subagent":
            return {"context": bootstrap}
        return None

    ctx.register_hook("pre_llm_call", pre_llm_call)
