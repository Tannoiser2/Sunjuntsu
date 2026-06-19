// Controller telefono — Senjutsu. Orizzontale, barra di stato, mano scorrevole e
// MAPPA 2D toccabile per muovere/ruotare/attaccare. Stessi messaggi del protocollo.

const $ = (id) => document.getElementById(id);
const qs = new URLSearchParams(location.search);
const LS = window.localStorage;
const SVGNS = "http://www.w3.org/2000/svg";

let ws = null, seat = -1, lastPrompt = null, board = null, activeSeat = -1;
let IMG_BASE = "", MAP_BASE = "", PORTRAIT_BASE = "";
let _prevMine = null, _ccTimer = null, _ccAuto = false;
let intentional = false, attempts = 0, reconnectTimer = null;

// ── Connessione ──────────────────────────────────────────────────────────────
const sameOrigin = location.protocol.startsWith("http");
const defServer = sameOrigin
  ? `ws${location.protocol === "https:" ? "s" : ""}://${location.host}`
  : `ws://${location.hostname || "127.0.0.1"}:8080`;
$("server").value = qs.get("server") || LS.getItem("senjutsu.server") || defServer;
$("code").value = (qs.get("code") || LS.getItem("senjutsu.code") || "").toUpperCase();

document.querySelectorAll(".seat").forEach((b) =>
  b.addEventListener("click", () => startConnect(Number(b.dataset.seat))));
$("leave").addEventListener("click", leave);
$("charcard").addEventListener("click", (e) => { if (e.target.id === "charcard" || e.target.className === "cc-close primary") closeCharCard(); });
$("kamaecard").addEventListener("click", (e) => { if (e.target.id === "kamaecard" || e.target.className === "cc-close primary") closeKamae(); });

const savedSeat = LS.getItem("senjutsu.seat");
if (savedSeat !== null && $("code").value) startConnect(Number(savedSeat));

function setStatus(t) { $("status").textContent = t; }
function setNet(t) { $("net").textContent = t || ""; }
function news(t) { $("news").textContent = t || ""; }

function imgBaseFromWs(wsUrl) {
  try { const u = new URL(wsUrl); return `${u.protocol === "wss:" ? "https:" : "http:"}//${u.host}/cards/`; }
  catch { return ""; }
}

function startConnect(s) {
  const code = $("code").value.trim().toUpperCase();
  if (!code) { setStatus("Inserisci il codice stanza."); return; }
  // Schermo intero (richiede un gesto utente: il tocco sul posto va bene).
  try { (document.documentElement.requestFullscreen || (() => {})).call(document.documentElement); } catch (e) {}
  seat = s; intentional = false; attempts = 0;
  LS.setItem("senjutsu.server", $("server").value.trim());
  LS.setItem("senjutsu.code", code);
  LS.setItem("senjutsu.seat", String(s));
  connect();
}

function connect() {
  const url = $("server").value.trim();
  const code = $("code").value.trim().toUpperCase();
  IMG_BASE = imgBaseFromWs(url);
  MAP_BASE = IMG_BASE.replace("/cards/", "/maps/");
  PORTRAIT_BASE = IMG_BASE.replace("/cards/", "/portraits/");
  setStatus("Connessione…"); setNet("Connessione…");
  try { ws = new WebSocket(url); } catch { scheduleReconnect(); return; }
  ws.onopen = () => { attempts = 0; setNet(""); ws.send(JSON.stringify({ t: "join", code, seat })); };
  ws.onerror = () => setStatus("Errore di connessione.");
  ws.onclose = () => { if (!intentional) scheduleReconnect(); };
  ws.onmessage = (ev) => onMessage(JSON.parse(ev.data));
}

function scheduleReconnect() {
  if (intentional) return;
  attempts++;
  setNet(`Connessione persa — riprovo… (${attempts})`);
  clearTimeout(reconnectTimer);
  reconnectTimer = setTimeout(connect, Math.min(1000 * attempts, 5000));
}

