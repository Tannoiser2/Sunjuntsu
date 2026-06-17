# Senjutsu 3D — Documento di design (primo passaggio)

Versione digitale di **Senjutsu: Battle for Japan**: duello tattico tra
guerrieri su mappa esagonale, pedine 3D, modalità **solo** (vs IA) e **1 vs 1**
in multiplayer. Motore: **Godot 4.6**.

## 1. Stato del materiale di partenza

Sorgente: `Tabelle_Materiali/Senjutsu/` (sul branch `main`).

| Tipo | Presente | Note |
|------|----------|------|
| **Dati carte (Excel)** | ✅ | `Tabelle/Senjutsu_Deckbuilding_1.1.xlsx` → 303 carte, 24 personaggi. Importato in `data/cards/card_pool.json` |
| Regolamento | ✅ | `Senjutsu_Rulebook_1.5_With_Solo_BGG.pdf` + `Tabelle/Senjutsu_Reference_Sheet.pdf`, `Senjutsu_Kamae_Cards_1.5.pdf` |
| Tabelle IA solo | ✅ | `Tabelle/solo_AI_tables_v1.xlsx`, `Tabelle/1.5_Path_Of_The_Ronin_Solo_Book.pdf` |
| Carte (immagini) | ✅ | `CARTE/Guerriero.pdf`, `Ronin .pdf`, `Ferite.pdf` (per i ritagli HUD) |
| Mappe | ✅ | 3 PNG arena ~3270×3270 (asset Tabletop Simulator) |
| Miniature 3D | ✅ | 11 `.obj`; **manca** `.mtl`/texture → modelli senza materiali |
| Mazzo **Jin Sakai** | ⚠️ | Presente come **immagini JPG** custom in `CARTE/SENJUTSU-JIN_SAKAI/` (~30 carte) — non nell'Excel: da trascrivere a parte |

> I dati carte ufficiali sono già importati. Restano da estrarre dalle immagini
> i dettagli "geometrici" (zone del corpo, movimento/rotazione) e il mazzo
> custom Jin Sakai.

## 2. Architettura

Separazione netta **logica ↔ presentazione** (la logica gira headless ed è
riusabile identica per solo e multiplayer).

```
godot/
├─ engine/         LOGICA PURA (RefCounted/autoload, niente nodi 3D)
│   Domain.gd      enum e costanti: Kamae, CardType, BodyZone, Warrior, Phase
│   HexGrid.gd     matematica esagoni assiali + conversione mondo 3D + BFS
│   CardDB.gd      carica i mazzi da data/cards/*.json (autoload)
│   GameState.gd   stato del duello: combattenti, mappa, mazzi, ferite
│   Duel.gd        macchina a fasi del turno + segnali
├─ scenes/         PRESENTAZIONE 3D
│   Menu.tscn/.gd  menu (Solo / 1v1 / Esci)
│   Arena.tscn/.gd mappa hex procedurale, camera orbitale, picking, movimento
│   Pawn.gd        pedina (capsula segnaposto → poi miniatura .obj)
├─ data/cards/     cataloghi carte JSON + SCHEMA.md
└─ assets/         (vuoto) — istruzioni in assets/README.md
```

## 3. Modello esagonale
- Coordinate **assiali (q, r)**, orientamento **flat-top**.
- `HexGrid` fornisce: vicini, distanza, area/raggio, anello, conversione
  hex↔mondo 3D (piano XZ), BFS per le celle raggiungibili.
- Arena = disco esagonale di raggio configurabile; tessere = `CylinderMesh` a 6
  lati con collisione per il picking del mouse.

## 4. Anatomia delle carte (osservata dalle immagini)
Tre tipi: **Attacco / Difesa / Meditazione**. Elementi:
- **Costo** (stemma in alto a sx) e **Kamae** giocabili (icone colorate a sx).
- **Iniziativa** (✱), **movimento** (↑), **rotazione/portata** (↻).
- **Pattern a nido d'ape (7 zone)** = il corpo: gli attacchi indicano le zone
  colpite, le difese quelle protette. È il cuore del sistema ferite.
- Effetti su mano/mazzo (pesca/scarta) e cambi di kamae.

Schema dati completo: `data/cards/SCHEMA.md`.

## 5. Flusso del turno (Duel.gd)
`SETUP → PLANNING (programmazione simultanea nascosta) → REVEAL → RESOLUTION
(per iniziativa) → WOUNDS (pesca da mazzo Ferite) → CLEANUP → PLANNING...`

Implementato: macchina a fasi, programmazione, rivelazione, ordine di
iniziativa, scarto/pesca. **Da completare**: risoluzione attacchi per zona,
difese, applicazione ferite, condizioni di vittoria reali — dipendono dai dati
carte.

## 6. Modalità di gioco
- **Solo**: `engine/AI.gd` (da creare) sceglie la carta dell'avversario.
- **1 vs 1**: high-level multiplayer di Godot (`MultiplayerAPI`). Poiché la
  logica è in `GameState`/`Duel`, basta sincronizzare le carte programmate e far
  girare la risoluzione in modo deterministico su entrambi i client (o
  autoritativo su host). Vedi roadmap.

## 7. Roadmap
1. **[fatto] Scaffold**: arena hex 3D, camera, pedine, movimento su click.
2. **[fatto] Dati carte**: Excel → `data/cards/card_pool.json` (303 carte, 24
   personaggi). Da completare: zone corpo/movimento dalle immagini, mazzo
   custom Jin Sakai, mazzo Ferite.
3. **Risoluzione combattimento**: attacchi per zona, difese, ferite, vittoria
   (basata su regolamento 1.5 + Reference Sheet).
4. **HUD carte**: mano in basso, selezione/programmazione, ritagli carte dai PDF.
5. **IA solo**: euristica di scelta carta.
6. **Multiplayer 1v1**: lobby + sincronizzazione.
7. **Asset reali**: miniature `.obj` come pedine, mappe PNG come texture arena.

## 8. Come eseguire
Apri `godot/project.godot` con Godot **4.6**, premi Play. Dal menu scegli una
modalità: nell'arena, **trascina col tasto destro** per ruotare la camera,
**rotella** per zoomare, **click sinistro** su un esagono evidenziato per
muovere la pedina attiva.
