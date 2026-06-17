# Senjutsu — versione digitale 3D

Reimplementazione digitale di *Senjutsu: Battle for Japan*: duello tra guerrieri
su mappa esagonale con **pedine 3D**, modalità **solo** e **1 vs 1**.
Motore: **Godot 4.6**. Uso personale.

> **Primo passaggio**: questo repo contiene lo *scaffold* giocabile (mappa
> esagonale 3D, camera, pedine, movimento) e il documento di design. Il gioco
> completo è in costruzione.

## Avvio rapido
1. Installa [Godot 4.6](https://godotengine.org/).
2. Apri `godot/project.godot`.
3. Premi **Play**. Nel menu scegli una modalità.

Controlli nell'arena: **tasto destro** = ruota camera · **rotella** = zoom ·
**click sinistro** su esagono evidenziato = muovi pedina.

## Struttura
- `godot/engine/` — logica di gioco pura (testabile, riusabile solo/multiplayer)
- `godot/scenes/` — presentazione 3D (menu, arena, pedine)
- `godot/data/cards/` — cataloghi carte (JSON) + schema
- `godot/assets/` — integrazione miniature/mappe (vedi `assets/README.md`)
- `godot/DESIGN.md` — design, architettura e roadmap

## Materiali
Carte, mappe e miniature di partenza sono nel repo `Tabelle_Materiali` sotto
`Senjutsu/`. Vedi `godot/DESIGN.md` per stato e cosa manca (regolamento,
tabelle/Excel dati carte, mazzo Jin Sakai).