function leave() {
  intentional = true; clearTimeout(reconnectTimer);
  if (ws) ws.close();
  LS.removeItem("senjutsu.seat");
  $("game").classList.add("hidden"); $("connect").classList.remove("hidden");
  setStatus("Uscito dalla stanza.");
}

function onMessage(m) {
  switch (m.t) {
    case "joined":
      $("connect").classList.add("hidden"); $("game").classList.remove("hidden");
      setNet("");
      if (!lastPrompt) waiting("In attesa del tuo turno…");
      updateHud();
      break;
    case "error":
      setStatus(m.error === "seat_taken" ? "Posto già occupato." : "Errore: " + m.error);
      break;
    case "from_host": onPayload(m.payload); break;
  }
}

function respond(kind, data) {
  ws.send(JSON.stringify({ t: "to_host", payload: { t: "respond", kind, data } }));
  activeSeat = -1; updateFighters();
  waiting("Inviato. Attendi…");
}

function onPayload(p) {
  if (!p) return;
  if (p.t === "event") { onEvent(p.kind, p.data); return; }
  if (p.t === "finished") { lastPrompt = null; finished(p.winner); return; }
  if (p.t !== "prompt") return;
  lastPrompt = p;
  activeSeat = seat; updateFighters();   // ho un'azione da fare → evidenzia il mio ritratto
  if (_ccAuto) closeCharCard();          // se la scheda era apparsa da sola, chiudila: devo agire
  switch (p.kind) {
    case "plan": renderPlan(p.data); break;
    case "instant_replace": renderPick("Sostituire la carta rivelata?", p.kind, p.data.options); break;
    case "instant_play": renderPick("Giocare un'istantanea aggiuntiva?", p.kind, p.data.options); break;
    case "resolve": renderResolve(p.data); break;
  }
}

function onEvent(kind, data) {
  if (kind === "board") { board = data; updateHud(); return; }
  if (kind === "turn_of") { activeSeat = data.seat; updateFighters(); news(data.seat === seat ? "▶ Tocca a te" : "Avversario…"); }
  else if (kind === "combat") news("⚔ " + combatLabel(data.kind));
  else if (kind === "revealed") news("Carte rivelate");
  else if (kind === "turn") { activeSeat = -1; updateFighters(); news("Nuovo turno"); }
}

// ── Barra di stato ───────────────────────────────────────────────────────────
function updateHud() {
  if (!board || !board.fighters || board.fighters.length <= seat) return;
  const me = board.fighters[seat];
  $("who").textContent = `G${seat + 1} · ${me.name}`;
  const k = $("kamae");
  k.className = "chip " + (me.kamae || "neutral");
  k.textContent = kamaeLabel(me.kamae);
  $("wounds").textContent = `❤ ${me.wounds}/${me.limit}`
    + (me.bleed ? ` 🩸${me.bleed}` : "") + (me.poison ? ` ☠${me.poison}` : "")
    + (me.stun ? `  ✦${me.stun}` : "");
  $("focus").textContent = "◈".repeat(me.focus) + "◇".repeat(Math.max(0, 3 - me.focus));
  $("round").textContent = `Round ${board.round}`;
  updateFighters();
  maybeFlashCharCard(me);
}

// Scheda personaggio "a comparsa": si apre da sola quando subisci ferite/veleno o
// cambia il focus, poi si richiude da sola. Non disturba mentre devi agire tu.
function maybeFlashCharCard(me) {
  const cur = { wounds: me.wounds || 0, bleed: me.bleed || 0, poison: me.poison || 0, focus: me.focus || 0 };
  if (!_prevMine) { _prevMine = cur; return; }
  const p = _prevMine; _prevMine = cur;
  const worse = cur.wounds > p.wounds || cur.bleed > p.bleed || cur.poison > p.poison;
  const focusChanged = cur.focus !== p.focus;
  if (activeSeat === seat) return;            // sto per agire: non coprire mappa/bottoni
  if (worse || focusChanged) { openCharCard(seat); _ccAuto = true; clearTimeout(_ccTimer); _ccTimer = setTimeout(closeCharCard, 2600); }
}

