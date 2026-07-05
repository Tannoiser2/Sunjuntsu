# Handoff — Completamento modalità "Solo" (mazzi IA)

Documento di ripartenza per **una sessione nuova** (il lavoro rimasto richiede
di *leggere* le scansioni delle carte, cosa che va fatta con budget-immagini
fresco — vedi §5).

Ultimo aggiornamento: 2026-07-05, alla versione **0.99.6**.

---

## 1. Stato: FATTO ✅

### Mazzi-personaggio Solo (tutti i 13 personaggi disponibili)
Geometria completa in `data/cards/geometry.json`; i nomi/metadati erano già in
`data/cards/card_pool.json`.

| Personaggio | ID pool | PR |
|---|---|---|
| Ashigaru | 976-979 | #92 |
| Hachikō | 933-937 | #92 |
| Yasuke | 916-920 | #93 |
| Wakou | 921-924, 981 | #93 |
| Navigatore (Sailor) | 925-928, 984 | #94 |
| Assassino | 929-932, 987 | #94 |
| Maestro (Master) | 943-947 | #95 |
| Monaco (Monk) | 948, 950-953 | #95 |
| Yojimbo | 963-965 | #96 |
| Onna-Bugeisha | 958-962 | #96 |
| Allievo (Student) | 966-970 | #97 |
| Guerriero — Incubo | 993 | #97 |
| Ninja | 954-957, 990 | (sessione precedente) |

### Meccaniche / fix
- **Sentiero Illuminato #953** (loti + soglie 3/5/7) IMPLEMENTATO (PR #100) +
  fix: le carte `stays_in_play` dell'IA ora entrano in gioco.
