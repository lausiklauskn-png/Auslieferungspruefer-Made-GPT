# Mitgelieferte Fremd-Bibliotheken

| Datei | Was | Lizenz | Herkunft |
|---|---|---|---|
| `vendor/pdfjs/pdf.min.js`, `vendor/pdfjs/pdf.worker.min.js` | PDF.js 3.11.174, Mozilla Foundation | Apache License 2.0 | byte-gleich aus Workflow PDF (`vendor/pdfjs/`), dort aus Mein-WorkFloh |
| `vendor/tesseract/tesseract.min.js`, `vendor/tesseract/worker.min.js` | Tesseract.js 7.0.0 (naptha) | Apache License 2.0, Lizenztext in `vendor/tesseract/LICENSE-Apache-2.0.txt`; gebündelte Hilfsbibliotheken (MIT, BSD-3-Clause) in den `*.LICENSE.txt` daneben | byte-gleich aus Workflow PDF (`vendor/tesseract/`), dort npm-Paket `tesseract.js@7.0.0`, `dist/` |
| `vendor/tesseract/tesseract-core-*-lstm.wasm.js` | tesseract.js-core 7.0.0 (Tesseract OCR als WebAssembly) | Apache License 2.0 | byte-gleich aus Workflow PDF, dort npm-Paket `tesseract.js-core@7.0.0` |
| `vendor/tesseract/lang/{deu,eng,rus}.traineddata` | Sprachdaten tessdata_fast (Tesseract OCR) | Apache License 2.0 | byte-gleich aus Workflow PDF, dort `tesseract-ocr/tessdata_fast`, Zweig `main` |
| `tests/vendor/pdf-lib.min.js` | pdf-lib 1.17.1, Andrew Dillon — **nur für die Proben und `tools/testvorlagen-bauen.mjs`**, wird nicht ausgeliefert | MIT | byte-gleich aus Workflow PDF (`vendor/pdf-lib.min.js`), npm-Paket `pdf-lib@1.17.1` |

Die Lizenzköpfe in den Dateien bleiben erhalten.
Lizenztexte: <https://www.apache.org/licenses/LICENSE-2.0> · <https://opensource.org/license/mit/> · <https://opensource.org/license/bsd-3-clause/>

⚠ pdf.js 3.x konnte mit einer präparierten Schrift eigenen Code ausführen
(CVE-2024-4367). Der Prüfer betreibt es mit `isEvalSupported: false`; ein
Wächter in `tests/smoke_anhang.mjs` liest die Zeile.
