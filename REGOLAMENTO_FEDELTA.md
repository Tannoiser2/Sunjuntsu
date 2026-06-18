# Senjutsu — Fedeltà al regolamento (obiettivo 1:1)

Fonte autorevole: **Senjutsu 1.5 Edition Rulebook (gennaio 2026)** + Reference Sheet +
Path of the Ronin (regole solo), presenti in `Tabelle_Materiali/Senjutsu/`.
Il regolamento italiano (`Senjutsu-Rule-Book-V1-ITA-web.pdf`) è la **prima edizione**
ed è un PDF solo-immagini: utile per la terminologia, ma la 1.5 EN è più recente e
completa, quindi è la base di riferimento.

Questo file traccia, regola per regola, cosa è già implementato (✅), cosa è parziale
(⚠️) e cosa manca (❌), con la roadmap.

---

## 1. Struttura del turno (rulebook p.6–7, Reference Sheet)

Ordine ufficiale di ogni turno:

1. **Start of turn** — risolvi effetti "At Start of Turn".
2. **Pre-draw** — effetti prima della pesca.
3. **Draw** — pesca **1** carta. Se hai ≥1 ferita sanguinante, prima scarti 1 carta
   dal mazzo. **Mazzo vuoto ⇒ subisci una ferita** (niente rimescolo, edizione 1.5).
4. **After-draw / before-choose** — effetti dopo la pesca.
5. **Choose** — gioca 1 carta coperta (devi poter pagare il focus; devi essere nella
   Kamae richiesta).
6. **Reveal** — scoprite simultaneamente. Paga focus obbligatori, poi opzionali;
   gioca eventuali Instant Replacement; scegli le iniziative variabili; confronta.
7. **Resolve** — risolvi in ordine d'iniziativa (alto→basso). Pareggi: per **tipo**
   (difesa → attacco → meditazione → core); ulteriore pareggio: chi è più in alto
   sulla **traccia vantaggio** sceglie l'ordine.
8. **Discard** — scarta la carta giocata, riporta i core in mano, rientra nel limite
   di mano (scarta in eccesso). Poi effetti "end of turn" (es. Hobble).

Stato:
- ✅ Sequenza programma→rivela→risolvi per iniziativa (interattiva).
- ✅ Pesca 1 a inizio turno; sanguinamento al draw; mazzo vuoto ⇒ ferita; limite mano a fine turno.
- ✅ Pareggio iniziativa per tipo (difesa→attacco→meditazione→core).
- ⚠️ Iniziative **variabili** (difese): scelta velocità semplificata; manca la scelta
   guidata in ordine di traccia vantaggio e l'iniziativa **alternativa** (box) con/senza Kamae/focus.
- ❌ Traccia **vantaggio** (ordine giocatori, tie-break, effetto "Advantage").
- ❌ Instant cards (Additional / Replacement / Instant) e relativi tempi.
- ❌ Core cards che tornano in mano (non modellati a parte).

## 2. Movimento (rulebook p.8–9)

- ✅ Step (frecce dritte) e Rotate (frecce curve), multi-direzione, relativi al facing.
- ✅ **Obbligatorio (icona piena) vs opzionale (icona vuota)** — riallineato carta per
   carta con audit sulle scansioni. `!` nei dati = obbligatorio.
- ✅ Righe gate-ate da Kamae (la mossa è disponibile solo in quella posizione).
- ✅ "then" = sequenza ordinata; stessa riga = ordine/combinazione libera.
- ⚠️ **Collisioni**: il movimento è bloccato dalle celle occupate, ma mancano gli
   effetti regolamentari: contro personaggio (scarta 1, entrambi +1 stun), fuori
   campo (+1 stun), contro terreno (effetto del terreno). E "le mosse obbligatorie
   devono scegliere l'opzione che evita la collisione".
- ⚠️ Mosse obbligatorie non ancora **forzate** nella UI (il giocatore può saltarle).
- ❌ Commit To Hit (se puoi colpire muovendoti/pagando focus, **devi**).
- ❌ Casi struttura carta da rivedere a mano: **#26** (2° passo avanti), **#27**
   (un solo passo bidirezionale obbligatorio), **#33** (passo+rot obbligatori + 2ª rot
   opzionale), **#23** (probabile assenza di movimento).

## 3. Attacchi (rulebook p.10)

