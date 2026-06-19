// Controller telefono — Senjutsu.
// Si collega al relay WebSocket, entra in una stanza su un seat, riceve i prompt del
// motore (via tavolo) e invia le risposte. Mostra le carte con la loro ARTE reale,
// layout touch, e si RICONNETTE da solo (riprendendo dal prompt in corso).

const $ = (id) => document.getElementById(id);
const qs = new URLSearchParams(location.search);
const LS = window.localStorage;

let ws = null, seat = -1, lastPrompt = null;
let IMG_BASE = "";
let intentional = false, attempts = 0, reconnectTimer = null;

// Default sensati: se la pagina è servita dal relay, stessa origine; altrimenti :8080.
const sameOrigin = location.protocol.startsWith("http");
const defServer = sameOrigin
  ? `ws${location.protocol === "https:" ? "s" : ""}://${location.host}`
  : `ws://${location.hostname || "127.0.0.1"}:8080`;

$("server").value = qs.get("server") || LS.getItem("senjutsu.server") || defServer;
$("code").value = (qs.get("code") || LS.getItem("senjutsu.code") || "").toUpperCase();

document.querySelectorAll(".seat").forEach((b) =>
  b.addEventListener("click", () => startConnect(Number(b.dataset.seat))));
$("leave").addEventListener("click", leave);

// Riprende automaticamente una sessione salvata (es. refresh pagina o schermo bloccato).
const savedSeat = LS.getItem("senjutsu.seat");
if (savedSeat !== null && $("code").value) startConnect(Number(savedSeat));

function setStatus(t) { $("status").textContent = t; }
function setNet(t) { $("net").textContent = t; }

function imgBaseFromWs(wsUrl) {
  try {
    const u = new URL(wsUrl);
    const proto = u.protocol === "wss:" ? "https:" : "http:";
    return `${proto}//${u.host}/cards/`;
  } catch { return ""; }
}

function startConnect(s) {
  const code = $("code").value.trim().toUpperCase();
  if (!code) { setStatus("Inserisci il codice stanza."); return; }
  seat = s;
  intentional = false;
  attempts = 0;
  LS.setItem("senjutsu.server", $("server").value.trim());
  LS.setItem("senjutsu.code", code);
  LS.setItem("senjutsu.seat", String(s));
  connect();
}

function connect() {
  const url = $("server").value.trim();
  const code = $("code").value.trim().toUpperCase();
  IMG_BASE = imgBaseFromWs(url);
  setStatus("Connessione…");
  setNet("Connessione…");
  try { ws = new WebSocket(url); } catch { scheduleReconnect(); return; }
  ws.onopen = () => { attempts = 0; setNet(""); ws.send(JSON.stringify({ t: "join", code, seat })); };
  ws.onerror = () => setStatus("Errore di connessione.");
  ws.onclose = () => { if (!intentional) scheduleReconnect(); };
  ws.onmessage = (ev) => onMessage(JSON.parse(ev.data));
}

function scheduleReconnect() {
  if (intentional) return;
  attempts++;
  const delay = Math.min(1000 * attempts, 5000);
  setNet(`Connessione persa — riprovo… (${attempts})`);
  clearTimeout(reconnectTimer);
  reconnectTimer = setTimeout(connect, delay);
}

function leave() {
  intentional = true;
  clearTimeout(reconnectTimer);
  if (ws) ws.close();
  LS.removeItem("senjutsu.seat");
  $("game").classList.add("hidden");
  $("connect").classList.remove("hidden");
  setStatus("Uscito dalla stanza.");
}

function onMessage(m) {
  switch (m.t) {
    case "joined":
      $("connect").classList.add("hidden");
      $("game").classList.remove("hidden");
      $("who").textContent = `Giocatore ${seat + 1}`;
      setNet("");
      // Se il tavolo non ha (ancora) un prompt per noi, restiamo in attesa;
      // alla riconnessione l'host rimanda da solo il prompt corrente.
      if (!lastPrompt) waiting("In attesa del tuo turno…");
      break;
    case "error":
      setStatus(m.error === "seat_taken" ? "Posto già occupato." : "Errore: " + m.error);
      break;
    case "from_host":
      onPayload(m.payload);
      break;
  }
}

function respond(kind, data) {
  ws.send(JSON.stringify({ t: "to_host", payload: { t: "respond", kind, data } }));
  waiting("Inviato. Attendi…");
}

function onPayload(p) {
  if (!p) return;
  if (p.t === "event") { onEvent(p.kind, p.data); return; }
  if (p.t === "finished") { lastPrompt = null; render("Duello terminato", finishedView(p.winner)); return; }
  if (p.t !== "prompt") return;
  lastPrompt = p;
  switch (p.kind) {
    case "plan": renderPlan(p.data); break;
    case "instant_replace": renderPick("Sostituire la carta rivelata?", p.kind, p.data.options); break;
    case "instant_play": renderPick("Giocare un'istantanea aggiuntiva?", p.kind, p.data.options); break;
    case "resolve": renderResolve(p.data); break;
  }
}

function onEvent(kind, data) {
  if (kind === "turn") $("pubstatus").textContent = "Nuovo turno";
  else if (kind === "combat") $("pubstatus").textContent = "⚔ " + combatLabel(data.kind);
  else if (kind === "revealed") $("pubstatus").textContent = "Carte rivelate";
  else if (kind === "turn_of") $("pubstatus").textContent = data.seat === seat ? "Tocca a te" : "Avversario…";
}

