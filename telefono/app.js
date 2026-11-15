// Senjutsu — controller da telefono.
// Parla con Firebase Realtime Database via REST (accesso anonimo), come il gioco.
// Il tavolo pubblica nella stanza "game" = {rq: {posto: richiesta}, st: stato}; il telefono risponde
// scrivendo log/<id> = {d: '{"s": posto, "i": scelta}'}.
"use strict";

const API_KEY = "AIzaSyCf1NQodB-J3OrdU_gHYQ1I6VJtXBk1ciU";
const qs = new URLSearchParams(location.search);
let DB = "https://flammerouge-f8669-default-rtdb.europe-west1.firebasedatabase.app";
let AUTH = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + API_KEY;
let REFRESH = "https://securetoken.googleapis.com/v1/token?key=" + API_KEY;
if (qs.get("frdb")) {           // prove in locale con il finto Firebase
  DB = qs.get("frdb");
  const base = DB.replace(/\/[^/]*$/, "");
  AUTH = base + "/signup"; REFRESH = base + "/refresh";
}
const ROOT = "senjutsu/rooms";
const KAMAE = {};
const NOMI_FASE = { setup: "Preparazione", terreno: "Terreno", piazzamento: "Schieramento", preparazione: "Preparazione",
  pesca: "Pesca", scelta: "Scelta della carta", rivela: "Rivelazione", risolvi: "Risoluzione", scarto: "Scarto", fine: "Fine" };
const COLORI = ["#b3261e", "#27456b"];

let sess = JSON.parse(localStorage.getItem("senjutsu_tel") || "{}");
let codice = (qs.get("c") || sess.codice || "").toUpperCase();
let posto = 0;               // 1 o 2
let cfg = null;              // configurazione della stanza (celle, personaggi)
let carte = null;            // carte.json
let stato = {};              // ultimo "game" letto
let rich = null;             // richiesta aperta per me
let risposte = {};           // id -> true (già inviate)
let selCella = null, selK = 0;
let celleOpz = {};           // "q,r" -> [[face, indice], ...]

const $ = (id) => document.getElementById(id);

// ───────────── accesso e database ─────────────
async function accedi() {
  const ora = Date.now() / 1000;
  if (sess.token && sess.scade > ora + 60) return;
  let r;
  if (sess.refresh) {
    r = await fetch(REFRESH, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: "grant_type=refresh_token&refresh_token=" + encodeURIComponent(sess.refresh) });
    if (r.ok) {
      const d = await r.json();
      sess.token = d.id_token; sess.refresh = d.refresh_token; sess.uid = d.user_id;
      sess.scade = ora + parseInt(d.expires_in || "3600");
      salva(); return;
    }
  }
  r = await fetch(AUTH, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ returnSecureToken: true }) });
  if (!r.ok) throw new Error("accesso non riuscito (" + r.status + ")");
  const d = await r.json();
  sess.token = d.idToken; sess.refresh = d.refreshToken; sess.uid = d.localId;
  sess.scade = ora + parseInt(d.expiresIn || "3600");
  salva();
}
function salva() { localStorage.setItem("senjutsu_tel", JSON.stringify(sess)); }
async function db(metodo, percorso, corpo) {
  await accedi();
  const r = await fetch(DB + "/" + percorso + ".json?auth=" + sess.token, {
    method: metodo, headers: { "Content-Type": "application/json" },
    body: corpo === undefined ? undefined : JSON.stringify(corpo) });
  if (!r.ok) throw new Error("database: " + r.status);
  return r.json();
}

// ───────────── ingresso nella stanza ─────────────
async function entra() {
  const msg = $("msg-entra");
  codice = $("codice").value.trim().toUpperCase();
  const nome = $("nome").value.trim() || "Giocatore";
  if (codice.length !== 4) { msg.textContent = "Il codice ha 4 lettere."; return; }
  msg.textContent = "Entro…";
  try {
    const st = await db("GET", ROOT + "/" + codice);
    if (!st || !st.cfg) { msg.textContent = "Stanza non trovata."; return; }
    cfg = JSON.parse(st.cfg);
    const posti = st.seats || {};
    const np = cfg.np || 2;
    posto = 0;
    for (const k in posti) if (posti[k] && posti[k].uid === sess.uid && k !== "0") posto = parseInt(k);
    if (!posto) {
      const voluto = parseInt(qs.get("g") || "0");
      const liberi = [];
      for (let k = 1; k <= np; k++) if (!posti[k]) liberi.push(k);
      if (!liberi.length) { msg.textContent = "La stanza è piena."; return; }
      posto = liberi.includes(voluto) ? voluto : liberi[0];
      await db("PUT", ROOT + "/" + codice + "/members/" + sess.uid, true);
      await db("PUT", ROOT + "/" + codice + "/seats/" + posto, { uid: sess.uid, name: nome });
    }
    sess.codice = codice; sess.nome = nome; salva();
    if (!carte) carte = await (await fetch("carte.json")).json();
    for (const k in carte.kamae_nomi || {}) KAMAE[k] = carte.kamae_nomi[k];
    $("entra").classList.add("nascosto");
    $("gioco").classList.remove("nascosto");
    disegnaTesta();
    ciclo();
  } catch (e) { msg.textContent = "Errore: " + e.message; }
}

