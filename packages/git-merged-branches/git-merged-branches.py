from __future__ import annotations

import os
import re
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import NoReturn

import click
from git import Repo
from git.exc import InvalidGitRepositoryError
from github import Auth, Github
from rich.console import Console
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    SpinnerColumn,
    TextColumn,
    TimeElapsedColumn,
)
from rich.table import Table

# Long-lived branches we never report or delete.
PROTECTED = re.compile(r"^(main|master|develop|dev|release/.*)$")

console = Console()

# One PyGithub client + Repository per worker thread. PyGithub isn't
# guaranteed thread-safe, so we never share a client across threads; each
# thread builds its own once and reuses it (keeps connection pooling).
_thread_local = threading.local()


@dataclass
class Result:
    branch: str
    pr_number: int | None = None
    pr_title: str | None = None
    error: str | None = None

    @property
    def merged(self) -> bool:
        return self.pr_number is not None


def die(message: str) -> NoReturn:
    console.print(f"[red]error:[/] {message}")
    raise SystemExit(1)


def get_token() -> str | None:
    for var in ("GITHUB_TOKEN", "GH_TOKEN"):
        if os.environ.get(var):
            return os.environ[var]
    # Reuse the existing gh login rather than demanding a separate PAT.
    try:
        out = subprocess.run(
            ["gh", "auth", "token"],
            capture_output=True,
            text=True,
            check=True,
        )
        return out.stdout.strip() or None
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None


def parse_remote(url: str) -> tuple[str, str]:
    # Handles git@github.com:owner/repo.git,
    # https://github.com/owner/repo(.git),
    # and ssh://git@github.com/owner/repo.git.
    m = re.search(r"github\.com[:/]([^/]+)/(.+?)(?:\.git)?/?$", url)
    if not m:
        msg = f"could not parse a github.com owner/repo from: {url}"
        raise ValueError(msg)
    return m.group(1), m.group(2)


def _get_repo(token: str, full_name: str):
    repo = getattr(_thread_local, "repo", None)
    if repo is None:
        client = Github(auth=Auth.Token(token))
        repo = client.get_repo(full_name)  # one GET /repos/... per thread
        _thread_local.repo = repo
    return repo


def check_branch(token: str, owner: str, name: str, branch: str) -> Result:
    """Return a Result describing whether `branch` has a merged PR."""
    try:
        repo = _get_repo(token, f"{owner}/{name}")
        # The REST API has no "merged" state, so query closed PRs whose head
        # is this branch and look for a non-null merged_at. merged_at comes
        # back in the list payload, so this needs no extra per-PR fetch.
        pulls = repo.get_pulls(state="closed", head=f"{owner}:{branch}")
        merged = next((pr for pr in pulls if pr.merged_at is not None), None)
        if merged is not None:
            return Result(branch, merged.number, merged.title)
        return Result(branch)
    except Exception as exc:  # one bad branch shouldn't abort the whole run
        return Result(branch, error=str(exc))


def check_branches(
    token: str,
    owner: str,
    name: str,
    bs: list[str],
    concurrency: int,
) -> list[Result]:
    results: list[Result] = []
    columns = (
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        MofNCompleteColumn(),
        TimeElapsedColumn(),
    )
    with Progress(*columns, console=console) as progress:
        task_id = progress.add_task("Checking branches", total=len(bs))
        with ThreadPoolExecutor(max_workers=concurrency) as pool:
            futures = [
              pool.submit(check_branch, token, owner, name, b) for b in bs
            ]

            # Advance from the main thread as each check lands.
            for fut in as_completed(futures):
                results.append(fut.result())
                progress.advance(task_id)
    return results


def report(results: list[Result], current: str | None) -> list[Result]:
    merged = [r for r in results if r.merged]
    errored = [r for r in results if r.error]

    if errored:
        msg = f"[yellow]warning:[/] {len(errored)} branch check(s) failed:"
        console.print(msg)
        for r in errored:
            console.print(f"  [yellow]{r.branch}[/]: {r.error}")
        console.print()

    if not merged:
        console.print("No local branches are tied to merged PRs.")
        return merged

    table = Table(title="Local branches tied to merged PRs")
    table.add_column("Branch", style="cyan", no_wrap=True)
    table.add_column("PR", justify="right", style="magenta")
    table.add_column("Title")
    for r in sorted(merged, key=lambda x: x.branch):
        name = f"{r.branch}  (current)" if r.branch == current else r.branch
        table.add_row(name, f"#{r.pr_number}", r.pr_title)
    console.print(table)
    return merged


def delete_branches(
    repo: Repo, merged: list[Result], current: str | None, force: bool
) -> None:
    for r in merged:
        if r.branch == current:
            console.print(f"[dim]skip {r.branch}: current branch[/]")
            continue
        if not force and not click.confirm(
            f"Delete local branch '{r.branch}'?", default=False
        ):
            console.print(f"[dim]skipped {r.branch}[/]")
            continue
        # Force delete: squash/rebase-merged branches aren't ancestors of HEAD,
        # so a non-force delete would refuse them even though GitHub merged
        # them.
        repo.delete_head(r.branch, force=True)
        console.print(f"[green]deleted[/] {r.branch}")


@click.command(context_settings={"help_option_names": ["-h", "--help"]})
@click.option(
    "-d",
    "--delete",
    "delete",
    is_flag=True,
    help="Delete the merged branches (prompts unless --force).",
)
@click.option(
    "-f",
    "--force",
    is_flag=True,
    help="With --delete, skip confirmation prompts.",
)
@click.option(
    "--remote",
    default="origin",
    show_default=True,
    help="Remote to resolve owner/repo from.",
)
@click.option(
    "-j",
    "--concurrency",
    type=int,
    default=8,
    show_default=True,
    help="Max concurrent requests / worker threads.",
)
def cli(delete: bool, force: bool, remote: str, concurrency: int) -> None:
    """
    List (and optionally delete) local branches whose GitHub PR is merged.
    """
    try:
        repo = Repo(os.getcwd(), search_parent_directories=True)
    except InvalidGitRepositoryError:
        die("not inside a git repository")

    try:
        current = repo.active_branch.name
    except TypeError:
        current = None  # detached HEAD

    branches = [h.name for h in repo.heads if not PROTECTED.match(h.name)]
    if not branches:
        console.print("No non-protected local branches to check.")
        return

    try:
        url = repo.remotes[remote].url
    except IndexError:
        die(f"no remote named '{remote}'")
    try:
        owner, name = parse_remote(url)
    except ValueError as exc:
        die(str(exc))

    token = get_token()
    if not token:
        die(
          "no GitHub token (set GITHUB_TOKEN/GH_TOKEN or run `gh auth login`)"
        )

    results = check_branches(token, owner, name, branches, concurrency)
    merged = report(results, current)

    if delete and merged:
        console.print()
        delete_branches(repo, merged, current, force)


if __name__ == "__main__":
    cli(prog_name="git merged-branches")