- ✅ Bersaglio per griglia esagonale relativa a posizione/facing (schema v2).
- ✅ Effetti: ferita, 2 ferite, sanguinante, esecuzione, effetto asterisco.
- ⚠️ "If Successful" e effetti asterisco: parziali.
- ❌ **Commit To Hit** (regola d'oro).
- ❌ Attacchi a distanza (Range) + Linea di Vista (LoS dai 2 angoli frontali).

## 4. Difese / Blocchi / Contrattacchi (rulebook p.11)

- ✅ Regola ufficiale del blocco (1.5): l'attacco alla **stessa** iniziativa è fermato
   se (1) c'è un blocco nella cella dell'attaccante, **oppure** (2) **ogni percorso più
   breve** attaccante→difensore passa per una cella con blocco. Il **terreno** aggiunge
   un blocco a tutte le iniziative. Rispetta `non_blockable`. Un solo attacco per difesa.
- ⚠️ **Counter**: meccanica implementata (`_try_counter`: il giocatore scarta un attacco
   non-core, l'IA infligge la ferita senza scartare) ma **inerte** finché non trascrivo
   il dato `counter` (velocità) sulle carte difesa.

## 5. Kamae (rulebook p.12)

- ✅ 4 posizioni: Aggressione, Equilibrio, Determinazione, Neutrale.
- ✅ Requisito Kamae per giocare una carta (controllato al Choose).
- ❌ **Albero Kamae** con rami/frecce: "Cambia Kamae su X" scorre lungo i rami; rami
   **rosa** ⇒ +1 focus; "Switch" va diretto (no focus). Le scansioni sono in
   `Tabelle_Materiali/Senjutsu/Tabelle/Senjutsu_Kamae_Cards_1.5_Edition.pdf`.
- ❌ Effetti Kamae mandatori (le righe colorate corrispondenti alla tua posizione).

## 6. Focus (rulebook p.12–13)

- ✅ Costo focus obbligatorio per giocare; carta "svanisce" se non puoi pagare.
- ⚠️ Massimo **3** focus: da verificare ovunque (cap).
- ❌ Focus opzionali su effetti (paghi per attivare la riga).
- ❌ Focus dai rami rosa dell'albero Kamae.

## 7. Status: Ferite, Sanguinamento, Stun, Hobble, Poison (rulebook p.10,13)

- ✅ Ferite / sanguinanti (contano come ferite); sconfitta a ferite ≥ limite.
- ✅ Sconfitta per stun in mano ≥ dimensione mano.
- ⚠️ Stun: presente come contatore; manca "occupa la mano, non scartabile, giocabile
   al posto di una carta a iniziativa 0".
- ❌ **Hobble**: −1 iniziativa per Hobble attivo (min 1), ruota 90° a fine turno e poi
   si scarta; le difese variabili riducono entrambi i valori.
- ❌ **Poison** (carta 002 Crippling Poison) e altri effetti asterisco.

## 8. Altri keyword (rulebook p.14–15)

- ❌ Push / Pull (con collisioni), Swap Positions, Rotate (sul bersaglio), Discard X,
   Search, Advantage, Split Initiative, Targeted Character, Ranged Effects.

## 9. Terreno (rulebook p.16)

- ⚠️ Le celle ostacolo bloccano il movimento e contano per il percorso del blocco.
- ❌ Effetti collisione per tipo (rocce/bambù/carri in fiamme/torii/ciliegio) e regole
   speciali (Torii attraversabile, bambù rimosso se colpito).

## 10. Solo (rulebook p.20–23 + Path of the Ronin)

L'attuale "IA" usa un modello con mano + euristiche proprie. Il regolamento solo è
diverso e molto più preciso:
- ❌ Gli avversari **non pescano e non scelgono**: rivelano la **cima del mazzo**
   (rimescolano gli scarti se vuoto). Niente focus, niente mano.
- ❌ Carte solo con struttura "attacco OR movimento", scelta secondo Commit To Hit.
- ❌ **Priorità di movimento** (tabelle p.23) per stance offensiva/difensiva, range
   preferito, approccio, facing. Tabelle in `Tabelle/solo_AI_tables_v1.xlsx`.

---

## Roadmap (ordine proposto)

1. **Turno & iniziativa fedeli** — ✅ fatto (pesca/scarto/limite mano, pareggi per tipo).
   Resta: traccia vantaggio + iniziative variabili/alternative complete.
2. **Movimento & collisioni 1:1** — collisioni regolamentari, mosse obbligatorie
   forzate, Commit To Hit, fix struttura #26/#27/#33/#23.
3. **Blocchi, percorso più breve, counter** — il cuore del combattimento difensivo.
4. **Albero Kamae & focus** (rami, rosa→focus, switch, cap 3) — da scansioni Kamae.
5. **Status completi** — hobble, stun-in-mano, poison, asterischi.
6. **Keyword** — push/pull/swap/rotate-bersaglio/range/LoS/search/discard.
7. **Terreno** — effetti collisione per tipo + regole speciali.
8. **IA solo fedele** — top-of-deck, priorità di movimento, stance/approccio/range.

Note di onestà: i punti ⚠️/❌ sono semplificazioni note del prototipo. Le icone delle
carte (movimento/gate) sono state riallineate via audit ma alcune restano "DA
VERIFICARE" sul gioco fisico.
