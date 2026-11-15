# Senjutsu — fedeltà al regolamento

Fonte: **Rulebook 1a edizione con errata** (`Senjutsu Rule Book_Errata_v1_MAIN_compressed.pdf`)
più le **carte italiane scansionate** (cartella `CARTE`). Le carte italiane sono della 1a
edizione: per questo NON si usa il regolamento 1.5, che cambia alberi Kamae, contrattacchi e
testo di varie carte.

## Implementato

- **Turno**: sanguinamento (scarto della cima del mazzo prima della pesca), pesca (mazzo vuoto =
  ferita), scelta coperta, rivelazione, costi focus, Sostituzioni istantanee (con rimborso),
  iniziative alternative (banda Kamae = obbligatoria), iniziative variabili, risoluzione in ordine
  d'iniziativa, spareggi per tipo (difesa, attacco, meditazione, speciale; le armi dopo le carte
  normali) e poi scelta di chi ha il Vantaggio, scarto, limite di mano.
- **Carte riga per riga**: bande Kamae, costi focus facoltativi, OPPURE (l'opzione della tua Kamae
  è obbligatoria), «SE RIUSCITO» (vale fino alla fine del segmento), divisori con seconda iniziativa.
- **Movimento**: passi e rotazioni facoltativi/obbligatori, stessa direzione per le mosse multiple,
  qualsiasi ordine sulla stessa riga, «poi» in sequenza; collisioni (fuori campo, altro personaggio)
  con interruzione della carta.
- **Commit To Hit**: se muovendoti (anche pagando un focus) puoi colpire, devi farlo.
- **Attacchi**: griglie a 2 anelli con celle esatte, ferite, sanguinanti, esecuzione, asterischi,
  non bloccabile.
- **Blocchi**: valgono solo all'iniziativa scelta; fermano l'attacco se coprono la cella
  dell'attaccante o ogni percorso più breve. **Contrattacco** (1a ed.): si gioca subito una carta
  Attacco non speciale di iniziativa uguale o inferiore.
- **Kamae**: alberi di Guerriero e Ronin con rami a senso unico e **Punto Focus**; «Passa a».
- **Stati**: stordimenti in mano (giocabili al posto di una carta, sconfitta al limite di mano),
  azzoppamento (−1 iniziativa per 3 turni, non nel turno in cui lo subisci), Armatura Pesante.
- **Istantanee**: Aggiunte «se l'attacco è riuscito» e «dopo aver risolto la carta», Blocco Ampio,
  una sola istantanea per turno, mai sulle carte speciali o dello stesso tipo.
- **Vantaggio**, spinte (con scelta in caso di parità e collisioni), rotazione del bersaglio,
  cancellazione di carte/movimento attivi, ricerca nel mazzo.
- **Campo**: tavoliere del «villaggio in fiamme» con tutte le 37 caselle (7 colonne da 4, 5, 6, 7, 6, 5, 4).
- **Costruzione del mazzo** (editor dei mazzi): 30 o 40 carte più carta speciale e arma; Legno 3 copie,
  Acciaio 2, Oro 1 (max 8 Oro), Giada 1; carte base per tutti, firma solo del proprio personaggio.
  Le «Scuole Ristrette» del gioco competitivo non sono applicate. Armi senza carta nel gioco (Bo, Kama,
  Sai, Tonfa, Shikomizue) non si possono scegliere.
- **Terreno**: piazzamento a turno a più di 2 caselle dagli altri pezzi; non si attraversa (collisione
  = si torna indietro e si prende 1 stordimento); blocco a ogni iniziativa che non conta come «blocco
  riuscito»; linea di vista dagli angoli frontali agli angoli del bersaglio. Ciliegio e Torii seguono il
  regolamento (stordimento); Campane e Carro non sono nel regolamento e usano la regola delle Rocce. Il
  Torii occupa una sola casella (non si passa sotto).
- **Schieramento**: chi è più in basso sul tracciato del Vantaggio si piazza su una casella libera
  qualsiasi; gli altri a più di 3 caselle dagli avversari già piazzati (se impossibile, il più lontano possibile).

## Solitario (carte Solo)

- Mazzo dell'avversario: 4 carte firma + 1 carta dai mazzi di selezione 1, 3, 4, 5 + 1 carta
  aggiuntiva (2, 4 o 5); in Incubo la carta Incubo sostituisce quella del mazzo 3.
- L'avversario non ha mano né focus: rivela la cima del mazzo; limite ferite 7; mazzo esaurito =
  1 ferita e rimescola; «Ricomponi il mazzo» a fine turno.
- Stordimenti mischiati nel mazzo: se escono salta il turno; sconfitto a 7 stordimenti.
- Carte con OPPURE: la parte alta se può attaccare, altrimenti la parte bassa alla sua iniziativa.
  Atteggiamento Difensivo: rinuncia se verrebbe parato o resterebbe sotto il tuo attacco.
- Difese: scelgono l'iniziativa del tuo attacco; contrattacco Solo (scarta la cima del mazzo: se è
  un attacco subisci 1 ferita).
- Movimento: distanza preferita (Ronin 2, Guerriero 1), fronte verso di te, lato dato dal
  Comportamento (Sinistra, Centro, Destra); in attacco preferisce le spalle e il maggior danno.
- Comportamento e Atteggiamento iniziali a caso, come da regolamento.

Semplificazioni: il «lato» del Comportamento è valutato come preferenza e non con il percorso
libero passo per passo; «verrebbe colpito» considera il tuo attacco dalla tua posizione attuale.

## Scelte d'interpretazione da confermare

- **Blocco Ampio (083)**: l'intervallo d'iniziativa si allarga di 1 a entrambi gli estremi.
- **Istinto Bruciante (057)**: rimescola nel mazzo mano e scarti (non le speciali).
- **«Pesca fino a N»**: scegli quante carte pescare, da 0 a N.
- **Spinta «direttamente via»**: la casella più lontana in linea d'aria; se due sono pari sceglie
  chi spinge.

## Non ancora fatto

- Allievo: «Specchio d'Acqua», riga da 2 focus (giocare la carta presa come Sostituzione istantanea)
  non è automatizzata.
- Solo: avversari su pedina (Ashigaru, Boss), più avversari insieme, carte a distanza (Yumi,
  archibugio), campagna «Path of the Ronin».
- Online «tavolo + telefoni» (il duello online a due su Firebase c'è).
- Terreno (rocce, bambù, carri, torii) e linea di vista; altre mappe; scelta dell'arma
  (ora Nodachi per il Guerriero e Naginata per il Ronin, come nei mazzi Signature).
- Veleni oltre al Veleno Debilitante, partite a 3+ giocatori.
