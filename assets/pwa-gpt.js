/* PWA readiness is based on cached files, not merely on an SW registration. */
(function(){
  'use strict';
  var text=document.getElementById('gpt-offline-status');
  function say(de,en){if(text)text.textContent=document.documentElement.lang==='en'?en:de;}
  function status(worker){
    if(!worker)return;
    var channel=new MessageChannel();
    var timer=setTimeout(function(){channel.port1.close();say("Offline-Status noch nicht verfügbar · online neu laden","Offline status unavailable · reload online");},10000);
    channel.port1.onmessage=function(event){
      clearTimeout(timer);
      var r=event.data;channel.port1.close();
      if(r.ready)say('Offline bereit · OCR + PDF geladen','Offline ready · OCR + PDF downloaded');
      else say('Offline-Vorrat unvollständig · online neu laden','Offline resources incomplete · reload online');
    };
    worker.postMessage({type:'OFFLINE_STATUS'},[channel.port2]);
  }
  if(location.protocol==='file:')say('Über GitHub Pages oder lokalen Server öffnen','Open using GitHub Pages or a local server');
  else if(!('serviceWorker' in navigator))say('Dieser Browser unterstützt keinen Offline-Vorrat','This browser does not support offline storage');
  else navigator.serviceWorker.register('sw.js',{scope:'./'}).then(function(reg){
    return navigator.serviceWorker.ready.then(function(){status(reg.active);});
  }).catch(function(){say('Offline-Vorrat konnte nicht eingerichtet werden','Offline resources could not be installed');});
  if('serviceWorker' in navigator)navigator.serviceWorker.addEventListener('controllerchange',function(){status(navigator.serviceWorker.controller);});
  window.addEventListener('pt:sprache',function(){if('serviceWorker' in navigator)status(navigator.serviceWorker.controller);});
  window.addEventListener('online',function(){if('serviceWorker' in navigator)status(navigator.serviceWorker.controller);});
  var picker=document.getElementById('gpt-file-picker'),file=document.getElementById('einzelDatei'),drop=document.getElementById('gpt-file-drop');
  if(picker&&file)picker.addEventListener('click',function(){file.click();});
  if(drop&&file){
    ['dragenter','dragover'].forEach(function(kind){drop.addEventListener(kind,function(e){e.preventDefault();drop.classList.add('pr-drueber');});});
    ['dragleave','drop'].forEach(function(kind){drop.addEventListener(kind,function(){drop.classList.remove('pr-drueber');});});
    drop.addEventListener('drop',function(e){e.preventDefault();if(e.dataTransfer&&e.dataTransfer.files.length){file.files=e.dataTransfer.files;file.dispatchEvent(new Event('change',{bubbles:true}));}});
  }
  // First input is the file checker; a supplied URL keeps the explicit URL input.
  if(!new URLSearchParams(location.search).has('adresse')){
    var first=document.getElementById('reiter-datei');if(first)first.click();
  }
})();
