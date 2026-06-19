# Senjutsu — relay multiplayer (companion)

Mini server WebSocket che fa da **centralino** tra il **tavolo** (host autorevole, la
build Godot che mostra la board) e i **telefoni** (un giocatore per seat). Non conosce le
regole: gestisce solo **stanze** (codice) e **instradamento** dei messaggi. Vedi
`../docs/MULTIPLAYER_PLAN.md` per il quadro completo.

## Avvio (locale)
```bash
cd server
npm install        # una volta (dipendenza: ws)
npm start          # HTTP + WebSocket su :8080  (PORT per cambiare porta)
```
Lo stesso processo fa due cose sulla **stessa porta**:
- **WebSocket** (relay stanze) — `ws://<ip-del-pc>:8080`
- **HTTP statico** — serve il controller telefono (`../phone/`) e l'**arte delle carte**
  (`../godot/assets/cards/` → `/cards/...`).

## Telefoni
Dal telefono apri nel browser **`http://<ip-del-pc>:8080/`** (niente più `file://`):
- il campo **Server** è già precompilato con la stessa origine;
- inserisci il **Codice stanza** mostrato dal tavolo e scegli **Giocatore 1/2**.

Le carte appaiono con la **loro immagine** (servite da `/cards/`). Il controller **ricorda**
la sessione e si **riconnette da solo** (refresh/segnale perso), riprendendo dal prompt in
corso. Su LAN serve l'IP del PC che ospita relay+tavolo; in produzione il relay va su un
host sempre acceso (es. free-tier).

## Test
```bash
npm test           # relay.test.mjs: stanze + instradamento (solo Node)
```
E2E completo (relay + tavolo Godot + 2 client via WebSocket reale):
```bash
bash ../godot/tests/run_ws_e2e.sh
```

## Protocollo busta (relay)
| Da | Messaggio | Effetto |
|---|---|---|
| tavolo | `{t:"create", code?}` | crea/claima la stanza → `{t:"created", code}` |
| telefono | `{t:"join", code, seat}` | entra come seat → `{t:"joined", seat}` / `{t:"error"}` |
| tavolo | `{t:"to_client", seat, payload}` | → telefono: `{t:"from_host", seat, payload}` |
| tavolo | `{t:"broadcast", payload}` | → tutti: `{t:"from_host", seat:-1, payload}` |
| telefono | `{t:"to_host", payload}` | → tavolo: `{t:"from_client", seat, payload}` |
| server→tavolo | `{t:"peer", event, seat}` | join/leave di un telefono |

Il `payload` è opaco: sono i messaggi di `MatchHost`/`MatchClient` (vedi `godot/net/`).
