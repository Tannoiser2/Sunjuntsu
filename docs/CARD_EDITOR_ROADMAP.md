# Editor di carte — Handoff & Roadmap

> **Scopo di questo documento.** La chat precedente è diventata lunga. Questo file
> serve a **ricominciare puliti in una nuova sessione** dedicata all'**editor di
> carte**: poter editare *ogni aspetto di ogni singola carta* da interfaccia,
> senza passare da Excel/PDF + script Python.
>
> Stato del progetto al momento della stesura: **v0.60.0**, Godot 4.6.
> Le ultime ~8 versioni hanno riguardato il *controller telefonico*; questa è una
> **nuova area di lavoro** e parte da zero (nessun editor esiste ancora).

---

## 0. Come usare questo file in una nuova sessione

Apri una sessione nuova e incolla un prompt tipo:

```
Leggi docs/CARD_EDITOR_ROADMAP.md e iniziamo l'editor di carte.
Prima conferma con me le "Decisioni da prendere" (§4), poi parti dalla Fase 1.
```

Sviluppo sul branch `claude/card-editor-roadmap-y1sp92` (vedi convenzioni del repo).

---

## 1. Obiettivo

Uno **strumento grafico, dentro il progetto Godot**, per **visualizzare, creare,
modificare, validare e testare** ogni carta — tutti i campi del catalogo *e* la
geometria/effetti stampati sulla faccia — con anteprima e salvataggio sui file
dati esistenti. Niente più editing manuale di JSON o round-trip via Excel per le
modifiche di gioco.

"Ogni aspetto" significa: anagrafica (`card_pool.json`) **+** geometria/effetti
(`geometry.json`) **+** immagine associata (`card_images.json`).

---

## 2. Stato attuale (cosa esiste già)

**Motore / dati** (separazione netta logica ↔ presentazione, tutto headless-testabile):

| File | Ruolo |
|------|-------|
| `godot/engine/CardDB.gd` | Autoload singleton: carica e indicizza **tutti** i dati carte |
| `godot/engine/Domain.gd` | Enum/costanti: `CardType`, `Rank`, `RANK_COLORS`, ordine di risoluzione |
| `godot/engine/Duel.gd`, `GameState.gd` | Macchina di gioco (per il "tester carta") |
| `godot/scenes/CardView.gd` | Render di una carta (immagine reale *o* scheda data-driven) — **riusabile per l'anteprima** |
| `godot/scenes/HUD.gd` (`_build_kamae_tree`) | Render albero Kamae con nodi posizionati — riferimento per editor visuale |

**File dati** (tutti JSON, in `godot/data/`):

| File | Contenuto | Origine |
|------|-----------|---------|
| `data/cards/card_pool.json` | 303 carte: `id, name, char, amount, rank, initiative, focus, keywords[], type` | **generato** da Excel (`tools/generate_cards.py`) |
| `data/cards/geometry.json` | 54 carte trascritte: `move, attack, defence, effects, kamae_req, counter, note` + `characters{}` stats | **trascrizione manuale** (Schema v2) |
| `data/cards/card_images.json` | `by_id`: ID → path webp relativo a `assets/cards/` | generato da `extract_card_images.py` |
| `data/cards/kamae_trees.json` | Alberi Kamae con nodi posizionati | manuale |
| `data/cards/wounds.json` | Carte di stato (ferite/sanguinanti/veleni/stun) | manuale |
| `data/decks/*.json` | 16 mazzi (espansione delle copie) | generato (`generate_decks.py`) |

**Test** (`godot/tests/`, eseguibili headless):
```bash
cd godot
godot --headless --scene tests/test_allcards.tscn   # risolve tutte le carte trascritte (smoke)
godot --headless --scene tests/test_duel_smoke.tscn  # partita completa
```

**Editor: non esiste.** Editing oggi = Excel + rigenera, oppure JSON a mano (rischioso).

---

## 3. Schema dei dati (riferimento preciso per l'editor)

### 3.1 Anagrafica — `card_pool.json` (una carta)
| Campo | Tipo | Note per l'editor |
|------|------|-------------------|
| `id` | int | chiave univoca; **read-only** in modifica, generato per le nuove |
| `name` | string | testo |
| `char` | string (enum) | dropdown: `Ronin, Warrior, Musashi, Gen. Ability, Weapon, …` |
| `amount` | int | 1–6 |
| `rank` | string (enum) | `Wood < Steel < Gold < Jade` oppure `-` (Core). Usa `Domain.RANK_COLORS` per il colore |
| `initiative` | string | numero / `=` (istantanea) / `-` (nessuna) / lista (`"6/7"`, `"7,6,5,4,3"`) |
| `focus` | int | 0–3 (costo) |
| `keywords` | array[string] | multi-select con **autocomplete** (vedi §3.3) |
| `type` | string (enum) | `attack/defence/meditation/core/other` — derivato dai keywords; mostralo e ricalcolalo |

