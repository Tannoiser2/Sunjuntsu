// Mini server WebSocket per Senjutsu (multiplayer companion, Tappa 3).
//
// È un RELAY "muto": non conosce le regole. Gestisce STANZE (codice) e instrada i
// messaggi tra il TAVOLO (host autorevole) e i TELEFONI (un seat ciascuno).
//
// Protocollo busta (client <-> server):
//   create  {t:"create", code?}                -> {t:"created", code}        (diventi TAVOLO)
//   join    {t:"join", code, seat}             -> {t:"joined", seat} | {t:"error"} (diventi TELEFONO)
//   table -> {t:"to_client", seat, payload}    -> al telefono: {t:"from_host", seat, payload}
//   table -> {t:"broadcast", payload}          -> a tutti i telefoni: {t:"from_host", seat:-1, payload}
//   phone -> {t:"to_host", payload}            -> al tavolo: {t:"from_client", seat, payload}
//   server -> tavolo: {t:"peer", event:"join"|"leave", seat}
//
// Il `payload` è opaco (i messaggi di MatchHost/MatchClient): il relay non li interpreta.
// Avvio: `node server/server.js`  (porta da env PORT, default 8080).

import { WebSocketServer } from "ws";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join, normalize, extname } from "node:path";

const PORT = process.env.PORT ? Number(process.env.PORT) : 8080;
const rooms = new Map(); // code -> { table: ws|null, seats: Map<number, ws> }

// ─── Server HTTP statico: serve il CONTROLLER (phone/) e l'ARTE delle carte ───
// Così i telefoni aprono http://<host>:<porta>/ (niente file://) e le immagini delle
// carte sono raggiungibili su /cards/...  Il WebSocket gira sulla STESSA porta.
const HERE = dirname(fileURLToPath(import.meta.url));
const PHONE_DIR = join(HERE, "..", "phone");
const CARDS_DIR = join(HERE, "..", "godot", "assets", "cards");
const MAPS_DIR = join(HERE, "..", "godot", "assets", "maps");
const PORTRAITS_DIR = join(HERE, "..", "godot", "assets", "portraits");
const MIME = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8", ".json": "application/json",
  ".webp": "image/webp", ".png": "image/png", ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg", ".svg": "image/svg+xml", ".ico": "image/x-icon",
};

// Risolve un path-URL dentro una directory base, bloccando i path-traversal.
function safeJoin(base, urlPath) {
  const rel = normalize(decodeURIComponent(urlPath)).replace(/^(\.\.[/\\])+/, "");
  const full = join(base, rel);
  return full.startsWith(base) ? full : null;
}

async function serveFile(res, path) {
  try {
    const buf = await readFile(path);
    res.writeHead(200, {
      "content-type": MIME[extname(path).toLowerCase()] || "application/octet-stream",
      "cache-control": "no-cache",   // i telefoni prendono sempre i file aggiornati
    });
    res.end(buf);
  } catch {
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("404");
  }
}

const http = createServer(async (req, res) => {
  let url = (req.url || "/").split("?")[0];
  if (url === "/" || url === "") url = "/index.html";
  if (url.startsWith("/cards/")) {
    const p = safeJoin(CARDS_DIR, url.slice("/cards/".length));
    return p ? serveFile(res, p) : (res.writeHead(403), res.end("403"));
  }
  if (url.startsWith("/maps/")) {
    const p = safeJoin(MAPS_DIR, url.slice("/maps/".length));
    return p ? serveFile(res, p) : (res.writeHead(403), res.end("403"));
  }
  if (url.startsWith("/portraits/")) {
    const p = safeJoin(PORTRAITS_DIR, url.slice("/portraits/".length));
    return p ? serveFile(res, p) : (res.writeHead(403), res.end("403"));
  }
  const p = safeJoin(PHONE_DIR, url);
  return p ? serveFile(res, p) : (res.writeHead(403), res.end("403"));
});

function makeCode() {
  const A = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let c = "";
  do {
    c = Array.from({ length: 4 }, () => A[Math.floor(Math.random() * A.length)]).join("");
  } while (rooms.has(c));
  return c;
}

function getRoom(code) {
  if (!rooms.has(code)) rooms.set(code, { table: null, seats: new Map() });
  return rooms.get(code);
}

function send(ws, obj) {
  if (ws && ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

const wss = new WebSocketServer({ server: http });
http.listen(PORT, () => {
  console.log(`[senjutsu-relay] HTTP + WebSocket su :${PORT}`);
  console.log(`  Controller telefono:  http://<ip-del-pc>:${PORT}/`);
  console.log(`  WebSocket:            ws://<ip-del-pc>:${PORT}`);
});

wss.on("connection", (ws) => {
  ws._role = null; // "table" | "phone"
  ws._code = null;
  ws._seat = null;

  ws.on("message", (raw) => {
    let m;
    try { m = JSON.parse(raw.toString()); } catch { return; }
    switch (m.t) {
      case "create": {
        const code = (m.code && String(m.code)) || makeCode();
        const room = getRoom(code);
        room.table = ws;
        ws._role = "table"; ws._code = code;
        send(ws, { t: "created", code });
        // notifica i seat già presenti (telefono arrivato prima del tavolo)
        for (const seat of room.seats.keys()) send(ws, { t: "peer", event: "join", seat });
        break;
      }
      case "join": {
        const code = String(m.code || "");
        const seat = Number(m.seat);
        const room = getRoom(code);
        if (room.seats.has(seat) && room.seats.get(seat) !== ws) {
          send(ws, { t: "error", error: "seat_taken" });
          break;
        }
        room.seats.set(seat, ws);
        ws._role = "phone"; ws._code = code; ws._seat = seat;
        send(ws, { t: "joined", seat });
        send(room.table, { t: "peer", event: "join", seat });
        break;
      }
      case "to_client": {
        const room = rooms.get(ws._code);
        if (!room) break;
        send(room.seats.get(Number(m.seat)), { t: "from_host", seat: Number(m.seat), payload: m.payload });
        break;
      }
      case "broadcast": {
        const room = rooms.get(ws._code);
        if (!room) break;
        for (const phone of room.seats.values()) send(phone, { t: "from_host", seat: -1, payload: m.payload });
        break;
      }
      case "to_host": {
        const room = rooms.get(ws._code);
        if (!room) break;
        send(room.table, { t: "from_client", seat: ws._seat, payload: m.payload });
        break;
      }
    }
  });

  ws.on("close", () => {
    const room = rooms.get(ws._code);
    if (!room) return;
    if (ws._role === "table" && room.table === ws) room.table = null;
    if (ws._role === "phone" && room.seats.get(ws._seat) === ws) {
      room.seats.delete(ws._seat);
      send(room.table, { t: "peer", event: "leave", seat: ws._seat });
    }
    if (!room.table && room.seats.size === 0) rooms.delete(ws._code);
  });
});