// ---- Viste ----
function el(tag, cls, txt) { const e = document.createElement(tag); if (cls) e.className = cls; if (txt != null) e.textContent = txt; return e; }
function render(title, node) { $("title").textContent = title; const host = $("prompt"); host.innerHTML = ""; host.appendChild(node); }
function waiting(t) { $("title").textContent = "Attendi"; const h = $("prompt"); h.innerHTML = ""; h.appendChild(el("div", "waiting", t)); }
function group(title) { const g = el("div", "group"); if (title) g.appendChild(el("h3", null, title)); const r = el("div", "row"); g.appendChild(r); g._row = r; return g; }

// Bottone-carta con arte reale (fallback a testo se manca/errore immagine).
function cardButton(c, onClick, disabled) {
  const b = el("button", "card");
  if (c.file && IMG_BASE) {
    b.classList.add("hasimg");
    const img = new Image();
    img.className = "art";
    img.alt = c.name || "";
    img.src = IMG_BASE + c.file;
    img.onerror = () => { b.classList.remove("hasimg"); img.remove(); };
    b.appendChild(img);
  }
  const cap = el("div", "cap");
  cap.appendChild(el("div", "nm", c.name || "?"));
  cap.appendChild(el("div", "meta", `${typeLabel(c.type)}${c.focus ? " · ◈" + c.focus : ""}`));
  b.appendChild(cap);
  if (disabled) b.disabled = true;
  b.onclick = onClick;
  return b;
}

function renderPlan(d) {
  const wrap = el("div");
  $("pubstatus").textContent = `Focus ◈${d.focus}`;
  const g = group("La tua mano — scegli una carta");
  g._row.classList.add("cards");
  for (const c of d.hand)
    g._row.appendChild(cardButton(c, () => respond("plan", { card: c.id }), !c.playable));
  wrap.appendChild(g);
  render("Programmazione", wrap);
}

function renderPick(title, kind, options) {
  const wrap = el("div");
  const g = group(null);
  g._row.classList.add("cards");
  for (const o of options)
    g._row.appendChild(cardButton(o, () => respond(kind, { pick: o.id })));
  wrap.appendChild(g);
  const skip = el("button", "primary wide", "Tieni / Salta");
  skip.onclick = () => respond(kind, { pick: -1 });
  wrap.appendChild(skip);
  render(title, wrap);
}

function renderResolve(d) {
  const wrap = el("div");
  $("pubstatus").textContent = d.foe ? `Tu ${d.cell} · avv. ${d.foe}` : "";
  const cells = Object.keys(d.legalCells || {});
  if (!d.move_used && cells.length) {
    const g = group("Muovi");
    for (const key of cells) {
      const b = el("button", "hex", hexLabel(key));
      b.onclick = () => respond("resolve", { action: "move", cell: key });
      g._row.appendChild(b);
    }
    wrap.appendChild(g);
  }
  if ((d.legalFacings || []).length) {
    const g = group("Ruota");
    for (const f of d.legalFacings) {
      const b = el("button", "hex", facingLabel(f));
      b.onclick = () => respond("resolve", { action: "rotate", facing: f });
      g._row.appendChild(b);
    }
    wrap.appendChild(g);
  }
  const kamae = d.kamae || {};
  if (Object.keys(kamae).length) {
    const g = group("Cambia Kamae");
    for (const slug of Object.keys(kamae)) {
      const gain = kamae[slug];
      const b = el("button", "hex", `${kamaeLabel(slug)}${gain > 0 ? " +◈" + gain : ""}`);
      b.onclick = () => respond("resolve", { action: "kamae", slug });
      g._row.appendChild(b);
    }
    wrap.appendChild(g);
  }
  if ((d.options || []).length) {
    const g = group("Scelta (OPPURE)");
    for (const o of d.options) {
      const b = el("button", "hex", String(o.alt));
      b.onclick = () => respond("resolve", { action: "option", alt: o.alt });
      g._row.appendChild(b);
    }
    wrap.appendChild(g);
  }
  const conf = el("button", "primary wide", "Conferma ▶");
  conf.onclick = () => respond("resolve", { action: "confirm" });
  wrap.appendChild(conf);
  render(`Risoluzione: ${d.card}`, wrap);
}

function finishedView(winner) {
  const me = winner === seat;
  return el("div", "waiting", winner < 0 ? "Pareggio" : (me ? "Hai vinto! 🏯" : "Hai perso."));
}

// ---- Etichette ----
function typeLabel(t) { return ({ attack: "Attacco", defence: "Difesa", meditation: "Meditazione", core: "Base", status: "Stato" })[t] || t || "—"; }
function kamaeLabel(s) { return ({ aggression: "Aggressività", balance: "Equilibrio", determination: "Determinazione", neutral: "Neutra" })[s] || s; }
function facingLabel(f) { return ["fronte", "fronte-dx", "dietro-dx", "dietro", "dietro-sx", "fronte-sx"][((f % 6) + 6) % 6] || ("dir " + f); }
function combatLabel(k) { return ({ hit: "colpo a segno", blocked: "parato", counter: "contrattacco", collision: "urto" })[k] || (k || ""); }
function hexLabel(key) { return key; }