### 3.2 Geometria/effetti — `geometry.json` ("Schema v2", chiave = ID stringa)
> ⚠️ Il file `data/cards/GEOMETRY_SCHEMA.md` documenta un **vecchio schema v1**
> (`range/wounds/dirs`) che **non corrisponde** ai dati reali. Lo schema reale è
> sotto; **aggiornare GEOMETRY_SCHEMA.md** è parte della Fase 1.

```jsonc
"55": {
  "name": "COLPO DELLA FENICE FIAMMANTE",
  "type": "attack",                 // attack | defence | meditation | core
  "kamae_req": "aggression",        // aggression | balance | determination (opz.)
  "move": { "opts": [ { "atoms": [
      { "t": "step", "dir": 0, "n": 1, "opt": false },  // t: step|rot; dir 0-5 (0=fronte,orario), -1=indietro; n=quantità; opt=facoltativo
      { "t": "rot",  "n": 2, "opt": true }
  ] } ] },
  "attack":  { "cells": [ { "d": 0, "k": 1, "w": 2 }, { "d": 1, "k": 1, "w": "exec" } ] },
                                    // d=direzione relativa 0-5, k=anello, w=ferite (int) | "exec" | "bleed"
  "defence": { "cells": [ { "d": 0, "k": 1, "v": 1 } ] },  // v=valore blocco
  "counter": [8],                   // iniziative di contrattacco (opz.)
  "effects": [ { "do": "push", "n": 1, "when": "on_hit", "kamae": "balance",
                 "alt": "a", "to": "aggression", "focus_cost": 1 } ],
  "note": "annotazioni / incertezze di trascrizione"
}
```
`characters{}` (in fondo a `geometry.json`): per personaggio → `{card_id, name, wound_limit, hand_limit, weapons[]}`.

### 3.3 Vocabolari controllati (per dropdown/validazione)
- **`type`**: `attack, defence, meditation, core, other`
- **`atom.t`**: `step, rot`
- **`w` (ferite)**: intero, oppure `"exec"`, `"bleed"`
- **`kamae` / `kamae_req` / `to`**: `aggression, balance, determination`
- **`effects[].do`** (23 verbi presenti nei dati — usarli come autocomplete):
  `block_initiative, cancel_abilities, cancel_movement, change_ai_behaviour,
  change_kamae, discard_self, draw, focus, foe_discard, foe_lose_focus,
  foe_stun, hobble, push, reduce_damage, replace_wound_bleed, reset_deck,
  rotate_target, search_draw, spend_focus, stun_self, swap_positions,
  switch_kamae`
- **`keywords`** noti: `Attack, Defence, Meditation, Core, Instant,
  Instant Replacement, Instant Additional, Range2…, Weapon, Prepared, Bushido`

### 3.4 Immagine — `card_images.json`
`by_id[<id>] = "warrior/warrior_01.webp"` (relativo a `res://assets/cards/`).
Naming: `{character}/{character}_{NN}.webp`.

---

## 4. Decisioni da prendere a inizio sessione (NON re-derivare: confermare con l'utente)

> **Decise (sessione 2026-06-20):** §4.1 → **(b) overlay** (`card_pool_overrides.json`);
> §4.2 → **scena standalone** (`CardEditor.tscn`); §4.3 → **sì, sola lettura prima**;
> §4.4 → **editor geometria visuale IN SCOPE** (M3, dopo le basi); §4.5 → **immagini
> con import/crop IN SCOPE** (M4).

Queste scelte cambiano l'architettura; vanno fissate **prima** di Fase 2.

1. **Sorgente di verità per l'anagrafica.** `card_pool.json` oggi è *generato*
   dall'Excel: se l'editor ci scrive sopra, una rigenerazione lo sovrascrive.
   Opzioni: (a) l'editor diventa autoritativo e si abbandona la rigenerazione da
   Excel; (b) l'editor scrive un file **overlay** di override applicato in
   `CardDB` sopra il pool generato; (c) l'editor modifica solo `geometry.json`
   (già hand-authored, nessun conflitto) e lascia l'anagrafica all'Excel.
   **Raccomandato: (b) overlay** — non distrugge la pipeline esistente.
