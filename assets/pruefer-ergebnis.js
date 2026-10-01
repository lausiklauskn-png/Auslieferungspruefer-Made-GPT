/* Ein Ergebnis für Anzeige und Bericht. Keine Speicherung, kein Netz. */
(function (welt) {
  'use strict';
  function neu(stellen, opt) {
    opt = opt || {};
    return { titel: opt.titel || 'Auslieferungsprüfer GPT', stellen: (stellen || []).slice(),
      teilweise: !!opt.ungeprueft, hinweise: (opt.hinweise || []).slice(), pixel: {}, basis: '', gueltig: true };
  }
  function uebernehmen(ergebnis, name, r, id) {
    if (!ergebnis || !ergebnis.gueltig) return false;
    ergebnis.pixel[id == null ? name : id] = { name: name, geprueft: !!r.geprueft, grund: r.grund || '',
      befunde: (r.befunde || []).slice(), hinweise: (r.hinweise || []).slice() };
    return true;
  }
  function zusammen(ergebnis) {
    var n = ergebnis.stellen.length, teilweise = ergebnis.teilweise;
    Object.keys(ergebnis.pixel).forEach(function (name) {
      var p = ergebnis.pixel[name]; n += p.befunde.length;
      if (!p.geprueft || p.hinweise.some(function (h) { return /ungeprüft/.test(h); })) teilweise = true;
    });
    return { anzahl: n, teilweise: teilweise, status: teilweise ? 'teilweise' : n ? 'hinweis' : 'unauffaellig',
      text: (n ? n + (n === 1 ? ' Befund' : ' Befunde') : 'Kein Befund im Prüfumfang') + (teilweise ? ' · teilweise ungeprüft' : '') };
  }
  function bericht(ergebnis) {
    if (!ergebnis || !ergebnis.gueltig) return '';
    var z = zusammen(ergebnis), aus = [ergebnis.titel + ' — ' + z.text];
    if (ergebnis.basis) aus.push(ergebnis.basis.split('\n').slice(1).join('\n'));
    if (ergebnis.hinweise.length) aus.push('\nPrüfumfang und Hinweise:\n' + ergebnis.hinweise.map(function (h) { return '- ' + h; }).join('\n'));
    Object.keys(ergebnis.pixel).forEach(function (name) {
      var p = ergebnis.pixel[name];
      aus.push('\nBildpunkte · ' + (p.name || name) + ': ' + (!p.geprueft ? 'nicht geprüft' : p.befunde.length ? 'Verdacht' : 'kein Verdacht im genannten Verfahren'));
      if (p.grund) aus.push(p.grund);
      p.befunde.forEach(function (b) { aus.push('[' + b.kennung + '] ' + b.satz); });
      p.hinweise.forEach(function (h) { aus.push('- ' + h); });
    });
    aus.push('\nKeine Virenprüfung. Ein fehlender Befund ist keine umfassende Sicherheitsfreigabe.');
    return aus.join('\n');
  }
  var API = { neu: neu, uebernehmen: uebernehmen, zusammen: zusammen, bericht: bericht };
  welt.GPTPrueferErgebnis = API;
  if (typeof module !== 'undefined' && module.exports) module.exports = API;
})(typeof window !== 'undefined' ? window : globalThis);
