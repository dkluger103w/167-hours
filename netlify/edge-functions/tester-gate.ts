// 167 Hours tester gate.
// Protects the setup page (/start) and the plugin download (/167-hours.plugin).
// Testers enter an access code once; a secure cookie remembers them for 90 days.
// Codes live in the Netlify environment variable TESTER_CODES (comma separated).
// Remove a code there and that tester loses access on their next visit.
import type { Config, Context } from "https://edge.netlify.com";

const COOKIE = "t167";
const MAX_AGE = 60 * 60 * 24 * 90;

async function hash(code: string): Promise<string> {
  const secret = Netlify.env.get("TESTER_SECRET") ?? "";
  const data = new TextEncoder().encode(code.trim().toLowerCase() + "|" + secret);
  const buf = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function codes(): string[] {
  return (Netlify.env.get("TESTER_CODES") ?? "")
    .split(",").map((c) => c.trim().toLowerCase()).filter(Boolean);
}

async function cookieOk(req: Request): Promise<boolean> {
  const m = (req.headers.get("cookie") ?? "").match(/(?:^|;\s*)t167=([a-f0-9]{64})/);
  if (!m) return false;
  for (const c of codes()) if ((await hash(c)) === m[1]) return true;
  return false;
}

function page(error = "", next = "/start/"): Response {
  const esc = (s: string) => s.replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch]!));
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex"><title>167 Hours Tester Access</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,700&family=Public+Sans:wght@400;600;700&display=swap">
<style>
:root{--navy:#13233A;--soft:#4E5D70;--panel:#EEF2F7;--line:#D8E0EA;--hl:#FFE04A}
*{box-sizing:border-box}body{margin:0;background:#fff;color:var(--navy);font-family:'Public Sans','Helvetica Neue',Arial,sans-serif;font-size:17px;line-height:1.55}
.top{border-bottom:1px solid var(--line);padding:16px max(16px,env(safe-area-inset-left,0px))}
.top a{color:var(--navy);text-decoration:none;font-family:'Bricolage Grotesque',Arial,sans-serif;font-weight:700;font-size:1.4rem}
main{min-height:calc(100vh - 70px);display:grid;place-items:center;padding:32px 16px}
.card{width:100%;max-width:440px;background:var(--panel);border-radius:20px;padding:28px;display:flex;flex-direction:column;gap:14px}
h1{font-family:'Bricolage Grotesque',Arial,sans-serif;font-size:2rem;line-height:1.1;margin:0}
p{margin:0;color:var(--soft)}
label{font-weight:700;font-size:.92rem}
input{width:100%;min-height:50px;border:1.5px solid var(--line);border-radius:12px;padding:0 14px;font:inherit;background:#fff}
button{min-height:50px;border:0;border-radius:999px;background:var(--navy);color:#fff;font:inherit;font-weight:700;cursor:pointer}
.err{background:#FDECEC;color:#8A1F1F;border-radius:10px;padding:10px 12px;font-size:.92rem}
.small{font-size:.88rem}
a.back{color:var(--navy);font-weight:600}
</style></head><body>
<div class="top"><a href="/">167 Hours</a></div>
<main><form class="card" method="POST" action="/start/login">
<h1>Tester access</h1>
<p>The 167 Hours prototype is invite-only for now. Enter the access code you were given.</p>
${error ? `<div class="err">${esc(error)}</div>` : ""}
<label for="code">Access code</label>
<input id="code" name="code" autocomplete="off" autocapitalize="none" spellcheck="false" required autofocus>
<input type="hidden" name="next" value="${esc(next)}">
<button type="submit">Continue</button>
<p class="small">Don't have a code? <a class="back" href="/#involved">Ask to join the early group</a>.</p>
</form></main></body></html>`;
  return new Response(html, { status: error ? 401 : 200, headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" } });
}

export default async (req: Request, context: Context) => {
  const url = new URL(req.url);

  if (url.pathname === "/start/login" && req.method === "POST") {
    const form = await req.formData();
    const code = String(form.get("code") ?? "").trim().toLowerCase();
    let next = String(form.get("next") ?? "/start/");
    if (!next.startsWith("/") || next.startsWith("//")) next = "/start/";
    if (!code || !codes().includes(code)) return page("That code didn't work. Check it and try again.", next);
    return new Response(null, {
      status: 303,
      headers: {
        location: next,
        "set-cookie": `${COOKIE}=${await hash(code)}; Path=/; Max-Age=${MAX_AGE}; HttpOnly; Secure; SameSite=Lax`,
        "cache-control": "no-store",
      },
    });
  }

  if (await cookieOk(req)) {
    const res = await context.next();
    res.headers.set("cache-control", "private, no-store");
    return res;
  }
  return page("", url.pathname === "/start/login" ? "/start/" : url.pathname);
};

export const config: Config = {
  path: ["/start", "/start/*", "/167-hours.plugin"],
};