async function ciclo() {
  for (;;) {
    try {
      const g = await db("GET", ROOT + "/" + codice + "/game");
      if (typeof g === "string") {
        const nuovo = JSON.parse(g);
        if (JSON.stringify(nuovo) !== JSON.stringify(stato)) { stato = nuovo; aggiorna(); }
      }
    } catch (e) { /* rete instabile: riprovo */ }
    await new Promise((r) => setTimeout(r, 900));
  }
}

// ───────────── disegno ─────────────
function io() { return (stato.st && stato.st.gi) ? stato.st.gi[posto - 1] : null; }
function cartaInfo(id) {
  if (id === -1) return { name: "Stordimento", img: "status/stordimento.webp" };
  if (id === -2) return { name: "Veleno Debilitante", img: "status/veleno_debilitante.webp" };
  return carte.cards[String(id)] || { name: "?", img: "" };
}
function imgCarta(id) { return "carte/" + cartaInfo(id).img; }

function disegnaTesta() {
  const me = io();
  const pers = cfg && cfg.pers ? carte.characters[cfg.pers[posto - 1]] : null;
  $("chi").innerHTML = (me ? me.n : (pers ? pers.name : "")) + `<small>Giocatore ${posto} · ${sess.nome || ""}</small>`;
  $("chi").style.color = COLORI[posto - 1];
  if (!me) { $("stato").textContent = "In attesa che inizi la partita…"; return; }
  const st = stato.st;
  $("stato").innerHTML = `Turno ${st.tu || 0} — ${NOMI_FASE[st.fa] || st.fa || ""}<br>Ferite ${me.w}/${me.l} · Focus ${me.fo}<br>${me.k} · Mazzo ${me.d} · Scarti ${me.sc}`;
  if (st.over) $("stato").innerHTML += "<br><b>" + (st.win === posto - 1 ? "Hai vinto!" : (st.win < 0 ? "Pareggio" : "Partita finita")) + "</b>";
}

function aggiorna() {
  disegnaTesta();
  const r = stato.rq ? stato.rq[String(posto)] : null;
  const nuova = r && !risposte[r.id] ? r : null;
  if (!nuova || !rich || nuova.id !== rich.id) { selCella = null; selK = 0; }
  rich = nuova;
  disegnaRichiesta();
  disegnaMano();
  disegnaMappa();
}

function disegnaRichiesta() {
  const box = $("richiesta"), op = $("opzioni");
  op.innerHTML = "";
  $("ruota").classList.add("nascosto");
  celleOpz = {};
  if (!rich) {
    box.classList.add("attesa");
    $("testo").textContent = stato.st && stato.st.over ? "Partita conclusa." : "Aspetta il tuo turno: guarda lo schermo.";
    return;
  }
  box.classList.remove("attesa");
  let t = rich.t;
  if (rich.k === "card") {
    const inMano = io() && rich.o.every((id) => io().h.includes(id));
    if (inMano) t += " — tocca una carta della tua mano.";
    else rich.o.forEach((id, i) => {
      const im = document.createElement("img");
      im.src = imgCarta(id); im.alt = cartaInfo(id).name;
      im.onclick = () => zoom(id, [["Scegli questa", () => rispondi(i)]]);
      op.appendChild(im);
    });
  } else if (["move", "place", "hex"].includes(rich.k)) {
    t += " — tocca una casella evidenziata sulla mappa.";
    rich.o.forEach((o, i) => {
      const k = o[0] + "," + o[1];
      (celleOpz[k] = celleOpz[k] || []).push([o[2], i]);
    });
  } else {
    rich.o.forEach((o, i) => {
      const b = document.createElement("button");
      b.textContent = o.l;
      b.onclick = () => rispondi(i);
      op.appendChild(b);
      if (o.c !== undefined && rich.k !== "replace" && rich.k !== "counter") {
        const v = document.createElement("button");
        v.textContent = "Vedi «" + cartaInfo(o.c).name + "»";
        v.onclick = () => zoom(o.c, []);
        op.appendChild(v);
      }
    });
    if (rich.c !== undefined) {
      const v = document.createElement("button");
      v.textContent = "Vedi la carta";
      v.onclick = () => zoom(rich.c, []);
      op.appendChild(v);
    }
  }
  $("testo").textContent = t;
}

