# Geometria/effetti delle carte — schema di trascrizione

`geometry.json` contiene i dati stampati **solo sulla faccia delle carte** (non
presenti nell'Excel): portata/raggio dell'attacco, ferite, movimento, blocco ed
effetti. Trascrizione manuale dalle immagini in
`Tabelle_Materiali/Senjutsu/CARTE/` — ogni voce è verificata col **numero
stampato** (= Card ID).

## Convenzione griglia
La honeycomb sulla carta è il vicinato esagonale del personaggio (centro + 6
adiacenti) orientato secondo la direzione: il **▲** è la pedina, le icone sugli
esagoni indicano i bersagli. In un duello 1v1 ciò che conta è **se l'avversario
è nella portata/arco dell'attacco**: per questo trascriviamo `range` (raggio max
degli esagoni colpiti) e, dove utile, `dirs` (direzioni relative: 0 = fronte,
senso orario). Le icone:

| Icona | Significato | Campo |
|-------|-------------|-------|
| ! (ottagono) | 1 ferita | `wounds: 1` |
| ‼ / doppia | 2 ferite | `wounds: 2` |
| goccia | ferita sanguinante | `wound_kind: "bleed"` |
| teschio | esecuzione (sconfitta) | `wound_kind: "exec"` |
| scudo ▽ | esagono bloccato (difesa) | `block: true` |
| ▲ | pedina/orientamento | (riferimento) |
| ↑ / ↓ / ↕ | passo (avanti/indietro) | `steps` |
| ↻ | rotazione | `rotates` |
| ✱ | iniziativa (variabile) | (in deck) |
| fiore | focus | `focus_gain` |

## Campi per carta (tutti opzionali)
| Campo | Tipo | Significato |
|-------|------|-------------|
| `range` | int | raggio max dell'attacco (1 = mischia, 2+ = reach/ranged) |
| `wounds` | int | ferite inflitte al bersaglio colpito (default 1) |
| `wound_kind` | string | `normal` / `bleed` / `exec` |
| `dirs` | array[int] | direzioni relative colpite (0=fronte, orario) — best effort |
| `steps` | int | passi di movimento |
| `rotates` | int | rotazioni |
| `alt_step_rotate` | bool | passo **oppure** rotazione (non entrambi) |
| `block` | bool | è una difesa che para |
| `block_value` | int/string | valore/iniziative del blocco |
| `focus_gain` | int | focus ottenuti |
| `draw` | int | carte pescate |
| `discard` | int | carte scartate |
| `change_kamae` | bool | permette di cambiare kamae |
| `if_success` | array[string] | effetti "se riuscito": `push:N`, `bleed`, `focus:N`, `rotate:N` |
| `note` | string | annotazioni / incertezze |

> **Stato**: trascrizione iniziale e iterativa. I campi robusti (portata, ferite,
> movimento, focus, blocco, effetti) sono affidabili; gli offset esatti dell'arco
> (`dirs`) sono best effort e vanno verificati sul gioco fisico.
