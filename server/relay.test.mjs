// Test del relay (stanze + instradamento), tutto in Node (niente Godot/browser).
// Avvia il server su una porta di test, connette un "tavolo" e due "telefoni" e
// verifica create/join/seat_taken e l'instradamento to_client/broadcast/to_host.
import { WebSocket } from "ws";

const PORT = 8137;
process.env.PORT = String(PORT);
await import("./server.js"); // avvia il WebSocketServer
await sleep(150);

const URL = `ws://127.0.0.1:${PORT}`;
let ok = true;
function check(cond, msg) { if (cond) console.log("OK:", msg); else { console.log("FAIL:", msg); ok = false; } }
function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
function open(url) {
  return new Promise((res, rej) => {
    const ws = new WebSocket(url);
    ws._q = [];
    ws.on("message", (d) => { ws._q.push(JSON.parse(d.toString())); });
    ws.on("open", () => res(ws));
    ws.on("error", rej);
  });
}
function snd(ws, o) { ws.send(JSON.stringify(o)); }
async function waitFor(ws, pred, label) {
  for (let i = 0; i < 100; i++) {
    const idx = ws._q.findIndex(pred);
    if (idx >= 0) return ws._q.splice(idx, 1)[0];
    await sleep(10);
  }
  console.log("FAIL: timeout in attesa di", label); ok = false; return null;
}

const table = await open(URL);
snd(table, { t: "create", code: "TEST" });
const created = await waitFor(table, (m) => m.t === "created", "created");
check(created && created.code === "TEST", "il tavolo crea la stanza con codice TEST");

const p0 = await open(URL);
snd(p0, { t: "join", code: "TEST", seat: 0 });
check(!!(await waitFor(p0, (m) => m.t === "joined" && m.seat === 0, "joined seat0")), "telefono 0 entra nel seat 0");
check(!!(await waitFor(table, (m) => m.t === "peer" && m.event === "join" && m.seat === 0, "peer join 0")), "il tavolo viene avvisato dell'arrivo del seat 0");

const p1 = await open(URL);
snd(p1, { t: "join", code: "TEST", seat: 1 });
check(!!(await waitFor(p1, (m) => m.t === "joined" && m.seat === 1, "joined seat1")), "telefono 1 entra nel seat 1");

// seat occupato
const pX = await open(URL);
snd(pX, { t: "join", code: "TEST", seat: 0 });
check(!!(await waitFor(pX, (m) => m.t === "error" && m.error === "seat_taken", "seat_taken")), "seat gia occupato -> errore");
pX.close();

// instradamento: tavolo -> telefono 0
snd(table, { t: "to_client", seat: 0, payload: { t: "prompt", kind: "plan", data: { x: 1 } } });
const fh = await waitFor(p0, (m) => m.t === "from_host", "from_host a p0");
check(fh && fh.payload && fh.payload.kind === "plan", "to_client instrada il prompt al telefono giusto");

// broadcast: tavolo -> tutti i telefoni
snd(table, { t: "broadcast", payload: { t: "event", kind: "turn" } });
check(!!(await waitFor(p0, (m) => m.t === "from_host" && m.seat === -1, "bcast p0")), "broadcast raggiunge il telefono 0");
check(!!(await waitFor(p1, (m) => m.t === "from_host" && m.seat === -1, "bcast p1")), "broadcast raggiunge il telefono 1");

// risposta: telefono 1 -> tavolo (il server aggiunge il seat)
snd(p1, { t: "to_host", payload: { t: "respond", kind: "plan", data: { card: 64 } } });
const fc = await waitFor(table, (m) => m.t === "from_client", "from_client al tavolo");
check(fc && fc.seat === 1 && fc.payload.data.card === 64, "to_host instrada la risposta al tavolo col seat corretto");

console.log("RISULTATO:", ok ? "PASS" : "FAIL");
process.exit(ok ? 0 : 1);
