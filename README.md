# Senjutsu — versione digitale

Duello tattico fra samurai su mappa esagonale (*Senjutsu: Battle for Japan*), in Godot 4.7.
Uso personale.

## Stato (versione 1.0.0)

- **Regole**: regolamento della **1a edizione + errata** (quello a cui appartengono le carte
  italiane scansionate), con le carte risolte **riga per riga come sono stampate**.
- **Personaggi giocabili**: Guerriero e Ronin con i mazzi «Signature» ufficiali da 30 carte.
- **Modalità**: partita contro un'IA di base (gioca il mazzo come un giocatore).
- **Editor carte**: scansione accanto alle righe della carta e al testo di come il gioco la applica.

Cosa manca è elencato in `REGOLAMENTO_FEDELTA.md`.

## Struttura

- `godot/engine/` — logica pura: `Game.gd` (regole), `Carte.gd` (dati e testi), `Hex.gd`, `Bot.gd`.
- `godot/scenes/` — `Menu`, `Partita` (tabellone 3D + interfaccia), `Editor`, `Tema`.
- `godot/data/carte.json` — carte, personaggi, alberi Kamae e mappa; si rigenera con
  `python3 godot/tools/genera_carte.py` (trascrizione commentata, carta per carta).
- `godot/tests/` — `regole.gd` (scenari di regole), `partite.gd` (partite automatiche),
  `Schermate.tscn` (schermate dell'interfaccia), `EditorProva.tscn`.
- `godot/tools/controlla_glifi.py` — verifica che ogni carattere dei testi esista nei font.
- `server/`, `phone/` — vecchio online «tavolo + telefoni»: **non ancora adattato** al nuovo motore.

## Verifiche

```
cd godot
godot --headless --path . --import
godot --headless --path . -s tests/regole.gd
godot --headless --path . -s tests/partite.gd -- 300
python3 tools/controlla_glifi.py
```

## Pubblicazione

Solo su richiesta: «Run workflow» a mano su GitHub Actions, oppure un commit su `main` con
`[pubblica]` nel messaggio.
