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

  "note": "annotazioni / incertezze di trascrizione"
}
```

### Campi

| Campo | Tipo | Significato |
|-------|------|-------------|
| `name` | string | Nome stampato sulla carta (riferimento, ridondante con `card_pool`). |
| `type` | string (enum) | `attack` \| `defence` \| `meditation` \| `core`. |
| `kamae_req` | string (enum, opz.) | Kamae richiesto: `aggression` \| `balance` \| `determination`. |
| `move` | object (opz.) | `{ "opts": [ Opzione, … ] }` — vedi **Movimento**. |
| `attack` | object (opz.) | `{ "cells": [ Cella, … ] }` — celle offensive (variante unica). |
| `attacks` | array[object] (opz.) | **Più varianti d'attacco**, ciascuna `{ "cells": […], "kamae": "<slug>"? }`. Il motore usa la variante il cui `kamae` combacia con la posa (stance) dell'attaccante; in mancanza, quella senza `kamae`. In alternativa a `attack`. |
| `defence` | object (opz.) | `{ "cells": [ Cella, … ] }` — celle protette (variante unica). |
| `defences` | array[object] (opz.) | Più varianti di difesa gated da `kamae`, come `attacks`. |
| `counter` | array[int] (opz.) | Iniziative a cui scatta il contrattacco. |
| `effects` | array[object] (opz.) | Effetti ordinati — vedi **Effetti**. |
| `note` | string (opz.) | Note di trascrizione / incertezze (es. `"… DA VERIFICARE"`). |
| `layout` | array[string] (opz.) | **Estetico, ignorato dal motore.** Ordine dei blocchi nell'editor (`combat`, `movement`, `kamae`, `effects`, `counter`, `note`): permette di disporre i blocchi come sulla carta fisica. |

### Movimento — `move.opts[].atoms[]`

`move` è un insieme di **opzioni alternative** (`opts`); il giocatore ne sceglie
una. Ogni opzione è una sequenza ordinata di **atomi**:

| Campo atomo | Tipo | Significato |
|-------------|------|-------------|
| `t` | string | `step` (passo) \| `rot` (rotazione) \| `anchor` (❄ àncora). |
| `dir` | int | Direzione del passo: `0`=fronte, senso **orario** 0–5; `-1`=qualsiasi direzione. Solo per `step`. |
| `n` | int | Quantità (passi · scatti di rotazione · numero stampato accanto al ❄). |
| `opt` | bool | `true` = atomo **facoltativo** (bonus). |

> **❄ Àncora (`t: "anchor"`).** Il fiocco di neve **non è un movimento**: è un
> marcatore-àncora sulla **Griglia di Posizione**. Una carta Abilità può
> *connettere* questo simbolo a un asterisco (`*`) sulla griglia, applicando
> quegli effetti al **personaggio colpito**. Il motore lo tratta come atomo
> "neutro": non sposta né ruota la pedina (vedi `Move.gd`). Compare nelle barre
> di movimento gated da Kamae (es. `❄2 ↻2`); l'azione esplicita "sostituisci
> `!` con ❄" è invece l'effetto `link_anchor` (vedi sotto).

### Celle attacco/difesa — `attack.cells[]` / `defence.cells[]`

La honeycomb sulla carta è il vicinato esagonale (centro + anelli) orientato
sulla pedina (▲ = fronte). Ogni cella colpita/protetta:

| Campo cella | Tipo | Significato |
|-------------|------|-------------|
| `q`, `r` | int | **Coordinate assiali** dell'esagono relativo alla pedina con fronte = `DIRS[0]` (qualsiasi esagono del vicinato, non solo i 6 raggi). Fronte adiacente = `(1,0)`. |
| `w` | int \| string | *(attacco)* ferite: intero, oppure `"exec"` (esecuzione) o `"bleed"` (sanguinante). |
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
| `kamae` | string (opz.) | Gate kamae per l'effetto: `aggression` \| `balance` \| `determination`. |
| `alt` | string (opz.) | Etichetta di alternativa (effetti mutuamente esclusivi). |
| `to` | string (opz.) | Kamae di destinazione (per cambi di kamae). |
| `focus_cost` | int (opz.) | Costo in focus dell'effetto (bonus opzionali). |

**Verbi `do` presenti nei dati** (usare come autocomplete; estendibile):
`block_initiative, cancel_abilities, cancel_movement, change_ai_behaviour,
change_kamae, discard_self, draw, focus, foe_discard, foe_lose_focus, foe_stun,
hobble, link_anchor, push, reduce_damage, replace_wound_bleed, reset_deck,
rotate_target, search_draw, spend_focus, stun_self, swap_positions, switch_kamae`.

> **`link_anchor`** (azione "SOSTITUISCI ! CON ❄", barra viola = focus): collega
> il marcatore-àncora ❄ all'asterisco (`*`) sulla Griglia di Posizione; gli
> effetti collegati si applicano al personaggio colpito. Di norma con
> `focus_cost` (bonus a pagamento), quindi saltato nell'auto-risoluzione.

## Vocabolari controllati

- `type`: `attack, defence, meditation, core` (anagrafica ammette anche `other`).
- `atom.t`: `step, rot, anchor`.
- `w` (ferite): intero `≥ 0`, oppure `"exec"`, `"bleed"`.
- `kamae` / `kamae_req` / `to`: `aggression, balance, determination`.

## Affidabilità

Trascrizione iterativa e best-effort. I campi robusti (movimento, ferite, focus,
blocco, effetti) sono affidabili; gli **offset esatti dell'arco** (`d`/`k`) sono
best-effort e annotati nelle `note` (cerca `DA VERIFICARE`). L'editor visuale
sul nido d'ape è pensato proprio per correggerli: il campo `note` va sempre
preservato.

Allo stato attuale **80 carte su 303** hanno geometria trascritta; l'editor deve
gestire bene il caso "geometria assente" (crearla da zero).
