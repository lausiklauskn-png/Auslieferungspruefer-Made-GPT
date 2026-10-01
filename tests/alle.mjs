/* Fehlender Browser ist kein grünes Gesamtergebnis. */
import {spawnSync} from 'node:child_process';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=dirname(fileURLToPath(import.meta.url)),nodeOnly=process.argv.includes('--node');
let failures=0,unavailable=0;
for(const file of ['smoke_knoten.mjs','smoke_anhang.mjs','smoke_pruefer.mjs','gpt-regression.mjs',...(nodeOnly?[]:['gpt-browser.mjs'])]){
 console.log('\n══ '+file+' ══');
 const r=spawnSync(process.execPath,[join(root,file)],{stdio:'inherit',env:{...process.env,GPT_NODE_ONLY:'1'}});
 if(r.status===2)unavailable++;else if(r.status!==0)failures++;
}
console.log(failures?'\nFEHLGESCHLAGEN: '+failures+' Testsuiten.':unavailable?'\nNICHT VOLLSTÄNDIG GEPRÜFT: Browser fehlt.':'\n'+(nodeOnly?'Node-Testumfang bestanden. Browser/OCR nicht Teil dieses Laufs.':'Node- und Browser-Testumfang bestanden.'));
process.exitCode=failures?1:unavailable?2:0;