function disegnaMano() {
  const m = $("mano"); m.innerHTML = "";
  const me = io();
  if (!me) return;
  const scegli = rich && rich.k === "card";
  const ids = me.h.slice().sort((a, b) => a - b);
  ids.forEach((id) => {
    const d = document.createElement("div");
    d.className = "carta";
    const idx = scegli ? rich.o.indexOf(id) : -1;
    if (scegli) d.classList.add(idx >= 0 ? "scelta" : "spenta");
    const im = document.createElement("img");
    im.src = imgCarta(id); im.alt = cartaInfo(id).name; im.loading = "lazy";
    d.appendChild(im);
    d.onclick = () => zoom(id, idx >= 0 ? [[rich.s ? "Scarta questa" : "Gioca questa", () => rispondi(idx)]] : []);
    m.appendChild(d);
  });
}

function zoom(id, azioni) {
  $("zoom-img").src = imgCarta(id);
  const b = $("zoom-bottoni"); b.innerHTML = "";
  azioni.forEach(([testo, f]) => {
    const x = document.createElement("button"); x.className = "primario"; x.textContent = testo;
    x.onclick = () => { chiudiZoom(); f(); }; b.appendChild(x);
  });
  const c = document.createElement("button"); c.textContent = "Chiudi"; c.onclick = chiudiZoom; b.appendChild(c);
  $("zoom").classList.remove("nascosto");
}
function chiudiZoom() { $("zoom").classList.add("nascosto"); }
$("zoom").addEventListener("click", (e) => { if (e.target.id === "zoom") chiudiZoom(); });

async function rispondi(i) {
  if (!rich) return;
  const r = rich;
  risposte[r.id] = true;
  rich = null;
  disegnaRichiesta(); disegnaMano(); disegnaMappa();
  $("testo").textContent = "Inviato…";
  try { await db("PUT", ROOT + "/" + codice + "/log/" + r.id, { d: JSON.stringify({ s: posto, i: i }) }); }
  catch (e) { delete risposte[r.id]; $("testo").textContent = "Invio non riuscito, riprova."; rich = r; aggiorna(); }
}

