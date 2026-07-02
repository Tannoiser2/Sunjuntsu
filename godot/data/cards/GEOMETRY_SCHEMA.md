# Geometria/effetti delle carte — Schema v2

`geometry.json` contiene i dati stampati **sulla faccia delle carte** (non
presenti nell'Excel di deckbuilding): movimento, arco/anelli dell'attacco,
ferite, blocco difensivo, contrattacco ed effetti. Trascrizione manuale
best-effort dalle immagini in `Tabelle_Materiali/Senjutsu/CARTE/`; ogni voce è
agganciata al **numero stampato sulla carta** (= Card ID).

> Questo documento descrive lo **schema reale** usato dai dati (`Schema v2`).
> Il vecchio schema v1 (`range/wounds/dirs/block`) è stato abbandonato: non
> corrisponde più ai dati e non va usato.

## Struttura del file

```jsonc
{
  "note": "...riassunto delle convenzioni e degli avvisi di affidabilità...",
  "cards": {
    "<id>": { /* geometria di una carta, vedi sotto */ }
  },
  "characters": {
    "<Personaggio>": { "card_id": int, "name": str,
                       "wound_limit": int, "hand_limit": int, "weapons": [str] }
  }
}
```

- La **chiave** in `cards` è l'`id` come **stringa** (in `card_pool.json` è `int`).
  Lo store normalizza: int per la logica, string per la chiave JSON.
- `characters` mappa il personaggio (es. `"Warrior"`) ai suoi limiti e armi.

## Geometria di una carta (tutti i campi opzionali tranne `name`/`type`)

```jsonc
"55": {
  "name": "COLPO DELLA FENICE FIAMMANTE",   // string — nome stampato (riferimento)
  "type": "attack",                          // attack | defence | meditation | core
  "kamae_req": "aggression",                 // gate kamae per giocarla (opz.)

  "move": { "opts": [ { "atoms": [           // movimento: lista di OPZIONI alternative,
      { "t": "step", "dir": 0, "n": 1, "opt": false },   // ognuna è una sequenza di ATOMI
      { "t": "rot",  "n": 2, "opt": true }
  ] } ] },

  "attack":  { "cells": [                     // arco offensivo: celle colpite
      { "d": 0, "k": 1, "w": 2 },             // d=dir relativa, k=anello, w=ferite
      { "d": 1, "k": 1, "w": "exec" }
  ] },

  "defence": { "cells": [ { "d": 0, "k": 1, "v": 1 } ] },  // v=valore di blocco

  "counter": [8],                             // iniziative di contrattacco (opz.)

  "effects": [                                // lista ORDINATA di effetti
    { "do": "push", "n": 1, "when": "on_hit", "kamae": "balance",
      "alt": "a", "to": "aggression", "focus_cost": 1 }
  ],

  "split": {                                   // seconda iniziativa (opz.) — stessi
    "initiative": 5,                           // campi della carta principale (tranne
    "move": { "opts": [ … ] },                 // name/type), per la "parte bassa" di
    "attack": { "cells": [ … ] },               // una carta split. Vedi anche §Split.
    "counter": [4],
    "effects": [ … ]
  },

  "note": "annotazioni / incertezze di trascrizione"
}
```

### Campi

| Campo | Tipo | Significato |
|-------|------|-------------|
| `name` | string | Nome stampato sulla carta (riferimento, ridondante con `card_pool`). |
| `type` | string (enum) | `attack` \| `defence` \| `meditation` \| `core`. |
| `kamae_req` | string (enum, opz.) | Kamae richiesto: `aggression` \| `balance` \| `determination`. |
| `state_req` | string \| object (opz.) | Giocabilità gated dallo **stato persistente** (vedi §Stati persistenti): `"occultato"` (richiede ≥ 1) oppure `{ "contratti": 2 }` (nome → minimo, AND fra le chiavi). |
| `move` | object (opz.) | `{ "opts": [ Opzione, … ] }` — vedi **Movimento**. |
| `attack` | object (opz.) | `{ "cells": [ Cella, … ] }` — celle offensive (variante unica). |
| `attacks` | array[object] (opz.) | **Più varianti d'attacco**, ciascuna `{ "cells": […], "kamae": "<slug>"? }`. Il motore usa la variante il cui `kamae` combacia con la posa (stance) dell'attaccante; in mancanza, quella senza `kamae`. In alternativa a `attack`. Se più varianti condividono lo stesso `kamae` (incluso nessuno, cioè libere/OPPURE non gated), sono opzioni scelte liberamente dal giocatore, non alternative gated — pattern raro (es. #164, #344), l'editor le mostra come widget "Combattimento" separati. |
| `defence` | object (opz.) | `{ "cells": [ Cella, … ] }` — celle protette (variante unica). |
| `defences` | array[object] (opz.) | Più varianti di difesa gated da `kamae`, come `attacks`. |
| `counter` | array (opz.) | Iniziative a cui scatta il contrattacco. Ogni voce è un **int** (sempre attiva) oppure un **oggetto gated** `{ "on": [7,6], "kamae"/"state"/"focus_cost" }` (attiva solo se il gate del difensore è soddisfatto — vedi §Gate unificato). |
| `alt_initiative` | object (opz.) | **Iniziativa alternativa** (roadmap §3.1): riquadro `[N]` extra sulla carta, usabile AL POSTO di quella stampata se il gate è soddisfatto. `{ "value": 8, "kamae"?/"focus_cost"?/"state"? }`. Non è uno `split` (che è una *seconda azione*). In auto-risoluzione si usa solo se gratis e più veloce. |
| `effects` | array[object] (opz.) | Effetti ordinati — vedi **Effetti**. |
| `stays_in_play` | bool (opz.) | **RIMANE IN GIOCO** (roadmap §3.2): a fine risoluzione la carta va nell'area "in gioco" del combattente invece che negli scarti. |
| `in_play_state` | string (opz.) | Con `stays_in_play`: entrando in gioco la carta incrementa questo stato persistente di 1, uscendo lo decrementa (es. contatore `illuminata` di #263/264/265, letto da `state_req` di #261/#262). |
| `limit_mod` | object (opz.) | Con `stays_in_play`: modifica i limiti finché la carta è in gioco — `{ "hand": +3, "wound": +1, "focus": +1 }` (§3.17). |
| `turn_start` | array[object] (opz.) | Con `stays_in_play`: effetti applicati **a inizio turno, prima del passo Draw**, finché la carta è in gioco (finestre di trigger, §3.3 — es. il mill forzato di #280). Stessa forma di `effects`. |
| `expires` | object (opz.) | Con `stays_in_play`: `{ "turns": N }` — la carta si scarta da sola dopo N fine-turno (es. #106 che ruota di 90°). |
| `targeting` | object (opz.) | **Bersaglio per confronto d'iniziativa** (§3.4), per armi a distanza senza diagramma: `{ "mode": "initiative", "threshold"?: N, "w"?: int\|"bleed"\|"exec", "w_from_gap"?: true }`. Colpisce se l'avversario è in gittata (keyword RangeN) e la sua velocità è inferiore alla propria (e sotto `threshold` se posto); `w_from_gap` = ferite pari al divario di velocità (#279). Le eventuali `cells` restano come placeholder di gittata per la UI. |
| `note` | string (opz.) | Note di trascrizione / incertezze (es. `"… DA VERIFICARE"`). |
| `layout` | array[object] (opz.) | **Estetico, ignorato dal motore.** Albero dei widget dell'editor (nodi `{type, …, children[]}`, dalla v0.61): conserva annidamento (Iniziativa/OPPURE) e ordine come sulla carta fisica. In lettura resta supportata la forma storica `array[string]`. |
| `split` | object (opz.) | **Seconda iniziativa.** Alcune carte agiscono due volte a iniziative diverse (riquadro `[N]` sulla carta fisica, "parte bassa"). `split` ha gli stessi campi della carta (tranne `name`/`type`): `initiative` (obbligatorio), più `kamae_req`/`move`/`attack(s)`/`defence(s)`/`counter`/`effects`/`note` opzionali. Risolto come una seconda azione indipendente alla propria iniziativa. |

### Movimento — `move.opts[].atoms[]`

`move` è un insieme di **opzioni alternative** (`opts`); il giocatore ne sceglie
una. Ogni opzione è una sequenza ordinata di **atomi**:

| Campo atomo | Tipo | Significato |
|-------------|------|-------------|
| `t` | string | `step` (passo) \| `rot` (rotazione) \| `anchor`. |
| `dir` | int | Direzione del passo: `0`=fronte, senso **orario** 0–5; **`-1`=qualsiasi direzione** (❄ fiocco di neve sulla carta fisica). Solo per `step`. |
| `dirs` | array[int] (opz.) | Alternativa a `dir`: più direzioni tra cui scegliere (es. bidente/tridente sulla carta fisica → `[0,1,5]`). |
| `n` | int | Quantità (passi · scatti di rotazione). |
| `opt` | bool | `true` = atomo **facoltativo** (bonus). |
| `kamae` | string (opz.) | Gate kamae per l'atomo: l'opzione di movimento è disponibile solo in quella Kamae (barra colorata sulla carta fisica). Stessi valori di `kamae_req`. |
| `focus_cost` | int (opz.) | Costo in focus per l'atomo (barra viola con loto sulla carta fisica). |

> **❄ Fiocco di neve (`t: "step", dir: -1`).** Il simbolo ❄ nella barra
> movimento di una carta significa **passo libero verso uno qualsiasi dei 6
> esagoni adiacenti**. Si trascrive come `{ "t": "step", "dir": -1, "n": 1 }`.
> Da non confondere con l'effetto `link_anchor` in `effects[]`, che è il
> meccanismo separato della Griglia di Posizione (asterisco `*`).

### Celle attacco/difesa — `attack.cells[]` / `defence.cells[]`

La honeycomb sulla carta è il vicinato esagonale (centro + anelli) orientato
sulla pedina (▲ = fronte). Ogni cella colpita/protetta:

| Campo cella | Tipo | Significato |
|-------------|------|-------------|
| `q`, `r` | int | **Coordinate assiali** dell'esagono relativo alla pedina con fronte = `DIRS[0]` (qualsiasi esagono del vicinato, non solo i 6 raggi). Fronte adiacente = `(1,0)`. |
| `w` | int \| string | *(attacco)* ferite automatiche: intero, oppure `"exec"` (esecuzione) o `"bleed"` (sanguinante). `0` = nessuna ferita automatica. |
| `focus_cost` | int (opz.) | *(attacco)* Costo in focus per sbloccare le ferite bonus `w_focus`. Se il giocatore non paga, la cella colpisce comunque per `w` ferire (spesso 0). Saltato in auto-risoluzione. |
| `w_focus` | int (opz.) | *(attacco)* Ferite aggiuntive applicate se il giocatore paga `focus_cost`. Default `1` quando `focus_cost > 0`. |
| `v` | int | *(difesa)* valore di blocco della cella. |

> **Schema celle.** L'editor scrive le celle in **coordinate assiali piene** `{q,r}`,
> così può colpire *ogni* esagono del vicinato (incluso l'anello 2 fuori dai raggi).
> Il motore le orienta secondo il facing (`HexGrid.rotate`). È supportato anche il
> vecchio formato a 6 direzioni **`{d,k}`** (`d`=direzione 0–5, `k`=anello): le carte
> non ancora ri-salvate lo usano e risolvono in modo identico (`{q,r} = DIRS[d]*k`).

### Effetti — `effects[]`

Lista **ordinata**; ogni effetto è un oggetto con un verbo `do` e campi
contestuali:

| Campo | Tipo | Significato |
|-------|------|-------------|
| `do` | string | Verbo dell'effetto (vocabolario sotto). |
| `n` | int (opz.) | Quantità (passi di push, focus, carte, …). |
| `when` | string (opz.) | Condizione: `on_hit` \| `always` (default contestuale). |
| `kamae` | string (opz.) | Gate kamae per l'effetto: `aggression` \| `balance` \| `determination` (anche array, gate OR: `["balance","determination"]`). |
| `alt` | string (opz.) | Etichetta di alternativa (effetti mutuamente esclusivi). |
| `to` | string (opz.) | Kamae di destinazione (per cambi di kamae): `aggression` \| `balance` \| `determination` \| `neutral` (torii ⛩, quasi sempre come destinazione, mai come gate) \| `any` (PASSA A UNA QUALSIASI KAMAE). |
| `focus_cost` | int (opz.) | Costo in focus dell'effetto (bonus opzionali). |
| `state` | string \| object (opz.) | Gate di **stato persistente** per l'effetto (sui verbi non-`state_*`): stessa forma di `state_req`. Per i verbi `state_*` è invece il **nome** dello stato da modificare. |
| `n_from_state` | string (opz.) | **Quantità a entità variabile** (roadmap §3.13): `n` effettivo = `n` (default 1) × valore dello stato indicato (es. "PER OGNI CONTRATTO COMPLETATO" → `"n_from_state": "contratti"`). A zero istanze l'effetto non scatta. |
| `random` | bool (opz.) | Su `discard_self`/`foe_discard`: la carta da scartare è scelta **a caso** (roadmap §3.19) invece che dall'ultima. |
| `what` | string (opz.) | Solo per `heal` (roadmap §3.20): cosa rimuovere — `wound` (default), `bleed`, `stun`, `hobble`, `poison`. |

**Verbi `do` presenti nei dati** (usare come autocomplete; estendibile):
`block_initiative, cancel_abilities, cancel_movement, change_ai_behaviour,
change_kamae, discard_self, draw, focus, foe_discard, foe_lose_focus, foe_stun,
hobble, link_anchor, push, reduce_damage, replace_wound_bleed, reset_deck,
rotate_target, search_draw, spend_focus, state_add, state_clear, state_set,
stun_self, swap_positions, switch_kamae`, più la famiglia sull'avversario
`foe_change_kamae, foe_discard, foe_draw, foe_lose_focus, foe_reveal_hand,
foe_stun, foe_switch_kamae` e `heal` (rimozione ferite/stati propri).

> **`link_anchor`** (azione "SOSTITUISCI ! CON ❄", barra viola = focus): collega
> il marcatore-àncora ❄ all'asterisco (`*`) sulla Griglia di Posizione; gli
> effetti collegati si applicano al personaggio colpito. Di norma con
> `focus_cost` (bonus a pagamento), quindi saltato nell'auto-risoluzione.

## Stati persistenti (contatori/flag per-combattente)

Sottosistema unico per le risorse/stati di personaggio che sopravvivono tra i
turni (roadmap meccaniche §4): **Disperazione** (Onna-Bugeisha), **Contratti**
(Yojimbo), **Occultato** (Assassino e Ninja), ciclo **Illuminata**
(Monaco), carte "**RIMANE IN GIOCO**". Runtime: `Fighter.states`
(dizionario libero nome → int, decisione §5.1); flag = assente/0 (off) o ≥ 1.

> **`occultato`** è il nome ufficiale (carta-regola #161 RIVELATO/OCCULTATO,
> unica per Assassino e Ninja — l'icona incappucciata di "ENTRA IN"). Le
> condizioni di USCITA sono cablate in `Duel._cleanup`: si torna Rivelati
> dopo un attacco riuscito, un blocco riuscito, ferite subite o un altro
> effetto di stato ricevuto — salvo re-ingresso nello stesso turno. La
> carta-regola #160 PIEDI DI CORVO (segnalini trappola, roadmap §3.28) non
> è ancora modellata.

- **Scrittura** (effetti): `{ "do": "state_add", "state": "contratti", "n": 1 }`
  somma `n` (anche negativo, per spendere; a ≤ 0 lo stato si rimuove);
  `state_set` imposta il valore assoluto; `state_clear` lo azzera.
- **Lettura** (gate): campo `state` su un effetto/parte, o `state_req` a
  livello carta — `"occultato"` (≥ 1) o `{ "contratti": 2 }` (nome → minimo, AND).

### Gate unificato (`engine/Gate.gd` — vedi `docs/GATE_AUDIT.md`)

Ovunque una sotto-parte sia condizionata, i campi sono sempre gli stessi, in
**AND** fra loro: `kamae` (string o array = OR fra Kamae), `focus_cost` (int),
`state` (come sopra). In auto-risoluzione le parti con `focus_cost > 0` si
saltano (sono bonus facoltativi); in partita interattiva si offre il pagamento.

## Vocabolari controllati

- `type`: `attack, defence, meditation, core` (l'anagrafica in `card_pool.json` ammette
  anche `other`, ma va sempre normalizzato a uno di questi 4 in `geometry.json`).
- `atom.t`: `step, rot, anchor`.
- `w` (ferite): intero `≥ 0`, oppure `"exec"`, `"bleed"`.
- `kamae` / `kamae_req`: `aggression, balance, determination` (anche array, gate OR).
- `to` (destinazione di un cambio kamae): `aggression, balance, determination, neutral, any`.

## Limiti noti (meccaniche non ancora rappresentabili)

Alcune meccaniche specifiche di personaggio, scoperte trascrivendo le carte,
non hanno ancora un campo/verbo dedicato: sono documentate carta per carta nel
campo `note` invece di forzare un valore inventato. Tra le principali: iniziativa
alternativa gated da Kamae/focus, effetti persistenti "rimane in gioco" con
trigger a inizio turno, azioni informative sull'avversario ("guarda la mano"),
carte a due facce con due movimenti sulla stessa entry (Hachikō), bersaglio
scelto per confronto d'iniziativa invece che per cella, stati/risorse
specifici di personaggio (Ombra, Disperazione, Contratti, Illuminata), una
quinta Kamae "Distanza" (Navigatore) fuori da questo enum. Cercare `DA
VERIFICARE` in `geometry.json` per l'elenco completo.

## Affidabilità

Trascrizione iterativa e best-effort. I campi robusti (movimento, ferite, focus,
blocco, effetti) sono affidabili; gli **offset esatti dell'arco** (`d`/`k`) sono
best-effort e annotati nelle `note` (cerca `DA VERIFICARE`). L'editor visuale
sul nido d'ape è pensato proprio per correggerli: il campo `note` va sempre
preservato.

Allo stato attuale **281 carte** hanno geometria trascritta — l'intero gioco
base (Musashi/Kojiro esclusi: nessuna espansione disponibile) è coperto e
verificato contro le scansioni reali. L'editor deve comunque gestire bene il
caso "geometria assente" (crearla da zero) per eventuali carte future.
