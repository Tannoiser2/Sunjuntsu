# Handoff — Completamento modalità "Solo" (mazzi IA)

Documento di ripartenza per **una sessione nuova** (il lavoro rimasto richiede
di *leggere* le scansioni delle carte, cosa che va fatta con budget-immagini
fresco — vedi §5).

Ultimo aggiornamento: 2026-07-04, alla versione **0.99.4**.

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

---

## 2. Stato: DA FARE ⏳ (richiede lettura scansioni → sessione nuova)

### A. Mazzo GENERICO, carte 010-041 (attacchi/difese/distanza)
- Fonte: `Tabelle_Materiali/Senjutsu/CARTE/Carte Solo generiche.pdf`
  (6 pagine, 9 carte/pagina). Batch 1 (001-009) già fatto.
- **Schema ID**: continuare da **1006** in su, un'entry per carta DISTINTA
  (stesso nome+iniziativa+contenuto ⇒ una entry con `amount` = n. copie;
  iniziative diverse ⇒ entry separate). Le 6 Incubo generiche (COLPO POTENTE,
  FENDENTE SELVAGGIO, SABBIA NEGLI OCCHI, FURIA SANGUINOSA, COLPO IN AFFONDO,
  ecc.) esistono già come 994-999 nel pool.
- Aggiungere in `card_pool.json` (append testuale, NON `json.dump` che
  riformatta tutto — vedi §4) + geometria in `geometry.json` (round-trip
  `json.dump(indent=1)` è stabile per geometry.json).

### B. Rifinitura Ronin (901-905) e Guerriero (911-914) parziali
Geometrie "approssimate" trascritte in una sessione vecchia; note dicono
"trascrizione parziale/approssimata". Riverificare celle/effetti dalle
scansioni `Carte Solo personaggi.pdf` (pagina 1 Ronin, pagina 2 Guerriero).
Mappa: 901=CHIATTA DI BUOI, 902=DIFESA D'ACCIAIO, 903=AFFONDO INVERTITO DI
ZANNA, 904=SPAZZATA FEROCE, 905=IL TERRORE(incubo); 911=BLOCCO CINEREO,
912=FALCIATA MONTANTE, 913=ARCO RESPINGENTE, 914=CONCENTRAZIONE RITROVATA.

### C. Wiring del mazzo generico (serve dato mancante)
`solo_deck_for()` NON collega ancora le carte generiche. Per farlo serve la
**tabella di raggruppamento mazzi I-VIII** (quali carte 001-041 stanno in
ciascun mazzo di selezione). Non è nella repo materiali. `CardDB.AI_DECK_COMPOSITION`
ha già i rapporti per personaggio ma non la mappa carta→mazzo. Chiedere
all'utente la tabella (o una foto del regolamento), poi wire + test.

### D. Carta mancante Monaco 949 "Enlighten"
Il pool elenca 949 ma non è tra le pagine scansionate (il Monaco fisico ha 5
carte). Verificare con l'utente se esiste una 6ª carta fisica da scansionare.

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
  `CHANGELOG.md`. Workflow: branch `claude/card-mechanics-roadmap-s7mnr0`,
  draft PR, merge squash, reset da `origin/main`.

## 5. Il muro delle immagini (perché serve una sessione nuova)
Il limite è ~**32 MB di immagini TOTALI accumulate nella conversazione**, non
il singolo file (i ritagli sono ~100 KB). In questa sessione ho letto decine di
scansioni e il budget si è esaurito: ogni nuova immagine viene rifiutata
("media removed / max 32mb"). Una **chat nuova** riparte da zero.
- Trucco di rendering che aiuta (ma non basta se il budget è pieno): PDF→pixmap
  200-300 dpi → PIL scala di grigi + `autocontrast` + un **solo riquadro** per
  volta → salvare **JPEG** q80 (~100 KB). Leggere poche carte per messaggio.