// ───────────── mappa ─────────────
const S3 = Math.sqrt(3);
let vista = { s: 30, ox: 0, oy: 0 };
function centro(q, r) { return [1.5 * q * vista.s + vista.ox, S3 * (r + q / 2) * vista.s + vista.oy]; }
function disegnaMappa() {
  const cv = $("mappa");
  const w = cv.clientWidth || 360;
  const celle = cfg ? cfg.celle : [];
  if (!celle.length) return;
  const dpr = window.devicePixelRatio || 1;
  let minx = 1e9, maxx = -1e9, miny = 1e9, maxy = -1e9;
  celle.forEach(([q, r]) => { const x = 1.5 * q, y = S3 * (r + q / 2); minx = Math.min(minx, x); maxx = Math.max(maxx, x); miny = Math.min(miny, y); maxy = Math.max(maxy, y); });
  vista.s = Math.min((w - 10) / (maxx - minx + 2), 26);
  const h = (maxy - miny + S3) * vista.s + 10;
  cv.style.height = h + "px";
  cv.width = w * dpr; cv.height = h * dpr;
  vista.ox = 5 + (w - 10 - (maxx - minx) * vista.s) / 2 - minx * vista.s;
  vista.oy = 5 + S3 / 2 * vista.s - miny * vista.s;
  const c = cv.getContext("2d");
  c.setTransform(dpr, 0, 0, dpr, 0, 0);
  c.clearRect(0, 0, w, h);
  const st = stato.st || {};
  const ter = new Set((st.ter || []).map((x) => x[0] + "," + x[1]));
  const tr = new Set((st.tr || []).map((x) => x[0] + "," + x[1]));
  celle.forEach(([q, r]) => {
    const k = q + "," + r;
    let col = "#4a4038";
    if (ter.has(k)) col = "#16120f";
    if (tr.has(k)) col = "#5c2a66";
    if (celleOpz[k]) col = "#c9a227";
    if (selCella === k) col = "#3c9a4a";
    esagono(c, q, r, col);
  });
  (st.fig || []).forEach(([q, r, f, o, n]) => figura(c, q, r, f, COLORI[o] || "#888", n));
  if (selCella && celleOpz[selCella]) {
    const [q, r] = selCella.split(",").map(Number);
    figura(c, q, r, celleOpz[selCella][selK][0], "#3c9a4a", "?");
  }
}
function esagono(c, q, r, col) {
  const [x, y] = centro(q, r);
  c.beginPath();
  for (let i = 0; i < 6; i++) {
    const a = Math.PI / 3 * i;
    const px = x + Math.cos(a) * vista.s * 0.95, py = y + Math.sin(a) * vista.s * 0.95;
    i ? c.lineTo(px, py) : c.moveTo(px, py);
  }
  c.closePath(); c.fillStyle = col; c.fill();
}
function figura(c, q, r, f, col, n) {
  const [x, y] = centro(q, r);
  c.beginPath(); c.arc(x, y, vista.s * 0.55, 0, Math.PI * 2); c.fillStyle = col; c.fill();
  // freccia del fronte: direzione f (0 = su, poi in senso orario)
  const a = -Math.PI / 2 + f * Math.PI / 3;
  c.beginPath();
  c.moveTo(x + Math.cos(a) * vista.s * 0.95, y + Math.sin(a) * vista.s * 0.95);
  c.lineTo(x + Math.cos(a + 0.5) * vista.s * 0.5, y + Math.sin(a + 0.5) * vista.s * 0.5);
  c.lineTo(x + Math.cos(a - 0.5) * vista.s * 0.5, y + Math.sin(a - 0.5) * vista.s * 0.5);
  c.closePath(); c.fillStyle = "#c9a227"; c.fill();
  c.fillStyle = "#fff"; c.font = "bold " + Math.round(vista.s * 0.6) + "px sans-serif";
  c.textAlign = "center"; c.textBaseline = "middle"; c.fillText(n, x, y + 1);
}
$("mappa").addEventListener("click", (e) => {
  if (!rich || !Object.keys(celleOpz).length) return;
  const rc = e.target.getBoundingClientRect();
  const px = e.clientX - rc.left, py = e.clientY - rc.top;
  // coordinate assiali dalla posizione toccata
  const x = (px - vista.ox) / vista.s, y = (py - vista.oy) / vista.s;
  const qf = 2 / 3 * x, rf = -1 / 3 * x + S3 / 3 * y;
  let q = Math.round(qf), r = Math.round(rf), s = Math.round(-qf - rf);
  const dq = Math.abs(q - qf), dr = Math.abs(r - rf), ds = Math.abs(s + qf + rf);
  if (dq > dr && dq > ds) q = -r - s; else if (dr > ds) r = -q - s;
  const k = q + "," + r;
  if (!celleOpz[k]) return;
  if (rich.k === "hex") { rispondi(celleOpz[k][0][1]); return; }
  selCella = k;
  // orientamenti in ordine di rotazione rispetto a quello attuale della pedina
  const mia = (stato.st.fig || []).find((x) => x[3] === posto - 1);
  const voglio = rich.k === "place" ? 3 : (mia ? mia[2] : 0);
  const rel = (f) => ((f - voglio + 9) % 6) - 3;
  celleOpz[k].sort((a, b) => rel(a[0]) - rel(b[0]));
  selK = 0; let meglio = 99;
  celleOpz[k].forEach((o, i) => { const d = Math.abs(rel(o[0])); if (d < meglio) { meglio = d; selK = i; } });
  mostraRuota();
});
function mostraRuota() {
  const l = celleOpz[selCella];
  $("ruota").classList.remove("nascosto");
  $("b-sx").disabled = selK === 0 || l.length < 2;
  $("b-dx").disabled = selK === l.length - 1 || l.length < 2;
  disegnaMappa();
}
$("b-sx").onclick = () => { selK = Math.max(0, selK - 1); mostraRuota(); };
$("b-dx").onclick = () => { selK = Math.min(celleOpz[selCella].length - 1, selK + 1); mostraRuota(); };
$("b-ok").onclick = () => { if (selCella) rispondi(celleOpz[selCella][selK][1]); };
window.addEventListener("resize", disegnaMappa);

// ───────────── avvio ─────────────
$("codice").value = codice;
$("nome").value = sess.nome || "";
$("b-entra").onclick = entra;
if (codice && sess.codice === codice && sess.uid) entra();