- **Doppione Guerriero #915** rimosso; init #993 corretto a "6" (PR #100/v0.99.4).
- **Log** spostato/colorato nella colonna destra (PR #98).
- Virtù Bushido, coppia alleata Ashigaru+Hachikō, ecc. (PR precedenti).

### Mazzo GENERICO — batch 1 (comportamento/meditazione)
Nuovi ID **1001-1005** in pool + geometria (PR #99): Mente Aggressiva (×2),
Mente Risoluta (×3), Mente Rapida (×2), Provocazione, Grido di Guerra.

### Mazzo GENERICO — batch 2 (attacchi/difese/distanza) — v0.99.5
Carte **010-041** trascritte da `Carte Solo generiche.pdf` come **30 entry
distinte**, pool **1006-1035** + geometria (append testuale al pool, load/dump
per la geometria). 22 attacchi + 8 difese; duplicati fusi con `amount` (BLOCCO
DI FIUME ×2 = 1027, BLOCCO DI VENTO ×2 = 1029). Carte a distanza (TIRO DI YUMI
×3 = 1030-1032, FUOCO = 1035) con `targeting` (confronto d'iniziativa) + `range`.
Seconda azione «OPPURE» modellata come `split`. `kamae_req` NON impostato (come
tutte le altre Solo). Offset arco/celle best-effort → note `DA VERIFICARE`.

### Incubo generiche 994-998 — v0.99.5
Aggiunta la **geometria mancante** alle 5 carte Incubo d'attacco (erano solo nel
pool): 994 Wild Swing (FENDENTE SELVAGGIO), 995 Powerful Strike (COLPO POTENTE),
996 Dirt Throw (SABBIA NEGLI OCCHI), 997 Blood Fury Cut (FURIA SANGUINOSA),
998 Dashdown Strike (COLPO IN AFFONDO). Mappate per nome+iniziativa (il numero
FISICO stampato ≠ id pool, annotato nelle note). **999 "Ancient Terror"**
(meditazione Incubo) resta SENZA geometria: non era tra le pagine scansionate —
da verificare con l'utente se esiste la carta fisica.

### Cablaggio mazzo generico nell'IA — v0.99.6
`solo_deck_for()` ora aggiunge le carte generiche (mazzi I-VII) alle carte di
Classe secondo `AI_DECK_COMPOSITION`. La mappa carta→mazzo (`CardDB.GENERIC_DECKS`)
viene dal foglio "groups based on cards" di `solo_AI_tables_v1.xlsx` — che ERA
già nei materiali (`Senjutsu/Tabelle/`), contrariamente a quanto ipotizzato prima.

### Rifinitura carte-personaggio 901-905 / 911-914 — v0.99.5
Ri-verificate dalle scansioni `Carte Solo personaggi.pdf` (Ronin pag.1,
Guerriero pag.2): iniziative pool corrette (Charge 1→6, Steel Block 6,5,4→8-3,
Reverse Carved Fang 1→8, Feral Sweep 3→6, Ember Block 9-5→8-5), valori di blocco
reali (Steel 6/5/4, Ember 8), strutture `split`/«OPPURE» e pattern d'attacco
allineati (Warding Arc = ventaglio 6 celle, ecc.). Offset residui `DA VERIFICARE`.

---

## 2. Stato: DA FARE ⏳

### A. ~~Mazzo GENERICO, carte 010-041~~ ✅ FATTO (v0.99.5, vedi §1)
Le 010-041 sono in pool `1006-1035` + geometria. Le Incubo generiche d'attacco
994-998 hanno ora la geometria. Resta la 999 "Ancient Terror" (vedi D-bis).

### B. ~~Rifinitura Ronin 901-905 / Guerriero 911-914~~ ✅ FATTO (v0.99.5, vedi §1)
Restano solo gli offset arco/celle marcati `DA VERIFICARE` (best-effort): da
confermare sul gioco fisico o con l'editor visuale sul nido d'ape. Punti più
incerti: SPAZZATA FEROCE (904, forma della spazzata), BLOCCO CINEREO (911, se il
valore 8 è solo frontale), direzione del passo di FALCIATA MONTANTE (912).

### C. ~~Wiring del mazzo generico~~ ✅ FATTO (v0.99.6)
La tabella di raggruppamento era in `Senjutsu/Tabelle/solo_AI_tables_v1.xlsx`
(foglio "groups based on cards"). Trascritta in `CardDB.GENERIC_DECKS` e
`solo_deck_for()` ora aggiunge le generiche alle carte di Classe secondo
`AI_DECK_COMPOSITION`. **Resta da PROVARE in Godot** (test non eseguibili in
remoto): aprire `tests/test_solo_decks.tscn` (verifica composizione mazzi per
ogni personaggio) e `tests/test_allcards.tscn` (risolve ogni carta con
geometria, incluse le nuove); poi lanciare una partita Solo e controllare che
l'IA risolva le carte generiche senza errori.
Il mazzo generico Incubo (VIII = 994-998) è definito in `GENERIC_DECKS` ma NON
è ancora pescato da `solo_deck_for()`: va agganciato quando esisterà una
Modalità Incubo esplicita.

### D. Carta mancante Monaco 949 "Enlighten"
Il pool elenca 949 ma non è tra le pagine scansionate (il Monaco fisico ha 5
carte). Verificare con l'utente se esiste una 6ª carta fisica da scansionare.

### D-bis. Carta Incubo generica 999 "Ancient Terror"
Il pool elenca 999 (meditazione, Incubo) ma la carta NON era tra le pagine
scansionate di `Carte Solo generiche.pdf` (che contiene solo 5 Incubo d'attacco,
ora trascritte come 994-998). Verificare con l'utente se esiste la 6ª carta
Incubo generica fisica da scansionare.

### E. Fuori scope (l'utente non possiede le carte)
Kojiro (938-942) e Musashi (971-975).

---

## 3. Convenzioni di mappatura (importanti)
- Gli ID pool NON seguono sempre il numero fisico stampato: mappare per
  **tipo + iniziativa + nome** (il nome EN del pool a volte differisce dal
  titolo IT della scansione, es. Yasuke "Ankle Strike"↔"COLPO DOPPIO").
- Numero fisico Incubo ≠ ID pool (es. Maestro fisica #992 = pool 947; Monaco
  fisica #985 = pool 952; Onna fisica #983 = pool 962).
- Celle attacco: `{d,k,w}` (d=direzione 0-5 da fronte orario, k=anello,
  w=ferite). Difesa: `{d,k,v}` (v=valore blocco). Movimento: atomi `step`
  (`dir` 0=avanti,3=indietro,-1=libero) e `rot`. Il motore riduce tutto a
  step/rot: dettagli incerti marcati `DA VERIFICARE` nelle note.
- Verbi utili: `change_ai_behaviour`, `reset_deck`, `foe_discard`, `push`,
  `swap_positions`, `foe_switch_kamae`, `cancel_movement`, `hobble`,
  `foe_lose_focus`, `state_set`(occultato), `discard_self`.

## 4. Note tecniche file
- `geometry.json`: `json.load` → modifica dict `d['cards']` →
  `json.dump(d, ensure_ascii=False, indent=1)` è **round-trip stabile**.
- `card_pool.json`: NON è round-trip stabile (ha tab misti nei `keywords`).
  Per AGGIUNGERE entry: append **testuale** prima di `\n ]\n}` finale. Per
  RIMUOVERE: taglio testuale dell'oggetto (vedi commit del fix 915).
- Validare sempre: `python3 -c "import json; json.load(open(...))"`.
- Sintassi GDScript: `gdparse <file>.gd` (niente Godot in remoto).
- Ogni PR funzionale: bump `config/version` in `project.godot` + voce in
  `CHANGELOG.md`. Workflow: branch dedicato, draft PR, merge squash, reset da
  `origin/main` (batch 2 fatto su `claude/solo-mode-completion-v39yb2`, PR #101).
- **Non eseguibile in remoto**: `test_allcards.gd`/`test_cardvalidator.gd`
  richiedono Godot. Verificare i dati con `python3 -c "import json; json.load(...)"`
  e, quando possibile, aprire il progetto in locale per lanciare i test headless.

## 5. Il muro delle immagini (perché serve una sessione nuova)
Il limite è ~**32 MB di immagini TOTALI accumulate nella conversazione**, non
il singolo file (i ritagli sono ~100 KB). In questa sessione ho letto decine di
scansioni e il budget si è esaurito: ogni nuova immagine viene rifiutata
("media removed / max 32mb"). Una **chat nuova** riparte da zero.
- Trucco di rendering che aiuta (ma non basta se il budget è pieno): PDF→pixmap
  200-300 dpi → PIL scala di grigi + `autocontrast` + un **solo riquadro** per
  volta → salvare **JPEG** q80 (~100 KB). Leggere poche carte per messaggio.
