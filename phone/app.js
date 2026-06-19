// Controller telefono — Senjutsu (Tappa 3).
// Si collega al relay WebSocket, entra in una stanza su un seat, riceve i prompt del
// motore (via tavolo) e invia le risposte. Stessi messaggi di MatchClient (GDScript).

const $ = (id) => document.getElementById(id);
const qs = new URLSearchParams(location.search);

let ws = null, seat = -1, lastPrompt = null;

// Precompila i campi da URL (?server=&code=&seat=) o da default sensati.
$("server").value = qs.get("server") || `ws://${location.hostname || "127.0.0.1"}:8123`;
$("code").value = (qs.get("code") || "").toUpperCase();

document.querySelectorAll(".seat").forEach((b) =>
  b.addEventListener("click", () => connect(Number(b.dataset.seat))));

function setStatus(t) { $("status").textContent = t; }

function connect(s) {
  seat = s;
  const url = $("server").value.trim();
  const code = $("code").value.trim().toUpperCase();
  if (!code) { setStatus("Inserisci il codice stanza."); return; }
  setStatus("Connessione…");
  ws = new WebSocket(url);
  ws.onopen = () => ws.send(JSON.stringify({ t: "join", code, seat }));
  ws.onerror = () => setStatus("Errore di connessione.");
  ws.onclose = () => setStatus("Connessione chiusa.");
  ws.onmessage = (ev) => onMessage(JSON.parse(ev.data));
}

function onMessage(m) {
  switch (m.t) {
    case "joined":
      $("connect").classList.add("hidden");
      $("game").classList.remove("hidden");
      $("who").textContent = `Giocatore ${seat + 1}`;
      waiting("In attesa dell'avversario / del tuo turno…");
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
  if (p.t === "finished") { render("Duello terminato", finishedView(p.winner)); return; }
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
  else if (kind === "combat") $("pubstatus").textContent = "⚔ " + (data.kind || "");
  else if (kind === "revealed") $("pubstatus").textContent = "Carte rivelate";
}

// ---- Viste ----
function el(tag, cls, txt) { const e = document.createElement(tag); if (cls) e.className = cls; if (txt != null) e.textContent = txt; return e; }
function render(title, node) { $("title").textContent = title; const host = $("prompt"); host.innerHTML = ""; host.appendChild(node); }
function waiting(t) { $("title").textContent = "Attendi"; const h = $("prompt"); h.innerHTML = ""; h.appendChild(el("div", "waiting", t)); }
function group(title) { const g = el("div", "group"); if (title) g.appendChild(el("h3", null, title)); const r = el("div", "row"); g.appendChild(r); g._row = r; return g; }

function renderPlan(d) {
  const wrap = el("div");
  $("pubstatus").textContent = `Focus ◈${d.focus}`;
  const g = group("La tua mano — scegli una carta");
  for (const c of d.hand) {
    const b = el("button", "card");
    b.appendChild(el("div", "nm", c.name));
    b.appendChild(el("div", "meta", `${typeLabel(c.type)} · ◈${c.focus}`));
    b.disabled = !c.playable;
    b.onclick = () => respond("plan", { card: c.id });
    g._row.appendChild(b);
  }
  wrap.appendChild(g);
  render("Programmazione", wrap);
}

function renderPick(title, kind, options) {
  const wrap = el("div");
  const g = group(null);
  for (const o of options) {
    const b = el("button", "card");
    b.appendChild(el("div", "nm", o.name));
    b.appendChild(el("div", "meta", `${typeLabel(o.type)} · ◈${o.focus}`));
    b.onclick = () => respond(kind, { pick: o.id });
    g._row.appendChild(b);
  }
  const skip = el("button", "primary", "Tieni / Salta");
  skip.onclick = () => respond(kind, { pick: -1 });
  g._row.appendChild(skip);
  wrap.appendChild(g);
  render(title, wrap);
}

function renderResolve(d) {
  const wrap = el("div");
  const cells = Object.keys(d.legalCells || {});
  if (!d.move_used && cells.length) {
    const g = group("Muovi");
    for (const key of cells) {
      const b = el("button", null, hexLabel(key));
      b.onclick = () => respond("resolve", { action: "move", cell: key });
      g._row.appendChild(b);
    }
    wrap.appendChild(g);
  }
  if ((d.legalFacings || []).length) {
    const g = group("Ruota");
    for (const f of d.legalFacings) {
      const b = el("button", null, facingLabel(f));
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
      const b = el("button", null, `${kamaeLabel(slug)}${gain > 0 ? " +◈" + gain : ""}`);
      b.onclick = () => respond("resolve", { action: "kamae", slug });
      g._row.appendChild(b);
    }
    wrap.appendChild(g);
  }
  if ((d.options || []).length) {
    const g = group("Scelta (OPPURE)");
    for (const o of d.options) {
      const b = el("button", null, String(o.alt));
      b.onclick = () => respond("resolve", { action: "option", alt: o.alt });
      g._row.appendChild(b);
    }
    wrap.appendChild(g);
  }
  const conf = el("button", "primary", "Conferma ▶");
  conf.onclick = () => respond("resolve", { action: "confirm" });
  wrap.appendChild(conf);
  render(`Risoluzione: ${d.card}`, wrap);
}

function finishedView(winner) {
  const me = winner === seat;
  return el("div", "waiting", winner < 0 ? "Pareggio" : (me ? "Hai vinto! 🏯" : "Hai perso."));
}

// ---- Etichette ----
function typeLabel(t) { return ({ attack: "Attacco", defence: "Difesa", meditation: "Meditazione", core: "Base" })[t] || t || "—"; }
function kamaeLabel(s) { return ({ aggression: "Aggressività", balance: "Equilibrio", determination: "Determinazione", neutral: "Neutra" })[s] || s; }
function facingLabel(f) { return ["fronte", "fronte-dx", "dietro-dx", "dietro", "dietro-sx", "fronte-sx"][((f % 6) + 6) % 6] || ("dir " + f); }
function hexLabel(key) { return key; }
