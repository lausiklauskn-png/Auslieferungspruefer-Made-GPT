/* Startseite „Was die App kann" (Klaus 2026-10-01): beim ersten Öffnen vor der
   App, mit Haken nicht mehr, aus der Kopfleiste jederzeit, Deutsch und Englisch.
   Echter Browser, eigener Server auf Port 0. */
import http from "node:http";
import { readFileSync, existsSync, statSync } from "node:fs";
import { join, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";
import { findeChromium } from "./chromium-finden.mjs";

const W = fileURLToPath(new URL("..", import.meta.url));
let gruen = 0, rot = 0;
const ok = (n, b, d = "") => { if (b) { gruen++; console.log("  ✓ " + n); } else { rot++; console.log("  ✗ ROT: " + n + (d ? "  → " + d : "")); } };
const TYP = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css", ".png": "image/png", ".jpg": "image/jpeg", ".json": "application/json" };
const server = http.createServer((q, a) => {
  let p = decodeURIComponent(new URL(q.url, "http://x").pathname).replace(/^\/+/, "") || "index.html";
  const f = join(W, p);
  if (!f.startsWith(W) || !existsSync(f) || statSync(f).isDirectory()) { a.writeHead(404); return a.end(); }
  a.writeHead(200, { "content-type": TYP[extname(f)] || "application/octet-stream" }); a.end(readFileSync(f));
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const B = `http://127.0.0.1:${server.address().port}/`;
const pfad = findeChromium();
let browser;
try { browser = await chromium.launch(pfad ? { executablePath: pfad } : {}); }
catch (e) { console.log("⊘ nicht lauffähig: kein Browser"); server.close(); process.exit(0); }

const ctx = await browser.newContext({ viewport: { width: 360, height: 780 } });
const p = await ctx.newPage();
await p.goto(B + "index.html");
await p.waitForFunction(() => location.pathname.endsWith("start.html"));
ok("beim ersten Öffnen steht die Startseite vor der App", p.url().endsWith("start.html"));
const de = await p.evaluate(() => {
  const sicht = (e) => !!e && e.checkVisibility();
  const blk = document.querySelector('main > [data-l="de"]');
  const t = blk.innerText, tun = [...blk.querySelectorAll(".tun details")];
  return { h1: blk.querySelector("h1").textContent, sicht: sicht(blk.querySelector("h1")), enVersteckt: !sicht(document.querySelector('main > [data-l="en"] h1')),
    haken: [...document.querySelectorAll(".nichtMehr")].every((h) => !h.checked),
    tun: tun.length, schritte: tun.every((d) => d.querySelectorAll("ol li").length >= 2),
    zurApp: [...document.querySelectorAll('a[href="auslieferungspruefer.html"]')].length >= 3,
    bilder: [...document.querySelectorAll("main img")].every((i) => i.hasAttribute("alt") && i.getAttribute("width") && i.getAttribute("height")),
    bilderDa: [...blk.querySelectorAll('img[src^="start/"]')].map((i) => i.getAttribute("src")),
    grenze: /kein Virenscanner/i.test(t), quer: document.documentElement.scrollWidth <= innerWidth + 1,
    jargon: t.match(/Gegenprobe|Wächter|Probe|byte-1:1|Modul \d|Stufe \d|Klaus|Befund/g) || [] };
});
ok("sie trägt den Kernsatz, auf Deutsch", /was Sie zeigen wollen/.test(de.h1) && de.sicht, de.h1);
ok("… und die englische Fassung ist dabei nicht zu sehen", de.enVersteckt);
ok("der Haken ist beim ersten Mal nicht gesetzt", de.haken);
ok("„Was tun, wenn …“ nennt je Fund Schritte in Reihenfolge", de.tun >= 6 && de.schritte, de.tun);
ok("jeder Weg zur App ist ein echter Link", de.zurApp);
ok("jedes Bild hat alt und feste Maße", de.bilder);
ok("die Bilder aus der App liegen wirklich da", de.bilderDa.length >= 4 && de.bilderDa.every((s) => existsSync(join(W, s))), de.bilderDa.join(" "));
ok("die Grenzen stehen sichtbar da", de.grenze);
ok("kein Werkstatt-Jargon auf der Seite", de.jargon.length === 0, de.jargon.join(", "));
ok("keine Querlauf-Breite bei 360 px", de.quer);

await p.click("#sprache");
const en = await p.evaluate(() => ({ h1: [...document.querySelectorAll("h1")].find((h) => h.checkVisibility())?.textContent || "",
  gespeichert: localStorage.getItem("toolpoint_lang"),
  tun: document.querySelectorAll('[data-l="en"] .tun details').length, deTun: document.querySelectorAll('[data-l="de"] .tun details').length,
  deutsch: ([...document.querySelectorAll('[data-l="en"]')].map((e) => e.textContent).join(" ").match(/\b(und|nicht|wenn|Datei)\b/g) || []) }));
ok("DE/EN schaltet auf Englisch und merkt es wie die App", /Show only/.test(en.h1) && en.gespeichert === "en", en.h1);
ok("die englische Fassung hat dieselben Funde wie die deutsche", en.tun === en.deTun, en.tun + "/" + en.deTun);
ok("… und keine deutschen Wörter", en.deutsch.length === 0, en.deutsch.join(" "));
await p.click("#sprache");

await p.check(".nichtMehr");
ok("der Haken merkt sich die Wahl", await p.evaluate(() => localStorage.getItem("auslieferungspruefer_start_v1") === "1"));
await p.goto(B + "index.html");
await p.waitForFunction(() => location.pathname.endsWith("auslieferungspruefer.html"));
ok("mit Haken geht index.html gleich in die App", p.url().endsWith("auslieferungspruefer.html"));
for (const breite of [360, 1300]) {
  await p.setViewportSize({ width: breite, height: 800 });
  const k = await p.evaluate(() => { const a = document.querySelector("#ueberblickKnopf");
    return { da: !!a && a.getAttribute("href") === "start.html" && a.checkVisibility() && !!a.closest("header"),
      quer: document.documentElement.scrollWidth <= innerWidth + 1, rechts: a ? Math.round(a.getBoundingClientRect().right) : -1 }; });
  ok(`${breite} px: der Überblick steht sichtbar in der Kopfleiste und führt zur Startseite`, k.da && k.rechts <= breite, k.rechts);
  ok(`${breite} px: … ohne Querlauf`, k.quer);
}
const mitAnhang = await ctx.newPage();
await mitAnhang.evaluate(() => 0);
await ctx.clearCookies();
const c2 = await browser.newContext(); const p2 = await c2.newPage();
await p2.goto(B + "?adresse=https%3A%2F%2Fbeispiel.example%2F");
await p2.waitForFunction(() => location.pathname.endsWith("auslieferungspruefer.html"));
ok("mit ?adresse= geht es beim ersten Öffnen direkt in den Prüfer", p2.url().includes("auslieferungspruefer.html?adresse="));

await browser.close(); server.close();
console.log(`\n${gruen} grün · ${rot} ROT`);
process.exitCode = rot ? 1 : 0;
