# Schema dati carte — Senjutsu

`card_pool.json` è generato dall'Excel ufficiale di deckbuilding
(`Tabelle_Materiali/Senjutsu/Tabelle/Senjutsu_Deckbuilding_1.1.xlsx`,
foglio *Card Pool*). Struttura:

```json
{
  "source": "...",
  "ranks": ["Wood", "Steel", "Gold", "Jade"],
  "count": 303,
  "characters": ["Ronin", "Warrior", "Musashi", ...],
  "cards": [ { ...carta... } ]
}
```

## Campi di ogni carta

| Campo        | Tipo          | Significato |
|--------------|---------------|-------------|
| `id`         | int           | Identificatore univoco (Card ID) |
| `name`       | string        | Nome della carta |
| `char`       | string        | Personaggio/tipo: `Ronin`, `Warrior`, `Musashi`, `Gen. Ability`, `Weapon`, ... |
| `amount`     | int           | Numero di copie nel mazzo |
| `rank`       | string        | Ramo kamae: `Wood` < `Steel` < `Gold` < `Jade`, oppure `-` (Core) |
| `initiative` | string        | Iniziativa: numero, `=` (istantanea), `-` (nessuna) o lista (`"7,6,5,4,3"`, `"6/7"`) |
| `focus`      | int           | Costo in Focus (Foc. Cst.) |
| `keywords`   | array[string] | Es. `Attack`, `Defence`, `Meditation`, `Range2`, `Instant`, `Prepared`, `Replacement` |
| `type`       | string        | Derivato dai keywords: `attack`/`defence`/`meditation`/`core`/`other` |

## Note
- Il pool copre **24 personaggi** (gioco base + espansioni). I giocabili di
  partenza (con carte/miniature) sono in `Domain.PLAYABLE`.
- **Jin Sakai** è un mazzo *custom* fornito solo come immagini JPG in
  `Tabelle_Materiali/Senjutsu/CARTE/SENJUTSU-JIN_SAKAI/`: va trascritto a parte
  e aggiunto al pool (non è nell'Excel ufficiale).
- Mancano ancora dal pool i dettagli "geometrici" delle carte (zone del corpo
  colpite/protette nel pattern a nido d'ape e movimento/rotazione): vanno presi
  dal Reference Sheet / dalle immagini. Vedi DESIGN.md.

## Rigenerare
Lo script di estrazione è in `tools/generate_cards.py` (rilanciarlo se l'Excel
cambia).
```
python3 tools/generate_cards.py
```
