# Multiplayer companion — Piano tecnico ("web + mini server")

Modello **second screen / companion** (stile Jackbox):
- **Tavolo** (browser su TV/PC/tablet): mostra mappa, pedine, animazioni — solo info
  pubbliche — ed è l'**host autorevole** che fa girare il motore.
- **Telefoni** (browser, niente app): URL + codice stanza; ogni giocatore vede la
  **propria mano** e riceve i **prompt** per ogni decisione.
- **Mini server WebSocket**: solo stanze + inoltro messaggi (non conosce le regole).

## Perché è a basso rischio
Il motore (`Duel`/`GameState`) è logica pura a segnali su decisioni discrete. Si
aggiunge uno strato **protocollo decisioni** (`engine/MatchProtocol.gd`) che traduce ogni
segnale in un messaggio dati e ogni risposta in una chiamata già esistente. La logica di
gioco non cambia.

## Protocollo decisioni (Tavolo ↔ Telefono, inoltrato dal server)
| Momento | Prompt → telefono | Risposta → tavolo |
|---|---|---|
| Programmazione | `plan {hand[], focus, kamae}` | `{card}` |
| Sostituzione (rivelazione) | `instant_replace {options[], revealed}` | `{pick \| -1}` |
| Risoluzione (loop azioni) | `resolve {card, legalCells, legalFacings, kamae, options, targets, canConfirm, split}` | `{action: move\|rotate\|kamae\|option\|confirm, ...}` |
| Istantanea aggiuntiva | `instant_play {options[]}` | `{pick \| -1}` |
| Stato privato | `you {hand[], focus, wounds, kamae}` | — |

Pubblico (board/pedine/ferite/narrazione/animazioni) resta sul tavolo.

## Flusso stanza
1. Tavolo crea stanza → server restituisce **codice**.
2. Telefoni aprono URL, inseriscono codice, scelgono seat (G1/G2).
3. Il server lega socket→seat; il tavolo manda i prompt al seat giusto.
4. Riconnessione: re-inserisci codice e riprendi il seat (stato sul tavolo).

## Sicurezza / correttezza
- Tavolo **autorevole**: il telefono manda intenzioni, il tavolo valida con la logica.
- Mani **private**: ogni telefono riceve solo il proprio stato.

## Componenti
| Componente | Tecnologia |
|---|---|
| Tavolo | Godot web (riusa l'esistente) |
| Telefono | Pagina HTML/JS leggera (usa le immagini carte già ritagliate) |
| Server | Node.js `ws` (~100 righe) o servizio gestito |

## Deploy
- Tavolo + telefono: pagine statiche (GitHub Pages).
- Server: free-tier (Fly.io/Render/Railway) — unico pezzo sempre acceso.

## Tappe
1. **Protocollo decisioni headless** (`MatchProtocol`) + test — *questo passo*. Niente rete.
2. **Loopback locale**: due controller fittizi pilotano il tavolo.
3. **Server WebSocket + stanze** + client telefono HTML minimale.
4. **Rifinitura UI telefono** (touch, layout, riconnessione).

## Stato
- Tappa 1: `engine/MatchProtocol.gd` + `tests/test_protocol` (in corso).
