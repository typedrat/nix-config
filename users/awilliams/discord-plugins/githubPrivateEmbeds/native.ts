import { RendererSettings } from "@main/settings";
import { execFile } from "child_process";

export type GithubKind = "repo" | "issue" | "pull";

export type GithubData =
    | { ok: false; status: number; }
    | {
        ok: true;
        private: boolean;
        repo: { fullName: string; description: string | null; };
        item?: { title: string; body: string | null; number: number; author: string | null; };
    };

const API = "https://api.github.com";
const NAME = /^[\w.-]+$/;

// The token is held here only; the renderer never sees it.
let cachedToken: string | null = null;

function ghToken(): Promise<string> {
    if (cachedToken) return Promise.resolve(cachedToken);

    const bin = RendererSettings.store.plugins?.GithubPrivateEmbeds?.ghPath || "gh";
    return new Promise((resolve, reject) => {
        execFile(bin, ["auth", "token"], { timeout: 5000 }, (err, stdout) => {
            const token = stdout?.trim();
            if (err || !token) return reject(err ?? new Error("gh printed no token"));
            resolve((cachedToken = token));
        });
    });
}

async function get(path: string, retry = true): Promise<Response> {
    const res = await fetch(`${API}${path}`, {
        headers: {
            Authorization: `Bearer ${await ghToken()}`,
            Accept: "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "Equicord-GithubPrivateEmbeds"
        }
    });

    // `gh auth login` / `gh auth refresh` can replace the token while Discord is running.
    if (res.status === 401 && retry) {
        cachedToken = null;
        return get(path, false);
    }
    return res;
}

export async function getGithubData(
    _,
    kind: GithubKind,
    owner: string,
    repo: string,
    number?: number
): Promise<GithubData> {
    // Everything interpolated into the request path is validated here, so a
    // compromised renderer can't aim the token at another endpoint.
    if (!NAME.test(owner) || !NAME.test(repo)) return { ok: false, status: 400 };
    if (kind !== "repo" && !Number.isSafeInteger(number)) return { ok: false, status: 400 };

    try {
        const repoRes = await get(`/repos/${owner}/${repo}`);
        if (!repoRes.ok) return { ok: false, status: repoRes.status };
        const r = await repoRes.json();

        const base = {
            ok: true as const,
            private: Boolean(r.private),
            repo: { fullName: r.full_name as string, description: (r.description ?? null) as string | null }
        };
        if (kind === "repo") return base;

        const itemRes = await get(`/repos/${owner}/${repo}/${kind === "pull" ? "pulls" : "issues"}/${number}`);
        if (!itemRes.ok) return { ok: false, status: itemRes.status };
        const i = await itemRes.json();

        return {
            ...base,
            item: { title: i.title, body: i.body ?? null, number: i.number, author: i.user?.login ?? null }
        };
    } catch (e) {
        console.error("[GithubPrivateEmbeds]", e);
        return { ok: false, status: 0 };
    }
}