2. **Forma dell'editor.** Scena di gioco standalone (`CardEditor.tscn`, lanciabile
   dal Menu e headless-testabile) **vs** plugin `@tool` nell'editor Godot.
   **Raccomandato: scena standalone** — coerente con il resto, testabile, e gira
   anche fuori dall'editor.
3. **Ambito Fase 1.** Solo-lettura (browser + inspector) prima, scrittura dopo?
   **Raccomandato: sì**, sblocca subito valore con rischio zero.
4. **Editor geometria visuale** (disegnare arco attacco/difesa sul nido d'ape):
   in scope ora o fase successiva? È la parte più costosa.
5. **Gestione immagini**: l'editor deve solo *associare* un'immagine esistente, o
   anche importarla/ritagliarla? (Il ritaglio da PDF resta in `tools/`.)

---

## 5. Architettura raccomandata

- **`scenes/CardEditor.tscn` + `CardEditor.gd`** — scena standalone, voce nel Menu.
- **Lettura** via `CardDB` (già carica tutto). **Scrittura** via un nuovo
  `engine/CardStore.gd`: carica/serializza i JSON, applica modifiche, salva con
  scrittura atomica + backup `.bak`, mantiene chiavi ordinate per diff git puliti.
- **Anteprima** riusa `CardView.gd` (immagine o scheda data-driven).
- **Validazione** in `engine/CardValidator.gd` (logica pura, testabile headless):
  regole in §6 Fase 3.
- **Tester** riusa `Duel.gd`/`GameState.gd` per risolvere la carta contro un dummy.
- Persistere il path dei file come costanti già presenti in `CardDB.gd`.

---

## 6. TODO (a fasi, spuntabili)

### Fase 0 — Setup (mezza giornata) ✅
- [x] Confermare le **Decisioni §4** con l'utente.
- [x] Aggiornare `data/cards/GEOMETRY_SCHEMA.md` allo **Schema v2** reale (§3.2).
- [x] Scheletro `scenes/CardEditor.tscn` + voce nel `Menu.tscn`.
- [x] `engine/CardStore.gd` con load/save atomico + `.bak` (no UI ancora) + test headless
      (`tests/test_cardstore.tscn`). CardDB ora applica l'overlay `card_pool_overrides.json`.

### Fase 1 — Browser & Inspector (sola lettura) ✅
- [x] Lista carte con filtri (per `char`, `type`, `rank`, testo libero su `name`).
- [x] Pannello dettaglio: tutti i campi anagrafici + geometria + immagine.
- [x] Anteprima carta via `CardView` accanto al dettaglio.
- [x] Indicatori "carta senza geometria" / "senza immagine".

> **Stato 2026-06-20:** M1 (Fase 0+1) completata. Test headless verdi su Godot 4.6:
> `test_cardstore`, `test_cardeditor_smoke`, `test_allcards` (regressione ok).
> Prossimo: Fase 2 (editing anagrafica via overlay).

### Fase 2 — Editing anagrafica (scrittura) ✅
- [x] Form editabile dei campi `card_pool` con widget tipizzati (dropdown per
      `char/rank`, SpinBox per `amount/focus`, LineEdit per `name/initiative`,
      keywords con campo testo + autocomplete da vocabolario noto).
- [x] Ricalcolo automatico di `type` dai `keywords` (regola validata su 313/313 carte).
- [x] Salvataggio overlay (§4.1b) `card_pool_overrides.json` + `.bak`; per le carte
      Excel si salva solo il **delta** dai valori originali, le carte-utente per intero.
- [x] Creazione **nuova carta** con allocazione `id` libero (intervallo id-utente ≥ 10000).
- [x] Duplica carta (copia con id nuovo, marcata "(copia)").

> **Stato 2026-06-20:** M2 in corso. Fase 2 completata; resta la Fase 3 (validazione).
> `CardDB.apply_override()` aggiorna la vista runtime senza riavvio (gestisce carte
> nuove e spostamento bucket per cambio `char`). Test headless verdi su Godot 4.6.

### Fase 3 — Validazione ✅
- [x] `CardValidator.gd` + test. Regole: attacco/difesa senza celle (se la
      geometria è avviata); `kamae_req`/`kamae`/`to` fuori vocabolario; `do` di
      effetto sconosciuto; keyword sconosciuta; immagine mancante; `type`
      incoerente coi keywords; `id` duplicato; `rank` non valido.
- [x] Warning/errori inline nell'inspector (⚠ non bloccanti vs ⛔ bloccanti),
      aggiornati live mentre editi anagrafica e geometria.

> **Stato 2026-06-20:** M2 completata (Fase 2+3). Validazione live integrata in
> `CardEditor`. Test headless `test_cardvalidator` verde su Godot 4.6.

### Fase 4 — Editor geometria/effetti  ✅
- [x] Editor `move` (sequenze "OPPURE" di atoms step/rot, dir/n/opt) **drag & drop**
      (frecce nere=obbligatorie / bianche=facoltative, rotazioni).
- [x] Editor `attack`/`defence` **visuale** sul nido d'ape (modello a 6 direzioni,
      §4.4): si **trascinano** ferite/esecuzione/sanguinamento/scudi sugli esagoni;
      `d`/`k` dedotti dalla posizione. Clic destro = svuota cella.
