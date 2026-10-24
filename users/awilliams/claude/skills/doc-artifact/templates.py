"""Page shell for rendered documents: one token system, both themes."""

# Blue-biased neutrals with an amber accent. The neutral is pulled slightly
# toward the accent so it reads as chosen rather than inherited.
CSS = """
:root{
  --paper:#f7f5f0; --raise:#fffdf9; --card:#fffdf9; --ink:#14181f; --muted:#5c6470;
  --accent:#9a5b0d; --rule:#e3ded4; --code-bg:#efece3;
  --mono:ui-monospace,SFMono-Regular,"SF Mono",Menlo,Consolas,"Liberation Mono",monospace;
  --serif:Charter,"Bitstream Charter","Iowan Old Style","Palatino Linotype",Palatino,Georgia,serif;
}
/* Unstamped root + dark OS is the common case; an explicit light choice must still win. */
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    --paper:#12151a; --raise:#171b21; --card:#161a20; --ink:#e7e5e0; --muted:#98a0ac;
    --accent:#e0a63c; --rule:#262b33; --code-bg:#1a1e25;
  }
}
:root[data-theme="dark"]{
  --paper:#12151a; --raise:#171b21; --card:#161a20; --ink:#e7e5e0; --muted:#98a0ac;
  --accent:#e0a63c; --rule:#262b33; --code-bg:#1a1e25;
}
*{box-sizing:border-box}
body{margin:0; background:var(--paper); color:var(--ink);
  font-family:var(--serif); font-size:17px; line-height:1.65; -webkit-font-smoothing:antialiased}
.shell{display:grid; grid-template-columns:17rem minmax(0,1fr); gap:3.5rem;
  max-width:80rem; margin:0 auto; padding:2.5rem 1.5rem 6rem}
@media (max-width:960px){.shell{grid-template-columns:1fr; gap:2rem}}

.rail{position:sticky; top:2rem; align-self:start; max-height:calc(100vh - 4rem); overflow-y:auto}
@media (max-width:960px){.rail{position:static; max-height:none; border-bottom:1px solid var(--rule); padding-bottom:1.5rem}}
.rail .eyebrow{font-family:var(--mono); font-size:.66rem; letter-spacing:.14em; text-transform:uppercase; color:var(--muted); margin:0 0 .9rem}
.rail nav{display:flex; flex-direction:column; gap:.05rem}
.rail a{font-family:var(--mono); font-size:.755rem; line-height:1.4; text-decoration:none; color:var(--muted);
  padding:.3rem .5rem; border-left:2px solid transparent; border-radius:0 3px 3px 0;
  display:flex; align-items:baseline; gap:.5rem}
.rail a.lvl2{color:var(--ink); font-size:.72rem; letter-spacing:.06em; text-transform:uppercase; margin:.7rem 0 .2rem}
.rail a.lvl3{padding-left:1.1rem}
.rail a .n{color:var(--accent); font-size:.68rem; flex:none; font-variant-numeric:tabular-nums}
.rail a .t{flex:1; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap}
.rail a .c{flex:none; font-size:.65rem; color:var(--muted); opacity:.65; font-variant-numeric:tabular-nums}
.rail a:hover{color:var(--ink); background:var(--raise); border-left-color:var(--accent)}
.rail a:focus-visible{outline:2px solid var(--accent); outline-offset:1px}

main{min-width:0}
.mast{border-bottom:1px solid var(--rule); padding-bottom:1.75rem; margin-bottom:2rem}
.mast .kicker{font-family:var(--mono); font-size:.7rem; letter-spacing:.14em; text-transform:uppercase; color:var(--accent); margin:0 0 .7rem}
h1{font-family:var(--mono); font-size:1.72rem; font-weight:600; letter-spacing:-.02em; margin:0; text-wrap:balance}
.mast .meta{font-family:var(--mono); font-size:.74rem; color:var(--muted); margin:.9rem 0 0; line-height:1.7}
.mast .meta i{font-style:normal; color:var(--rule)}

.note{background:var(--raise); border:1px solid var(--rule); border-left:3px solid var(--accent);
  padding:1.1rem 1.35rem; margin:0 0 2.5rem; border-radius:0 4px 4px 0}
.note h2{font-family:var(--mono); font-size:.72rem; letter-spacing:.13em; text-transform:uppercase;
  color:var(--accent); margin:0 0 .7rem; border:0; padding:0}

.controls{display:flex; gap:.5rem; margin:0 0 2rem}
.controls button{font-family:var(--mono); font-size:.72rem; letter-spacing:.06em; text-transform:uppercase;
  color:var(--muted); background:var(--raise); border:1px solid var(--rule); border-radius:3px; padding:.45rem .8rem; cursor:pointer}
.controls button:hover{color:var(--ink); border-color:var(--accent)}
.controls button:focus-visible{outline:2px solid var(--accent); outline-offset:1px}

h2{font-family:var(--mono); font-size:1.1rem; font-weight:600; margin:2.8rem 0 .9rem;
  padding-top:1.1rem; border-top:1px solid var(--rule); scroll-margin-top:1.5rem}
h3{font-family:var(--mono); font-size:.96rem; font-weight:600; margin:2.1rem 0 .7rem; scroll-margin-top:1.5rem}
h4{font-family:var(--mono); font-size:.85rem; font-weight:500; color:var(--muted); margin:1.5rem 0 .6rem}
p{margin:0 0 1.05rem; max-width:40rem}
ul,ol{margin:0 0 1.15rem; padding-left:1.4rem; display:flex; flex-direction:column; gap:.4rem; max-width:40rem}
strong{font-weight:600}
a{color:var(--accent); text-underline-offset:2px}
blockquote{margin:1.2rem 0; padding:.2rem 0 .2rem 1.1rem; border-left:2px solid var(--accent); color:var(--muted); font-style:italic; max-width:40rem}
code{font-family:var(--mono); font-size:.86em; background:var(--code-bg); padding:.12em .34em; border-radius:3px; word-break:break-word}
figure.code{margin:1.15rem 0; background:var(--code-bg); border:1px solid var(--rule); border-radius:4px; overflow-x:auto}
figure.code pre{margin:0; padding:.95rem 1.1rem}
figure.code code{background:none; padding:0; font-size:.775rem; line-height:1.6; display:block; white-space:pre; border-radius:0}
.tablewrap{overflow-x:auto; margin:1.2rem 0; border:1px solid var(--rule); border-radius:4px}
table{border-collapse:collapse; width:100%; font-size:.85rem; font-variant-numeric:tabular-nums}
th,td{text-align:left; padding:.6rem .8rem; border-bottom:1px solid var(--rule); vertical-align:top}
th{font-family:var(--mono); font-size:.71rem; letter-spacing:.05em; text-transform:uppercase; color:var(--muted); font-weight:600; background:var(--raise)}
tbody tr:last-child td{border-bottom:0}

details.card{background:var(--card); border:1px solid var(--rule); border-radius:5px; margin:0 0 .6rem; scroll-margin-top:1.5rem}
details.card[open]{border-color:var(--accent)}
details.card summary{list-style:none; cursor:pointer; display:flex; align-items:baseline; gap:.85rem;
  padding:.85rem 1.1rem; font-family:var(--mono); font-size:.9rem; font-weight:600}
details.card summary::-webkit-details-marker{display:none}
details.card summary:hover{color:var(--accent)}
details.card summary:focus-visible{outline:2px solid var(--accent); outline-offset:-2px; border-radius:5px}
details.card summary .num{color:var(--accent); font-size:.78rem; flex:none; font-variant-numeric:tabular-nums}
details.card summary .ttl{flex:1; min-width:0}
details.card summary .steps{flex:none; font-size:.68rem; font-weight:400; color:var(--muted); letter-spacing:.05em; text-transform:uppercase}
.cardbody{padding:.2rem 1.1rem 1.2rem; border-top:1px solid var(--rule); margin-top:.2rem}

p.step{font-family:var(--mono); font-size:.83rem; margin:1.7rem 0 .8rem; padding-left:.85rem; border-left:2px solid var(--accent)}
p.step.done{opacity:.6}

@media (prefers-reduced-motion:reduce){*{animation:none!important; transition:none!important}}
"""

# Deep links must open the card they point at, or the anchor lands on a closed element.
JS = """
const all=[...document.querySelectorAll('details.card')];
const x=document.getElementById('xall'), c=document.getElementById('call');
if(x) x.onclick=()=>all.forEach(d=>d.open=true);
if(c) c.onclick=()=>all.forEach(d=>d.open=false);
function openHash(){
  const h=location.hash.slice(1); if(!h) return;
  const el=document.getElementById(h);
  if(el&&el.tagName==='DETAILS'){el.open=true; el.scrollIntoView();}
}
addEventListener('hashchange',openHash); openHash();
document.querySelectorAll('.rail a[href^="#card-"]').forEach(a=>{
  a.addEventListener('click',()=>{const d=document.getElementById(a.hash.slice(1)); if(d) d.open=true;});
});
"""

def page(title, kicker, heading, meta_html, nav, note, controls, body):
    return f"""<title>{title}</title>
<style>{CSS}</style>
<div class="shell">
  <aside class="rail">{nav}</aside>
  <main>
    <header class="mast">
      <p class="kicker">{kicker}</p>
      <h1>{heading}</h1>
      {meta_html}
    </header>
    {note}{controls}{body}
  </main>
</div>
<script>{JS}</script>
"""
