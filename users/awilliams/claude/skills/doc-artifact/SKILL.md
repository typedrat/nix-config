---
name: doc-artifact
description: Use when someone wants to read or review a long markdown document — a plan, spec, design doc, RFC, or report — in the browser instead of the terminal. Renders it to a navigable Artifact page with a sticky contents rail, collapsible sections, and theme support. Generated from the file, so the rendered text is exactly what is committed.
---

# Rendering a document for browser review

Long markdown is miserable to review in a terminal. This renders it to a page
with a contents rail, collapsible task/section cards, and scrollable code and
tables.

**This skill carries its own page design** (`templates.py`). Do not load
`artifact-design` — the token system, type pairing, and both themes are already
decided. Deviate only if the user asks for a different look.

## Use it

```bash
python3 ~/.claude/skills/doc-artifact/render.py <input.md> -o <output.html> [options]
```

Then publish `<output.html>` with the Artifact tool.

| Option | Effect |
| --- | --- |
| `--title` | Browser tab and gallery title. Defaults to the doc's h1. |
| `--heading` | Masthead heading. Defaults to the doc's h1. |
| `--kicker` | Small label above the heading, e.g. `Design spec · for review`. |
| `--meta` | Pipe-separated facts under the heading: `branch foo\|1,200 lines\|12 tasks`. |
| `--cards` | Heading regex to collapse into cards. Defaults to `^###\s+Task\s+\d+`. Pass `""` to disable. |
| `--note` | Raw HTML callout above the body — use it for context that is *yours*, not the document's. |

Write to a scratch directory, not into the repo.

## The fidelity contract

The script counts code blocks and checklist steps in the source and in the
output, prints both, and **exits 1 if they disagree**. A mismatch means the
converter dropped content.

**Never publish on a mismatch.** The value of this over hand-transcription is
that the reviewer is reading what is committed; a page that silently lost a code
block is worse than no page, because the review will pass on content that does
not exist. Fix the converter, or fall back to publishing the `.md` directly.

Sanity-check the printed counts against the document even when they match —
if the source says 15 tasks and the table says 3 cards, the `--cards` regex is
wrong for that document.

## Choosing a shape

- **Cards** suit documents that are a list of comparable units — a plan of
  tasks, an RFC of numbered proposals. Collapsed by default, so the whole shape
  is scannable before drilling in.
- **Flat** (`--cards ""`) suits prose that is read in order — a design spec, a
  postmortem. A rail is enough.

Over ~2,000 lines, prefer cards; a flat page that long is a wall.

## What the converter handles

Headings, paragraphs, fenced code, tables, ordered and unordered lists,
blockquotes, task-list items (`- [ ]`), and inline code, bold, italics, links.

It is deliberately small. If a document needs footnotes, nested lists, or
reference links, extend `render.py` rather than hand-editing its output —
hand edits break the count guarantee.

## Three things it gets right that are easy to get wrong

**Fence state is tracked before headings.** A `# comment` on the first line of a
Python block is content, not a section. A naive line scan promotes it and
corrupts the contents rail.

**The document's own h1 is stripped**, because the masthead already carries the
title. Otherwise every page renders two h1s.

**No external fonts.** The Artifact CSP blocks font CDNs, so a linked webfont
fails silently to a fallback. The stacks in `templates.py` are system faces
chosen to pair.
