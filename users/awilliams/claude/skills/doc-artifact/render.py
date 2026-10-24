#!/usr/bin/env python3
"""Render a markdown document to a navigable HTML page for browser review.

Generated from the file rather than transcribed, so the rendered text is
exactly what is on disk. Prints a source-vs-output count table; a mismatch
means the converter dropped something and the page must not be trusted.
"""
import argparse, html, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from templates import page


def esc(t):
    return html.escape(t, quote=False)


def slug(t):
    t = re.sub(r"`([^`]*)`", r"\1", t)
    t = re.sub(r"[^\w\s-]", "", t).strip().lower()
    return re.sub(r"[\s_]+", "-", t) or "section"


def inline(t):
    # Code spans and link targets become placeholders first, so emphasis never
    # runs inside them but can still wrap them (**`x`.**, [`x`](url)).
    held = []

    def hold(s):
        held.append(s)
        return f"\x00{len(held) - 1}\x00"

    t = re.sub(r"`([^`]+)`", lambda m: hold(f"<code>{esc(m.group(1))}</code>"), t)
    t = re.sub(r"\]\(([^)\s]+)\)", lambda m: "](" + hold(html.escape(m.group(1))) + ")", t)
    p = esc(t)
    p = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', p)
    p = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", p)
    p = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", p)
    p = re.sub(r"(?<![\w_])_([^_\n]+)_(?![\w_])", r"<em>\1</em>", p)
    return re.sub(r"\x00(\d+)\x00", lambda m: held[int(m.group(1))], p)


ITEM = re.compile(r"^(\s*)([-*]|\d+\.)\s+(.*)$")


def render_list(items, start=0):
    """Render [indent, ordered, text] items as nested lists; a deeper indent
    becomes a child of the preceding item. Returns (html, next_index)."""
    indent = items[start][0]
    tag = "ol" if items[start][1] else "ul"
    out, i = [f"<{tag}>"], start
    while i < len(items) and items[i][0] >= indent:
        if items[i][0] > indent:
            sub, i = render_list(items, i)
            out[-1] = out[-1][:-len("</li>")] + sub + "</li>"
            continue
        out.append(f"<li>{inline(items[i][2])}</li>")
        i += 1
    out.append(f"</{tag}>")
    return "".join(out), i


