# Senjutsu — versione digitale

Duello tattico fra samurai su mappa esagonale (*Senjutsu: Battle for Japan*), in Godot 4.7.
Uso personale.

## Stato (versione 1.14.0)

- **Regole**: regolamento della **1a edizione + errata** (quello a cui appartengono le carte
  italiane scansionate), con le carte risolte **riga per riga come sono stampate**.
- **Personaggi giocabili**: Guerriero, Ronin, Allievo, Maestro, Assassino, Monaco, Yasuke, Yojimbo, Wakou, Onna-Bugeisha, Navigatore, Ashigaru con Hachiko e Ninja, con i mazzi «Signature» ufficiali da
  30 carte (tranne Guerriero e Ronin, non hanno ancora la miniatura 3D né il mazzo Solo da avversario).
- **Modalità**: **Solitario** con le carte Solo ufficiali (anche Incubo) e duello contro un'IA di base
  che gioca il mazzo normale.
- **Duello online** a due su Firebase (stanza con codice di 4 lettere, si può rientrare).
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
- `firebase/database.rules.json` — regole della radice `senjutsu` da pubblicare nel progetto Firebase
  della ludoteca (senza, l'online risponde «permesso negato»).
- `server/`, `phone/` — vecchio online «tavolo + telefoni»: **non ancora adattato** al nuovo motore.

Dopo aver cambiato carte o personaggi: `python3 godot/tools/genera_carte.py` e poi
`python3 godot/tools/filtra_export.py` (tiene nell'esportazione web solo le immagini usate).

## Verifiche

```
cd godot
godot --headless --path . --import
godot --headless --path . -s tests/regole.gd
godot --headless --path . -s tests/partite.gd -- 300
python3 tools/controlla_glifi.py
# online, con il finto Firebase:
python3 tests/firebase_mock.py 8765 &
FR_DB_URL=http://127.0.0.1:8765/db FR_AUTH_URL=http://127.0.0.1:8765/signup \
  FR_REFRESH_URL=http://127.0.0.1:8765/refresh godot --headless --path . res://tests/OnlineProva.tscn
```

## Pubblicazione

Solo su richiesta: «Run workflow» a mano su GitHub Actions, oppure un commit su `main` con
`[pubblica]` nel messaggio.
