# Meccaniche di carta & semplificazione editor — Handoff & Roadmap

> **Scopo di questo documento.** La sessione precedente è diventata lunga.
> Questo file serve a **ricominciare puliti in una nuova sessione** con due
> obiettivi legati:
> **(A)** implementare le meccaniche di carta che oggi non sono rappresentabili
> nello schema/motore (catalogo completo in §3), e
> **(B)** un audit di semplificazione: molte azioni diverse (movimento,
> attacco/difesa, contrattacco, effetti) ripetono lo stesso concetto di
> "condizione" (Kamae richiesta + costo focus) in modi leggermente diversi —
> vale la pena unificarli invece di far crescere lo schema con N varianti
> dello stesso pattern.
>
> Stato del progetto al momento della stesura: **v0.77.0**, Godot 4.6.
> Gioco base **completo**: 281 carte trascritte e verificate (Musashi/Kojiro
> esclusi permanentemente, nessun PDF disponibile). L'editor visuale
> (`CardEditor`/`GeometryEditor`) è completo e senza bug di perdita dati noti
> (vedi PR #82, mergiata). Questa è la **prossima area di lavoro**.

---

## 0. Come usare questo file in una nuova sessione

Apri una sessione nuova e incolla un prompt tipo:

```
Leggi docs/CARD_MECHANICS_ROADMAP.md. Prima conferma con me le "Decisioni da
prendere" (§5), poi parti dalla Fase 0.
```

Crea un branch **nuovo, fresh da `origin/main`** (non riusare
`claude/card-editor-roadmap-y1sp92`, che ha già chiuso il suo arco con la
build dell'editor):
```
git fetch origin main && git checkout -b claude/card-mechanics-<slug> origin/main
```
Repo: `tannoiser2/sunjuntsu`. Non toccare `tannoiser2/tabelle_materiali` a
meno che non richiesto esplicitamente.

---

## 1. Vincoli permanenti (NON re-derivare, NON rimetterli in discussione)

- **Musashi e Kojiro sono fuori scope permanentemente** — appartengono a
  un'espansione che l'utente non possiede, nessun PDF/scan disponibile.
- **Non aggiungere Jin Sakai** — non è un personaggio originale del gioco.
- Ogni altro personaggio ha regole speciali "case by case", da trattare via
  via che si affrontano nel catalogo §3 — non tutte insieme, non a
  sorpresa.
- Sviluppo su branch dedicato, PR come **draft**, mai push diretto su `main`
  salvo emergenze già concordate con l'utente (è successo una volta in
  questa sessione per risolvere un conflitto di merge locale — non è la
  norma).
- Ogni PR funzionale richiede: bump `config/version` in `project.godot` +
  voce in `godot/CHANGELOG.md`.

---

## 2. Stato attuale (cosa esiste già — leggi prima di ripartire da zero)

- **281 carte** in `godot/data/cards/geometry.json`, tutte con geometria
  (eccetto 2 ID che sono divisori fisici del mazzo, non carte giocabili:
  215, 234 — già documentato, non è un buco).
- **Editor completo**: `godot/scenes/CardEditor.gd` (anagrafica + immagini)
  + `godot/scenes/GeometryEditor.gd` (geometria visuale su griglia
  esagonale, drag&drop, tester "Simula carta"). Bug di perdita dati noti
  (split.defence/counter, varianti attacks[] duplicate) **risolti** in PR
  #82. Codice morto rimosso.
- **`Kamae.gate_values(gate) -> Array`** (in `godot/engine/Kamae.gd`) è
  l'helper attuale per normalizzare un gate Kamae che può essere String,
  Array (OR) o assente — usalo ovunque serva leggere un `kamae_req`/`kamae`,
  non riscrivere la logica a mano.
- **Schema documentato** in `godot/data/cards/GEOMETRY_SCHEMA.md`,
  aggiornato in questa sessione con `split`, `dirs`/`kamae`/`focus_cost`
  sugli atomi di movimento, `to: neutral/any`, limiti noti.
- **Test headless** (Godot 4.6): 27 scene in `godot/tests/*.tscn`.
  **4 test falliscono già in partenza, in modo pre-esistente e NON
  collegato a questo lavoro** — confermato più volte con `git stash` +
  ri-esecuzione sul commit precedente: `test_kamae` (OR-gate sul campo
  `kamae` di un *effetto*, non su `kamae_req` — nota: potrebbe essere
  proprio uno dei buchi di questo catalogo, vedi §3.7), `test_blocks`,
  `test_combat2`, `test_options`. Non provare a "sistemarli" a meno che il
  task specifico li riguardi.
- ⚠️ **Il binario Godot 4.6 headless linux NON è incluso nel repo.** La
  sessione precedente ne aveva scaricato una copia locale in
  `/tmp/Godot_v4.6-stable_linux.x86_64` — in un container fresco questo
  path **non esisterà**. Prima cosa da fare: procurarsi un binario Godot
  **4.6** headless linux x86_64 (stessa major.minor del progetto, vedi
  `config/features` in `project.godot`) per poter eseguire i test.
- **Pattern consolidato per editare `geometry.json` chirurgicamente**
  (281 carte, ~350KB, non riscrivere mai a mano): script Python che trova
  l'ancora `"<id>": {`, fa brace-matching per individuare la fine del
  blocco, sostituisce con `json.dumps(obj, indent=1, ensure_ascii=False)`
  ri-tabulato. Validare sempre con `python3 -c "import json; json.load(...)"`
  dopo ogni modifica.
- ⚠️ **L'Edit tool a volte fallisce con "old_string not found" su
  `GeometryEditor.gd`** nonostante il contenuto sembri identico nel Read.
  Causa non chiarita (probabile encoding di caratteri come — o simboli
  Unicode). Workaround consolidato: leggere/sostituire/scrivere il file con
  Python (`open().read()` → `str.replace()` → `open('w').write()`) invece
  di insistere con l'Edit tool.

---

## 3. Catalogo delle 28 meccaniche non rappresentate

Fonte: audit di tutti i 274 campi `note` non vuoti di `geometry.json`
(pattern-matching su "DA VERIFICARE", "non modellat*", "RIMANE IN GIOCO",
nomi di meccaniche personaggio, ecc.). Ordinate per numero di carte
coinvolte. Per ciascuna: carte rappresentative, cosa chiede la carta, e
costo stimato — **facile** (campo nuovo, nessuna logica nuova),
**schema+motore** (campo nuovo + logica in `Duel.gd`), **strutturale**
(serve un sottosistema nuovo).

| # | Meccanica | Carte | Costo |
|---|---|---|---|
| 1 | Iniziativa alternativa/"segreta" gated da Kamae o focus | ~20 | schema+motore |
| 2 | Carte che "RIMANGONO IN GIOCO" tra i turni | 13 | strutturale |
| 3 | Finestre di gioco speciali (inizio turno, dopo reazione/contratto…) | 12 | strutturale |
| 4 | Attacchi/trappole a distanza per confronto iniziativa (non cella) | 8 | strutturale |
| 5 | Guardare la mano dell'avversario | 8 | schema+motore |
| 6 | Risorsa personaggio: Disperazione (Onna-Bugeisha) | 8 | strutturale |
| 7 | Forzare il cambio Kamae dell'**avversario** (non il giocatore) | 10 | schema+motore |
| 8 | Stato personaggio: "stato Ninja" | 7 | strutturale |
| 9 | Stato personaggio: "stato Ombra" (Assassino) | 6 | strutturale |
| 10 | Contrattacchi (`counter`) gated da Kamae | 5 | schema+motore |
| 11 | Risorsa personaggio: Contratti (Yojimbo) | 5 | strutturale |
| 12 | Ciclo "Illuminata" (Monaco) | 5 | strutturale |
| 13 | Effetti di entità variabile/scalata (non un intero fisso) | 6 | schema+motore |
| 14 | Carte a doppia faccia Attacco/Difesa (Hachikō) | 9 | strutturale |
| 15 | Meccanica "gira la carta" (≠ switch_kamae) | 5 | schema+motore |
| 16 | Manipolazione mazzo avanzata (mill, reveal+filtra) | 4 | schema+motore / strutturale |
| 17 | Aumenti permanenti di limite (mano/ferite/focus) | 5 | strutturale |
| 18 | Far pescare l'avversario (`foe_draw`) | 3 | facile→schema+motore |
| 19 | Selezione casuale (scarto/pesca a caso) | 3 | facile |
| 20 | Guarigione ferite / rimozione stati | 4 | schema+motore |
| 21 | Requisiti di giocabilità su conteggio carte in gioco | 3 | strutturale |
| 22 | Quinta Kamae "Distanza" (solo Navigatore) | 4 | schema+motore |
| 23 | Giocare una carta pescata/cercata subito come istantanea | 2 | strutturale |
| 24 | IA compagno "muovi verso il bersaglio" (Hachikō) | 1–2 | strutturale |
| 25 | Trigger di adiacenza a un terzo pezzo (Ashigaru+Hachikō insieme) | 1 | strutturale |
| 26 | Effetto anti-sconfitta | 1 | strutturale |
| 27 | Ricorsione carta: torna in gioco dallo scarto pagando focus | 1 | strutturale |
| 28 | Marcatori trappola sulla griglia, effetto ritardato | 1–2 | strutturale |

Più due cluster **non meccanici** (dati mancanti, non buchi di schema):
carte Solo parzialmente trascritte (901–905, 911–915, mancano gli scan) e i
2 ID divisori-mazzo (215, 234, già esclusi).

### 3.1 Dettaglio per meccanica

**§1 — Iniziativa alternativa.** Una sola azione, giocabile a
un'iniziativa DIVERSA da quella stampata se sei in una Kamae o paghi
focus — **non è uno split** (split = due azioni separate, entrambe
succedono). Verificato sui dati reali: carte come #58, #86, #149, #166 non
hanno campo `split` affatto, solo la nota su un riquadro/banner colorato
con un secondo numero. #44 ha *sia* split *sia* questa iniziativa
alternativa, sono due concetti distinti sulla stessa carta. Esempio
concreto (#149, nota reale): *"Iniziativa stampata 4; il [5] sulla barra
viola col loto = iniziativa alternativa 5 pagando 1 focus."* Serve un campo
tipo `alt_initiative: {value, kamae_req?, focus_cost?}` letto dal
risolutore al momento della scelta dell'iniziativa.
Carte: 44, 58, 60, 65, 77, 86, 100, 105, 109, 140, 143, 146, 149, 166, 169, 175, 279, 303, 324, 325.

**§2 — "RIMANE IN GIOCO".** Carta lasciata scoperta sul tavolo (a volte
nell'area dell'*avversario*, es. #280) che continua a valere ogni turno
finché non viene scartata/pagata. Il motore oggi risolve solo effetti
one-shot. Buco strutturale più grande del catalogo — vedi raccomandazione
strategica in §4.
Carte: 25, 85, 91, 93, 94, 95 (virtù Bushido), 106, 261, 263, 264, 265 (ciclo Illuminata, §3.12), 280, 295, 318.

**§3 — Finestre di gioco speciali.** Trigger diversi da "il tuo turno,
risoluzione normale": inizio turno, dopo una Reazione riuscita, dopo un
Contratto completato, prima di scegliere l'iniziativa in un blocco, "prima
della tua carta attiva". Si lega a §2 (serve comunque un modello di
fase/trigger di turno).
Carte: 79, 82, 83, 85/91/93/94/95, 261, 328, 350, 362.

**§4 — Bersaglio per confronto iniziativa.** Armi a distanza senza vero
diagramma esagonale: colpiscono chi ha iniziativa più bassa questo turno,
a volte solo oltre una soglia. Serve un modo di bersagliare alternativo a
quello posizionale; spesso si accompagna a danno scalato (§13).
Carte: 166, 167, 169, 279, 280, 281, 325, 336.

**§5 — Guardare la mano dell'avversario.** Effetto informativo puro, oggi
senza verbo dedicato (a volte approssimato male con `foe_discard`). Basta
un verbo `foe_reveal_hand` + un'interfaccia per mostrarla — poca
complessità di regole.
Carte: 12, 16, 44 (split), 97, 117, 122, 153, 305, 320.

**§6 — Disperazione (Onna-Bugeisha).** Risorsa/gate extra parallela alle 3
Kamae, esclusiva del personaggio, che sblocca bonus d'attacco,
contrattacchi ed effetti. Candidato per il sottosistema generico di §4.
Carte: 295, 296, 298, 299, 302, 303, 305, 306.

**§7 — Forzare la Kamae dell'avversario.** `switch_kamae`/`change_kamae`
oggi toccano solo il proprietario della carta. Serve la versione "foe" di
questi due verbi — stesso pattern già esistente di `foe_discard`/
`foe_lose_focus`/`foe_stun`. Probabilmente il gap più economico da
chiudere nonostante l'etichetta "schema+motore".
Carte: 45, 66, 87, 97, 145, 240, 301, 326, 336, 362.

**§8 — Stato Ninja.** Modalità specifica del personaggio ("ENTRA IN [stato
Ninja]"), attivata da alcune carte e letta/consumata da altre. Stesso tipo
di problema di §6 e §9.
Carte: 165, 166, 171, 172, 174, 175, 176.

**§9 — Stato Ombra (Assassino).** Stesso schema di §8, personaggio
diverso.
Carte: 221, 224, 225, 226, 228, 229.

**§10 — Contrattacco gated da Kamae.** `counter` oggi è una lista piatta
di iniziative; alcune difese ottengono contrattacchi extra solo in una
Kamae specifica. Stesso trattamento già esistente per `attacks[]`/
`defences[]` — va solo replicato su `counter`.
Carte: 111, 118, 120, 141, 151.

**§11 — Contratti (Yojimbo).** Contatore che dura l'intera partita, letto/
speso/usato per moltiplicare effetti. Si lega a §13 (scalata).
Carte: 316, 319, 321, 322, 328.

**§12 — Ciclo Illuminata (Monaco).** Ciclo auto-referenziale: giocabilità
che richiede "3 carte Illuminata in gioco", ritorno dallo scarto, aumento
permanente di limiti. Si sovrappone a §2, §17, §21.
Carte: 261, 262, 263, 264, 265.

**§13 — Effetti a entità variabile.** Il campo `n` oggi è sempre un intero
letterale; qui va calcolato da qualcos'altro (celle mosse, divario
iniziativa, contatore contratti). Serve un concetto `n_source`/formula
sopra gli effetti esistenti.
Carte: 279, 319, 321, 322, 353, 355.

**§14 — Doppia faccia Hachikō.** Vera carta Attacco + vera carta Difesa
sotto un solo ID, ciascuna col proprio movimento — il campo `move` singolo
non basta. `split` non è il fit giusto (non è "seconda iniziativa", è
"seconda faccia fisica"). Serve una struttura dual-face vera.
Carte: 248, 249, 250, 251, 252, 253, 254, 255, 256.

**§15 — "Gira la carta".** Distinta da `switch_kamae`: un'icona propria
per cambiare faccia/kamae attiva, oggi mascherata con
`switch_kamae to:any`. Probabilmente si risolve insieme a §14.
Carte: 236, 237, 248, 252, 253.

**§16 — Manipolazione mazzo avanzata.** Mill, mill forzato sull'avversario,
reveal+filtra per sottotipo — non mappano su `search_draw`/`reset_deck`/
`draw`. I casi one-shot (#339) sono schema+motore; il mill ricorrente ogni
turno (#280) è strutturale (si lega a §2).
Carte: 219, 225, 280, 339.

**§17 — Limiti permanenti.** Aumento permanente di mano/ferite/focus
finché la carta resta in gioco — sottoinsieme di §2.
Carte: 263, 264, 265, 295, 318.

**§18 — foe_draw.** Il verbo `draw` fa pescare solo chi gioca la carta;
serve la versione che fa pescare l'avversario (o tutti). Stessa famiglia
di §7.
Carte: 12, 13, 17.

**§19 — Selezione casuale.** Un flag `random: true` su discard/search
basta, più una chiamata RNG in risoluzione.
Carte: 242, 318, 327.

**§20 — Guarigione/rimozione stato.** Nessun verbo per rimuovere
davvero una ferita o un token di stato (solo `replace_wound_bleed`, la cui
direzione inversa è essa stessa incerta in più note). Ferite/stati sono
già tracciati per-combattente, quindi non serve un sottosistema nuovo.
Carte: 81, 124, 249, 261.

**§21 — Requisiti su conteggio carte in gioco.** La giocabilità stessa
dipende dal contare carte di un sottotipo in gioco. Si lega a §2/§12.
Carte: 220, 261, 262.

**§22 — Quinta Kamae "Distanza" (Navigatore).** Stance fuori
dall'enum `aggression/balance/determination`. Decidere se enum globale o
per-personaggio prima di implementare (§5.4).
Carte: 252, 279, 280, 281.

**§23 — Giocare una carta pescata come istantanea.** Il risolutore deve
poter giocare una carta come sotto-effetto di un'altra carta in
risoluzione.
Carte: 9, 42.

**§24 — IA "muovi verso il bersaglio".** `change_ai_behaviour` esiste già
ma manca un atomo di movimento "muovi verso X" (opponent/ally). Implica
vera logica di pathing per un personaggio non-giocante.
Carte: 251.

**§25 — Adiacenza a un terzo pezzo.** La maggior parte del motore assume
esattamente due combattenti; questa carta assume tre pezzi sulla plancia
(mazzi Hachikō/Ashigaru schierano due pedine amiche).
Carte: 254.

**§26 — Anti-sconfitta.** Serve un aggancio al passaggio di
verifica-sconfitta del game loop, più ricostruzione del mazzo dallo
scarto.
Carte: 318.

**§27 — Ricorsione dallo scarto.** Se la carta viene scartata da un
effetto avversario, si può pagare focus per riportarla in gioco. Si lega a
§2/§12.
Carte: 264.

**§28 — Marcatori trappola sulla griglia.** Diverso dal già supportato
`link_anchor` (che applica l'effetto SUBITO se colpisci quella cella): qui
si piazza un token che persiste e scatta indipendentemente dall'attacco di
questo turno.
Carte: 170, 280.

---

## 4. Raccomandazione strategica (dal catalogo, prioritizzare qui)

**§6, §11, §9, §8, §12, §2/§17 sono lo stesso identico problema travestito
da personaggio a personaggio**: una risorsa/stato per-combattente che
persiste oltre il turno, che alcune carte impostano e altre leggono o
spendono (Disperazione, Contratti, stato Ombra, stato Ninja, ciclo
Illuminata, carte "rimangono in gioco"). Un solo sottosistema generico
(contatori/flag nominati agganciati a un fighter, leggibili/scrivibili da
`effects[]`) chiuderebbe **~40 carte in un colpo solo** invece di 6
implementazioni su misura. **Costruire questo per primo è la mossa a
maggior leva di tutto il catalogo.**

Secondo blocco a buon rapporto costo/beneficio: **§5, §7, §18** sono tutte
piccole estensioni della famiglia di verbi `foe_*` già esistente — vale la
pena chiuderle insieme in una sessione di lavoro dedicata e corta.

---

## 5. Decisioni da prendere a inizio sessione (confermare con l'utente, non re-derivare da soli)

> **Decise (sessione 2026-07-02):** §5.1 → **dizionario libero** di
> flag/contatori per-fighter; §5.2 → **confermato**, `alt_initiative` campo
> separato dallo split; §5.3 → **audit prima** (report in
> `docs/GATE_AUDIT.md`), refactor in Fase 5; §5.4 → Kamae "Distanza"
> **vincolata al solo Navigatore**.

1. **Forma del sottosistema "stato persistente"** (§4): contatori/flag
   nominati per-fighter, dizionario libero vs enum fisso di nomi noti,
   dove vive nello schema (`geometry.json` per la definizione, `GameState`
   per il valore runtime).
2. **Iniziativa alternativa (§3.1) è un concetto a parte** dallo split
   (verificato con l'utente in questa sessione, non ridiscuterlo da capo)
   — implementare come campo `alt_initiative` separato.
3. **Ambito della fase di semplificazione (obiettivo B).** L'utente ha
   chiesto un controllo accurato di tutte le 281 carte per trovare
   condizioni/azioni duplicabili (es. "posso ruotare se kamae_req e
   focus_cost sono soddisfatti" — lo stesso gate che già esiste su atomi
   di movimento, `attacks[]`/`defences[]`, e che serve anche per `counter`
   §3.10 e `alt_initiative` §3.1). **Questo audit NON è ancora stato
   fatto** in modo sistematico — la sessione precedente ha trovato solo il
   pattern isolato durante la discussione, non un'analisi completa.
   Decidere: prima un audit "solo report" (Fase 1 sotto) da presentare
   all'utente, o direttamente un refactor incrementale mano a mano che si
   implementano le meccaniche del catalogo? **Raccomandato: audit prima**
   — cambiare la forma dello schema mentre si aggiungono 28 meccaniche
   nuove rischia di dover rifare lavoro due volte.
4. **Quinta Kamae "Distanza"** (§3.22): enum globale (`kamae_req` accetta
   anche `"distanza"` per chiunque) o vincolato al solo Navigatore?

---

## 6. TODO a fasi

### Fase 0 — Setup
- [x] Leggere questo file + `GEOMETRY_SCHEMA.md` + `docs/CARD_EDITOR_ROADMAP.md`
      (per capire come è fatto l'editor esistente).
- [ ] Procurarsi un binario Godot **4.6** headless linux x86_64, verificare
      che la suite di test giri e dia la stessa baseline di §2 (4 fail
      pre-esistenti, tutto il resto verde). ⚠️ *Bloccato nelle sessioni
      remote correnti: la policy di rete nega il download (github releases
      e mirror) — vedi `GATE_AUDIT.md` §6. Da fare in locale o allargando
      la policy dell'ambiente.*
- [x] Confermare le **Decisioni §5** con l'utente prima di scrivere codice.

### Fase 1 — Audit di semplificazione (obiettivo B, se deciso in §5.3)
- [x] Scandire le 281 carte e mappare ogni pattern di condizione/gate
      usato oggi per movimento, attacco/difesa, contrattacco, effetti.
- [x] Individuare quali sono davvero lo stesso concetto ripetuto vs quali
      sono genuinamente diversi.
- [x] Proporre (senza ancora implementare) un concetto di "gate" unificato
      — quali campi lo compongono (`kamae_req`? `focus_cost`? altro
      trovato durante l'audit?), dove si applica.
- [ ] Presentare il report all'utente per approvazione prima di toccare
      schema o editor. → **report pronto: `docs/GATE_AUDIT.md`** (include
      un bug reale trovato: `focus_cost` sugli atomi di movimento ignorato
      da `Move.gd`, 31 atomi).

### Fase 2 — Sottosistema stato persistente (cuore dell'obiettivo A)
- [x] Disegnare schema + `Duel.gd`/`GameState.gd` per stato per-fighter
      che persiste tra i turni (contatori/flag nominati, leggibili/
      scrivibili da `effects[]`). → `Fighter.states`, verbi `state_*`,
      gate `state`/`state_req`, helper `engine/Gate.gd` (v0.78.0, PR #83).
- [ ] Widget editor per crearlo/leggerlo (`GeometryEditor.gd`). → per ora
      i campi nuovi SOPRAVVIVONO all'editor (passthrough dei campi non
      modellati, v0.78.0) ma non hanno ancora UI dedicata.
- [x] Applicarlo a Disperazione (§3.6), stato Ombra (§3.9), stato Ninja
      (§3.8), ciclo Illuminata (§3.12) — 25 carte, verificate sugli scan.
      **Contratti (§3.11) rinviati a Fase 3** (serve `n_source`, il
      conteggio moltiplica effetti); "rimane in gioco" (§3.2/§3.17) resta
      per la Fase 4 (trigger per-turno). Aperto: attivazione Disperazione
      (regola espansione), possibile unificazione Ombra=Ninja
      ("Occultamento"), uscita/durata degli stati.
- [x] Test headless dedicati (`tests/test_gate_states.tscn`) + re-verifica
      delle carte toccate contro gli scan reali. ⚠️ Suite NON eseguita:
      binario Godot non disponibile nella sessione remota (vedi Fase 0).

### Fase 3 — Gruppo economico "schema+motore"
- [x] `alt_initiative` (§3.1) — 16 carte (v0.79.0); #146 ha un *range*
      alternativo, non un valore: in nota. #166/#169/#279 erano soglie
      trappola (§3.4), non alt initiative.
- [x] `foe_switch_kamae`/`foe_change_kamae` (§3.7), `foe_draw` (§3.18),
      `foe_reveal_hand` (§3.5) — fatti insieme; corretti 7 dati che
      spostavano il GIOCATORE invece dell'avversario e 3 segnaposto errati.
- [x] `counter` gated da Kamae/stato (§3.10) — 6 carte (#299 inclusa).
- [x] Effetti a entità variabile: `n_from_state` (§3.13) — sblocca #322
      (Contratti); #319/#321/#328 restano per fasi successive (bonus
      iniziativa/raggio variabile, finestre di gioco).
- [ ] Quinta Kamae "Distanza" (§3.22): **rinviata** — tocca gli enum di
      stance ovunque; da fare quando la suite di test è eseguibile.
- [x] Guarigione/rimozione stato `heal` (§3.20), selezione casuale
      `random: true` (§3.19).

### Fase 4 — Gruppo strutturale rimanente
- [ ] Doppia faccia Hachikō (§3.14) + "gira la carta" (§3.15).
- [ ] Bersaglio per confronto iniziativa (§3.4).
- [ ] Finestre di trigger/fase turno (§3.3, si appoggia sul lavoro di
      Fase 2 per §3.2).
- [ ] Manipolazione mazzo avanzata (§3.16).
- [ ] Requisiti su conteggio carte in gioco (§3.21).
- [ ] Marcatori trappola su griglia (§3.28).
- [ ] I casi isolati (1-2 carte ciascuno): giocare carta pescata come
      istantanea (§3.23), IA muovi-verso (§3.24), adiacenza a terzo pezzo
      (§3.25), anti-sconfitta (§3.26), ricorsione da scarto (§3.27).

### Fase 5 — Refactor di semplificazione (obiettivo B, esecuzione)
- [ ] Applicare il concetto di "gate" unificato deciso in Fase 1, ora che
      è chiaro cosa serve davvero dalle Fasi 2-4 (non prima — rischio di
      disegnare la generalizzazione sbagliata).
- [ ] Aggiornare `GeometryEditor.gd` di conseguenza.
- [ ] Verificare che il refactor non perda dati su nessuna delle 281
      carte (stesso approccio usato in PR #82: round-trip test su un
      campione + suite completa).

### Fase 6 — Riverifica finale
- [ ] Con tutti i nuovi campi disponibili, ripassare le carte del
      catalogo §3 e rimuovere "non modellata"/"DA VERIFICARE" dalle note
      dove il gap è stato davvero chiuso.
- [ ] Aggiornare `GEOMETRY_SCHEMA.md` con tutti i campi nuovi.
- [ ] Bump versione + CHANGELOG finale del ciclo.

---

## 7. Rischi & trappole

- **Non disegnare 5 implementazioni bespoke** per Disperazione/Contratti/
  Ombra/stato Ninja/Illuminata — è esattamente l'errore che la
  raccomandazione strategica (§4) vuole evitare.
- **Non rifattorizzare lo schema prima di sapere cosa serve**: l'audit di
  semplificazione (Fase 1) è un report, non un'implementazione — eseguirlo
  troppo presto rischia di generalizzare nel modo sbagliato.
- **`geometry.json` è grande (281 carte)**: mai riscritture manuali
  massive, sempre lo script Python chirurgico (§2). Validare sempre con
  `json.load` dopo ogni modifica.
- **I 4 test pre-esistenti falliti (§2) non sono un problema da questa
  sessione** — non provare a "pulirli" a meno che il task lo richieda.
  `test_kamae` in particolare potrebbe risolversi *naturalmente* come
  effetto collaterale di §3.7 (foe_switch_kamae) — verificare, non
  presumere.
- **Ogni carta toccata va riverificata contro lo scan reale**, non solo
  contro la propria nota — la sessione precedente ha trovato ~20 errori
  reali proprio in una fase di "verifica adversariale" post-transcrizione;
  aspettarsi lo stesso qui.

---

## 8. Mappa rapida dei file

```
godot/data/cards/geometry.json          # 281 carte, Schema v2 + split
godot/data/cards/GEOMETRY_SCHEMA.md     # schema documentato, aggiornalo mano a mano
godot/data/cards/card_pool.json         # anagrafica (generata da Excel)
godot/data/cards/card_pool_overrides.json  # overlay editor sopra l'anagrafica
godot/data/cards/card_images.json       # ID -> path immagine
godot/engine/CardDB.gd                  # carica/indicizza tutti i dati carte
godot/engine/Duel.gd                    # risolutore di carta (dove va la nuova logica)
godot/engine/GameState.gd               # Fighter/stato di gioco (dove va lo stato persistente)
godot/engine/Kamae.gd                   # gate_values/gate_allows/gate_is_empty
godot/engine/CardValidator.gd           # regole di validazione + vocabolari controllati
godot/engine/CardSimulator.gd           # tester "Simula carta" + explain() in italiano
godot/scenes/GeometryEditor.gd          # editor visuale geometria (widget tree)
godot/scenes/CardEditor.gd              # editor anagrafica + immagini
godot/tests/test_allcards.tscn          # smoke: risolve tutte le 281 carte
godot/tests/test_geometry_editor.tscn   # round-trip editor
godot/tests/test_cardvalidator.tscn     # regole di validazione
docs/CARD_EDITOR_ROADMAP.md             # come è stato costruito l'editor (storico)
```