def convert(md):
    """Markdown to HTML, returning (html, toc). Fence state is tracked first:
    a `# comment` inside a code block is content, not a heading."""
    lines, out, toc = md.split("\n"), [], []
    i, n = 0, len(lines)
    while i < n:
        ln = lines[i]

        m = re.match(r"^(`{3,})(\w*)", ln)
        if m:
            # Only a bare fence at least as long as the opener closes it, so a
            # ```` block can show ``` blocks inside it.
            fence, lang, i, buf = m.group(1), m.group(2), i + 1, []
            while i < n and not re.fullmatch(re.escape(fence) + r"`*\s*", lines[i]):
                buf.append(lines[i]); i += 1
            i += 1
            out.append(f'<figure class="code"><pre><code data-lang="{esc(lang)}">'
                       + esc("\n".join(buf)) + "</code></pre></figure>")
            continue

        m = re.match(r"^(#{1,6})\s+(.*)$", ln)
        if m:
            lvl, txt = len(m.group(1)), m.group(2).strip()
            sid = slug(txt)
            if lvl in (2, 3):
                toc.append((lvl, txt, sid))
            out.append(f'<h{lvl} id="{sid}">{inline(txt)}</h{lvl}>')
            i += 1
            continue

        m = re.match(r"^-\s+\[([ xX])\]\s+(.*)$", ln)
        if m:
            done = " done" if m.group(1).lower() == "x" else ""
            out.append(f'<p class="step{done}">{inline(m.group(2))}</p>')
            i += 1
            continue

        if ln.startswith("|"):
            tbl = []
            while i < n and lines[i].startswith("|"):
                tbl.append(lines[i]); i += 1
            cells = lambda r: [c.strip() for c in r.strip().strip("|").split("|")]
            head = cells(tbl[0])
            sep = len(tbl) > 1 and set(tbl[1]) <= set("|-: ")
            body = [cells(r) for r in tbl[2 if sep else 1:]]
            th = "".join(f"<th>{inline(c)}</th>" for c in head)
            rows = "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in body)
            out.append(f'<div class="tablewrap"><table><thead><tr>{th}</tr></thead><tbody>{rows}</tbody></table></div>')
            continue

        if re.match(r"^\s*[-*]\s+", ln) or re.match(r"^\s*\d+\.\s+", ln):
            items = []
            # A top-level task-list item ends the list: a step's indented
            # sub-bullets must not swallow the steps that follow them.
            while i < n and not re.match(r"^-\s+\[[ xX]\]\s", lines[i]) and (
                    re.match(r"^\s*[-*]\s+", lines[i]) or re.match(r"^\s*\d+\.\s+", lines[i])
                    or (lines[i].strip() and lines[i].startswith("  ") and items)):
                m = ITEM.match(lines[i])
                if m:
                    items.append([len(m.group(1)), m.group(2)[0].isdigit(), m.group(3)])
                else:
                    items[-1][2] += " " + lines[i].strip()
                i += 1
            # Items shallower than the first would end render_list early and
            # be dropped, so clamp them to the first item's depth.
            for it in items:
                it[0] = max(it[0], items[0][0])
            html_out, _ = render_list(items)
            out.append(html_out)
            continue

        if ln.startswith(">"):
            buf = []
            while i < n and lines[i].startswith(">"):
                buf.append(lines[i].lstrip(">").strip()); i += 1
            out.append(f"<blockquote>{inline(' '.join(buf))}</blockquote>")
            continue

        if not ln.strip():
            i += 1
            continue

        buf = []
        while i < n and lines[i].strip() and not re.match(r"^(#{1,6}\s|```|\||>|\s*[-*]\s|\s*\d+\.\s)", lines[i]):
            buf.append(lines[i].strip()); i += 1
        out.append(f"<p>{inline(' '.join(buf))}</p>")
    return "\n".join(out), toc


def fence_step(fence, line):
    """Track fenced-code state across lines. Returns (new_fence, is_fence_line);
    `fence` is the open fence's backticks, or None outside code."""
    if fence is None:
        m = re.match(r"^(`{3,})", line)
        return (m.group(1), True) if m else (None, False)
    if re.fullmatch(re.escape(fence) + r"`*\s*", line):
        return None, True
    return fence, False


def split_cards(md, pattern):
    """Split at headings matching `pattern`, ignoring matches inside fences.
    Returns (preamble, [(title, body)], tail)."""
    lines, fence, starts, tail_at = md.split("\n"), None, [], None
    for i, l in enumerate(lines):
        fence, is_fence = fence_step(fence, l)
        if is_fence or fence:
            continue
        if re.match(pattern, l):
            starts.append(i)
            # A section heading between cards (a plan's phases) belongs to the
            # card before it; only one after the last card starts the tail.
            tail_at = None
        elif starts and re.match(r"^##\s+", l) and tail_at is None:
            tail_at = i
    if not starts:
        return md, [], ""
    tail_at = tail_at if tail_at is not None else len(lines)
    cards = []
    for k, st in enumerate(starts):
        end = starts[k + 1] if k + 1 < len(starts) else tail_at
        head = re.sub(r"^#+\s+", "", lines[st])
        cards.append((head, "\n".join(lines[st + 1:end])))
    return "\n".join(lines[:starts[0]]), cards, "\n".join(lines[tail_at:])