// ── Ritratti dei contendenti (cerchi ai lati: io a sinistra, avversario a destra) ──
function portraitFile(name) { return ({ Ronin: "ronin.png", Warrior: "guerriero.png" })[name] || ""; }

function updateFighters() {
  if (!board || !board.fighters) return;
  const other = board.fighters.length > 1 ? (seat === 0 ? 1 : 0) : -1;
  setFighter($("fLeft"), seat, "me");
  setFighter($("fRight"), other, "foe");
}

function setFighter(fig, idx, role) {
  if (!fig) return;
  if (idx < 0 || !board.fighters[idx]) { fig.classList.add("hidden"); return; }
  const f = board.fighters[idx];
  fig.className = "fighter " + (role === "me" ? "left me" : "right foe") + (idx === activeSeat ? " active" : "");
  fig.onclick = () => openCharCard(idx);
  const pic = fig.querySelector(".pic");
  const file = portraitFile(f.name);
  if (file && PORTRAIT_BASE) {
    const url = PORTRAIT_BASE + file;
    if (pic.getAttribute("src") !== url) { pic.src = url; pic.onerror = () => { pic.style.visibility = "hidden"; }; }
    pic.style.visibility = "";
  } else { pic.style.visibility = "hidden"; }
  fig.querySelector(".nm").textContent = f.name || "";
}

// ── Scheda personaggio (carta reale + ferite/sanguinanti/veleno/focus) ──
function charFile(name) { return ({ Ronin: "ronin/ronin_char.webp", Warrior: "warrior/warrior_char.webp" })[name] || ""; }

function openCharCard(idx) {
  if (!board || !board.fighters || !board.fighters[idx]) return;
  const f = board.fighters[idx];
  const card = $("charcard"); card.classList.remove("hidden");
  const img = card.querySelector(".cc-img");
  const file = charFile(f.name);
  if (file && IMG_BASE) { img.src = IMG_BASE + file; img.style.display = ""; img.onerror = () => { img.style.display = "none"; }; }
  else img.style.display = "none";
  card.querySelector(".cc-name").textContent = `G${idx + 1} · ${f.name}`;
  const total = f.wounds || 0, bleed = f.bleed || 0, limit = f.limit || 0;
  const normal = Math.max(0, total - bleed), free = Math.max(0, limit - total);
  let wh = "Ferite: " + "❤".repeat(normal) + "🩸".repeat(bleed) + "♡".repeat(free);
  if (f.poison) wh += "  ☠×" + f.poison;
  if (f.stun) wh += "  ✦" + f.stun;
  card.querySelector(".cc-wounds").textContent = wh;
  card.querySelector(".cc-focus").textContent = "Focus: " + "◈".repeat(f.focus) + "◇".repeat(Math.max(0, 3 - f.focus));
}

function closeCharCard() { clearTimeout(_ccTimer); _ccAuto = false; $("charcard").classList.add("hidden"); }

// ── Carta Kamae interattiva: immagine + nodi raggiungibili toccabili ──
function openKamae(ui) {
  if (!ui || !ui.card || !IMG_BASE) return;
  const m = $("kamaecard"); m.classList.remove("hidden");
  const img = m.querySelector(".km-img");
  img.src = IMG_BASE + ui.card; img.style.display = "";
  img.onerror = () => { img.style.display = "none"; };
  const layer = m.querySelector(".km-nodes"); layer.innerHTML = "";
  const nodes = ui.nodes || {}, reach = ui.reach || {}, at = ui.at;
  for (const slug in nodes) {
    const isAt = slug === at;
    const reachable = Object.prototype.hasOwnProperty.call(reach, slug) && !isAt;
    if (!reachable && !isAt) continue;   // mostra solo posizione attuale e nodi raggiungibili
    const pos = nodes[slug];
    const n = el("button", "km-node" + (reachable ? " reach" : "") + (isAt ? " at" : ""));
    n.style.left = (pos[0] * 100) + "%"; n.style.top = (pos[1] * 100) + "%";
    const gain = reach[slug] || 0;
    n.textContent = kamaeLabel(slug) + (reachable && gain > 0 ? " +◈" + gain : "") + (isAt ? " ●" : "");
    if (reachable) n.onclick = () => { respond("resolve", { action: "kamae", slug }); closeKamae(); };
    else n.disabled = true;
    layer.appendChild(n);
  }
}

