/* Baut die Bilder der Startseite (start/*.jpg) an der ECHTEN App.
   Wer die Oberfläche ändert, ruft dies neu auf:  node tools/start-bilder.mjs
   Alle Eingaben sind die erfundenen Vorlagen und Beispiele dieses Depots. */
import http from "node:http";
import { readFileSync, existsSync, statSync } from "node:fs";
import { join, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";
import { findeChromium } from "../tests/chromium-finden.mjs";

const WURZEL = fileURLToPath(new URL("..", import.meta.url));
const TYP = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript",
  ".css": "text/css", ".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg",
  ".svg": "image/svg+xml", ".wasm": "application/wasm", ".webmanifest": "application/manifest+json" };
const server = http.createServer((q, a) => {
  let p = decodeURIComponent(new URL(q.url, "http://x").pathname);
  if (p.endsWith("/")) p += "index.html";
  const f = join(WURZEL, p);
  if (!f.startsWith(WURZEL) || !existsSync(f) || statSync(f).isDirectory()) { a.writeHead(404); return a.end(); }
  a.writeHead(200, { "content-type": TYP[extname(f)] || "application/octet-stream" }); a.end(readFileSync(f));
}).listen(0);
const basis = `http://127.0.0.1:${server.address().port}/`;
const pfad = findeChromium();
const browser = await chromium.launch(pfad ? { executablePath: pfad } : {});
const ctx = await browser.newContext({ viewport: { width: 1000, height: 760 }, deviceScaleFactor: 1 });
await ctx.addInitScript(() => { try { localStorage.setItem("auslieferungspruefer_start_v1", "1"); } catch (e) {} });
const p = await ctx.newPage();

async function oeffnen() {
  await p.goto(basis + "auslieferungspruefer.html");
  await p.waitForFunction(() => document.querySelector("#reiter-html"));
}
async function ergebnis(name) {
  await p.waitForFunction(() => document.querySelectorAll("#ergebnis .pr-karte").length > 0, null, { timeout: 120000 });
  await p.waitForTimeout(400);
  const r = await p.evaluate(() => { const b = document.querySelector("#ergebnis").getBoundingClientRect();
    return { x: b.x + scrollX, y: b.y + scrollY, width: b.width, height: b.height }; });
  await p.screenshot({ path: join(WURZEL, "start", name), type: "jpeg", quality: 78,
    clip: { x: r.x, y: r.y, width: r.width, height: Math.min(r.height, 640) }, fullPage: true });
  console.log("✓", name);
}

await oeffnen(); await p.click("#koederKnopf"); await ergebnis("01-seite.jpg");
await oeffnen(); await p.click("#reiter-mail"); await p.click("#mailBeispielKnopf"); await ergebnis("02-mail.jpg");
await oeffnen(); await p.click("#reiter-datei");
await p.setInputFiles("#einzelDatei", join(WURZEL, "testvorlagen/Vorlage-1A-Bild-mit-Text.png"));
await p.waitForFunction(() => document.querySelector('#ergebnis [data-kennung="BILD-KI-ANWEISUNG"]'), null, { timeout: 120000 });
await ergebnis("03-bild.jpg");
await oeffnen(); await p.click("#reiter-datei");
await p.setInputFiles("#einzelDatei", join(WURZEL, "testvorlagen/Vorlage-H2-Foto-mit-GPS-Verweis-und-Anhaengsel.jpg"));
await ergebnis("04-foto.jpg");
await browser.close(); server.close();
