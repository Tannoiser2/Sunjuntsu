# Changelog — Senjutsu (versione digitale 3D)

Tutte le modifiche rilevanti del progetto. Formato ispirato a *Keep a Changelog*;
versioni in [SemVer](https://semver.org/lang/it/) (pre-1.0: in sviluppo).

## [0.23.0] — 2026-06-18
### Scelta OPPURE interattiva + nuovi verbi effetto
- **OPPURE interattivo**: durante la tua risoluzione, se la carta ha opzioni mutuamente
  esclusive, compare un selettore a pulsanti con l'etichetta di ciascuna opzione; la prima
  è pre-selezionata. La scelta guida quale effetto si applica (`set_option_choice`).
- **Gruppi `alt` rigenerati** dai marcatori "OPPURE" su tutte le carte ri-trascritte di
  Guerriero e Ronin (le core #23/#53 mantengono la struttura hand-crafted verificata).
- **Nuovi verbi effetto** nel motore: `spend_focus` (tutto / tutto-tranne-N / N),
  `foe_lose_focus`, `foe_discard`, `reduce_damage` (persistente, es. Armatura Pesante:
  riduce ogni attacco subito, min 1), `reset_deck` (rimescola le abilità non-meditazione).
  Restano stub dichiarati: `cancel_movement`, `cancel_abilities`, `block_initiative`
  (richiedono timing tra le carte). Nuovo campo `damage_reduction` sul combattente.
- Nuovo test `test_effects` (verbi + presenza gruppi OPPURE). Suite completa verde (10).
  Versione 0.23.0.

## [0.22.0] — 2026-06-18
### Ri-trascrizione completa delle carte del Ronin (dalle immagini)
- **22 carte uniche del Ronin ri-lette dalle immagini** (6 agenti di visione) e riscritte
  in `geometry.json`, stessa legenda icone del Guerriero. Aggiunte molte **iniziative
  divise** (split: parte sopra/sotto a velocità diverse) trascritte fedelmente, **counter**
  (Difesa d'Acciaio ▼6/5/4), **NON BLOCCABILE** (Chiatta di Buoi), `kamae_req` Aggressività
  (Carica del Toro, Vortice Cremisi), asterischi e costi.
- Personaggio Ronin (Ferite 5 · Mano 5 · Mazzo 27) e albero Kamae letti.
- Corretto un errore storico: **Carica del Toro (#26)** colpisce Fronte-Sx/Fronte-Dx (non
  il fronte) e **richiede Aggressività**; aggiornati i test di regressione `test_split`
  (ora usa #24 Vortice Cremisi per lo split a doppio attacco) e `test_combat2`.
- Carta core #23 mantenuta nella struttura OPPURE verificata (le opzioni OPPURE di alcune
  altre carte restano un'approssimazione, annotata: il motore applica tutte le righe).
- Excel `Ronin_carte.xlsx` rigenerato (22 carte + personaggio + Kamae, colonna "Iniz.
  divisa" e "DA VERIFICARE"). Suite test tutta verde. Versione 0.22.0.

## [0.21.0] — 2026-06-18
### Ri-trascrizione completa delle carte del Guerriero (dalle immagini)
- **Tutte le 22 carte uniche del Guerriero ri-lette dalle immagini ad alta risoluzione**
  (5 agenti di visione, legenda icone corretta) e riscritte in `geometry.json`. Corretti
  errori sistematici della vecchia trascrizione a mano:
  - **Aggressività (crisantemo rosso)** vs **costo Focus (4 quadretti arancioni)**: prima
    confusi di continuo, ora distinti.
  - **Kabuto = l'avversario** (es. "Spingi [avversario] 1"), non un'icona generica.
  - **Asterisco** = effetto sul bersaglio (prima letto come "0 ferite").
  - Aggiunti flag **NON BLOCCABILE**, carte **istantanee** (addizione/sostituzione),
    **counter** sulle difese (Blocco Cinereo ▼8), `kamae_req` (Fenice Fiammante = Aggr.),
    costi di gioco (scarti).
- Excel di revisione `Guerriero_carte.xlsx` rigenerato (22 carte + personaggio + Kamae),
  con colonna "DA VERIFICARE" sui punti incerti.
- Importate le carte inglesi (`Tabelle_Materiali/Senjutsu/Carte INGLESE/`) come controprova.
- **Rotazione manuale**: dopo il movimento la pedina del giocatore **mantiene
  l'orientamento** invece di auto-mirare al nemico; la rotazione torna una scelta con
  Q/E (prima ruotava da sola).
- Test invariati e verdi (allcards 44, turnflow, split, multi, combat2, blocks). Alcuni
  effetti senza verbo nel motore restano inerti (annotati). Versione 0.21.0.

## [0.20.0] — 2026-06-18
### Risoluzione sbloccata + anteprima azione al passaggio del mouse
- **Fine dello "stallo" in risoluzione**: dopo aver mosso e visto i bersagli rossi, ora
  **basta cliccare un esagono rosso** per portare a segno l'attacco e chiudere il turno
  (prima il rosso non era cliccabile e si poteva solo premere INVIO, poco scopribile).
- Nuovo **pulsante "Conferma ▶"** visibile durante la tua risoluzione: rende esplicita la
  chiusura dell'azione per **tutte** le carte (movimento puro, meditazione, difesa, non
  solo attacco). Equivale a INVIO / click sul bersaglio.
- **Anteprima sulla mappa al passaggio del mouse**: passando il mouse su una carta in
  mano, la carta si alza e la mappa mostra la sua azione contestuale (giallo = movimento,
  rosso = bersagli); togliendo il mouse, la carta si riabbassa e la mappa torna allo stato
  precedente (selezione attiva, se c'è, o pulita). Solo in pianificazione.
- Refactor: estratto `_draw_overlays_for(card, move_used)` riutilizzato da selezione,
  risoluzione e anteprima hover. Versione 0.20.0.

## [0.17.0] — 2026-06-18
### Status: Azzoppamento fedele (Hobble, regolamento 1.5 p.13)
- L'azzoppamento ora **scade** correttamente: ogni carta ruota di 90° a fine turno e
  viene scartata quando torna diritta (~3 turni attivi). **Non riduce** l'iniziativa nel
  turno in cui lo subisci; poi −1 per ogni azzoppamento attivo (minimo 1). Prima era un
  contatore permanente che valeva anche subito. Modello per-carta (`hobbles`).
- Stun e Poison restano approssimazioni note (vedi REGOLAMENTO_FEDELTA.md §7).
- Nuovo test `test_status` (ciclo di vita azzoppamento). Versione 0.17.0.

## [0.16.0] — 2026-06-18
### Albero Kamae & focus (regolamento 1.5 p.12)
- **Cambio Kamae lungo l'albero**: "Cambia Kamae fino a N" ora funziona davvero — il
  selettore legge l'effetto `change_kamae` dalle carte (prima cercava una chiave al posto
  sbagliato e non appariva mai). Il giocatore sceglie la destinazione lungo i rami; i
  rami **rosa** danno +1 focus (cap 3). L'IA traversa l'albero in automatico.
- **Switch Kamae** ("Passa a Y") resta diretto senza focus; gestito `to:"any"` (≠ neutral).
- Nuovo test `test_kamae` (traversal, focus rami rosa, IA, switch any, cap focus).
  Versione 0.16.0.

## [0.15.0] — 2026-06-18
### Collisioni + Commit To Hit (regolamento 1.5 p.9–10)
- **Collisioni** per push/pull: bersaglio spinto fuori arena → +1 stordimento; contro un
  personaggio → scarta 1 carta dalla mano ed entrambi +1 stordimento; contro terreno →
  effetto del terreno (ostacolo=ferita; bambù=ferita+stordimento e rimosso; carri in
  fiamme=ferita+sanguinante; torii=ferita). Il bersaglio resta nella cella d'origine.
  Push/pull possono colpire i pericoli di proposito. Aggiunto anche il supporto **pull**.
- **Commit To Hit**: se la carta attacco può colpire muovendoti, la conferma del turno è
  bloccata finché non ti posizioni per colpire (helper `attack_can_hit`/`attack_hits_now`).
- Nuovo test `test_combat2` (collisioni + commit-to-hit). Versione 0.15.0.

## [0.14.0] — 2026-06-18
### IA solo fedele al regolamento (top-of-deck)
- L'avversario singolo ora segue le **regole solo ufficiali**: **non pesca e non
  sceglie**, **rivela la cima del proprio mazzo** ogni turno (rimescolando gli scarti se
  vuoto), **niente mano e niente focus** (costi focus/scarto ignorati), salta il passo
  Draw. La carta rivelata finisce negli scarti a fine turno.
- Semplificazioni note: il **movimento** dell'IA usa ancora un'euristica (non le tabelle
  di priorità ufficiali); l'IA usa il **mazzo normale** del personaggio (non le carte
  "solo"/nightmare dedicate). Vedi REGOLAMENTO_FEDELTA.md §10. Versione 0.14.0.

## [0.13.0] — 2026-06-18
### Blocchi fedeli al regolamento 1.5 (p.11)
- **Blocco geometrico 1:1**: un attacco alla stessa iniziativa è parato se (1) c'è un
  blocco nella **cella dell'attaccante**, oppure (2) **ogni percorso più breve**
  attaccante→difensore passa per una cella con blocco. Il **terreno** è un blocco a
  tutte le iniziative; rispettato il flag `non_blockable`; un solo attacco per difesa.
  (Prima: "se la velocità combacia, para tutto" — ignorava la geometria.)
- **Contrattacco**: meccanica `_try_counter` agganciata (giocatore scarta un attacco
  non-core; IA infligge la ferita) — inerte finché non trascrivo il dato `counter`.
- Test blocchi riscritto per validare percorso più breve, terreno e copertura della
  cella dell'attaccante. Versione 0.13.0.

## [0.12.0] — 2026-06-18
### Verso il regolamento 1:1 (regolamento ufficiale 1.5 acquisito)
- **Fonte regole**: trascritto il **Senjutsu 1.5 Rulebook** (gennaio 2026) + Reference
  Sheet + regole solo dal repo `Tabelle_Materiali/Senjutsu/`. Aggiunto
  `REGOLAMENTO_FEDELTA.md`: spec autorevole del turno/combattimento + analisi degli
  scostamenti (✅/⚠️/❌) e roadmap verso il 1:1.
- **Struttura di turno fedele (1.5)**: si **pesca 1 carta a inizio turno** (non si
  riempie la mano); il **sanguinamento** scarta 1 carta al passo Draw; **mazzo vuoto ⇒
  ferita** (niente rimescolo); il **limite di mano** si applica a fine turno (scarto in
  eccesso). Pareggi d'iniziativa risolti per **tipo** (difesa→attacco→meditazione→core).
- **Movimento 1:1 con le carte**: ripristinata la distinzione **obbligatorio (icona
  piena) vs opzionale (icona vuota)** carta per carta dagli audit sulle scansioni
  (prima erroneamente "tutto opzionale"). Restano da rivedere a mano #26/#27/#33/#23.
- Test aggiornati (pesca a inizio turno).

## [0.11.0] — 2026-06-18
### Cambiato (sequenza di turno fedele + correzioni movimento)
- **Sequenza di turno fedele al regolamento**: ora **programmi una carta coperta** (1° click anteprima, 2° click programma), poi **rivelazione** simultanea, poi **risoluzione nell'ordine d'iniziativa**. Al tuo turno di risoluzione **muovi** (esagoni gialli, Q/E ruota) e poi **INVIO** per attaccare/risolvere. L'IA agisce al suo turno. Niente più movimento/risoluzione immediati durante la sola selezione.
  - `Duel`: risoluzione a passi (`begin_resolution`/`await_resolution`/`resolve_current`) con segnale di rivelazione; percorso sincrono mantenuto per i test.
  - `Arena`: macchina a fasi (pianificazione/risoluzione); il movimento sulla board è abilitato solo durante la tua risoluzione.
- **Correzioni ai movimenti** (audit carta-per-carta sulle scansioni): le **rotazioni sono opzionali** (non obbligatorie), e alcune righe-movimento "libere" erano state gate-ate per errore — corretti i gate di **#34, #72, #113** e il passo avanti di **#107** (segnalato dall'utente).
- Test del flusso interattivo (`tests/test_interactive.tscn`).

## [0.10.0] — 2026-06-18
### Aggiunto (re-trascrizione fedele delle carte + meccaniche — punto "rework")
- **Schema dati v2** (`data/cards/geometry.json`): attacchi/difese descritti **esagono per esagono** (`cells`: direzione relativa, anello, ferite / valore di blocco) invece di `dirs`+ferite uniformi; lista **`effects`** ordinata con finestra (`on_hit`/`always`), gate Kamae per riga e **costo focus opzionale**; `play_cost` (focus + "scarta N carte"); `timing` per le carte istantanee/persistenti.
- **Re-trascrizione di tutte le 44 carte** Guerriero+Ronin rilette dalle scansioni ad alta risoluzione dei PDF, dopo che la verifica aveva trovato errori diffusi (vedi report): archi d'attacco, componenti di movimento mancanti, gate Kamae, e soprattutto i **costi in focus** (prima letti come guadagni).
- **Motore aggiornato** (`Duel`): risoluzione per celle d'attacco con ferite per-esagono; interprete effetti (spinta, sanguinamento, sostituisci-ferita, focus, azzoppa, ruota-bersaglio, pesca, cambia/passa Kamae) con gate e alternative "OPPURE"; effetti esotici (riduci danno, annulla movimento, intervallo blocco) registrati come "non ancora simulati".
- **Overlay arena** dei bersagli allineato alle celle v2.
- Test deterministici (`tests/test_duel_smoke.tscn`).

> **DA VERIFICARE sul gioco fisico** (segnati con `note` nei dati): alcuni diagrammi a 2 anelli e valori di blocco (#55 Fenice, #24 Vortice, #63/#118 difese, #71 Naginata) — le scansioni non distinguono sempre esagoni "bordo" da "angolo". La Testata (#64) è confermata dall'utente.

## [0.9.0] — 2026-06-18
### Aggiunto (blocchi / iniziativa variabile — punto 3)
- **Blocco fedele per aggancio di velocità**: una difesa rivelata para l'attacco avversario solo se la sua velocità d'iniziativa **scelta combacia** con quella dell'attacco (non più "para il primo attacco" a caso).
- **Iniziativa variabile risolta**: le difese con valore variabile (es. *Ember Block* `9,8,7,6`, *Steel Block* `7,6,5,4,3`, *Fend* `5,4,3,2`) scelgono automaticamente il valore che aggancia l'attacco in arrivo; al netto degli azzoppamenti. `Domain.initiative_options()` enumera i valori selezionabili.
- **Velocità del turno centralizzata** (`Duel._resolve_chosen_speeds`): l'ordine d'iniziativa e il blocco usano la stessa velocità scelta; il log indica a che velocità avviene la parata.
- **Test headless** del blocco (`tests/test_blocks.tscn`).

> In corso (punto 4): scelta da parte del giocatore del valore d'iniziativa variabile e costi focus opzionali (rami loto). Le carte *istantanee* (finestre di reazione) restano da implementare.

## [0.8.0] — 2026-06-18
### Aggiunto (vincoli Kamae delle carte — punto 2)
- **"Passa a [Kamae]"**: switch diretto della posizione in risoluzione (anche gated da una Kamae); trascritto per le carte Guerriero che lo prevedono.
- **Giocabilità gated da Kamae** (`kamae_req`): meccanismo che impedisce di giocare una carta fuori dalla Kamae richiesta (rispettato anche dall'IA).
- **Movimento gated da Kamae**: il motore `Move` filtra i passi/rotazioni in base alla Kamae corrente (campo `kamae` sugli atomi).

> In corso: trascrizione carta-per-carta dei gate Kamae delle singole righe-effetto (le barre colorate) per Guerriero/Ronin — da verificare sul gioco fisico.

## [0.7.0] — 2026-06-18
### Aggiunto (fedeltà alle regole)
- **Movimento fedele alla carta** (`engine/Move.gd`): passi direzionali (avanti/indietro, relativi al facing), rotazioni, opzionale/obbligatorio, alternative "oppure". Le celle muovibili sono quelle della carta scelta; `Q/E` cicla solo i facing legali.
- **Iniziativa fedele**: risoluzione per velocità decrescente → tipo carta (Difesa→Attacco→Meditazione→Base) → posizione Kamae; iniziativa **variabile** (es. "6-2") e modificatore **Azzoppato**.
- **Stato Kamae**: posizione dell'anello (Aggressività/Equilibrio/Determinazione/Neutra) tracciata e mostrata; alberi Kamae trascritti (`data/cards/kamae_trees.json`).
- **Cambio Kamae interattivo**: selezionando una carta con "Cambia Kamae" appare il selettore con le posizioni raggiungibili lungo i rami; i rami rosa danno focus (`engine/Kamae.gd`).

## [0.6.0] — 2026-06-18
### Corretto / Aggiunto
- **Board corretta**: esagono di raggio 3 (37 celle, colonne 4-5-6-7-6-5-4), come il gioco fisico.
- **Griglia e miniature più grandi**; miniature scalate in proporzione agli esagoni.
- **Calibrazione live** mappa↔griglia nell'arena: `+`/`−` scala, frecce spostano la mappa, `R` reset camera (valori mostrati nell'HUD).

## [0.5.0] — 2026-06-18
### Aggiunto
- **Board reale**: esagono di raggio 3 (37 celle, colonne 4-5-6-7-6-5-4) come il gioco fisico.
- **Mappa reale** (`assets/maps/arena.webp`, da Senjutsu/MAPPE) come piano texturizzato, con griglia esagonale sovrapposta; allineamento calibrabile (`hex_size`, `map_world_size`, `map_offset`, `map_y_rotation`).
- **Miniature 3D** (`.obj`, da Senjutsu/Miniature) per Guerriero e Ronin, scalate automaticamente.
- **Carte vere in mano**: `data/cards/card_images.json` mappa Card ID → immagine ritagliata reale (niente più segnaposto).
- **Facing/archi**: orientamento dei combattenti (0–5); gli attacchi colpiscono l'arco trascritto ruotato col facing; rotazione del giocatore con Q/E e anteprima dell'arco; l'IA si orienta verso l'avversario.
- **Mazzo Ferite** (`data/cards/wounds.json`): ferita/sanguinante/stordimento/veleni; sanguinamento (scarto dal mazzo), limite ferite effettivo, sconfitta per stordimento.

## [0.4.0] — 2026-06-18
### Aggiunto
- **Trascrizione geometria/effetti carte** dalle immagini (verificata col numero stampato = Card ID): mazzi **Guerriero** e **Ronin** completi (44 carte) + carte personaggio (limite ferite/mano, armi).
- Il motore usa la geometria: portata/reach, n. ferite, sanguinante, focus, spinta, blocco.

## [0.3.0] — 2026-06-17
### Aggiunto
- **Risoluzione del combattimento** (`engine/Duel.gd`): sequenza del turno 1.5 — pesca → scelta → rivelazione → focus → iniziativa → attacco/blocco/meditazione → ferite → sconfitta → riordino.
- **IA modalità solo** (`engine/AI.gd`): euristica per portata/tipo carta + avvicinamento.

## [0.2.0] — 2026-06-17
### Aggiunto
- **Dati carte**: pool da Excel (303 carte) e **mazzi autorevoli** dal foglio Custom Decks (16 mazzi).
- **HUD mano** con le carte; estrazione immagini carte dai PDF (3×3 per pagina).
- **Export Web (HTML5)** e deploy automatico su **GitHub Pages**.

## [0.1.0] — 2026-06-17
### Aggiunto
- Scaffold iniziale: progetto **Godot 4.6**, arena esagonale 3D procedurale, camera orbitale, pedine, menu; separazione logica/presentazione; documento di design.
