import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const EXTREMELY_IMPORTANT_MARKER = "<EXTREMELY_IMPORTANT>";
const BOOTSTRAP_MARKER = "superpowers:using-superpowers bootstrap for pi";

const extensionDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(extensionDir, "../..");
const skillsDir = resolve(packageRoot, "skills");
const bootstrapSkillPath = resolve(skillsDir, "using-superpowers", "SKILL.md");

let cachedBootstrap: string | null | undefined;

export default function superpowersPiExtension(pi: ExtensionAPI) {
	let injectBootstrap = true;

	pi.on("session_start", async () => {
		injectBootstrap = true;
	});

	pi.on("session_compact", async () => {
		injectBootstrap = true;
	});

	// Messages returned from a context handler are sent to the provider but never
	// written to session history, so the bootstrap has to be injected into every
	// provider request, on every prompt, for the whole session.
	pi.on("context", async (event) => {
		if (!injectBootstrap) return;
		if (event.messages.some(messageContainsBootstrap)) return;

		const bootstrap = getBootstrapContent();
		if (!bootstrap) return;

		const bootstrapMessage = {
			role: "user" as const,
			content: [{ type: "text" as const, text: bootstrap }],
			timestamp: Date.now(),
		};

		const insertAt = firstNonCompactionSummaryIndex(event.messages);
		return {
			messages: [
				...event.messages.slice(0, insertAt),
				bootstrapMessage,
				...event.messages.slice(insertAt),
			],
		};
	});
}

function getBootstrapContent(): string | null {
	if (cachedBootstrap !== undefined) return cachedBootstrap;

	try {
		const skillContent = readFileSync(bootstrapSkillPath, "utf8");
		const body = stripFrontmatter(skillContent);
		cachedBootstrap = `${EXTREMELY_IMPORTANT_MARKER}
${BOOTSTRAP_MARKER}

You have superpowers.

Инструкция using-superpowers приведена ниже и уже загружена для этой сессии Pi. Следуй ей; не загружай using-superpowers повторно.

${body}

${piToolMapping()}
</EXTREMELY_IMPORTANT>`;
		return cachedBootstrap;
	} catch {
		cachedBootstrap = null;
		return null;
	}
}

function stripFrontmatter(content: string): string {
	const match = content.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
	return (match ? match[1] : content).trim();
}

function piToolMapping(): string {
	return `## Pi tool mapping

Pi поддерживает навыки, но не предоставляет инструмент Claude Code \`Skill\`. Для применимого навыка загрузи соответствующий \`SKILL.md\` через \`read\` или позволь человеку вызвать \`/skill:name\`.

Встроенные инструменты Pi пишутся строчными буквами: \`read\`, \`write\`, \`edit\`, \`bash\`; могут быть доступны \`grep\`, \`find\` и \`ls\`. Используй их для чтения, создания и изменения файлов, команд и поиска.

В Pi нет стандартного инструмента субагентов. Используй доступный инструмент, например \`subagent\` из \`pi-subagents\`, только когда делегирование разрешено. Иначе работай в этой сессии и сообщи об ограничении вместо вымышленных вызовов \`Task\`.

В Pi нет стандартного инструмента списка задач. Если он установлен, используй его; иначе при необходимости отслеживай работу в плане или локальном \`TODO.md\`. Старые ссылки на \`TodoWrite\` обозначают такое отслеживание.`;
}

function messageContainsBootstrap(message: unknown): boolean {
	const content = (message as { content?: unknown }).content;
	if (typeof content === "string") return content.includes(BOOTSTRAP_MARKER);
	if (!Array.isArray(content)) return false;
	return content.some((part) => {
		return (
			part &&
			typeof part === "object" &&
			(part as { type?: unknown }).type === "text" &&
			typeof (part as { text?: unknown }).text === "string" &&
			(part as { text: string }).text.includes(BOOTSTRAP_MARKER)
		);
	});
}

function firstNonCompactionSummaryIndex(messages: unknown[]): number {
	let index = 0;
	while ((messages[index] as { role?: unknown } | undefined)?.role === "compactionSummary") {
		index += 1;
	}
	return index;
}
