# Changelog — Senjutsu (versione digitale 3D)

Tutte le modifiche rilevanti del progetto. Formato ispirato a *Keep a Changelog*;
versioni in [SemVer](https://semver.org/lang/it/) (pre-1.0: in sviluppo).

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
