# Changelog — Senjutsu (versione digitale 3D)

Tutte le modifiche rilevanti del progetto. Formato ispirato a *Keep a Changelog*;
versioni in [SemVer](https://semver.org/lang/it/) (pre-1.0: in sviluppo).

## [0.85.0] — 2026-07-03
### Alberi Kamae: tutti i 13 personaggi, archi a senso unico, quinta Kamae "Distanza"
- **Ri-verifica sugli scan di tutte le carte-albero**: le doppie frecce
  stampate sono transizioni A SENSO UNICO — lo schema le ignorava (campo
  nuovo `dir: true` sugli archi; `Kamae._adj` le rispetta). Trovati e
  corretti nei 4 alberi base: **arco fantasma** determination—aggression
  del Ronin (non esiste sulla carta), **archi mancanti**
  balance—determination di Guerriero e Maestro, e le direzioni di
  Guerriero (loto→Det, loto→Equil, Det→Neutrale), Ronin
  (Neutrale→Aggressività), Allievo (Det→loto, Equil→Neutrale).
- **Trascritti i 9 alberi mancanti** (Assassino, Ninja, Onna-Bugeisha,
  Yojimbo, Ashigaru, Monaco, Navigatore, Wakou, Yasuke) dagli scan _02 —
  prima questi personaggi non potevano cambiare Kamae (albero vuoto).
  Hachikō, correttamente, non ha albero: usa flip_kamae (#247).
- **Quinta Kamae "Distanza"** (§3.22, CHIUSA): il nodo onda blu
  sull'albero del Navigatore. `Domain.Stance.DISTANCE` + slug/nomi,
  ammessa nei gate; `kamae_req: "distance"` su #279/#280/#281.
- **`Kamae.change_targets` riscritta**: espansione a livelli pulita
  (via il segnaposto `_steps_to`=99), sensi unici rispettati, focus
  massimo per destinazione corretto.
- **Fix slug**: `kamae_tree_for(character.to_lower())` non trovava gli
  alberi di Onna-Bugeisha (stesso bug dei mazzi in v0.84.0) — ora
  `deck_slug_for` ovunque (Arena, Duel, MatchProtocol).
- L'HUD mostra già lo scan dell'albero con i marcatori dai dati: la
  Distanza appare da sola; selettore Kamae esteso alla quinta stance.
- **Controprova sui PDF ad alta risoluzione** (Tabelle_Materiali/CARTE):
  3 correzioni rispetto alla prima lettura dagli scan webp — Yojimbo non
  ha frecce (era il disegno della tigre), la giunzione del Maestro è una
  Y dal loto (niente det—balance diretto), il gambo di Yasuke si biforca
  da Determinazione (det—agg e det—bal, non agg—bal). Gli altri 10
  alberi confermati.
- Test: 9 casi nuovi su direzioni/fantasma/focus/Distanza/roster.

## [0.84.0] — 2026-07-03
### Selezione dei combattenti con ritratti + ritratti nell'HUD
- **13 ritratti ufficiali** (da Tabelle_Materiali/Senjutsu/Personaggi,
  rinominati dall'utente) processati in `assets/portraits/<slug>.webp`
  (512px, alpha). Hachikō non ha ritratto nei materiali: la UI mostra
  l'iniziale. Musashi/Kojiro esclusi (fuori scope permanente).
- **Menu → selezione combattenti**: premendo Solo o 1v1 si apre la
  griglia dei 14 personaggi (ritratto + nome italiano); si sceglie prima
  il combattente del Giocatore 1 e poi quello del Giocatore 2/IA, con
  "Indietro" per annullare. La scelta finisce in `Domain.selected_chars`;
  vuota = coppia storica Warrior/Ronin (test e avvii diretti invariati).
- **HUD**: ritratti dei contendenti agli angoli in alto (P1 a sinistra
  bordo vermiglio, P2 a destra bordo blu, stessa convenzione del
  controller telefono), tooltip col nome; testo della barra centrato.
- **Slug unificati**: nuovo `CardDB.deck_slug_for` (Onna-Bugeisha →
  onna_bugeisha, Hachiko → hachik) usato da Arena per mazzi/miniature —
  prima i personaggi non-base avrebbero caricato un mazzo VUOTO
  (to_lower non combaciava con lo slug del mazzo). `portrait_for` per i
  ritratti. Pedine senza miniatura → placeholder già esistente.
- **Controller telefono**: `portraitFile` esteso a tutto il roster
  (prima solo Ronin/Guerriero); rimossi i vecchi png duplicati.
- Rimosso il commento obsoleto "Jin Sakai da aggiungere" (fuori scope).

## [0.83.0] — 2026-07-03
### Regola Hachikō completa: flip_kamae e immunità (carte-regola #245/#233/#247)
- **`flip_kamae`** (§3.15, "VOLTA LA CARTA KAMAE"): la carta Kamae di
  Hachikō (#247) ha due facce — **Determinazione e Aggressività** (scan
  forniti dall'utente) — e si cambia solo voltandola. Nuovo verbo che
  alterna le due facce dichiarate sulla scheda personaggio
  (`kamae_flip`); sostituisce l'approssimazione `switch_kamae to:any` su
  #248/#252/#253 (faccia attacco e difesa). Chiude §3.15.
- **Immunità di personaggio** (`immunities` sulla scheda): Hachikō non
  può essere obbligato a scartare carte/focus, a cambiare Kamae, né a
  farsi guardare la mano — i verbi foe_* indicati non hanno effetto su
  di lui (generico: vale per qualsiasi personaggio futuro).
- Registrate in nota le regole non ancora cablate (compagno a 2 pedine,
  #233): mazzo esaurito → rimescola senza ferita; stordimenti mischiati
  nel mazzo e messi in gioco alla pescata; sconfitta a 2 stordimenti in
  gioco; risolve solo carte abilità; Kamae iniziale scelta dall'Ashigaru.
- Nota su CardStore: il presunto bug dei diff-fantasma a tab NON è
  riproducibile col codice attuale (save_geometry scrive già 1-spazio,
  formato del repo) — probabile artefatto di una build vecchia; da
  riverificare solo se ricompare.

## [0.82.0] — 2026-07-02
### Fase 4 (parte 2) — doppia faccia Hachikō, Disperazione derivata, anti-sconfitta, trappole, ricorsione
- **Carte a doppia faccia** (§3.14, Hachikō): nuovo campo `face_defence`
  — la faccia DIFESA con iniziativa/movimento/effetti propri. Scelta in
  pianificazione (`Duel.plan_card(i, id, "defence")`): con la faccia
  difesa i campi sostituiscono quelli della carta e il tipo diventa
  `defence` (`_planned_type`/`_planned_geom` usati in tutta la
  risoluzione: velocità, blocchi, counter, effetti, ordine). Ristrutturate
  le **9 carte Hachikō #248–#256**: gli effetti/movimenti della faccia
  difesa, prima schiacciati nei campi condivisi o solo in nota, ora sono
  al posto giusto. UI di scelta faccia non ancora presente ("VOLTA LA
  CARTA KAMAE" resta approssimato: serve la carta-regola Kamae di Hachikō).
- **Disperazione = stato DERIVATO** (carta-regola #292 fornita
  dall'utente): attiva finché l'Onna-Bugeisha ha **3+ ferite/sanguinanti**.
  Dichiarata sulla scheda personaggio (`derived_states`) e calcolata da
  `Fighter.gate_states()` a ogni valutazione di gate — chiude la domanda
  aperta n.1: nessuna carta la attiva, deriva dal conteggio ferite.
- **Anti-sconfitta** (§3.26, #318): `play_when: "defeated"` — la carta si
  gioca d'ufficio quando la sconfitta arriverebbe dalle ferite: ferite
  azzerate, mazzo ricostruito se vuoto (3 a caso dagli scarti),
  `limit_set {"wound": 1}` (valori assoluti), resta in gioco.
- **Ricorsione da scarto** (§3.27, #264): `on_foe_discard:
  "return_to_play"` — scartata da un effetto avversario, il proprietario
  paga 1 focus e la mette in gioco.
- **Trappole sulla griglia** (§3.28, #170 + carta-regola #160): verbo
  `place_traps` (celle relative al facing, `caltrop`/`decoy`, coperte se
  Occultato), `GameState.traps` + `spring_traps` (1 ferita + AZZOPPATO,
  diversivo = nulla); il motore le fa scattare su push/pull, mosse
  obbligatorie e scambi di posizione — la scena deve chiamare
  `spring_traps` alla conferma del movimento del giocatore.
- **Rinviati**: atomo "muovi verso" (§3.24) e adiacenza al terzo pezzo
  (§3.25) di #251/#254 (implicano pathing e 3 pedine); Kamae "Distanza"
  (§3.22) — richiede prima la trascrizione degli alberi Kamae dei 10
  personaggi nuovi (kamae_trees.json ne ha solo 4); restrizioni globali
  Bushido; "gioca la carta pescata subito" (§3.23).
- Validatore/simulatore/schema aggiornati; test estesi (dual, derivata,
  anti-sconfitta, ricorsione, trappole). Suite da rilanciare in locale.

## [0.81.0] — 2026-07-02
### Occultato: stato unico Assassino/Ninja con condizioni di uscita (da carte-regola fisiche)
- L'utente ha fornito le foto delle carte-regola **#160 PIEDI DI CORVO** e
  **#161 RIVELATO/OCCULTATO**: lo "stato Ombra" (Assassino) e lo "stato
  Ninja" sono **lo stesso stato ufficiale, "Occultato"** (stessa carta a
  doppia faccia, stessa icona incappucciata di "ENTRA IN").
- **Nomi unificati nei dati**: `ombra`/`ninja` → `occultato` su 13 carte
  (state/state_req/alt_initiative.state) + note aggiornate.
- **Condizioni di USCITA cablate** in `Duel._cleanup` (dalla faccia
  OCCULTATO di #161): si torna Rivelati dopo un attacco riuscito, un
  blocco riuscito, ferite subite o un altro effetto di stato ricevuto
  (stordito/azzoppato/veleno) — salvo esserci ENTRATI nello stesso turno
  (le carte Assassino/Ninja tipicamente attaccano E entrano in Occultato:
  l'ingresso a fine carta prevale). Fotografia di ferite/stati a inizio
  turno (`_turn_baseline`) + tracking dell'ingresso (`_stealth_entered`).
- **#170 LANCIO DI PIEDI DI CORVO**: nota aggiornata con la regola
  confermata di #160 (miniatura visibile se lanciati da Rivelato,
  segnalini '?' coperti con diversivi se da Occultato). I marcatori su
  griglia restano da modellare (roadmap §3.28).
- Test: 4 casi nuovi sulle condizioni di uscita. ⚠️ Suite ancora NON
  eseguita in remoto; gdparse ok.

## [0.80.0] — 2026-07-02
### Fase 4 (parte 1) — zona "in gioco", trigger a inizio turno, bersaglio per confronto d'iniziativa, mill
- **Zona "in gioco" per-fighter** (roadmap §3.2): `Fighter.in_play`; le carte
  con `stays_in_play` a fine risoluzione restano sul tavolo invece di andare
  negli scarti (anche le istantanee). Campi collegati:
  - `in_play_state`: entrando la carta incrementa uno stato persistente,
    uscendo lo decrementa — il contatore `illuminata` di #263/#264/#265 ora è
    **vivo** (chiude il DA VERIFICARE sul decremento della 0.78.0);
  - `limit_mod {hand/wound/focus}`: limiti modificati finché in gioco
    (§3.17; nuovo `Fighter.focus_limit` al posto del MAX_FOCUS fisso);
  - `turn_start`: effetti applicati a inizio turno PRIMA del passo Draw
    (finestre di trigger, §3.3), con risoluzione dei gruppi OPPURE;
  - `expires {turns:N}`: la carta scade da sola dopo N fine-turno (#106).
  Nuove API `Duel._enter_play` / `Duel.remove_from_play` (rovescia
  stato/limiti e scarta).
- **Bersaglio per confronto d'iniziativa** (§3.4): campo `targeting
  {mode:"initiative", threshold?, w?, w_from_gap?}` — l'attacco a distanza
  senza diagramma colpisce se l'avversario è in gittata (keyword RangeN) e
  la sua velocità scelta è inferiore (e sotto la soglia, se posta); ferite
  fisse, bleed/exec, o pari al divario di velocità (#279).
- **Verbi `mill`/`foe_mill`** (§3.16): scarto dalla cima del mazzo.
- **Dati (18 carte)**: gruppo RIMANE IN GIOCO — #295 (mano +3), #261 (tutti
  gli effetti spostati in `turn_start`), #263/#264/#265 (in_play_state
  'illuminata' + limiti, rimosso lo state_add statico), #25, #106 (expires),
  #85/#91/#93/#95 (Bushido: in gioco; le restrizioni globali "FINCHÉ È
  ATTIVA" restano note), #280 (targeting + turn_start foe_mill). Targeting
  iniziativa su #167/#169 (threshold 6)/#279 (w_from_gap)/#281/#325 (bleed)/
  #336.
- **Rinviati al prossimo giro**: doppia faccia Hachikō (§3.14/§3.15, tocca
  pianificazione/UI/protocollo), marcatori trappola (§3.28), casi isolati
  (§3.23–§3.27), restrizioni globali Bushido.
- Validatore (campi in-gioco/targeting, verbi mill), simulatore, schema e
  test aggiornati. ⚠️ Suite ancora NON eseguita (binario Godot non
  disponibile in sessione remota); gdparse ok su tutti i file toccati.

## [0.79.0] — 2026-07-02
### Fase 3 — gruppo "schema+motore": alt_initiative, famiglia foe_*, counter gated, n_from_state, heal, scarto casuale
- **`alt_initiative`** (roadmap §3.1): nuovo campo `{ value, kamae?/focus_cost?/state? }`
  — iniziativa alternativa AL POSTO di quella stampata quando il gate è
  soddisfatto (non è uno split). In auto-risoluzione si usa solo se gratis
  e più veloce; le difese la includono tra le velocità che agganciano
  l'attacco avversario. Applicata a **16 carte** (#44 #58 #60 #65 #77 #86
  #100 #105 #109 #140 #143 #149 #175 #303 #324 #325); #146 ha un *range*
  alternativo (8-3), non un valore: resta in nota.
- **`counter` gated** (§3.10): le voci della lista possono essere oggetti
  `{ on: [7,6], kamae/state/focus_cost }` valutati col gate del difensore.
  Applicato a #111 #118 #120 #141 #151 e al counter in Disperazione di #299.
  L'editor preserva le voci gated (passthrough nel widget counter).
- **Famiglia `foe_*`** (§3.5/§3.7/§3.18): nuovi verbi `foe_switch_kamae`
  (7 carte usavano `switch_kamae to:neutral` che spostava il GIOCATORE
  invece dell'avversario — bug di dati corretto su #97 #145 #240 #301 #326
  #336 #362), `foe_change_kamae` (#45 #66 #87), `foe_draw` (#12 #13 #17),
  `foe_reveal_hand` (10 carte; su #117 e #122 sostituisce il segnaposto
  errato `foe_discard`, su #153 il vecchio `draw` errato). #87 aveva anche
  NON BLOCCABILE stampato ma non trascritto (`non_blockable` aggiunto).
- **`n_from_state`** (§3.13): quantità a entità variabile — `n` effettivo =
  n × valore di uno stato persistente. Sblocca i **Contratti** di #322
  ("per ogni contratto completato" su focus/pesca/ricerca + `state_clear`
  finale); #319/#321/#328 restano in nota (bonus iniziativa/raggio e
  finestre di gioco, fasi successive).
- **`heal`** (§3.20): rimozione ferite/stati propri (`what`: wound/bleed/
  stun/hobble/poison, `all: true` per "tutti"). Applicato a #81 #124 #249
  #261 (su #249 e #261 sostituisce le approssimazioni reduce_damage/
  discard_self annotate come errate).
- **Scarto casuale** (§3.19): flag `random: true` su `discard_self`/
  `foe_discard`. Applicato a #242 e #327.
- Quinta Kamae "Distanza" (§3.22) **rinviata**: tocca gli enum di stance in
  tutto il progetto e senza suite eseguibile il rischio di regressione è
  alto — da fare con Godot a disposizione.
- Validatore e simulatore aggiornati ai campi/verbi nuovi; schema
  documentato in GEOMETRY_SCHEMA.md; test estesi in test_gate_states.
  ⚠️ Suite ancora NON eseguita (binario Godot non disponibile in sessione
  remota); sintassi verificata con gdparse su tutti i file toccati.

## [0.78.0] — 2026-07-02
### Stati persistenti per-fighter + gate unificato (roadmap meccaniche, Fase 2)
- **Nuovo sottosistema di stato persistente** (`Fighter.states`, dizionario
  libero nome → int, decisione §5.1 della roadmap): copre come UN SOLO
  meccanismo Disperazione (Onna-Bugeisha), Contratti (Yojimbo), stato Ombra
  (Assassino), stato Ninja, ciclo Illuminata (Monaco) e le carte "RIMANE IN
  GIOCO" (~40 carte del catalogo §3). Verbi effetto nuovi: `state_add`
  (anche negativo, per spendere), `state_set`, `state_clear`; gate di
  lettura: campo `state` sugli effetti e `state_req` sulla giocabilità
  (stringa = flag ≥ 1, dizionario nome → minimo in AND).
- **Nuovo `engine/Gate.gd`** (da `docs/GATE_AUDIT.md`): helper unico per il
  gate ricorrente kamae + focus_cost + state. `Duel._apply_effects`,
  `_resolve_option` e `playable()` ora passano da qui invece di ripetere il
  controllo a mano; il resto dei siti duplicati migra in Fase 5.
- **GeometryEditor: passthrough dei campi non modellati.** L'editor
  ricostruiva la geometria da zero al salvataggio: i campi che la UI non
  modella (`non_blockable`, `play_cost`, `wound_kind` dello split, `all`/
  `all_but` di spend_focus, e i nuovi `state`/`state_req`) sparivano al primo
  giro apri → salva (stessa classe di bug della 0.77.0). Ora le chiavi
  sconosciute a livello carta/split/effetto/atomo sono preservate com'erano.
- **CardValidator**: fix falso errore sul gate `kamae` in forma Array di un
  effetto (probabile causa del fail pre-esistente di `test_kamae` — da
  riverificare col binario); nuovi verbi `state_*` nel vocabolario e
  validazione delle forme di `state`/`state_req`.
- **`GEOMETRY_SCHEMA.md`**: documentati stati persistenti, gate unificato,
  `state_req` e i tre verbi nuovi. Nuovo report `docs/GATE_AUDIT.md` (censimento
  dei gate su tutte le 281 carte) e aggiornamento roadmap (decisioni §5 fissate).
- **Pilota dati: Disperazione (Onna-Bugeisha)** — prime carte reali sul
  sottosistema: #295/#296 giocabili solo in Disperazione (`state_req`),
  #298 PESCA 5 (alternativa b), #299 PESCA 2 dello split, #305 terza riga
  di movimento + PESCA 2, #306 STORDISCI+AZZOPPA on-hit gated
  `state: "disperazione"`; #302 tridente dello split gated sull'atomo.
  `Move.reachable_states/reachable_by_cell` ora filtrano gli atomi anche
  per stato persistente (nuovo parametro, tutti i chiamanti aggiornati).
  Restano in nota (fasi successive): counter gated di #299 (§3.10),
  iniziativa alternativa e bonus-cella di #303 (§3.1), regole persistenti
  di #295 (§3.2). Come si ENTRA in Disperazione è da definire con
  l'utente (regola dell'espansione, non presente negli scan).
- **Estensione agli altri gruppi di stato** (17 carte, verificate sugli
  scan): **Ombra/Assassino** — #221/#224 (state_set nello split, posizione
  confermata sugli scan), #225/#226/#228 (state_set nei effetti), #229
  (movimento raddoppiato gated `state: "ombra"` sull'atomo);
  **Ninja** — #165/#172 (state_set nello split), #174/#176 (state_set nei
  effetti), #171 (AZZOPPA gated state), #166 (giocabile solo in stato
  Ninja, `state_req`); **Illuminata/Monaco** — #263/#264/#265 incrementano
  il contatore `illuminata` quando entrano in gioco, #261/#262 richiedono
  `state_req {"illuminata": 3}` (l'uscita dal gioco non decrementa ancora
  il contatore — legata a §3.2, in nota). **Contratti (Yojimbo)** resta in
  nota: serve lo scaling a entità variabile (§3.13, Fase 3), non un flag.
  L'icona "ENTRA IN [sagoma incappucciata]" è identica per Assassino e
  Ninja: possibile stato unico "Occultamento" da confermare col
  regolamento — per ora restano `ombra` e `ninja` come nel catalogo.
- **Test**: nuova scena `tests/test_gate_states.tscn` (Gate, helper Fighter,
  verbi state_*, gate su effetti, state_req su playable, round-trip
  passthrough editor). ⚠️ Non ancora eseguita: il binario Godot 4.6 non è
  scaricabile dalla sessione remota corrente (policy di rete) — da lanciare
  alla prima occasione insieme alla baseline (4 fail pre-esistenti attesi).

## [0.77.0] — 2026-07-02
### Fix perdita dati nell'editor geometria + audit meccaniche mancanti
- **3 bug di perdita dati silenziosa in GeometryEditor.gd**, trovati da una
  revisione mirata dopo la crescita dello schema in questa sessione:
  - `split.defence`/`split.defences`/`split.counter` non venivano mai letti né
    scritti: aprire e salvare le carte #354 (Anima Devota) o #360 (Difesa a
    Due Lame) cancellava la difesa/contrattacco della seconda iniziativa.
    Corretto riusando `_emit_part`/`_read_variants` (già corretti per il
    livello principale) in modo simmetrico anche per lo split, invece di
    ricopiare a mano solo `move`/`attack`/`effects`.
  - Varianti `attacks[]` con lo stesso gate Kamae (incluso vuoto, cioè
    opzioni libere non gated) venivano scartate tranne la prima: le carte
    #164 (Colpo di Kusarigama) e #344 (Calcio del Mulo) perdevano una
    variante d'attacco al primo salvataggio dall'editor.
  - Rimosso codice morto (`_set_widget_type`/`_move_widget`, zero riferimenti
    nel repo).
  - Verificato con Godot 4.6 headless: suite di test esistente (`test_geometry_editor`,
    `test_cardeditor_smoke`, `test_cardvalidator`, `test_allcards`, 281 carte)
    tutta verde, più verifica mirata sulle 4 carte precedentemente affette.
- **`GEOMETRY_SCHEMA.md` aggiornato**: documenta `split` (mai descritto),
  i campi `kamae`/`focus_cost`/`dirs` sugli atomi di movimento, i valori
  `neutral`/`any` per `to`, il pattern delle varianti `attacks[]` non gated,
  e i limiti noti (meccaniche non ancora rappresentabili). Statistica di
  copertura aggiornata da "140/303" a "281 carte, gioco base completo".
- **Audit completo delle meccaniche non rappresentabili**: catalogate ~24
  meccaniche ricorrenti trovate nelle note "DA VERIFICARE" di 156 carte,
  raggruppate per impatto con proposte di estensione schema/motore (non
  ancora implementate — richiede una decisione di scope, vedi discussione).
  Due fix "gratis" identificati: `non_blockable` e `kamae_req` come array
  (gate OR) sono già supportati dal motore ma non documentati né usati sui
  dati (#35/#168/#334/#337 e #16/#45).
- **`kamae_req` come Array: 3 punti del codice non lo gestivano** (assumevano
  sempre una String), scoperti applicando il fix sopra alle carte #16/#45:
  `CardValidator.gd` segnalava un falso errore "kamae_req non valido" (con
  `str()` su un Array), `CardSimulator._run()` (anteprima "Simula" in
  editor) non impostava la Kamae del combattente di prova, e
  `test_allcards.gd` andava in crash a runtime (tipo `String` forzato su un
  valore `Array`). Aggiunto `Kamae.gate_values(gate) -> Array` (normalizza
  String/Array/assente a una lista di slug) e riusato nei tre punti.

## [0.76.0] — 2026-07-02
### Verifica adversariale dei 10 nuovi personaggi + fix ordine "spiega carta"
- **Gioco base completato**: con Musashi e Kojiro esclusi dallo scope (nessuna
  espansione disponibile), tutte le carte del gioco base caricato hanno ora
  geometria trascritta — mancavano solo 2 carte, entrambe divisori di mazzo
  senza contenuto di gioco (215, 234), ora documentate come tali.
- **Verifica sistematica delle 137 carte trascritte nella 0.74.0/0.75.0**:
  confrontate una a una con le scansioni reali (10 agenti indipendenti, uno
  per personaggio). Su 137 carte, ~20 correzioni applicate:
  - Direzioni di movimento invertite o incomplete (Assassino #219/#229,
    Ninja #172, Monaco #266)
  - Celle d'attacco sull'anello sbagliato: tre carte Onna-Bugeisha
    (#297, #304, #306) avevano ferite sull'anello 1 quando in realtà
    l'anello 1 è vuoto e il colpo è sull'anello 2; Yasuke #352 aveva le
    coordinate delle celle laterali invertite
    - Costo "SCARTA 1 CARTA" mancante (Yojimbo #317); `type` errato
    "other"→"meditation" (Yojimbo #321, causato da un refuso "Mediation"
    nell'anagrafica sorgente)
  - Effetti indipendenti erroneamente resi alternativi con "OPPURE"
    (Ashigaru #240)
  - Icona Kamae "Distanza" del Navigatore scambiata per Neutrale (#276)
  - Varie correzioni di nota (Hachikō, Wakou, Altre carte 3 #146)
- **Fix CardSimulator.explain()**: il costo iniziale "SCARTA 1 CARTA" (47
  carte nel dataset) veniva spiegato per ultimo invece che per primo, perché
  `effects[]` era sempre stampato dopo movimento e attacco. Ora il costo
  incondizionato viene estratto e mostrato subito dopo l'intestazione,
  rispecchiando l'ordine reale sulla carta stampata.
- Validazione automatica: zero errori su tutte le 281 carte.

## [0.75.0] — 2026-07-02
### 10 nuovi personaggi: geometria completata (fase 2, tutte le 137 carte)
- Trascritte le ultime 45 carte rimaste in coda dalla 0.74.0: **Ninja** (14),
  **Monaco** (13), **Yasuke** (14) e le prime 4 carte di **Wakou** (333-336,
  sostituiscono i segnaposto temporanei).
- Tutti e 10 i personaggi caricati in questa tornata (Assassino, Ninja,
  Onna-Bugeisha, Yojimbo, Ashigaru, Hachikō, Monaco, Navigatore, Wakou,
  Yasuke) hanno ora la geometria completa: **279 carte totali** in
  geometry.json (era 140 prima di questa fase).
- **Nuove meccaniche scoperte e documentate in nota** (non ancora
  modellabili con lo schema attuale, coerentemente con l'approccio
  "non inventare" delle fasi precedenti):
  - **Stato "Ombra"** dell'Assassino e **stato speciale del Ninja mascherato**
    ricorrono su più carte (probabile stessa meccanica "Occultamento" delle
    due carte-personaggio) — nessuna quinta kamae nello schema.
  - **Ciclo "Illuminata"** del Monaco: risorsa/costo non standard per
    "cerca carta specifica", buff permanenti al limite ferite/mano/focus.
  - **Attacchi "trappola"** del Ninja (166, 167, 169): bersaglio scelto per
    confronto di iniziativa invece che per cella, con soglie a pagamento.
  - Scaling di effetti "per casella mossa" (Yasuke 353, 355) non
    rappresentabile come intero fisso.
- Validazione automatica sull'intero file: zero verbi/kamae/direzioni fuori
  vocabolario su tutte le 279 carte.
- **Ancora bloccati**: Musashi e Kojiro (nessun PDF caricato).

## [0.74.0] — 2026-07-02
### 10 nuovi personaggi: anagrafica, immagini, geometria (fase 1)
- **10 nuovi personaggi caricati**: Assassino, Ninja, Onna-Bugeisha, Yojimbo
  (immagini già presenti ma senza geometria), Ashigaru, Hachikō, Monaco,
  Navigatore, Wakou, Yasuke (PDF nuovi). Musashi e Kojiro restano bloccati:
  nessun PDF caricato.
- **Statistiche personaggio** (ferite/mano/armi/rinomanza) aggiunte a
  `geometry.characters` per tutti e 10, lette dalle carte-personaggio
  stampate. Scoperta: Assassino e Ninja hanno mano 6/ferite 4 (diverso dal
  5/5 standard); il Navigatore possiede una **quinta Kamae "Distanza"** non
  presente nell'enum standard (non modellata, richiede estensione schema).
- **137 carte tradotte in italiano** in `card_pool.json` (erano in inglese,
  importate dall'Excel) + 145 nuove mappature immagine in `card_images.json`
  (qui il numero stampato = id pool direttamente, a differenza delle armi).
- **Geometria trascritta per 104/137 carte** (Assassino, Onna-Bugeisha,
  Yojimbo, Ashigaru, Hachikō, Navigatore, Wakou 9/13, più le 17 «Altre
  carte 3» che completano i buchi Gen. Ability lasciati aperti nella 0.73.0:
  96, 97, 100, 111, 121, 136 e altri nuovi 99, 103, 110, 141, 144-147, 151,
  152, 157).
  - **Hachikō**: formato inedito, carte a due facce Attacco/Difesa con
    iniziative separate sulla stessa carta — lo schema attuale non supporta
    due movimenti paralleli, gestito con `attack`+`defence` sulla stessa
    entry e note esplicite.
  - **Meccaniche scoperte e non ancora modellabili** (documentate in nota
    carta per carta): stato "Ombra" dell'Assassino, "Disperazione"
    dell'Onna-Bugeisha, "Contratti" dello Yojimbo, "Ubriaco" del Wakou,
    attacchi a "Distanza" con bersaglio scelto per confronto d'iniziativa
    invece che per cella.
- **Ancora da fare**: Ninja (14), Monaco (13), Yasuke (14) e le prime 4
  carte di Wakou (333-336) — trascrizione interrotta da un limite di
  sessione, in coda per la prossima fase.

## [0.73.0] — 2026-07-02
### Armi, Gen. Ability e Bushido: immagini collegate e geometria verificata
- **Mappatura id→immagine**: catalogate le 72 scansioni di altre_carte/
  altre_carte_2 (nome + numero di collezione stampato) → 54 nuove voci in
  card_images.json (copertura 78→132 carte). Senza scansione restano 96, 97,
  100, 111, 121, 136 e le 10 carte Solo.
- **Verifica visiva delle 54 carte appena mappate**: 46 corrette, 8 già giuste
  (le Bushido 79/82/85/91/93/94/95 e la 106).
  - **Armi (66-77, 133-139)**: la trascrizione originale aveva esecuzioni
    inventate su quasi tutte — le carte reali hanno ferite semplici (Yari e
    Jumonji Yari colpiscono a distanza 3-4, il Kanabo stordisce con celle
    asterisco); seconde iniziative [1]-[3] aggiunte su 8 carte; costi focus
    delle barre viola sui movimenti.
  - **counter:[1] fantasma rimossi** da 7 carte (108, 112, 114→[5,4,3],
    120→[8,7,6,5], 140, 143, 148, 155); su 80 il counter era la copia
    dell'iniziativa (→[8,7,6,5]).
  - **#88 DOVERE**: «tutti scartano tutto il focus» (era: la mano) e
    «passano a Neutrale» (era: Aggressività, il torii ⛩ = Neutrale).
  - **#153 VANTAGGIO**: l'icona occhio = guarda la mano (il 'pesca' era
    inventato); **#108** si chiama DISTRAZIONE (non 'Difesa Accennante');
    **#156** è una Meditazione (era type 'other').
  - Gate kamae ricostruiti su movimenti ed effetti (barre rossa/verde/gialla)
    e celle di difesa corrette (80, 114, 115, 120 avevano scudi in più o in
    meno).
- Iniziative alternative «[N] su barra kamae/focus» documentate nelle note
  (non ancora modellate dallo schema).

## [0.72.0] — 2026-07-01
### Verifica visiva della geometria contro le carte reali (56 carte corrette)
- **Verifica sistematica**: le 70 carte di geometry.json con immagine collegata
  sono state confrontate una a una con le scansioni reali (WEBP estratte dai
  PDF di Tabelle_Materiali); 56 presentavano differenze, tutte corrette.
- **#23 CARTA SPECIALE RONIN**: SCARTA 1 CARTA (era stun_self) + tre
  alternative corrette (pesca 2 / focus+passa a qualsiasi Kamae / cambia 1 ramo).
- **#24 VORTICE CREMISI**: arco completo — tutte le 12 celle dell'anello 2 con
  2 ferite (il formato {d,k} ne conservava solo 6).
- **Errori ricorrenti corretti in blocco**:
  - «PASSA A UNA QUALSIASI KAMAE» trascritto come `change_kamae` invece di
    `switch_kamae to:any` (8 carte);
  - barra gialla «4 quadretti» letta come costo focus invece che gate
    Determinazione (#63, #98, #107, #126) e cerchio verde letto come
    Determinazione invece di Equilibrio (#86, #98, #116…);
  - frecce a più punte (arco frontale dirs 0,1,5 / posteriore 2,3,4 /
    diagonali 1,5) trascritte come passo singolo (12+ carte);
  - celle diagonali dell'anello 2 perse dal formato {d,k} → coordinate
    assiali {q,r} (#55, #58, #60, #62, #71, #72);
  - «elmo + ellisse di stelle» = STORDISCI uniformato (#125 era
    swap_positions, #126 era rotate_target, #32 era foe_stun→hobble);
  - seconde iniziative mancanti aggiunte come `split` (#39, #44, #48, #49,
    #118, #123 — il [1] di Respinta era stato letto come counter);
  - archi/scudi con celle mancanti o spostate (#10, #15, #16, #18, #19, #39,
    #40, #44, #45, #46, #47, #55, #62, #119…), #19 ricostruita con 3 varianti
    d'attacco gated per Kamae.
- **Limiti documentati in nota** («DA VERIFICARE»): effetti sull'avversario
  senza verbo nel vocabolario (pesca/prende carte/forza Kamae), gate doppi
  Equilibrio/Determinazione su kamae_req, iniziative alternative per Kamae,
  sottotipo DISTANZA. Le ~70 carte senza immagine collegata restano da
  verificare (serve la mappatura id→immagine).

## [0.71.0] — 2026-07-01
### Turno di gioco più chiaro + editor ottimizzato + fix
- **Banner di fase in partita**: banner in alto al centro che mostra sempre
  iniziativa corrente, chi agisce e la carta giocata (tipo compreso) —
  rivelazione (grigio), risoluzione (oro), parte bassa split (blu), turno IA.
  Suggerimenti rietichettati «FASE 1 — MOVIMENTO» / «FASE 2 — ATTACCO»; la
  selezione carta mostra nome, tipo e iniziativa.
- **Fix avvio partita**: errore GDScript "variable typed as Variant" in
  `Arena.gd` (righe 284/285/406) — dichiarazioni tipizzate esplicite.
- **Fix pagina web ferma a versioni vecchie**: il deploy su GitHub Pages ora
  rinomina i file esportati (pck/wasm/js) con lo SHA del commit — i browser
  non possono più riusare una build in cache.
- **Editor — meno ricostruzioni**: la spunta «facolt.» e i clic sulla barra
  Kamae aggiornano solo il controllo toccato (prima ricostruivano l'intero
  albero dei widget perdendo focus e scroll); tema e stile dei pannelli
  condivisi in cache; validazione live coalizzata (una per raffica di tasti);
  cronologia undo limitata a 100 passi.
- **Editor — «+ aggiungi widget» diretto**: menu che crea subito il widget del
  tipo scelto (prima: pannello vuoto + tendina, doppio passaggio).
- **Editor — pulizia**: rimosse ~190 righe di codice morto in `CardEditor.gd`
  e il pulsante «Salva geometria» ridondante (il «Salva» della barra salva già
  tutto); helper `_commit()`/`_eff_spin`/`_eff_opt` riusati al posto di ~20
  blocchi duplicati in `GeometryEditor.gd`.
- **Validatore**: aggiunti i verbi `pull`, `bleed`, `change_approach` (già
  gestiti dal motore); i controlli "senza celle" ora vedono anche le varianti
  plurali `attacks`/`defences` e la parte `split` (niente più falsi avvisi su
  #24, #26, #65, #113).
- **Geometria dati**: audit completo delle 140 carte (schema pulito, nessun
  errore bloccante); normalizzati 6 atomi `dirs:[0..5]` → `dir:-1` (#23, #28,
  #34) e rimosso un `effects:[]` vuoto (#154); documentazione `layout`
  aggiornata alla forma ad albero. Restano 77 carte con nota «DA VERIFICARE».

## [0.70.0] — 2026-06-30
### Fix geometria carte + miglioramenti editor
- **❄ passo libero**: 34 atomi `t:"anchor"` convertiti in `t:"step", dir:-1` su 30 carte — il simbolo ❄ nella barra movimento ora muove davvero la pedina in qualsiasi direzione adiacente; rimosso il no-op in `Move.gd`.
- **Asterisco (*) nell'esagono**: corrette 4 carte con significato errato — #35 CHIATTA DI BUOI (stun del bersaglio), #71 SPAZZATA DI NAGINATA (stun con 1 focus), #86 COLPO IN AFFONDO (ferita se spendi 1 focus), #113 TAGLIO TRONCANTE (ferita aggiuntiva in Aggressività via variante `attacks`).
- **Schema celle attacco** (`focus_cost`/`w_focus`): nuovo schema per ferite condizionali al costo di focus; ferite gated saltate nell'auto-risoluzione come gli effetti a pagamento.
- **Editor — Salva unificato**: il pulsante "Salva" ora salva sia l'anagrafica sia la geometria in un unico clic (prima richiedeva un secondo pulsante "Salva geometria" separato).
- **Editor — Cambia immagine**: il picker ora mostra una lista testuale invece della griglia di miniature, eliminando il freeze nel browser causato dal caricamento sincrono di centinaia di texture.
- **Editor — Esporta**: popup con istruzioni chiare dopo il download del bundle JSON.
- **Spiega carta**: la finestra di spiegazione mostra ora anche la seconda iniziativa (campo `split`) con movimento, attacco ed effetti della parte bassa.

## [0.69.0] — 2026-06-29
### Carte Solo AI estese + immagini personaggi aggiuntivi
- **Immagini carte (nuovi personaggi)**: estratte via `tools/extract_card_images.py`
  le carte WEBP dai PDF mancanti (`Assassino.pdf`, `Ninja.pdf`, `Onna Bugeisha.pdf`,
  `Yojimbo.pdf`, `Altre carte.pdf`, `Altre carte 2.pdf`) in `assets/cards/`.
  Nuove cartelle: `assassin/` (27 carte), `ninja/` (33), `onna_bugeisha/` (27),
  `yojimbo/` (34), `altre_carte/` (36), `altre_carte_2/` (36).
- **Solo AI estese (75 nuove carte)**: aggiunte a `card_pool.json` le carte Solo AI
  dedicate per tutti i personaggi non ancora coperti, ricavate da
  `Solo_AI_carte.xlsx` (Tabelle_Materiali). Nuovi mazzi:
  - Yasuke Solo (916-920): Ankle Strike, Lion's Bite, Dual Blade Defence,
    Charging Pride, Righteous Fury (incubo N920).
  - Wakou Solo (921-924, 981): Staggering Hulk, Faster Legs, Headbutt,
    Staggering Blow, Broadside Slam (incubo N981).
  - Sailor Solo (925-928, 984): Carrack Plow, Roof Guard, Towering Strike,
    Dreadnaught, Barbed Black Shot (incubo N984).
  - Assassin Solo (929-932, 987): Shadow Strike, Venomous Slice, Penumbra Vault,
    Sever Artery, Spider's Kiss (incubo N987).
  - Hachiko Solo (933-937): Swipe, Feral Howl, Menacing Growl, Quick Bite, Jump.
  - Kojiro Solo (938-942): Iron Block, Scornful Jab, Biting Remark, Close In,
    Turning Swallow Cut (incubo).
  - Master Solo (943-947): Dark Insight, Reposition, Masterful Cut, Idle Strike,
    Hidden Victory (incubo).
  - Monk Solo (948-953): Satori Smite, Enlighten, Palm Strike, Resolute Block,
    Zen Wave Slash (incubo), Enlightened Path (carta persistente).
  - Ninja Solo (954-957, 990): Smoke Screen, Ninja Slash, Shuriken Throw,
    Metsubushi Pipe, Lunar Sniper Trap (incubo N990).
  - Onna-Bugeisha Solo (958-962): Surging River, Falling Arc, Rage Guard,
    Screaming Mind, Silent End (incubo).
  - Yojimbo Solo (963-965): Leg Breaker, Scorpion Sting, Row.
  - Student Solo (966-970): Obedience, Rock Strike, Mountain Swap, Insightful,
    Lightning Tail (incubo).
  - Musashi Solo (971-975): Rushing Water Slice, Dancing Fire Slash, Wind Slash,
    Standing Earth, Dark Void (incubo).
  - Ashigaru Solo (976-979): Scything Cleave, Skewer, Lunging Pierce,
    Heaven's Descent (incubo).
  - Generic nightmares (993-999): Rising Phoenix Arc, Wild Swing, Powerful Strike,
    Dirt Throw, Blood Fury Cut, Dashdown Strike, Ancient Terror.
- **CardDB.solo_deck_for()**: ora restituisce i mazzi dedicati per tutti i 16
  personaggi (prima solo Ronin e Warrior); il fallback `draw_pile_for()` resta per
  eventuali personaggi futuri.

## [0.68.0] — 2026-06-25
### Editor carte: salvataggio nelle build + finestra "Spiega carta"
- **Fix salvataggio (grave)**: "Salva geometria" (e gli override anagrafica/immagini)
  fallivano in una **build esportata** con "tmp non scrivibile"/"rename fallita",
  perché l'editor scriveva sotto `res://`, che è di **sola lettura** fuori
  dall'editor Godot. Ora la scrittura va su un overlay **`user://`** (sempre
  scrivibile) quando non si è nell'editor; `CardDB` **fonde** quegli overlay
  (`geometry.json`, `card_pool_overrides.json`, `card_images.json`) sopra i dati
  base al caricamento, così le modifiche **persistono** anche nel gioco esportato.
  Dall'editor Godot il comportamento è invariato (scrive in `res://`, per il
  commit nel repo). Nuovi helper `CardStore.writable_path()` / `read_effective()`
  e `CardDB._overlay()`/`_merge_*`.
  - **Build web (GitHub Pages)**: `user://` mappa sull'**IndexedDB del browser**,
    quindi le modifiche persistono tra i ricaricamenti **ma restano locali a quel
    browser/dispositivo**: NON tornano nel repo. Per rendere un'edit permanente
    nel gioco pubblicato va riportata in `geometry.json` (dall'editor desktop +
    commit, o esportando l'overlay). Pulire i dati del sito azzera gli override.
- **Esporta override**: nuovo pulsante "Esporta" nella toolbar dell'editor. Su
  **web** scarica `senjutsu_overrides.json` (bundle con lo stato corrente di
  `card_pool_overrides.json`, `geometry.json`, `card_images.json`); su desktop lo
  scrive in `user://` e mostra il percorso. Serve a **riportare nel repo** le
  modifiche fatte da Pages (committando i file in `godot/data/cards/`), rendendole
  permanenti per tutti. Nuovo `CardStore.export_bundle()`; download via
  `JavaScriptBridge` (Blob + ancora `download`).
- **"Simula carta" → "Spiega carta"**: il pulsante apre ora una finestra che
  spiega **in italiano** cosa fa la carta — iniziativa, costo focus, Kamae
  richiesta, movimento ("muoverti di 2 in avanti, poi ruotare di 1 se in
  Aggressività"), arco/difesa, contrattacco ed effetti ("peschi 2 carte se
  l'attacco va a segno") — invece del solo log tattico numerico. L'esito tattico
  di prova resta come riga riassuntiva in fondo. Nuovo `CardSimulator.explain()`.
- **Test**: `test_simulator.gd` con casi su `explain()` (frasi attese per
  movimento, gate Kamae, effetto on_hit, e geometria assente).
- ⚠️ Da verificare in Godot (la sessione non aveva il binario). Versione 0.68.0.

## [0.67.0] — 2026-06-23
### Gate Kamae in logica OR + editor più compatto
- **Motore — gate Kamae OR**: il gate delle Kamae ora accetta un **Array di
  stance** (es. `["aggression","balance"]`) interpretato in **OR**, oltre alla
  stringa singola e al valore vuoto già supportati. In `Kamae.gd` due helper
  uniformi — `gate_allows()` e `gate_is_empty()` — gestiscono `null` / `""` /
  stringa / Array vuoto / Array pieno. Aggiornati tutti i punti di consumo:
  `Duel.gd` (playable, variante attiva, selezione alternativa, applicazione
  effetti), `AI.gd` (check `kamae_req`) e `Move.gd` (filtro atomi).
- **Editor — barra Kamae multi-select**: nel card editor la `KamaeBar` diventa
  multi-selezione (gate OR); il campo "a" (kamae di destinazione) resta a
  selezione singola. Serializzazione **retro-compatibile**: 1 stance → stringa,
  N stance → Array, vuoto → `""`.
- **Editor — gate unico nell'header**: rimosso il controllo Kamae duplicato nel
  corpo dell'effetto (duplicava il "se" dell'intestazione); il gate dell'effetto
  ora **è** la condizione del widget. Atomi di movimento ed effetti compattati
  su una sola riga (entità, kamae, Focus, facoltatività); il gate Kamae
  per-atomo resta distinto (coperto da `test_move_fidelity`). Segmenti della
  `KamaeBar` più alti (26px) per allinearsi ai campi di testo.
- **Test**: `test_kamae_node.gd` con nuovi casi per `gate_allows`/`gate_is_empty`
  su Array e verifica di `_apply_effects` con gate OR (fighter in stance inclusa
  ed esclusa dal set).
- ⚠️ Da verificare in Godot (la sessione non aveva il binario). Versione 0.67.0.

## [0.66.0] — 2026-06-23
### Editor carte: rifiniture grafiche dei widget
- **Simboli non resi dal font rimossi**: alcuni glifi (in particolare la freccia
  `→`, ma anche trattini lunghi `—`, punto centrale `·`, ellissi `…`)
  apparivano come "tofu" (riquadro col codice). Tutte le stringhe della UI ora
  usano solo ASCII + lettere accentate italiane (che il tema rende).
- **Larghezza uniforme**: tutti i widget hanno la stessa larghezza (riempiono la
  colonna) invece di adattarsi al contenuto.
- **Angoli più stondati** dei pannelli-widget (raggio 8).
- **Campi più bassi**: menu/spin/righe di testo non si allungano più in
  verticale (allineamento "shrink center"), restano alti poco più del testo.
- **Testo di dimensione uniforme** in tutti i widget: un tema dell'editor fissa
  un'unica misura (12) per tutti i controlli, al posto degli override sparsi.
- **Trascinamento da qualsiasi zona** non interattiva del widget (sfondo ed
  etichette non catturano più il mouse); durante il drag si vede un'**anteprima
  stilizzata** che segue il cursore e l'originale si **attenua**.
- **Note a capo automatico** (word-wrap) invece dello scorrimento orizzontale.
  (Le note sono **solo promemoria di trascrizione**: il campo `note` non è letto
  dal motore, nessun effetto di gioco.)
- ⚠️ Da verificare in Godot (la sessione non aveva il binario). Versione 0.66.0.

## [0.65.0] — 2026-06-23
### Editor carte: interfaccia più compatta + selettore Kamae a barra colorata
- **Selettore Kamae senza testo**: i menu a tendina della Kamae (condizione "se"
  dei widget, kamae dell'atomo di movimento, campi `kamae`/`to` dell'Effetto)
  sono ora una **barra a tre segmenti colorati** — 🔴 rosso = Aggressività,
  🟢 verde = Equilibrio, 🟡 giallo = Determinazione. Clic per scegliere, clic sul
  segmento attivo per azzerare. (Il colore della Determinazione passa da blu a
  giallo, coerente con la barra.)
- **Box più stretti e corti**: i pannelli-widget ora si adattano al contenuto
  (non occupano più tutta la colonna), con uno stile a margini ridotti; font,
  spaziature, esagono di combattimento (`HEX_R` 21→16), rosetta direzioni,
  icone àncora/rotazione e campi numerici rimpiccioliti. Testo generalmente più
  piccolo (label/menu/hint a 10–11 px).
- **Glifi non resi dal font** rimossi/sostituiti: la maniglia di trascinamento
  "⠿" (appariva come tofu) è ora **disegnata** a 6 puntini; tolto il "❄" dai
  testi del pulsante/tooltip àncora (l'icona fiocco è comunque disegnata).
- **CardValidator**: accetta le Kamae `neutral` e `any` nel campo `to` degli
  effetti `switch_kamae` (le stance reali sono 4, vedi `Kamae.gd`; Duel.gd
  risolve `any`). Prima 4 carte valide (23, 89, 118, 119) davano un falso
  errore. Validazione strutturale delle 140 geometrie esistenti: **0 errori**.
- ⚠️ Da verificare in Godot (suite `test_geometry_editor`, `test_cardvalidator`,
  `test_cardeditor_smoke` e l'editor a video): la sessione di sviluppo non aveva
  il binario per eseguirli. Versione 0.65.0.

## [0.64.0] — 2026-06-23
### Editor carte: il widget Iniziativa ora avvolge OGNI carta
- Prima il contenitore **Iniziativa** veniva creato solo per le carte a più
  iniziative (campo `split`); le carte a iniziativa singola restavano una
  **lista piatta** di widget (vecchio metodo). Ora **ogni** carta ha le sue
  azioni dentro un contenitore Iniziativa, che mostra a quale iniziativa sono
  attive (valore dal `card_pool`).
- I mutatori dell'editor (`_first_combat`, `add_opt`, `add_move_atom`,
  `add_effect`, `set_kamae_req`) operano dentro il contenitore (`_primary_children`),
  così i widget aggiunti finiscono nell'Iniziativa e non al livello superiore.
- Round-trip salvataggio invariato: il motore riceve la geometria appiattita,
  l'albero completo (incluso il contenitore) è in `layout`. Test aggiornati.
- ⚠️ Da verificare in Godot (suite `test_geometry_editor`, `test_cardeditor_smoke`
  e l'editor): la sessione di sviluppo non aveva il binario per eseguirli.
  Versione 0.64.0.

## [0.63.0] — 2026-06-23
### Dati carte: mazzi Maestro e Allievo + armi e abilità generiche
- **Geometria trascritta da 54 a 140 carte** su 303 (`geometry.json`): mazzi
  completi **Maestro** (Master, id 8–20) e **Allievo** (Student, id 38–50),
  più **armi** (66–77/133–139) e **abilità generiche** (78–158) presenti nelle
  scansioni `Tabelle_Materiali/Senjutsu/CARTE/`.
- Aggiunti i **personaggi** Maestro ("Il Vecchio Dragone") e Allievo ("Impavido
  come una Tigre") con armi e limiti; corretto: il numero grande sulle carte
  personaggio è la **Rinomanza** (74/62), non il limite ferite (5/5).
- **Alberi Kamae** Maestro e Allievo (`kamae_trees.json`), con mapping
  icone→pose verificato sul Guerriero.
- **Immagini carte** Master/Student estratte (`extract_card_images.py`, +79
  webp, manifest a 162 carte) e collegate all'HUD (`card_images.json`).
- Campi affidabili (tipo, movimento, effetti, focus) completi; archi
  attacco/difesa best-effort con note `DA VERIFICARE`, da rifinire nell'editor.
  Non presenti nelle scansioni (restano senza geometria): #103 Passo Aggraziato,
  #110 Schivata Rapida e altre 9 generiche. Versione 0.63.0.

## [0.62.1] — 2026-06-21
### Menu: "Novità" dal CHANGELOG + immagine di sfondo
- Il riquadro **Novità** dello splash ora **legge l'ultima voce del CHANGELOG**
  (titolo + primi punti): prima era un testo fisso che non cambiava mai.
- Aggiunta l'**immagine dell'arena** come sfondo del menu (attenuata, con velo
  scuro per la leggibilità dei pulsanti). Versione 0.62.1.

## [0.62.0] — 2026-06-21
### Editor carte: l'iniziativa diventa un widget contenitore
- L'**iniziativa** non è più un campo dell'intestazione: è un **widget Iniziativa**
  che **raccoglie tutti i widget attivi a quella iniziativa**.
- Le carte a **più iniziative** (campo `split`, es. **024 Vortice Cremisi**) si aprono con
  **due contenitori Iniziativa**: la **parte alta** (con la sua velocità) e la **parte bassa**
  (lo split, con movimento/attacco e la propria velocità). Le carte a iniziativa singola
  restano una lista piatta.
- L'iniziativa della parte alta resta sincronizzata con il `card_pool` (ordine di turno
  invariato); lo split continua a essere serializzato per il motore. Versione 0.62.0.

## [0.61.0] — 2026-06-21
### Editor carte: intestazione riorganizzata + geometria annidabile
- **Intestazione** su tre righe: **nome · personaggio · rank**; il **tipo** come **badge**
  rimovibili (con "+" per aggiungerne); **costo focus · copie · iniziativa**. I keyword
  passano da campo testo a **badge cliccabili**.
- **Geometria a widget annidabili**: due **contenitori** — **Iniziativa** (con numero di
  iniziativa) e **OPPURE (alternative)** — annidano altri widget in un riquadro rientrato.
- Ogni widget ha in cima una **condizione kamae** ("se …"); per il Combattimento è la posa
  che attiva la variante d'attacco.
- I widget si **riposizionano trascinandoli** (drag & drop tra liste e dentro/fuori i
  contenitori); rimossi i tasti su/giù.
- Serializzazione **provvisoria**: il motore riceve la geometria appiattita (invariato),
  mentre l'albero completo (annidamento + condizioni) è salvato in `layout` e ricostruito
  al ricaricamento; le carte col layout classico restano compatibili. Versione 0.61.0.

## [0.60.0] — 2026-06-19
### Controller telefono: scheda personaggio "a comparsa quando serve"
- La **scheda personaggio** ora **appare da sola** nei momenti rilevanti — quando **subisci
  ferite/sanguinanti/veleno** o **cambia il focus** — e si **richiude da sola** dopo poco
  (resta toccabile a mano in qualsiasi momento).
- Non disturba mentre devi agire: se è apparsa da sola e arriva il tuo turno, si **chiude**
  subito per non coprire mappa e bottoni. Versione 0.60.0.

## [0.59.0] — 2026-06-19
### Controller telefono: carta Kamae interattiva (immagine + nodi raggiungibili)
- Quando una carta permette di **cambiare Kamae**, in risoluzione compare il pulsante
  **«⟳ Cambia Kamae»** che apre la **carta Kamae reale** del personaggio con sopra i **nodi**
  toccabili: il nodo **attuale** è evidenziato in rosso, i nodi **raggiungibili** in oro (con
  l'eventuale **+◈ focus** guadagnato). Tocchi il nodo per spostare l'anello.
- Le coordinate dei nodi e l'immagine carta vengono dai dati (`kamae_trees.json`) inviati nel
  prompt di risoluzione (`kamaeUI`); resta il fallback a bottoni per compatibilità.
- Completa la modalità verticale (stage 3/3). Versione 0.59.0.

## [0.58.0] — 2026-06-19
### Controller telefono: scheda personaggio (carta reale + ferite/veleno/focus)
- **Tocca un ritratto** (il tuo o l'avversario) per aprire la **scheda personaggio**: la
  **carta reale** del personaggio (Ronin/Guerriero) con sopra lo **stato live** — ferite
  **normali** (❤), **sanguinanti** (🩸) e caselle libere (♡), **veleno** (☠×n), **stordimento**
  (✦n) e **focus** (◈/◇).
- La barra di stato in alto ora mostra anche **sanguinanti** e **veleno**, non solo il totale
  ferite.
- Il server serve le carte personaggio da `/cards/` (nuovi asset
  `ronin/ronin_char.webp`, `warrior/warrior_char.webp`). Versione 0.58.0.

## [0.57.0] — 2026-06-19
### Controller telefono: ora utilizzabile anche in VERTICALE (iPhone in mano)
- Il controller **non forza più l'orizzontale**: funziona in **entrambi gli orientamenti**.
  In **verticale** la mappa prende tutta la larghezza (margini laterali ridotti), la
  risoluzione resta a colonna (mappa sopra, comandi sotto) e i **ritratti** diventano piccoli
  negli angoli in alto.
- Rispetto di **notch/safe-area** iPhone (padding su barra di stato e bordo inferiore).
- (Prossimi passi: carta personaggio con ferite/sanguinanti/veleno/focus, e carta Kamae
  interattiva.) Versione 0.57.0.

## [0.56.0] — 2026-06-19
### Controller telefono: ritratti dei contendenti ai lati dello schermo
- Aggiunti i **ritratti** di **Ronin** e **Guerriero** (da Tabelle/Senjutsu/Personaggi) come
  **cerchi ai lati** dello schermo del telefono: **io a sinistra** (bordo vermiglio),
  **avversario a destra** (bordo blu), con il nome sotto. Il ritratto di chi deve agire si
  **evidenzia in oro**.
- I cerchi stanno nei **margini laterali** (il contenuto ha spazio riservato): **non coprono
  la mappa**. Il server espone la nuova rotta statica **`/portraits/`**. Versione 0.56.0.

## [0.55.0] — 2026-06-19
### Fix: rotazione non più illimitata (rispetta il budget della carta)
- In risoluzione (telefono/tavolo) la **rotazione** era di fatto **illimitata**: i facing
  legali venivano **ricalcolati dal facing corrente** a ogni passo, così il budget di
  rotazione della carta (di solito 1 o 2 passi) si **rigenerava** ad ogni rotazione.
- Ora gli stati raggiungibili (cella → facing) sono calcolati **una sola volta** dalla
  posizione di partenza e la rotazione è **limitata a quell'insieme fisso** — come già fa
  l'arena locale. Il telefono salta il passo Rotazione se l'unico facing disponibile è
  quello attuale. Versione 0.55.0.

## [0.54.0] — 2026-06-19
### Fix: controller telefono bloccato in risoluzione («in attesa» senza tasti)
- Nel passo **Rotazione** il telefono chiamava una funzione (`facingLabel`) **mai definita**:
  l'errore interrompeva il disegno della schermata **prima** di mostrare i comandi, lasciando il
  telefono fermo su "In attesa…" **senza pulsanti**. Aggiunta la funzione (frecce di
  orientamento ↘ ↗ ↑ ↖ ↙ ↓): la risoluzione ora prosegue regolarmente.
- I **comandi non coprono più la mappa**: layout a colonna con **mappa sopra** (grande) e
  **barra comandi sotto** (mai sovrapposta). Rimosso un blocco CSS duplicato che reintroduceva
  il vecchio pannello laterale sovrapposto. Versione 0.54.0.

## [0.53.0] — 2026-06-19
### Controller telefono: mappa a tutto schermo, comandi grandi centrati, passi separati
- La **mappa** in risoluzione ora occupa **tutto lo schermo** (più grande); al tocco sul posto
  il telefono va **a schermo intero** (Fullscreen API).
- I **comandi/scelte** non sono più piccoli a sinistra ma in un **pannello grande e centrato**
  in basso (bottoni comodi).
- **Movimento e rotazione separati** in passi distinti: *Passo 1 Movimento* (caselle gialle) →
  *Passo 2 Rotazione* (bottoni grandi «Fronte / Fronte-Dx/…», niente più maniglie sulla mappa,
  così non si rischia di toccare l'esagono sbagliato) → *Passo 3 Azione* (bersaglio rosso o
  «Fine», più Kamae/OPPURE). Versione 0.53.0.

## [0.52.0] — 2026-06-19
### Tavolo online: setup che collassa a partita iniziata + schermo intero
- Quando **entrambi i telefoni sono connessi** e la partita inizia, il pannello di
  **setup (codice stanza / connessione)** **collassa e sparisce**, liberando l'area per il
  tavolo 3D.
- **Schermo intero**: il tavolo va automaticamente a tutto schermo all'avvio della partita;
  **F** alterna finestra/schermo intero. Versione 0.52.0.

## [0.51.0] — 2026-06-19
### Fix: turno bloccato dopo aver giocato la carta («Avanti» spariva)
- Dopo aver bloccato la carta, il pulsante **«Avanti»** della Rivelazione veniva **nascosto
  subito** (l'ordine delle chiamate spegneva il pulsante appena mostrato): il turno restava
  fermo "in attesa". Ora la pulizia avviene **prima** di programmare, così la Rivelazione
  mostra «Avanti» e si può proseguire. Versione 0.51.0.

## [0.50.0] — 2026-06-19
### Fix: «Avanti» nascosto e mano sovrapposta in Rivelazione
- La **mano** ora viene **nascosta** in Rivelazione/Risoluzione (prima restava visibile e
  interattiva: più carte si alzavano insieme e coprivano lo schermo). Torna in Programmazione.
- Il pulsante **«Avanti» / «Fine»** ora sta **sopra** le carte (z-index alto): prima era
  coperto dal ventaglio della mano e non si riusciva a premerlo.
- Corretto il refresh che ri-mostrava la mano subito dopo aver bloccato la carta. Versione 0.50.0.

## [0.49.0] — 2026-06-19
### Flusso del turno corretto (solo/locale): Programmazione → Rivelazione → Risoluzione
- **Programmazione**: scegli la carta e premi **«Conferma carta»** per bloccarla (coperta).
  Niente più "muovi e poi conferma": la conferma è solo qui, all'inizio.
- **Rivelazione**: si vedono le **carte giocate** e l'**ordine d'iniziativa** (alta → bassa);
  premi **«Avanti»** per iniziare.
- **Risoluzione per iniziativa**: prima chi ha iniziativa più alta fa *movimento → rotazione →
  attacco/azioni*, poi il successivo. In risoluzione niente pulsante a metà: muovi (giallo),
  ruoti, poi tocchi il **bersaglio rosso** per attaccare (o **«Fine»** se la carta non attacca).
- La barra di stato indica chiaramente l'iniziativa corrente e di chi è il turno.
- Aggiornati i test pilotati dall'Arena per la nuova fase di Rivelazione. Suite verde (20).
  Versione 0.49.0.

## [0.48.0] — 2026-06-19
### Tavolo: ordine d'iniziativa + animazioni delle carte
- **Ordine d'iniziativa** mostrato sul tavolo: "Ordine iniziativa: 1) G1 Att ⚡8 · 2) G2 Dif ⚡5",
  così è chiaro chi risolve prima e in che sequenza (alta → bassa).
- **Animazioni delle carte giocate** sul tavolo: **comparsa** alla rivelazione (dissolvenza +
  ingrandimento), **sostituzione** (la carta si capovolge e cambia quando si gioca un'istantanea
  di sostituzione), **scarto** a fine turno (sfuma). 
- Motore/protocollo: nuovo segnale `resolution_order` → evento pubblico `order`; la sostituzione
  istantanea ri-trasmette le carte rivelate per animarle. Versione 0.48.0.

## [0.47.0] — 2026-06-19
### Mazzi SOLO dedicati per gli avversari Ronin e Guerriero
- L'IA solitaria ora usa il suo **mazzo SOLO dedicato** (non più le carte del giocatore):
  **Ronin** = Charge, Steel Block, Reverse Carved Fang, Feral Sweep, The Terror (incubo);
  **Guerriero** = Ember Block, Scything Uppercut, Warding Arc, Refocused Mind, Flaming Phoenix
  Arc (incubo). Trascritte (best-effort) dall'Excel *Solo_AI_carte* corretto.
- **Ripristinata la meccanica solo**: le carte SOLO portano **CHANGE AI BEHAVIOUR** (l'IA
  alterna offensiva/difensiva, postura visibile) e **RESET DECK** (rimescola e cicla), che si
  erano persi quando #28 era stata ri-trascritta come carta del giocatore.
- Geometria approssimata dove la trascrizione era parziale (note sulle carte). Le altre ~110
  carte solo (altri avversari non ancora nel gioco) restano da integrare quando quei
  personaggi verranno aggiunti. Suite verde (54 carte testate). Versione 0.47.0.

## [0.46.0] — 2026-06-19
### Chiarezza: scelte leggibili, movimento/rotazione separati, tavolo informativo
- **Scelte OPPURE leggibili**: sul telefono le opzioni non sono più "a/b/c" ma la **descrizione**
  degli effetti (es. "Spingi 1", "Pesca 2", "Passa a Aggressività").
- **Movimento e rotazione separati**: sul telefono ora sono **due passi** distinti — prima
  *Passo 1 — Movimento* (caselle gialle o «Non muovere»), poi *Passo 2 — rotazione + azioni +
  attacco*. Niente più maniglie verdi sovrapposte alle caselle gialle.
- **Tavolo (computer) più informativo**: mostra la **fase/iniziativa corrente** (chi tocca e
  cosa fa), le **carte giocate** (immagini alla rivelazione), un **registro pubblico** degli
  eventi (rivelazione, scelte OPPURE, colpi/parate/contrattacchi, riepilogo turno) e i
  contatori mano/mazzo per entrambi — tutto visibile a entrambi i giocatori.
- Protocollo: etichette opzioni, azione **"non muovere"**, evento **choice**, e mano/mazzo/scarti
  nei dati pubblici. Versione 0.46.0.

## [0.45.0] — 2026-06-19
### Telefono: mappa in stile 3D (texture vera + inclinazione da tavolo)
- La mini-mappa toccabile del telefono ora mostra la **texture reale della mappa** sotto gli
  esagoni e ha un'**inclinazione "da tavolo"** (prospettiva) per assomigliare alla vista 3D
  del computer. Le tessere neutre sono semi-trasparenti (si vede la mappa); le caselle di
  **movimento** (gialle) e i **bersagli** (rosse) restano ben evidenti e toccabili.
- Il relay serve anche le **mappe** via HTTP su `/maps/...` (stessa porta), oltre a controller
  e carte. Versione 0.45.0.

## [0.44.0] — 2026-06-19
### Carte Ronin e Guerriero ri-trascritte (Excel CORRETTO + audit)
- Importate le **correzioni** dai due Excel (`*_carte_CORRETTO.xlsx`) e dal report di audit:
  **44 carte** (Ronin + Guerriero) riallineate in `geometry.json` — movimenti (direzione
  obbligatoria/opzionale, avanti/indietro, gating per Kamae), griglie d'attacco (celle/lato/
  distanza), iniziative divise (parte bassa), difese e contrattacchi, alternative *OPPURE*,
  costi focus, e gli effetti corretti (stordimento vs sanguinante, scambio posizione, ecc.).
- Nuovi verbi del motore per coprire le carte: **`foe_stun`** (stordisci l'avversario),
  **`swap_positions`** (scambia posizione), ed **esecuzione per-cella** nella griglia d'attacco
  (es. Colpo della Fenice Fiammante).
- Iniziativa/focus delle 44 carte allineati ai valori corretti.
- Suite completa verde (20 suite); aggiornati `test_options` e `test_multi` alle carte corrette.
  Restano alcune approssimazioni dichiarate (note nelle carte) per simboli non ancora
  modellati per-cella. Versione 0.44.0.

## [0.43.0] — 2026-06-19
### Controller telefono rinnovato: orizzontale, mappa toccabile, stile giapponese
- **Orizzontale**: layout pensato per il telefono in landscape (con avviso "ruota il telefono"
  in verticale).
- **Barra di stato** sempre visibile: giocatore + **Kamae** (pastiglia colorata), **ferite**
  (❤ e stordimento ✦), **focus** (◈◇), **round** e una riga **notizie** (turno, rivelazione,
  colpi/parate). Alimentata dagli eventi `board` del tavolo (ora con il raggio mappa).
- **Mano scorrevole**: le carte (con arte reale) scorrono in orizzontale se sono tante.
- **Movimento GRAFICO**: in risoluzione compare una **mappa esagonale 2D toccabile** — tocchi
  la casella **gialla** per muovere, le **pedine verdi** attorno alla tua per **ruotare**, il
  **rosso** per **attaccare**; la tua pedina mostra l'**orientamento**. Niente più codici
  tipo "1,-2". Kamae/OPPURE/Conferma restano come pulsanti.
- **Stile giapponese**: tema carta di riso & inchiostro, accenti vermiglio (hanko), pulsanti
  più curati.
- Protocollo: `radius` aggiunto ai dati di board/risoluzione (per disegnare la mappa). Test
  net + E2E WebSocket verdi. Versione 0.43.0.

## [0.42.0] — 2026-06-19
### Tavolo online: indirizzo configurabile + riconnessione automatica
- Il **tavolo online** non si blocca più su "Connessione al server persa": ora ha un campo
  **Server** modificabile + pulsante **Connetti**, **riprova da solo** (backoff) e
  **ricorda** l'ultimo indirizzo (`user://net.cfg`).
- In riconnessione **mantiene lo stesso codice stanza**, così i telefoni già collegati non
  devono rifare nulla.
- Messaggi d'aiuto chiari quando non riesce a connettersi (avvia il relay con
  `cd server && npm start`; nota che su web in **HTTPS** serve un relay **wss://**, non `ws://`)
  e suggerimento dell'URL `http://…/` da aprire sul telefono. Versione 0.42.0.

## [0.41.0] — 2026-06-19
### Controller telefono: carte con arte reale, layout touch, riconnessione
- **Carte con immagine**: il controller mostra le carte con la **loro arte reale** (mano,
  sostituzioni, istantanee), con didascalia (nome · tipo · ◈). Fallback a testo se l'immagine
  manca.
- **Server tutto-in-uno**: il relay ora serve anche via **HTTP** il controller (`/`) e l'arte
  delle carte (`/cards/...`) sulla **stessa porta** del WebSocket. Dal telefono basta aprire
  `http://<ip>:<porta>/` (niente più `file://`); il campo Server è precompilato con la stessa
  origine. Protezione contro i path-traversal.
- **Riconnessione**: il controller **ricorda** la sessione (server/codice/seat) e si
  **riconnette da solo** (con backoff) dopo un calo di rete o il refresh della pagina; l'host
  **rimanda il prompt in corso** così riprendi esattamente da dove eri. Aggiunto il tasto
  **Esci**.
- **Touch**: bottoni più grandi, mano a griglia, pillole per movimento/rotazione/Kamae/OPPURE.
- Verifica: relay test + E2E WebSocket (partita 1v1 completa) verdi. Versione 0.41.0.

## [0.40.0] — 2026-06-19
### Multiplayer companion — Tappa 4.1: tavolo 3D online + voce di menu
- Nuova scena **`TableOnline`**: la vista TAVOLO online. Costruisce la board 3D, si collega
  al relay, **mostra il codice stanza**, possiede il motore (`MatchHost`) e **disegna lo
  stato pubblico** (posizioni, ferite/focus/Kamae, animazioni di combattimento) man mano
  che i due telefoni decidono. Niente mano/HUD di scelta sul tavolo (sono sui telefoni).
- **Menu**: nuova voce **"Online (tavolo + telefoni)"** che apre il tavolo; i giocatori si
  collegano dalla pagina `phone/` con il codice mostrato. URL del relay in `Domain.ws_url`
  (default `ws://127.0.0.1:8080`).
- Protocollo/host: ora emettono eventi pubblici utili al tavolo — **snapshot board** (a
  ogni cambiamento) e **"turn_of"** (di chi è il turno e in quale passo).
- Resta da fare: ospitare il relay su un host sempre acceso (per giocare fuori dalla LAN) e
  rifinire la UI telefono (immagini carte, riconnessione). Versione 0.40.0.

## [0.39.0] — 2026-06-19
### Multiplayer companion — Tappa 3: rete WebSocket + stanze + telefono
- **Server relay** (`server/server.js`, Node `ws`): stanze con **codice** e instradamento
  messaggi tavolo↔telefoni; non conosce le regole. Test `server/relay.test.mjs` (PASS).
- **`net/WebSocketChannel.gd`**: canale Godot con la **stessa interfaccia** del loopback,
  sopra WebSocket reale (vale per tavolo e telefono).
- **Pagina telefono** (`phone/index.html` + `app.js` + `style.css`): si collega al relay,
  entra in una stanza su un seat, riceve i prompt e invia le scelte (mano privata).
- **E2E reale** (`godot/tests/run_ws_e2e.sh`): relay + tavolo Godot + 2 client via
  WebSocket giocano una partita 1v1 completa fino a fine coerente (PASS, ~120 messaggi).
- Resta da fare (Tappa 4): collegare il **tavolo 3D** (Arena) come vista host e ospitare
  il relay su un host sempre acceso. Versione 0.39.0.

## [0.38.0] — 2026-06-19
### Multiplayer companion — Tappa 2: loopback locale (host + client)
- Astrazione di **trasporto** (`net/LoopbackChannel.gd`) con messaggi **serializzabili**
  (round-trip JSON, consegna asincrona): in Tappa 3 basterà sostituirla con un canale
  WebSocket dagli stessi metodi/segnali.
- **`net/MatchHost.gd`** (tavolo autorevole): possiede `MatchProtocol`, inoltra i prompt al
  seat giusto, trasmette eventi pubblici/fine, applica le risposte.
- **`net/MatchClient.gd`** (telefono): riceve i prompt del proprio seat e gli eventi
  pubblici, invia le risposte; non conosce regole né stato completo (mano privata).
- Nuovo test `test_loopback`: un host + **due client-bot** giocano una partita 1v1 intera
  **interamente via canale** (i bot decidono solo dai dati del prompt) fino a fine coerente
  — 10/10 esecuzioni OK. Versione 0.38.0.

## [0.37.0] — 2026-06-19
### Multiplayer companion — Tappa 1: protocollo decisioni (no rete)
- Nuovo `engine/MatchProtocol.gd`: strato sopra il motore che trasforma **ogni
  punto-decisione** del turno in un **messaggio dati** (`prompt`) e applica la risposta
  (`respond`) — la base per il multiplayer "tavolo + telefoni" (vedi
  `docs/MULTIPLAYER_PLAN.md`). Niente rete in questo passo.
- Prompt: `plan` (scegli carta), `instant_replace` (sostituzione), `resolve`
  (movimento/rotazione/Kamae/OPPURE/conferma a passi), `instant_play` (istantanea
  aggiuntiva); eventi pubblici per il tavolo (rivelazione/combattimento/log/fine).
- I seat IA sono gestiti in automatico; le mani restano per-seat (private).
- Nuovo test `test_protocol`: gioca una **partita 1v1 completa solo via protocollo**
  (prompt→risposta) fino a una fine coerente. Documento di piano in `docs/`. Versione 0.37.0.

## [0.36.0] — 2026-06-19
### Animazioni di combattimento
- Nuovo segnale `combat_event` dal motore (solo presentazione, non tocca le regole) e
  animazioni nell'arena:
  - **Colpo a segno**: la pedina **affonda** verso il bersaglio + **lampo d'impatto** rosso
    sulla cella colpita + leggera **scossa di camera**.
  - **Parata**: affondo + lampo **azzurro** (più tenue) sul difensore.
  - **Contrattacco**: lampo arancio sull'attaccante colpito di rimando.
  - **Collisione** (spinta su terreno/bordo/altro): lampo ampio + scossa più decisa.
- Disattivate automaticamente in headless (test) per restare leggeri. Versione 0.36.0.

## [0.35.0] — 2026-06-19
### Carte ISTANTANEE: sostituzione + aggiuntive (regolamento 1.5 p.7/13/16)
- **Istantanea di Sostituzione** (es. #61 Colpo Corto, #32 Balzo del Lupo): nella fase di
  **Rivelazione**, dopo aver pagato i costi, puoi **sostituire la carta rivelata** con
  un'istantanea di **tipo diverso** (Attacco/Difesa/Meditazione, non core); la carta
  originale va negli scarti e **recuperi il focus** che avevi speso, pagando quello della
  nuova. Poi si calcolano iniziative e ordine sulla carta nuova.
- **Istantanea Aggiuntiva / Istantanea** (es. #56 Punto Cieco, #54 Ruggito Ardente, #30
  Artigli Laceranti, #25 Armatura Pesante): dopo aver risolto la carta scelta puoi giocare
  **1 carta istantanea** dalla mano — **mai** se hai giocato una carta core (regolamento).
  Gli effetti "se a segno" si applicano come reazione se il tuo attacco è andato a segno.
- Riconoscimento dal mazzo: `CardDB.instant_kind()` dalle keyword
  (Instant / Instant Additional / Instant Replacement).
- **UI**: selettore dedicato per scegliere la carta istantanea (o «Tieni / Salta»),
  nelle due finestre giuste del turno (Rivelazione e Risoluzione).
- Nuovo test `test_instant`; aggiornati i test interattivi per gestire le nuove finestre;
  ripristinati due test datati (mano con carte core; #64 trascritta). Versione 0.35.0.

## [0.34.0] — 2026-06-19
### Restyling GUI + focus visibile + rotazione con frecce + sequenza chiara
- **Tema UI** applicato a tutto il gioco (`scenes/ui_theme.tres`): **bottoni in stile**
  (stati normale/hover/premuto/disabilitato, angoli arrotondati, ombre), pannelli e
  etichette leggibili (contorno) sopra la scena 3D.
- **Focus visibile**: nuovo indicatore con i **gettoni di concentrazione** (◈ pieni / ◇
  vuoti, x3) del giocatore di turno, che **diminuiscono quando li spendi** e aumentano
  attraversando il ramo rosa della Kamae (il costo è anche sulle carte).
- **Rotazione senza tasti**: frecce ⟲ ⟳ **vicino alla pedina** (oltre a Q/E), mostrate solo
  quando la carta consente di ruotare.
- **Sequenza di risoluzione più chiara**: per iniziativa, prima **movimento + rotazione**,
  poi le **scelte** (Kamae/OPPURE), infine **conferma**; la barra di stato descrive il passo
  corrente (chi risolve, iniziativa, cosa fare).
- **Cambio Kamae illuminato**: i nodi raggiungibili sulla carta Kamae vengono evidenziati.
- **Carte più in alto** e più leggibili. Versione 0.34.0.

## [0.33.0] — 2026-06-18
### Le ferite (e gli altri stati) sono CARTE
- Le **ferite**, lo **stordimento**, gli **azzoppamenti** e i **veleni** sono ora modellati
  come vere **carte di stato** (con la loro **arte reale** ritagliata da `CARTE/Ferite.pdf`):
  Stordimento, Azzoppato, Ferita, Ferita Sanguinante, Veleno Virulento/Debilitante, Nebbia
  di Confusione, Tossina Paralizzante/Emorragica. Hanno nome e testo del regolamento
  (`engine/Status.gd`, ID negativi per non collidere con le carte abilità).
- **Visibili in partita**: nuova striscia laterale che mostra come **carte** le ferite/stati
  del combattente di turno, con contatore per tipo.
- **Stordimento fedele**: occupa il limite di carte in mano (riduce quante carte abilità
  puoi pescare/tenere) e **non si scarta mai**; sconfitta quando riempie la mano.
- Test `test_status` esteso (catalogo carte, mappa ferite→carte, stordimento che occupa la
  mano). Versione 0.33.0.

## [0.32.0] — 2026-06-18
### 1v1 locale (hot-seat) con tutta la logica + suggerimento leggibile
- **Modalità 1v1 locale (hot-seat)**: il pulsante *Versus* ora avvia un vero duello tra
  **due giocatori umani** sullo stesso dispositivo, usando **tutta** la logica del gioco
  (programmazione coperta a turno, rivelazione simultanea, risoluzione per iniziativa,
  Kamae/focus, blocchi, contrattacchi, spinte/collisioni, ecc.). I giocatori **si passano
  il dispositivo**: dopo che il Giocatore 1 ha programmato (coperta), compare *"Passa il
  dispositivo al Giocatore 2"*; poi entrambi risolvono la propria carta nell'ordine
  d'iniziativa, ciascuno muovendo/orientando la **propria** pedina.
- L'Arena non è più cablata su "pedina 0 = umano": un indice di **combattente attivo**
  guida overlay, movimento, rotazione (Q/E), scelta Kamae e *OPPURE* per il giocatore di
  turno (in solo o in 1v1). La carta **Kamae mostrata** segue il combattente attivo.
- La modalità **Solo** (vs IA) resta invariata.
- **Suggerimento in basso leggibile**: la scritta dei controlli ora sta in una **barra con
  sfondo** ancorata in fondo e disegnata **sopra** le carte (z-index alto), così non viene
  più coperta/illeggibile quando le carte si alzano.
- Nuovo test headless `test_versus` per il flusso del motore a due umani. Versione 0.32.0.

## [0.31.0] — 2026-06-18
### Miniature più grandi
- Le pedine sono ora **più grandi** (altezza ~2.4× il raggio esagono, base che riempie
  quasi l'esagono) per leggerle meglio sulla mappa.
- Le **ferite** restano tracciate e mostrate nella barra di stato (❤ rimaste/limite);
  segnalini-ferita visivi sulla pedina: possibile lavoro futuro. Versione 0.31.0.

## [0.30.0] — 2026-06-18
### Miniature 3D a colori (Guerriero e Ronin)
- Le pedine ora usano i **modelli .glb texturizzati** caricati (Guerriero/Ronin) con i
  **colori/texture propri**, invece della tinta piatta. La base resta colorata per
  squadra (rosso = tu, blu = IA) + indicatore di facing.
- I modelli originali erano enormi (~55 e ~45 MB, scansioni ad alta densità): li ho
  **ottimizzati** (semplificazione mesh + texture WebP 1024) a **~1.4 e ~2 MB**, così il
  gioco web resta leggero. `Pawn.gd` istanzia il modello mantenendone i materiali.
- Rimossi i vecchi `.obj` senza texture. Versione 0.30.0.

## [0.29.0] — 2026-06-18
### Rotazione miniatura: feedback chiaro (perché Q/E a volte non gira)
- La rotazione (Q/E) è **per-carta e per-Kamae**: molte carte permettono di ruotare solo
  in una certa Kamae. Finché il cambio Kamae era rotto (corretto in 0.27) e restavi sempre
  Neutro, quelle rotazioni non erano mai accessibili → sembrava che la miniatura non
  girasse mai.
- Ora, se premi Q/E e la rotazione non è disponibile, l'HUD lo spiega:
  *"⟳ Rotazione non disponibile con questa carta — ruota solo in Kamae: …"*, così sai che
  devi prima cambiare Kamae (col selettore, ora funzionante).
- Le rotazioni non vincolate e quelle nella Kamae giusta funzionano regolarmente.
  Versione 0.29.0.

## [0.28.0] — 2026-06-18
### Postura IA visibile + approccio dinamico
- **Postura IA visibile in partita**: la barra di stato mostra ora `IA: ⚔ Offensiva / 🛡
  Difensiva · approccio fronte/destra/spalle/sinistra`, aggiornata in tempo reale.
- **Approccio dinamico**: nuovo effetto `change_approach` che sposta il segnalino approccio
  alla posizione successiva (fronte → destra → spalle → sinistra), come le frecce nere
  sulla carta avversario. Attaccato a *Mente Risoluta* (#102) nel mazzo IA; cambia quindi
  l'angolo da cui l'IA cerca di posizionarsi rispetto al tuo facing.
- Test `test_ai` esteso (rotazione approccio). Suite verde (12). Versione 0.28.0.

## [0.27.0] — 2026-06-18
### Avversario Ronin "solitario": mazzo IA dedicato + cambio atteggiamento
- L'IA ora usa un **mazzo solitario dedicato** (sottoinsieme curato di carte Ronin
  secondo `solo_AI_tables_v1.xlsx`: attacchi mischia + 1 difesa con counter + 2
  meditazioni), invece dell'intero mazzo del giocatore. `CardDB.solo_deck_for()`.
- Nuovo effetto **CHANGE AI BEHAVIOUR** (carta solo *Il Terrore* #28): l'IA inverte
  l'atteggiamento **offensivo ⇄ difensivo**, cambiando le priorità di movimento.
- L'IA continua a: rivelare la cima del mazzo, ignorare il focus, muoversi per priorità
  (v0.26), contrattaccare alla velocità counter (il giocatore subisce 1 ferita).
- Trascritte ~139 carte solo dalle immagini inglesi (2 montaggi) in `Solo_AI_carte.xlsx`
  come riferimento; il mazzo IA riusa la geometria già verificata delle carte Ronin.
- **Fix cambio Kamae**: il selettore non cambiava posizione (restavi sempre Neutro)
  perché tutti i pulsanti emettevano l'ultima stance per un bug di cattura nella lambda;
  ora ogni pulsante cambia la Kamae giusta.
- Test `test_ai` esteso (mazzo solo valido + cambio atteggiamento). Suite verde (12).
  Versione 0.27.0.

## [0.26.0] — 2026-06-18
### Motore comportamentale IA solitaria (priorità di movimento)
- L'IA non si limita più ad avvicinarsi: `AI.plan_move` valuta tutte le posizioni
  raggiungibili dalla mossa della carta e sceglie secondo le **priorità del solitario**
  (regolamento p.22), in base all'**atteggiamento**:
  - **Offensivo**: colpire → più ferite → vicino alle spalle → restare non colpibile →
    avvicinarsi alla portata preferita → angolo d'approccio → fronteggiare.
  - **Difensivo**: restare non colpibile → poi colpire → ferite → portata → spalle →
    approccio → fronteggiare.
- Nuovi parametri sul combattente: `ai_stance`, `ai_preferred_range`, `ai_approach`
  (la pedina IA è offensiva, portata 1, approccio frontale).
- Il **contrattacco** dell'IA era già regolamentare (para a velocità counter → il
  giocatore subisce 1 ferita); ora il counter del giocatore scarta un attacco **non-core**.
- Lo schema deck del solitario (`solo_AI_tables_v1.xlsx`) e le carte solo dedicate
  restano lavoro futuro: l'IA usa il mazzo del personaggio come segnaposto.
- Nuovo test `test_ai` (offensivo si posiziona per colpire; difensivo evita la minaccia).
  Suite completa verde (12). Versione 0.26.0.

## [0.25.0] — 2026-06-18
### Carte CORE (Speciale + Arma) e setup iniziale corretti
- **Setup iniziale fedele** (regolamento p.4): le carte **core** (la carta Speciale e la
  carta **Arma** core) partono **in mano** e il resto si rimescola nel mazzo; prima erano
  erroneamente mescolate nel mazzo e pescate a caso.
- **Le core non si scartano mai** (p.10): la carta core giocata **torna in mano** invece
  di finire negli scarti; non vengono toccate da scarto-per-limite, costi di gioco
  (`SCARTA 1 CARTA`), `discard_self` né dal `reset_deck`.
- **Non contano verso il limite di mano**: il limite (5) si applica solo alle carte
  non-core, quindi tieni 5 non-core + Speciale + Arma.
- `is_core` riconosce sia il tipo "core" sia la keyword "Core" (carte arma: Nodachi #72,
  Naginata #71). Nuovo test `test_core`; suite completa verde (11). Versione 0.25.0.

## [0.24.0] — 2026-06-18
### Iniziativa divisa interattiva + verbi di timing
- **Parte bassa (iniziativa divisa) interattiva**: quando giochi una carta a iniziativa
  divisa, prima risolvi la parte sopra (muovi/attacca/Conferma), poi entri in una seconda
  fase per la **parte bassa** — riposizioni la pedina secondo la sua mossa e attacchi, con
  il pulsante "Conferma parte bassa". Per l'IA/headless resta automatica. Nuovi metodi
  motore `has_pending_split`/`pending_split_geom`/`resolve_split_now` e overlay con
  geometria esplicita (`geom_override`).
- **Verbi di timing implementati** (prima stub):
  - `cancel_movement` — annulla il movimento dell'avversario per il turno (rispettato sia
    dall'IA che dal giocatore se chi annulla risolve prima).
  - `cancel_abilities` — azzera gli effetti persistenti dell'avversario (es. Armatura Pesante).
  - `block_initiative` — allarga di N l'intervallo d'iniziativa a cui il blocco è efficace
    (Blocco Ampio): il blocco ferma anche attacchi a ±N dalla velocità scelta.
  - Stati per-turno azzerati a inizio turno (`movement_cancelled`, `block_initiative_bonus`).
- Test estesi: `test_effects` (cancel_movement/abilities, block_initiative) e `test_split`
  (flusso interattivo della parte bassa). Suite completa verde (10). Versione 0.24.0.

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

## [0.19.0] — 2026-06-18
### Iniziativa divisa + correzioni carte (#26/#27/#33)
- **Iniziativa divisa (split)**: le carte con due parti a velocità diverse risolvono la
  parte sopra e la parte sotto come due azioni separate (auto in headless/IA).
- **#26 Carica del Toro** completata con il requisito Kamae Aggressività.
- Correzioni a **#27** (passo bidirezionale) e **#33** (passo + rotazione obbligatori).

## [0.18.0] — 2026-06-18
### Carte core, scelta OPPURE e robustezza multi-turno
- Prima trascrizione delle **carte core** e gestione della scelta **OPPURE** a opzione
  singola; **#23** (core Ronin) corretta.
- Fix del **2° turno** (mano disallineata) e visualizzazione della carta giocata.
- Nuovo test di regressione su partita multi-turno deterministica (anti-freeze).

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