- [x] Editor `effects` come lista ordinata con `do` da autocomplete (23 verbi) +
      campi contestuali (`n, when, kamae, alt, to, focus_cost`).
- [x] Editor `counter`, `kamae_req` (token colorati), `note`.

> **Stato 2026-06-20:** M3 completata — editor geometria visuale completo
> (`GeometryEditor.gd`, incorporato in `CardEditor`). Salvataggio su `geometry.json`
> con `.bak`, int puliti (no float `2.0`) e diff minimi. Test headless verdi su
> Godot 4.6 (`test_geometry_editor`: round-trip move/attack/effects + mutatori).

### Fase 5 — Anteprima geometria & Tester
- [ ] Disegno dell'arco attacco/difesa sul nido d'ape (read-only render).
- [ ] Bottone "Simula carta": risolve la carta in un `Duel` con avversario dummy
      e mostra l'esito (riusa engine, niente GUI 3D).

### Fase 6 — Immagini & rifiniture
- [ ] Associare/cambiare l'immagine di una carta (picker dai file in `assets/cards`).
- [ ] (Opz.) integrare il flusso di import/crop da PDF (oggi in `tools/`).
- [ ] Undo/redo nell'editor.
- [ ] Aggiornare `tests/test_allcards` se cambia la struttura dati.

---

## 7. Roadmap / milestone

| Milestone | Contenuto | Esito |
|-----------|-----------|-------|
| **M1 — Visione** | Fase 0 + 1 | Posso *vedere* ogni campo di ogni carta con anteprima. Rischio zero. |
| **M2 — Editing dati** | Fase 2 + 3 | Posso *modificare/creare* carte (anagrafica) in sicurezza, con validazione. |
| **M3 — Geometria** | Fase 4 + 5 | Posso editare attacco/difesa/effetti e *simulare* la carta. È il cuore di "ogni aspetto". |
| **M4 — Completo** | Fase 6 | Immagini, undo/redo, rifiniture. Editor pienamente self-service. |

Ordine di priorità = ordine delle milestone. M1→M2 danno già il 70% del valore.

---

## 8. Rischi & trappole (note dalla ricognizione)

- **Rigenerazione vs editing**: vedi §4.1 — il rischio principale. Decidere prima.
- **`GEOMETRY_SCHEMA.md` è obsoleto** (schema v1 ≠ dati v2 reali). Non fidarsene
  finché non aggiornato.
- **Solo 54 carte su 303 hanno geometria**; l'editor deve gestire bene il caso
  "geometria assente" (crearla da zero).
- **Offset `dirs`/celle attacco sono "best effort"** (annotati nelle `note`):
  l'editor visuale è proprio l'occasione per correggerli — prevedere il campo `note`.
- **Scrittura JSON**: ordinare le chiavi e formattare in modo stabile, altrimenti
  ogni salvataggio produce diff git enormi. Sempre `.bak` prima di sovrascrivere.
- **`id` come chiave**: in `card_pool` è int, in `geometry.json`/`card_images.json`
  è stringa. Normalizzare nello store.

---

## 9. Mappa rapida dei file (per la nuova sessione)

```
godot/engine/CardDB.gd          # carica tutti i dati carte (punto d'ingresso lettura)
godot/engine/Domain.gd          # enum/colori/ordini (CardType, RANK_COLORS)
godot/scenes/CardView.gd        # render carta → riusare per anteprima
godot/scenes/HUD.gd             # _build_kamae_tree → riferimento editor a nodi
godot/data/cards/card_pool.json # anagrafica
godot/data/cards/geometry.json  # geometria/effetti (Schema v2)
godot/data/cards/card_images.json
godot/data/cards/SCHEMA.md             # anagrafica (aggiornato)
godot/data/cards/GEOMETRY_SCHEMA.md    # ⚠️ DA AGGIORNARE a v2
godot/tools/generate_cards.py   # pipeline Excel→pool (occhio alla §4.1)
godot/tests/test_allcards.tscn  # smoke test (godot --headless --scene ...)
```

*Documento generato come handoff. Aggiornarlo man mano che le fasi avanzano.*