function closeKamae() { $("kamaecard").classList.add("hidden"); }

// ── Helpers DOM/SVG ──────────────────────────────────────────────────────────
function el(tag, cls, txt) { const e = document.createElement(tag); if (cls) e.className = cls; if (txt != null) e.textContent = txt; return e; }
function svg(tag, attrs, kids) { const e = document.createElementNS(SVGNS, tag); for (const k in (attrs || {})) e.setAttribute(k, attrs[k]); (kids || []).forEach((c) => e.appendChild(c)); return e; }
function setContent(node) { const c = $("content"); c.innerHTML = ""; c.appendChild(node); }
function waiting(t) { setContent(el("div", "waiting", t)); }
function finished(w) { news(""); setContent(el("div", "finish", w < 0 ? "Pareggio" : (w === seat ? "Hai vinto! 🏯" : "Hai perso."))); }

// Carta con arte reale (fallback a testo).
function cardEl(c, onClick, disabled, large) {
  const b = el("button", "card" + (large ? " lg" : ""));
  let over = false;
  if (c.file && IMG_BASE) {
    over = true;
    const img = new Image();
    img.className = "art"; img.alt = c.name || "";
    img.src = IMG_BASE + c.file;
    img.onerror = () => { over = false; b.classList.remove("withimg"); cap.classList.remove("over"); img.remove(); };
    b.appendChild(img);
  }
  const cap = el("div", "cap" + (over ? " over" : ""));
  cap.appendChild(el("div", "nm", c.name || "?"));
  cap.appendChild(el("div", "meta", `${typeLabel(c.type)}${c.focus ? " · ◈" + c.focus : ""}`));
  b.appendChild(cap);
  if (disabled) b.disabled = true;
  b.onclick = onClick;
  return b;
}

// ── Vista: programmazione ────────────────────────────────────────────────────
function renderPlan(d) {
  news("Scegli una carta da programmare");
  const strip = el("div", "cards-strip");
  for (const c of d.hand) strip.appendChild(cardEl(c, () => respond("plan", { card: c.id }), !c.playable, true));
  setContent(strip);
}

function renderPick(title, kind, options) {
  news(title);
  const wrap = el("div", "pick-wrap");
  const strip = el("div", "cards-strip");
  for (const o of options) strip.appendChild(cardEl(o, () => respond(kind, { pick: o.id }), false, true));
  wrap.appendChild(strip);
  const foot = el("div", "foot");
  const skip = el("button", "primary", "Tieni / Salta");
  skip.onclick = () => respond(kind, { pick: -1 });
  foot.appendChild(skip);
  wrap.appendChild(foot);
  setContent(wrap);
}

// ── Vista: risoluzione (MAPPA toccabile) ─────────────────────────────────────
const DIRS = [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]];
const S = 22;
function ax(q, r) { return { x: S * 1.5 * q, y: S * Math.sqrt(3) * (r + q / 2) }; }
function hexPts(cx, cy) { let p = []; for (let i = 0; i < 6; i++) { const a = Math.PI / 3 * i; p.push(`${(cx + S * Math.cos(a)).toFixed(1)},${(cy + S * Math.sin(a)).toFixed(1)}`); } return p.join(" "); }
function inRange(R) { const o = []; for (let q = -R; q <= R; q++) for (let r = Math.max(-R, -q - R); r <= Math.min(R, -q + R); r++) o.push([q, r]); return o; }
function pk(q, r) { return `${q},${r}`; }
function parseKey(s) { const a = s.split(","); return [parseInt(a[0]), parseInt(a[1])]; }

