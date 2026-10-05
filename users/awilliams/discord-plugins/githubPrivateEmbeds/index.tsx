import { updateMessage } from "@api/MessageUpdater";
import { definePluginSettings } from "@api/Settings";
import { Logger } from "@utils/Logger";
import definePlugin, { OptionType, PluginNative } from "@utils/types";
import { Message } from "@vencord/discord-types";
import { findByCodeLazy } from "@webpack";
import { MessageStore, React } from "@webpack/common";

import type { GithubData, GithubKind } from "./native";

const logger = new Logger("GithubPrivateEmbeds");
const Native = VencordNative.pluginHelpers.GithubPrivateEmbeds as PluginNative<typeof import("./native")>;

// Turns an API-shaped embed into the object the message renderer expects.
const convertEmbed = findByCodeLazy(".uniqueId(\"embed_\")");

const settings = definePluginSettings({
    ghPath: {
        type: OptionType.STRING,
        description: "Path to the gh binary, for when Discord's PATH doesn't include it",
        default: "gh"
    }
});

interface Target {
    url: string;
    kind: GithubKind;
    owner: string;
    repo: string;
    number?: number;
}

const SUCCESS_TTL = 5 * 60_000;
const FAILURE_TTL = 60_000;
const cache = new Map<string, { at: number; ok: boolean; embed: Promise<any | null>; }>();

// A leading `<` is Discord's syntax for suppressing the embed.
const URL_RE = /(?<!<)https:\/\/github\.com\/\S+/g;

function parseTargets(content: string): Target[] {
    const seen = new Set<string>();
    const targets: Target[] = [];

    for (const match of content.matchAll(URL_RE)) {
        const url = match[0].replace(/[.,;:!?)\]>]+$/, "");
        if (seen.has(url)) continue;

        let parsed: URL;
        try { parsed = new URL(url); } catch { continue; }

        const [owner, repo, section, num, ...rest] = parsed.pathname.split("/").filter(Boolean);
        if (!owner || !repo) continue;

        if (!section) {
            seen.add(url);
            targets.push({ url, kind: "repo", owner, repo });
        } else if ((section === "issues" || section === "pull") && /^\d+$/.test(num ?? "") && !rest.length) {
            seen.add(url);
            targets.push({ url, kind: section === "pull" ? "pull" : "issue", owner, repo, number: Number(num) });
        }
    }
    return targets;
}

const collapse = (s: string, max: number) => {
    const flat = s.replace(/\s+/g, " ").trim();
    return flat.length > max ? `${flat.slice(0, max - 1)}…` : flat;
};

// Mirrors the metadata GitHub puts in the og: tags of its public pages,
// which is what Discord's own unfurler uses for public repos.
function buildEmbed(target: Target, data: Extract<GithubData, { ok: true; }>) {
    const { fullName, description } = data.repo;
    const embed: Record<string, unknown> = {
        type: "article",
        url: target.url,
        provider: { name: "GitHub", url: "https://github.com" },
        // An embed with no scan version is treated as awaiting the sensitive-media scan
        // and hidden behind a warning on other people's messages. -1 marks it as
        // scanned, which is accurate since these embeds carry no media.
        content_scan_version: -1
    };

    if (target.kind === "repo") {
        embed.title = description ? `GitHub - ${fullName}: ${description}` : `GitHub - ${fullName}`;
        embed.description = `${description ? `${description}. ` : ""}Contribute to ${fullName} development by creating an account on GitHub.`;
    } else if (data.item) {
        const { title, body, number, author } = data.item;
        const label = target.kind === "pull" ? "Pull Request" : "Issue";
        embed.title = `${title}${target.kind === "pull" && author ? ` by ${author}` : ""} · ${label} #${number} · ${fullName}`;
        if (body) embed.description = collapse(body, 200);
    }
    return embed;
}

function load(target: Target): Promise<any | null> {
    const hit = cache.get(target.url);
    if (hit && Date.now() - hit.at < (hit.ok ? SUCCESS_TTL : FAILURE_TTL)) return hit.embed;

    const entry = { at: Date.now(), ok: false, embed: Promise.resolve<any | null>(null) };
    entry.embed = Native.getGithubData(target.kind, target.owner, target.repo, target.number).then(data => {
        // Public repos are left to Discord's own embed.
        if (!data.ok || !data.private) return null;
        entry.ok = true;
        return buildEmbed(target, data);
    }).catch(e => {
        logger.error("Failed to load", target.url, e);
        return null;
    });
    cache.set(target.url, entry);
    return entry.embed;
}

// Bounds how often one message/link pair is rewritten, in case Discord keeps
// replacing the embeds we inject.
const MAX_REPLACEMENTS = 3;
const replacements = new Map<string, number>();

const isOurs = (embed: any, raw: any) => (embed.rawTitle ?? embed.title) === raw.title;

function Injector({ message }: { message: Message; }) {
    React.useEffect(() => {
        const targets = parseTargets(message.content);
        if (!targets.length) return;

        let live = true;
        Promise.all(targets.map(load)).then(raws => {
            if (!live) return;

            // Re-read the message: Discord's own embed update may have landed while we were fetching.
            const current = MessageStore.getMessage(message.channel_id, message.id);
            if (!current) return;

            let embeds: any[] = [...current.embeds];
            let changed = false;

            raws.forEach((raw, i) => {
                if (!raw) return;
                const { url } = targets[i];
                const existing = embeds.filter(e => e.url === url);
                if (existing.some(e => isOurs(e, raw))) return;

                // Discord's unfurler can't read private repos, but it may still attach
                // an empty placeholder embed for the same URL, which we replace.
                const key = `${message.id}:${url}`;
                const count = replacements.get(key) ?? 0;
                if (count >= MAX_REPLACEMENTS) return;
                replacements.set(key, count + 1);

                embeds = [...embeds.filter(e => e.url !== url), convertEmbed(message.channel_id, message.id, raw)];
                changed = true;
            });
            if (!changed) return;

            embeds.sort((a, b) => message.content.indexOf(a.url) - message.content.indexOf(b.url));
            updateMessage(message.channel_id, message.id, { embeds });
        });

        return () => { live = false; };
    }, [message.content, message.embeds]);

    return null;
}

export default definePlugin({
    name: "GithubPrivateEmbeds",
    description: "Embeds links to private GitHub repos, issues and pull requests using your `gh` login",
    tags: ["Appearance", "Chat"],
    authors: [{ name: "typedrat", id: 0n }],
    dependencies: ["MessageUpdaterAPI", "MessageAccessoriesAPI"],
    settings,

    renderMessageAccessory: ({ message }) => <Injector message={message} />
});
