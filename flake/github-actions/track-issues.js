const fs = require("fs");
const path = require("path");

// Recursively find .nix files, skipping hidden directories
function findNixFiles(dir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith(".")) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findNixFiles(full));
    } else if (entry.name.endsWith(".nix")) {
      results.push(full);
    }
  }
  return results;
}

// Scan for GitHub issue/PR references:
//   owner/repo#number  OR  https://github.com/owner/repo/(issues|pull)/number
const shortRefPattern = /[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+#[0-9]+/g;
const urlRefPattern = /(?:https?:\/\/)?(?:redirect\.)?github\.com\/([a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+)\/(?:issues|pull)\/([0-9]+)/g;
const locations = new Map();

for (const file of findNixFiles(".")) {
  const lines = fs.readFileSync(file, "utf-8").split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const relPath = file.replace(/^\.\//, "");
    const loc = `\`${relPath}:${i + 1}\``;

    // Collect URL refs first so we can skip short refs that overlap
    const urlRefs = new Set();
    for (const m of line.matchAll(urlRefPattern)) {
      const ref = `${m[1]}#${m[2]}`;
      urlRefs.add(ref);
      if (!locations.has(ref)) locations.set(ref, []);
      locations.get(ref).push(loc);
    }

    for (const m of line.matchAll(shortRefPattern)) {
      const ref = m[0];
      if (urlRefs.has(ref)) continue; // already captured from URL form
      if (!locations.has(ref)) locations.set(ref, []);
      locations.get(ref).push(loc);
    }
  }
}

const refs = [...locations.keys()].sort();
if (refs.length === 0) {
  console.log("No upstream references found.");
  return;
}

// Fetch issue/PR info for each reference
const info = new Map();

for (const ref of refs) {
  const hashIdx = ref.indexOf("#");
  const ownerRepo = ref.slice(0, hashIdx);
  const number = parseInt(ref.slice(hashIdx + 1));
  const [refOwner, refRepo] = ownerRepo.split("/");

  try {
    const { data: issue } = await github.rest.issues.get({
      owner: refOwner, repo: refRepo, issue_number: number,
    });

    let state = issue.state;
    let status;
    const merged = issue.pull_request?.merged_at;

    if (merged) {
      status = "Merged";
    } else if (state === "closed") {
      status = "Closed";
    } else {
      status = "Open";
    }

    // For NixOS/nixpkgs merged PRs, check if in nixos-unstable
    if (merged && ownerRepo.toLowerCase() === "nixos/nixpkgs") {
      try {
        const { data: pr } = await github.rest.pulls.get({
          owner: refOwner, repo: refRepo, pull_number: number,
        });
        if (pr.merge_commit_sha) {
          const { data: compare } = await github.rest.repos.compareCommits({
            owner: refOwner, repo: refRepo,
            base: "nixos-unstable",
            head: pr.merge_commit_sha,
          });
          if (compare.status === "behind" || compare.status === "identical") {
            status = "Merged (in nixos-unstable)";
          } else {
            status = "Merged (awaiting nixos-unstable)";
            state = "open";
          }
        }
      } catch (e) {
        console.log(`Warning: could not check nixos-unstable status for ${ref}`);
      }
    }

    info.set(ref, { title: issue.title, state, status });
  } catch (e) {
    console.log(`Warning: could not fetch ${ref}, skipping`);
  }
}

// Find or create the dashboard issue
const { owner, repo } = context.repo;

const { data: search } = await github.rest.search.issuesAndPullRequests({
  q: `repo:${owner}/${repo} is:issue is:open in:title "Upstream Issue Tracker"`,
});

let issueNumber = null;
for (const issue of search.items) {
  if (issue.title === "Upstream Issue Tracker") {
    issueNumber = issue.number;
    break;
  }
}

if (!issueNumber) {
  const { data: created } = await github.rest.issues.create({
    owner, repo,
    title: "Upstream Issue Tracker",
    body: "Initializing...",
  });
  issueNumber = created.number;
  console.log(`Created tracking issue #${issueNumber}`);
}

// Parse existing issue body for checkbox states
const { data: existing } = await github.rest.issues.get({
  owner, repo, issue_number: issueNumber,
});
const existingBody = existing.body || "";
const prevChecked = new Set();
const prevResolved = new Set();
const checkboxPattern = /^- \[([ x])\] \[([a-zA-Z0-9_./-]+#\d+)\]/;

for (const line of existingBody.split("\n")) {
  const m = line.match(checkboxPattern);
  if (!m) continue;
  prevResolved.add(m[2]);
  if (m[1] === "x") prevChecked.add(m[2]);
}

// Post comments for newly resolved refs
for (const ref of refs) {
  const ri = info.get(ref);
  if (!ri || ri.state !== "closed") continue;
  if (prevResolved.has(ref)) continue;

  const ownerRepo = ref.slice(0, ref.indexOf("#"));
  const num = ref.slice(ref.indexOf("#") + 1);
  const locs = locations.get(ref) || [];

  let body = `<!-- track-issues:${ref} -->\n`;
  body += `@${owner} **[${ref}](https://redirect.github.com/${ownerRepo}/issues/${num})** has been resolved (${ri.status}). Locations that may need cleanup:\n`;
  for (const loc of locs) {
    body += `- ${loc}\n`;
  }
  body += "\nCheck the box on the dashboard to dismiss this notification.";

  await github.rest.issues.createComment({
    owner, repo, issue_number: issueNumber, body,
  });
  console.log(`Posted notification for ${ref}`);
}

// Delete comments for checked/removed/no-longer-resolved refs
const comments = await github.paginate(
  github.rest.issues.listComments,
  { owner, repo, issue_number: issueNumber },
);

const trackPattern = /track-issues:([a-zA-Z0-9_./-]+#\d+)/;
for (const comment of comments) {
  if (!comment.body?.startsWith("<!-- track-issues:")) continue;
  const m = comment.body.match(trackPattern);
  if (!m) continue;

  const commentRef = m[1];
  let shouldDelete = false;

  if (prevChecked.has(commentRef)) shouldDelete = true;
  if (!locations.has(commentRef)) shouldDelete = true;

  const ri = info.get(commentRef);
  if (ri && ri.state !== "closed") shouldDelete = true;

  if (shouldDelete) {
    await github.rest.issues.deleteComment({
      owner, repo, comment_id: comment.id,
    });
    console.log(`Deleted notification for ${commentRef}`);
  }
}

// Generate dashboard body
let resolvedItems = "";
let openRows = "";

for (const ref of refs) {
  const ri = info.get(ref);
  if (!ri) continue;

  const ownerRepo = ref.slice(0, ref.indexOf("#"));
  const num = ref.slice(ref.indexOf("#") + 1);
  const link = `[${ref}](https://redirect.github.com/${ownerRepo}/issues/${num})`;
  const locs = (locations.get(ref) || []).join(" ");

  if (ri.state === "closed") {
    const check = prevChecked.has(ref) ? "x" : " ";
    resolvedItems += `- [${check}] ${link} \u2014 ${ri.title} (${ri.status}) \u2014 ${locs}\n`;
  } else {
    const title = ri.title.replace(/\|/g, "\\|");
    openRows += `| ${link} | ${title} | ${ri.status} | ${locs} |\n`;
  }
}

// Format timestamp
const parts = new Intl.DateTimeFormat("en-US", {
  timeZone: "America/Los_Angeles",
  year: "numeric", month: "2-digit", day: "2-digit",
  hour: "2-digit", minute: "2-digit", hour12: true,
  timeZoneName: "short",
}).formatToParts(new Date());
const get = (type) => parts.find((p) => p.type === type).value;
const timestamp = `${get("year")}-${get("month")}-${get("day")} ${get("hour")}:${get("minute")} ${get("dayPeriod")} ${get("timeZoneName")}`;

let body = "This issue is automatically updated by CI to track external issue/PR references found in the codebase.\n\n";
body += "## Resolved\n\n";
body += "These upstream issues have been resolved. The associated workarounds or temporary changes may no longer be needed.\n";
body += "Check the box to acknowledge and dismiss the notification.\n\n";
body += resolvedItems || "_None_\n";
body += "\n## Awaiting Upstream\n\n";
body += "These upstream issues are still open.\n\n";
body += "| Reference | Title | Status | Locations |\n";
body += "|-----------|-------|--------|-----------|\n";
body += openRows || "| _None_ | | | |\n";
body += "\n---\n";
body += `*Last updated: ${timestamp}. This issue is managed by CI \u2014 do not edit manually.*`;

await github.rest.issues.update({
  owner, repo, issue_number: issueNumber, body,
});
console.log(`Updated issue #${issueNumber}`);