let _curCard = null, _rotDone = false;

function renderResolve(d) {
  news(`Risoluzione: ${d.card}`);
  // Nuova carta in risoluzione → riparti dal passo movimento.
  if (d.card !== _curCard) { _curCard = d.card; _rotDone = false; }
  const R = d.radius || 3;
  const legal = (!d.move_used && d.legalCells) ? d.legalCells : {};
  const targets = new Set(d.targets || []);
  const facings = d.legalFacings || [];
  const [mq, mr] = parseKey(d.cell);
  const foe = d.foe ? parseKey(d.foe) : null;
  // Passi SEPARATI: 1) Movimento  2) Rotazione  3) Azione/Attacco.
  // La rotazione è limitata ai facing legali della carta: se l'unico facing
  // disponibile è quello attuale, niente passo rotazione.
  const canRotate = facings.some((f) => f !== d.facing);
  const moveStep = Object.keys(legal).length > 0;
  const rotStep = !moveStep && !_rotDone && canRotate;
  const attackStep = !moveStep && !rotStep;

  // Mappa (viewBox dall'estensione esagoni).
  let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
  const cells = inRange(R).map(([q, r]) => { const p = ax(q, r); minX = Math.min(minX, p.x); minY = Math.min(minY, p.y); maxX = Math.max(maxX, p.x); maxY = Math.max(maxY, p.y); return { q, r, p }; });
  const pad = S * 2;
  const bx = minX - pad, by = minY - pad, bw = (maxX - minX) + 2 * pad, bh = (maxY - minY) + 2 * pad;
  const root = svg("svg", { class: "map", viewBox: `${bx} ${by} ${bw} ${bh}`, preserveAspectRatio: "xMidYMid meet" });
  if (MAP_BASE) {
    const bg = svg("image", { x: bx, y: by, width: bw, height: bh, opacity: "0.92", preserveAspectRatio: "xMidYMid slice" });
    bg.setAttribute("href", MAP_BASE + "arena.webp");
    root.appendChild(bg);
  }
  // Tessere: gialle (movimento) solo nel passo 1; rosse (bersaglio) solo nel passo 3.
  for (const { q, r, p } of cells) {
    let cls = "hex";
    const key = pk(q, r);
    const isMove = moveStep && legal.hasOwnProperty(key);
    const isTarget = attackStep && targets.has(key);
    if (isMove) cls += " move"; else if (isTarget) cls += " target";
    const poly = svg("polygon", { class: cls, points: hexPts(p.x, p.y) });
    if (isMove) poly.addEventListener("click", () => respond("resolve", { action: "move", cell: key }));
    else if (isTarget) poly.addEventListener("click", () => respond("resolve", { action: "confirm" }));
    root.appendChild(poly);
  }
  if (foe) { const fp = ax(foe[0], foe[1]); root.appendChild(svg("circle", { class: "pawn-foe", cx: fp.x, cy: fp.y, r: S * 0.5 })); }
  const mp = ax(mq, mr);
  root.appendChild(svg("circle", { class: "pawn-me", cx: mp.x, cy: mp.y, r: S * 0.5 }));
  // Freccia di orientamento (niente più "maniglie" toccabili sulla mappa).
  const fd = DIRS[((d.facing % 6) + 6) % 6]; const fv = ax(fd[0], fd[1]); const fl = Math.hypot(fv.x, fv.y) || 1;
  root.appendChild(svg("line", { class: "facing", x1: mp.x, y1: mp.y, x2: mp.x + fv.x / fl * S * 0.95, y2: mp.y + fv.y / fl * S * 0.95 }));

  // Mappa a tutto schermo + barra azioni grande e CENTRATA in basso.
  const wrap = el("div", "resolve");
  const mapWrap = el("div", "map-wrap");
  const tilt = el("div", "map3d"); tilt.appendChild(root); mapWrap.appendChild(tilt);
  wrap.appendChild(mapWrap);
  const acts = el("div", "acts");

  if (moveStep) {
    acts.appendChild(el("h3", null, "Passo 1 — Movimento"));
    acts.appendChild(el("div", "hint", "Tocca una casella gialla per muovere."));
    const skip = el("button", "primary big", "Non muovere →");
    skip.onclick = () => respond("resolve", { action: "skip_move" });
    acts.appendChild(skip);
  } else if (rotStep) {
    acts.appendChild(el("h3", null, "Passo 2 — Rotazione"));
    acts.appendChild(el("div", "hint", "Scegli dove guardare, poi «Avanti»."));
    const g = el("div", "grp");
    for (const f of facings) {
      const b = el("button", "jp" + (f === d.facing ? " on" : ""), facingLabel(f));
      b.onclick = () => respond("resolve", { action: "rotate", facing: f });
      g.appendChild(b);
    }
    acts.appendChild(g);
    const next = el("button", "primary big", "Avanti →");
    next.onclick = () => { _rotDone = true; renderResolve(d); };
    acts.appendChild(next);
  } else {
    acts.appendChild(el("h3", null, "Passo 3 — Azione"));
    const kamae = d.kamae || {};
    if (d.kamaeUI && d.kamaeUI.card) {
      // Carta Kamae interattiva: apri la carta e tocca il nodo raggiungibile.
      const kb = el("button", "jp big", "⟳ Cambia Kamae");
      kb.onclick = () => openKamae(d.kamaeUI);
      acts.appendChild(kb);
    } else if (Object.keys(kamae).length) {
      // Fallback: bottoni delle Kamae raggiungibili.
      acts.appendChild(el("div", "lbl", "Cambia Kamae"));
      const g = el("div", "grp");
      for (const slug of Object.keys(kamae)) {
        const gain = kamae[slug];
        const b = el("button", "jp", `${kamaeLabel(slug)}${gain > 0 ? " +◈" + gain : ""}`);
        b.onclick = () => respond("resolve", { action: "kamae", slug });
        g.appendChild(b);
      }
      acts.appendChild(g);
    }
    if ((d.options || []).length) {
      acts.appendChild(el("div", "lbl", "Scegli (OPPURE)"));
      const g = el("div", "grp");
      for (const o of d.options) {
        const b = el("button", "jp", o.label || String(o.alt));
        b.onclick = () => respond("resolve", { action: "option", alt: o.alt });
        g.appendChild(b);
      }
      acts.appendChild(g);
    }
    acts.appendChild(el("div", "hint", targets.size ? "Tocca il bersaglio rosso per attaccare, o «Fine»." : "Premi «Fine» per risolvere."));
    const conf = el("button", "primary big", "Fine ▶");
    conf.onclick = () => respond("resolve", { action: "confirm" });
    acts.appendChild(conf);
  }
  wrap.appendChild(acts);
  setContent(wrap);
}

// ── Etichette ────────────────────────────────────────────────────────────────
function typeLabel(t) { return ({ attack: "Attacco", defence: "Difesa", meditation: "Meditazione", core: "Base", status: "Stato" })[t] || t || "—"; }
function kamaeLabel(s) { return ({ aggression: "Aggressività", balance: "Equilibrio", determination: "Determinazione", neutral: "Neutra" })[s] || s || "—"; }
function combatLabel(k) { return ({ hit: "colpo a segno", blocked: "parato", counter: "contrattacco", collision: "urto" })[k] || (k || ""); }
// Orientamento: freccia per direzione esagonale assoluta (DIRS flat-top).
function facingLabel(f) { return (["↘", "↗", "↑", "↖", "↙", "↓"])[((f % 6) + 6) % 6] || "•"; }
