/* Auslieferungsprüfer GPT — ausschließlich app-eigene, scopegebundene Ressourcen. */
'use strict';
const CACHE_PREFIX='ap-gpt-';
const CACHE_VERSION=CACHE_PREFIX+'v1.0.0';
const CORE=[
  "404.html",
  "assets/config/netz.js",
  "assets/config/pruefer-netz.js",
  "assets/design-gpt.css",
  "assets/i18n-pruefer.js",
  "assets/i18n-start-gpt.js",
  "assets/i18n-recht.js",
  "assets/installieren.js",
  "assets/og-image.png",
  "assets/pruefer-anhang.js",
  "assets/pruefer-browser.js",
  "assets/pruefer-ergebnis.js",
  "assets/pruefer-formate.js",
  "assets/pruefer-karte.png",
  "assets/pruefer-mail.js",
  "assets/pruefer-sbkim-andock-wizard.js",
  "assets/pruefer-sbkim-init.js",
  "assets/pruefer-siegel-inhalt.js",
  "assets/pruefer-ui.js",
  "assets/pruefer.js",
  "assets/pwa-gpt.js",
  "assets/sprache.js",
  "assets/start.css",
  "assets/style.css",
  "assets/thema.js",
  "auslieferungspruefer.html",
  "beispiele/Testbild-versteckte-Anweisung.png",
  "datenschutz.html",
  "icons/apple-touch-icon.png",
  "icons/favicon-32.png",
  "icons/favicon-48.png",
  "icons/icon-192.png",
  "icons/icon-512.png",
  "icons/marke-96.png",
  "icons/marke-gpt.svg",
  "icons/maskable-512.png",
  "impressum.html",
  "index.html",
  "manifest.json",
  "sbkim/01_storage.js",
  "sbkim/02_spore.js",
  "sbkim/03_embedding.js",
  "sbkim/04_match.js",
  "sbkim/05_anastomose.js",
  "sbkim/05b_nostr_relay.js",
  "sbkim/07_apoptose.js",
  "sbkim/15_membran.js",
  "sbkim/16_siegel.js",
  "sbkim/17_floating_widget.js",
  "sbkim/23_rendezvous.js",
  "sbkim/23_rendezvous_ui.js",
  "sbkim/noble-secp256k1.js",
  "sicherheit.html",
  "start.html",
  "testvorlagen/Vorlage-0D-PDF-versteckter-Text.pdf",
  "testvorlagen/Vorlage-1A-Bild-mit-Text.png",
  "testvorlagen/Vorlage-1A-PDF-Scan-ohne-Textebene.pdf",
  "testvorlagen/Vorlage-2B-Bild-blasser-Text.png",
  "testvorlagen/Vorlage-3E-PDF-Bild-und-Textebene-widersprechen.pdf",
  "testvorlagen/Vorlage-4C-Bild-mit-versteckter-Botschaft.png",
  "testvorlagen/Vorlage-4C-Bild-ohne-Botschaft.png",
  "testvorlagen/Vorlage-Alle-als-Mail.eml",
  "testvorlagen/Vorlage-H0-Foto-sauber.jpg",
  "testvorlagen/Vorlage-H1-Text-mit-Angaben.txt",
  "testvorlagen/Vorlage-H2-Foto-mit-GPS-Verweis-und-Anhaengsel.jpg",
  "testvorlagen/Vorlage-H3-Grafik-laedt-von-fremdem-Rechner.svg",
  "testvorlagen/Vorlage-H4-Word-mit-externer-Vorlage.docx",
  "testvorlagen/Vorlage-H5-Bild-als-PDF-getarnt.pdf",
  "testvorlagen/index.html",
  "vendor/pdfjs/pdf.min.js",
  "vendor/pdfjs/pdf.worker.min.js",
  "vendor/tesseract/LICENSE-Apache-2.0.txt",
  "vendor/tesseract/lang/deu.traineddata",
  "vendor/tesseract/lang/eng.traineddata",
  "vendor/tesseract/lang/rus.traineddata",
  "vendor/tesseract/tesseract-core-lstm.wasm.js",
  "vendor/tesseract/tesseract-core-relaxedsimd-lstm.wasm.js",
  "vendor/tesseract/tesseract-core-simd-lstm.wasm.js",
  "vendor/tesseract/tesseract.min.js",
  "vendor/tesseract/tesseract.min.js.LICENSE.txt",
  "vendor/tesseract/worker.min.js",
  "vendor/tesseract/worker.min.js.LICENSE.txt"
];
const APP_BASE=new URL('./',self.location.href);
const KNOWN=new Set(CORE.map(path=>new URL(path,APP_BASE).pathname));
self.addEventListener('install',event=>{
  event.waitUntil((async()=>{
    const cache=await caches.open(CACHE_VERSION);
    // Small batches avoid loading multiple large WASM bundles at once.
    for(let i=0;i<CORE.length;i+=4)await Promise.allSettled(CORE.slice(i,i+4).map(async path=>{
      const response=await fetch(new Request(new URL(path,APP_BASE),{cache:'reload'}));
      if(!response.ok)throw new Error('Resource '+path+' '+response.status);
      await cache.put(new URL(path,APP_BASE).href,response);
    }));
    await self.skipWaiting();
  })());
});
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  const names=await caches.keys();
  await Promise.all(names.filter(name=>name.startsWith(CACHE_PREFIX)&&name!==CACHE_VERSION).map(name=>caches.delete(name)));
  await self.clients.claim();
})()));
async function readiness(){
  const cache=await caches.open(CACHE_VERSION),missing=[];
  for(const path of CORE)if(!await cache.match(new URL(path,APP_BASE).href))missing.push(path);
  return {ready:missing.length===0,missing,version:CACHE_VERSION};
}
self.addEventListener('message',event=>{
  if(event.data&&event.data.type==='OFFLINE_STATUS')event.waitUntil(readiness().then(r=>{if(event.ports[0])event.ports[0].postMessage(r);}));
});
self.addEventListener('fetch',event=>{
  const req=event.request,url=new URL(req.url);
  if(req.method!=='GET'||url.origin!==APP_BASE.origin||!url.pathname.startsWith(APP_BASE.pathname))return;
  const directoryIndex=url.pathname.endsWith('/')?url.pathname+'index.html':null;
  const path=directoryIndex&&KNOWN.has(directoryIndex)?directoryIndex:url.pathname;
  if(!KNOWN.has(path)){
    if(req.mode==='navigate')event.respondWith(fetch(req).catch(()=>new Response('Seite nicht verfügbar.',{status:404,headers:{'Content-Type':'text/plain; charset=utf-8'}})));
    return;
  }
  const key=APP_BASE.origin+path;
  event.respondWith((async()=>{
    const cache=await caches.open(CACHE_VERSION);
    if(req.mode==='navigate'){
      try{const response=await fetch(req);if(response.ok)await cache.put(key,response.clone());return response;}
      catch(error){const saved=await cache.match(key);if(saved)return saved;throw error;}
    }
    const saved=await cache.match(key);if(saved)return saved;
    const response=await fetch(req);if(response.ok)await cache.put(key,response.clone());return response;
  })());
});
