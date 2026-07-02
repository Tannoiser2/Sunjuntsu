# Audit di semplificazione — gate/condizioni sulle carte (Fase 1)

> Report della Fase 1 del piano in `CARD_MECHANICS_ROADMAP.md` (obiettivo B).
> Analisi statica di tutte le **281 carte** di `godot/data/cards/geometry.json`
> (inclusi i blocchi `split`) + lettura dei siti del motore che consumano i
> gate. **Solo report: nessuna modifica a schema, dati o editor** — da
> approvare prima di implementare (Fase 5, con l'helper anticipabile in Fase 2).

---

## 1. Censimento: dove vive oggi il concetto di "condizione"

Il pattern ricorrente è sempre lo stesso: *"questa (carta | sotto-parte) vale
solo se sei in una certa Kamae e/o paghi N focus"*. Oggi appare in **6 sedi**
con nomi di campo e supporto motore diversi, più 2 sedi future già note:

| # | Sede | Campo Kamae | Campo focus | Occorrenze nei dati | Supporto motore |
|---|------|-------------|-------------|---------------------|-----------------|
| 1 | Giocabilità carta (e `split`) | `kamae_req` (string o array OR) | — | 24 carte (22 string, 2 array) | ✅ `Duel.playable`, `AI`, `CardSimulator` via `Kamae.gate_allows` |
| 2 | Atomi di movimento | `kamae` | `focus_cost` | kamae: 98 atomi (79 + 19 split) · focus: 31 (21 + 10 split) · entrambi: 1 (#270) | ⚠️ kamae ✅ (`Move.reachable_states`); **`focus_cost` IGNORATO** (vedi §4) |
| 3 | Varianti `attacks[]` / `defences[]` | `kamae` | — | 10 varianti (9 att. su #19/24/26/39/100/113…, 1 dif. #99) | ✅ `Duel._variant_for` con fallback `gate_is_empty` |
| 4 | Celle d'attacco | — | `focus_cost` (+ `w_focus` come payoff) | 5 celle (#68, #71, #86, #164×2) | ✅ ferite bonus a pagamento (`Duel.gd:689`), saltate in auto-risoluzione |
| 5 | Effetti | `kamae` (string o array OR) | `focus_cost` | kamae: 98 (89 + 9 split, oggi tutti string) · focus: 28 · **mai entrambi sullo stesso effetto** | ✅ `_apply_effects`: `gate_allows` + skip se `focus_cost > 0` in auto-risoluzione |
| 6 | Contrattacco `counter` | — | — | 16 liste piatte (14 + 2 split) | ❌ nessun gate possibile: **5 carte** lo richiedono (#111, #118, #120, #141, #151 — nota "gate non modellabile") |
| 7 | `alt_initiative` (da creare, §3.1 roadmap) | serve | serve | 20 carte: 7 solo-Kamae, 4 solo-focus, **9 entrambi** | ❌ non esiste |
| 8 | Stato persistente (Fase 2 roadmap) | — | — | i gate su Disperazione/Ombra/Ninja/… sono la stessa forma con una risorsa diversa dalla Kamae | ❌ non esiste |

Campi che convivono coi gate ma **non sono gate** (da NON unificare):

- `when` (`on_hit` ×166, `always` esplicito ×1) — è un *trigger temporale*
  (quando si valuta l'effetto), non una condizione di stato del combattente.
- `alt` (96 effetti) — è una *scelta esclusiva del giocatore* ("OPPURE"),
  ortogonale al gate: un'opzione può a sua volta essere gated.
- `w_focus` — è il *payoff* dell'aver pagato, non la condizione (resta
  accoppiato a `focus_cost` di cella).
- `to` — destinazione di un cambio Kamae, non condizione.

## 2. Diagnosi

1. **I nomi sono già quasi uniformi** (`kamae` + `focus_cost` in ogni
   sotto-parte; `kamae_req` come nome storico a livello carta): il problema
   non è la forma dei dati ma la **logica duplicata**. Il motore ripete il
   trio `Kamae.gate_allows(x.get("kamae", ""), stance)` +
   `int(x.get("focus_cost", 0)) > 0 → skip` in ~8 punti tra `Duel.gd`,
   `Move.gd`, `CardSimulator.gd`, `MatchProtocol.gd`, con piccole differenze
   di comportamento non intenzionali (§4).
2. **Dove il gate manca del tutto** (`counter`, `alt_initiative`) la
   trascrizione è finita in `note` come "non modellabile" — sono i buchi
   §3.10 e §3.1 del catalogo, entrambi chiudibili con lo *stesso* gate.
3. **L'editor** replica il pattern con widget separati per atomi
   (barra Kamae + loto focus), varianti e effetti: un widget "gate"
   riusabile eliminerebbe la triplicazione anche lì.

## 3. Proposta: gate unificato come *convenzione + helper*, non nuovo schema

**Nessuna migrazione dei dati.** I 281 file-carta restano come sono; si fissa
la convenzione e si centralizza la logica.

### 3.1 Convenzione di schema (documentare in `GEOMETRY_SCHEMA.md`)

Un **gate** è la coppia di campi opzionali, sempre con questi nomi, ovunque
appaia:

```jsonc
{ "kamae": "aggression" | ["balance","determination"],  // OR fra più Kamae
  "focus_cost": 1 }                                      // AND col kamae
```

- Semantica: `kamae` assente/`""`/`[]` = nessun vincolo; `focus_cost`
  assente/0 = gratis; se presenti entrambi valgono in **AND**
  (sei nella Kamae *e* paghi).
- `kamae_req` (livello carta/split) resta col nome storico: è la stessa
  semantica del solo campo `kamae`, il rename non vale il churn su 24 carte
  + motore + editor.
- Le sedi nuove nascono già con questa forma:
  - **`counter` gated (§3.10)**: la lista può contenere, oltre agli int,
    oggetti `{ "on": [6,5], "kamae": "determination" }` — retro-compatibile
    con le 16 liste piatte esistenti (int = sempre attivo).
  - **`alt_initiative` (§3.1)**: `{ "value": 5, "kamae": …?, "focus_cost": …? }`.
  - **Stato persistente (Fase 2)**: il gate si estenderà con una chiave per
    le risorse/flag (es. `"state": {"contratti": 2}`) — stessa sede, stesso
    helper, deciso in dettaglio in Fase 2.

### 3.2 Helper unico nel motore — `Gate.gd` (o estensione di `Kamae.gd`)

```gdscript
static func allows(part: Dictionary, stance_slug: String) -> bool
    # gate_allows(part.kamae) — il solo controllo di stato, senza focus
static func cost(part: Dictionary) -> int
    # int(part.focus_cost) normalizzato
static func auto_allows(part: Dictionary, stance_slug: String) -> bool
    # allows() AND cost()==0 — la regola "in auto-risoluzione i bonus
    # a pagamento si saltano", oggi copiata a mano in 4 punti
static func describe(part: Dictionary) -> String
    # frase italiana per CardSimulator.explain() / tooltip editor
```

Sostituisce i siti duplicati in: `Duel._apply_effects`, `Duel._resolve_option`,
`Duel._variant_for`, `Move.reachable_states`, `CardSimulator` (×3),
`MatchProtocol` (×2).

### 3.3 Editor: un widget "gate" riusabile

Un solo controllo (barra Kamae multi-selezione + spinner focus) istanziato da
atomi di movimento, varianti di combattimento, effetti, e dalle sedi nuove
(`counter`, `alt_initiative`) — oggi sono tre implementazioni parallele in
`GeometryEditor.gd`.

## 4. Trovato dall'audit: difformità reali del motore (da correggere)

1. **`focus_cost` sugli atomi di movimento è ignorato** — `Move.gd` filtra
   gli atomi per `kamae` ma non legge mai `focus_cost`: i 31 atomi a
   pagamento (es. #35, #46, #67, #72, #99, #134, #136, #138, #270, #277,
   #278) oggi **muovono gratis** in partita. Comportamento atteso (coerente
   con effetti e celle): in auto-risoluzione l'atomo a pagamento si salta;
   in partita interattiva si offre il pagamento. È il caso d'uso perfetto
   per `Gate.auto_allows`.
2. **`test_kamae` (pre-fallito, §2 roadmap)** riguarda l'OR-gate array sul
   campo `kamae` di un effetto: `Kamae.gate_allows` supporta già gli array,
   quindi il fallimento va ri-diagnosticato *eseguendo* il test — non è
   verificabile senza il binario Godot (vedi §6). Nei dati odierni nessun
   effetto usa ancora un `kamae` array: il primo utilizzo reale arriverà
   proprio dai gate nuovi.
3. `kamae` + `focus_cost` **non compaiono mai insieme su uno stesso effetto**
   nei dati attuali (e una sola volta su un atomo, #270 split): la semantica
   AND proposta non cambia il comportamento di nessuna carta esistente.

## 5. Cosa NON fare (confini approvati)

- Nessun oggetto annidato `{"gate": {...}}` nello schema: i campi restano
  piatti dove sono — zero migrazione, diff nulli su `geometry.json`.
- `when`/`alt`/`to`/`w_focus` restano campi propri, fuori dal gate.
- Il refactor dei siti esistenti resta in **Fase 5** come da roadmap;
  `Gate.gd` però conviene introdurlo **all'inizio della Fase 2**, così
  contatori/stati e i campi nuovi (`counter` gated, `alt_initiative`)
  nascono già sull'helper invece di aggiungere l'ennesima copia.

## 6. Stato Fase 0 e vincoli di ambiente

- Decisioni §5 del roadmap **confermate dall'utente** (2026-07-02):
  §5.1 dizionario libero di flag/contatori per-fighter · §5.2 `alt_initiative`
  campo separato dallo split · §5.3 audit prima, refactor in Fase 5 ·
  §5.4 Kamae "Distanza" vincolata al solo Navigatore.
- ⚠️ **Binario Godot 4.6 non ottenibile in questa sessione**: la policy di
  rete limita l'accesso GitHub ai soli repo in scope e blocca i mirror
  (403 dal proxy di egress, non transitorio). La baseline test (4 fail
  pre-esistenti) è quindi **non riverificata**; va rifatta appena il binario
  è disponibile (in locale o allargando la policy dell'ambiente).