def source_counts(md):
    fence, c = None, {"headings": 0, "code blocks": 0, "steps": 0, "list items": 0}
    for l in md.split("\n"):
        opened = fence is None
        fence, is_fence = fence_step(fence, l)
        if is_fence:
            c["code blocks"] += opened
            continue
        if fence:
            continue
        if re.match(r"^#{1,6}\s", l):
            c["headings"] += 1
        if re.match(r"^-\s+\[[ xX]\]\s", l):
            c["steps"] += 1
        elif ITEM.match(l):
            c["list items"] += 1
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--title", help="browser tab + gallery title")
    ap.add_argument("--heading", help="masthead heading (defaults to the doc's h1)")
    ap.add_argument("--kicker", default="For review")
    ap.add_argument("--meta", default="", help="pipe-separated masthead facts")
    ap.add_argument("--cards", default=r"^###\s+Task\s+\d+",
                    help="heading regex to collapse into cards; empty to disable")
    ap.add_argument("--note", default="", help="raw HTML callout above the body")
    args = ap.parse_args()

    md = open(args.input, encoding="utf-8").read()
    src = source_counts(md)

    doc_h1 = next((re.sub(r"^#\s+", "", l) for l in md.split("\n") if re.match(r"^#\s+", l)), "")
    heading = args.heading or re.sub(r"`", "", doc_h1) or os.path.basename(args.input)
    title = args.title or heading

    pre, cards, tail = split_cards(md, args.cards) if args.cards else (md, [], "")
    pre_html, pre_toc = convert(pre)
    tail_html, tail_toc = convert(tail)

    # The masthead carries the title; the doc's own h1 would duplicate it.
    pre_html = re.sub(r'<h1 [^>]*>.*?</h1>\n?', "", pre_html, count=1, flags=re.S)

    nav, cards_html = [], []
    for lvl, txt, sid in pre_toc:
        nav.append(f'<a class="lvl{lvl}" href="#{sid}"><span class="t">{esc(re.sub("`","",txt))}</span></a>')
    for k, (head, body_md) in enumerate(cards, 1):
        body, _ = convert(body_md)
        nsteps = len(re.findall(r'<p class="step"', body))
        num = (re.search(r"(\d+)", head) or [None, str(k)])[1]
        ttl = head.split(": ", 1)[1] if ": " in head else head
        sid = f"card-{num}"
        nav.append(f'<a class="lvl3" href="#{sid}"><span class="n">{num.zfill(2)}</span>'
                   f'<span class="t">{esc(re.sub("`","",ttl))}</span>'
                   f'<span class="c">{nsteps or ""}</span></a>')
        cards_html.append(
            f'<details class="card" id="{sid}"><summary><span class="num">{num.zfill(2)}</span>'
            f'<span class="ttl">{inline(ttl)}</span>'
            + (f'<span class="steps">{nsteps} steps</span>' if nsteps else "")
            + f'</summary><div class="cardbody">{body}</div></details>')
    for lvl, txt, sid in tail_toc:
        nav.append(f'<a class="lvl{lvl}" href="#{sid}"><span class="t">{esc(re.sub("`","",txt))}</span></a>')

    meta = ""
    if args.meta:
        parts = [f"<span>{esc(p.strip())}</span>" for p in args.meta.split("|")]
        meta = '<p class="meta">' + '<i>&nbsp;/&nbsp;</i>'.join(parts) + "</p>"

    controls = ('<div class="controls"><button id="xall" type="button">Expand all</button>'
                '<button id="call" type="button">Collapse all</button></div>') if cards_html else ""

    out = page(esc(title), esc(args.kicker), esc(heading), meta,
               '<p class="eyebrow">Contents</p><nav>' + "".join(nav) + "</nav>",
               args.note, controls, pre_html + "".join(cards_html) + tail_html)
    open(args.output, "w", encoding="utf-8").write(out)

    got = {"headings": len(re.findall(r"<h[1-6][ >]", out)) + len(cards_html),
           "code blocks": len(re.findall(r'<figure class="code"', out)),
           "steps": len(re.findall(r'<p class="step"', out)),
           "list items": len(re.findall(r"<li>", out))}
    ok = True
    print(f"{'':<14}{'source':>8}{'output':>8}")
    for k in ("code blocks", "steps", "list items"):
        flag = "" if src[k] == got[k] else "   MISMATCH"
        ok &= src[k] == got[k]
        print(f"{k:<14}{src[k]:>8}{got[k]:>8}{flag}")
    print(f"{'cards':<14}{len(cards):>8}{len(cards_html):>8}")
    print(f"\nwrote {args.output} ({len(out):,} bytes)")
    if not ok:
        print("\nCounts disagree — the converter dropped content. Do not publish.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
