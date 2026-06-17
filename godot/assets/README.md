# Asset — integrazione

Lo scaffold gira **senza** asset esterni (mappa e pedine sono generate
proceduralmente). Per usare i materiali reali presenti in
`Tabelle_Materiali/Senjutsu/`:

## Miniature 3D (.obj)
- Sorgente: `Tabelle_Materiali/Senjutsu/Miniature/*.obj`
  (Yojimbo, Musashi, Onna-Bugeisha, Wakou, Student, Doggo, ...).
- **Attenzione:** i file `.mtl` e le texture referenziati dagli `.obj` **non
  sono nel repo materiali** → i modelli si importano senza materiali. Servono
  le texture originali oppure si assegnano materiali in Godot.
- Copia gli `.obj` (+ eventuali `.mtl`/texture) in `assets/miniatures/`, poi in
  `scenes/Pawn.gd` istanzia la mesh importata al posto della capsula.

## Mappe (texture arena)
- Sorgente: `Tabelle_Materiali/Senjutsu/MAPPE/*.png` (~3270×3270 px).
- Si possono usare come texture del piano dell'arena, oppure come riferimento
  per disegnare la griglia esagonale sopra.

## Carte
- Sorgente: `Tabelle_Materiali/Senjutsu/CARTE/*.pdf` (immagini).
- I dati funzionali vanno in `data/cards/*.json` (vedi `data/cards/SCHEMA.md`).
- Le immagini delle singole carte possono essere ritagliate dai PDF per l'HUD.
