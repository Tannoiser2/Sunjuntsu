## Arena 3D — Senjutsu
##
## Costruisce proceduralmente una mappa esagonale (raggio configurabile),
## camera orbitale, illuminazione e due pedine. Click su un esagono = muovi la
## pedina attiva (entro la portata, celle libere).
##
## Questo è lo scaffold giocabile del "primo passaggio": dimostra mappa hex 3D
## + pedine + camera + interazione. La logica di duello completa vive in
## engine/Duel.gd e va collegata progressivamente (vedi DESIGN.md).
extends Node3D

const TILE_GROUP := "hex_tile"

@export var map_radius: int = 3    ## esagono di raggio 3 = 37 celle (colonne 4,5,6,7,6,5,4)
# ─── Calibrazione mappa↔griglia (regolabili nell'editor) ─────────────────────
@export var hex_size: float = 3.0          ## raggio esagono in unità mondo
@export var map_world_size: float = 44.0   ## lato del piano-mappa (la board occupa la parte centrale)
@export var map_offset: Vector2 = Vector2(0.0, 0.5)  ## scostamento mappa (x,z) per centrare gli esagoni
@export var map_y_rotation: float = 0.0    ## rotazione mappa attorno a Y (gradi)

var state: GameState
var _tiles: Dictionary = {}        ## Vector2i -> MeshInstance3D
var _pawns: Array[Node3D] = []
var _active_pawn: int = 0
var _highlighted: Array[Vector2i] = []

var _cam_pivot: Node3D
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.62
var _cam_dist: float = 34.0
var _dragging := false

var _hud: CanvasLayer
var _duel: Duel
var _attack_preview: Array[Vector2i] = []
var _selected_card: Dictionary = {}
var _move_used: bool = false       ## movimento della carta corrente già speso
var _move_states: Dictionary = {}  ## cella -> Array[int] facing legali (dalla carta)
var _kamae_used: bool = false      ## cambio kamae della carta corrente già fatto
var _ground: MeshInstance3D

## Fase dell'interazione: "planning" (programmi una carta) o "resolving"
## (tocca a te risolvere: muovi + attacca nell'ordine d'iniziativa).
var _phase_mode: String = "planning"
var _resolving_index: int = -1     ## chi sta risolvendo ora (-1 = nessuno)
var _split_stage: bool = false     ## true = stai risolvendo la PARTE BASSA (iniziativa divisa)

## 1v1 locale (hot-seat): entrambe le pedine sono umane e si passano il
## dispositivo. `_planning_player` è il giocatore umano che sta programmando ora.
var _versus: bool = false
var _planning_player: int = 0
var _kamae_shown: int = 0    ## quale combattente è mostrato ora nella carta Kamae dell'HUD
var _instant_mode: String = ""   ## "replace" (Rivelazione) | "play" (Risoluzione) | ""
var _instant_index: int = -1     ## combattente a cui è offerta la scelta istantanea
var _visuals: bool = true        ## animazioni di combattimento attive (disattive in headless)
var _reveal_order: Array = []    ## ordine d'iniziativa (per il pannello di rivelazione)
var _reveal_pending: int = -1    ## primo combattente da risolvere, in attesa di «Avanti»
var _revealed_planned: Dictionary = {}


func _ready() -> void:
	_versus = (Domain.game_mode == "versus")
	_visuals = DisplayServer.get_name() != "headless"   # niente animazioni nei test headless
	state = GameState.new()
	state.map_radius = map_radius
	_build_environment()
	_build_map()
	_spawn_pawns()
	_build_hud()
	_start_duel()


func _build_hud() -> void:
	_hud = preload("res://scenes/HUD.tscn").instantiate()
	add_child(_hud)
	_hud.card_played.connect(_on_card_played)


func _start_duel() -> void:
	_duel = Duel.new(state)
	_duel.interactive = true
	_duel.cards_revealed.connect(_on_cards_revealed)
	_duel.await_resolution.connect(_on_await_resolution)
	_duel.turn_resolved.connect(_on_turn_resolved)
	_duel.fighter_updated.connect(_on_fighter_updated)
	_duel.duel_over.connect(_on_duel_over)
	_duel.phase_changed.connect(_on_phase_changed)
	_duel.await_instant_replace.connect(_on_await_instant_replace)
	_duel.await_instant_play.connect(_on_await_instant_play)
	_duel.combat_event.connect(_on_combat_event)
	_duel.resolution_order.connect(func(o): _reveal_order = o)
	_hud.instant_chosen.connect(_on_instant_chosen)
	_hud.card_selected.connect(_on_card_selected)
	_hud.card_hovered.connect(_on_card_hovered)
	_hud.confirm_pressed.connect(_confirm_resolution)
	_hud.kamae_chosen.connect(_on_kamae_chosen)
	_hud.option_chosen.connect(_on_option_chosen)
	_hud.rotate_requested.connect(_rotate_player)
	_duel.start()
	_planning_player = 0
	# Carta Kamae del giocatore attivo + segnalino della posizione.
	_setup_kamae_for(0)
	_refresh_hand()
	_refresh_status()
	_apply_pawn_facing(0); _apply_pawn_facing(1)
	if _versus:
		_hud.set_info("1v1 locale — Giocatore 1: programma una carta")
		_hud.set_hint("HOT-SEAT: il Giocatore 1 programma (coperta), poi passa il dispositivo al Giocatore 2. Rivelazione e risoluzione per iniziativa.")
	else:
		_hud.set_info("Pianificazione — scegli e programma una carta")
		_hud.set_hint("PIANIFICAZIONE: 1° click anteprima · 2° click PROGRAMMA. Poi rivelazione e risoluzione per iniziativa (muovi/attacca al tuo turno).")


## Indice del combattente umano attivo ORA: chi risolve (in risoluzione) oppure
## chi programma (in pianificazione). Sostituisce il vecchio "sempre pedina 0".
func _active() -> int:
	if _resolving_index >= 0:
		return _resolving_index
	return _planning_player


## Etichetta del combattente: in 1v1 "Giocatore N", in solo "TU"/"IA".
func _who(i: int) -> String:
	if _versus:
		return "Giocatore %d" % (i + 1)
	return "TU" if i == 0 else "IA"


func _card_type_it(t: String) -> String:
	return {"attack": "Attacco", "defence": "Difesa", "meditation": "Meditazione",
		"core": "Carta base", "other": "Speciale"}.get(t, t)


## Carica nell'HUD la carta Kamae del combattente `i` e posiziona il segnalino.
func _setup_kamae_for(i: int) -> void:
	_kamae_shown = i
	var tree := CardDB.kamae_tree_for(state.fighters[i].character.to_lower())
	if tree.has("card"):
		_hud.setup_kamae_tree(tree["card"], tree.get("nodes", {}))
	_hud.set_kamae_marker(Domain.STANCE_SLUG[state.fighters[i].stance])


## Inizio di un nuovo turno: la fase del MOTORE torna a PLANNING (dopo la pesca).
## Allinea la UI allo stato reale e rinfresca la mano (così la carta pescata appare).
func _on_phase_changed(p: int) -> void:
	if p != Domain.Phase.PLANNING:
		return
	_phase_mode = "planning"
	_resolving_index = -1
	_split_stage = false
	_planning_player = 0
	_selected_card = {}
	_move_used = false
	_kamae_used = false
	_reveal_pending = -1
	_reveal_order = []
	_revealed_planned = {}
	_clear_overlays()
	_hud.hide_kamae()
	_hud.hide_confirm()
	_hud.hide_options()
	_hud.hide_instant()
	_hud.hide_played_card()
	_instant_mode = ""
	_sync_pawns()
	_setup_kamae_for(0)
	_refresh_hand()
	_refresh_status()
	if _versus:
		_hud.set_info("Giocatore 1: programma una carta")
	else:
		_hud.set_info("Pianificazione — scegli e programma una carta")


## 2° click su una carta = PROGRAMMA la carta coperta (fase di pianificazione).
## Il movimento NON avviene ora: si farà in risoluzione, nell'ordine d'iniziativa.
func _on_card_played(card_data: Dictionary) -> void:
	if _phase_mode != "planning":
		return   # durante la risoluzione/handoff la mano è bloccata
	var id := int(card_data.get("id", -1))
	if id == -1:
		return
	var pi := _planning_player
	var f := state.fighters[pi]
	if not Duel.playable(f, id):
		var req: String = CardDB.geometry(id).get("kamae_req", "")
		_hud.set_hint("⛔ Non giocabile: richiede Kamae %s (sei in %s)" % [
			Domain.STANCE_NAMES.get(Domain.STANCE_FROM_SLUG.get(req, -1), req),
			Domain.STANCE_NAMES[f.stance]])
		return   # la carta resta in mano
	var cost: int = int(CardDB.card(id).get("focus", 0))
	if f.focus < cost:
		_hud.set_hint("◈ Focus insufficiente: servono %d, ne hai %d" % [cost, f.focus])
		return   # la carta resta in mano
	# Pulisci selezione/pulsante PRIMA di programmare: plan_card può avviare subito la
	# Rivelazione (che mostra il pulsante «Avanti»), quindi non va nascosto dopo.
	_selected_card = {}
	_clear_overlays()
	_hud.hide_kamae()
	_hud.hide_confirm()
	if not _duel.plan_card(pi, id):   # → quando entrambi pronti parte begin_resolution()
		_hud.set_hint("⛔ Impossibile programmare la carta ora (riprova).")
		_refresh_hand()
		return
	# 1v1: se l'altro umano deve ancora programmare, passa il dispositivo.
	if _versus and state.phase == Domain.Phase.PLANNING:
		_enter_handoff()
		return
	# La carta è bloccata (coperta). La RIVELAZIONE (che nasconde la mano e mostra
	# l'ordine d'iniziativa + «Avanti») è già stata avviata da _on_cards_revealed.


## 1v1 hot-seat: il giocatore corrente ha programmato; chiede di passare il
## dispositivo all'altro umano (che non deve vedere la carta scelta).
func _enter_handoff() -> void:
	_phase_mode = "handoff"
	var other := 1 - _planning_player
	_hud.show_hand([])              # nasconde la mano: l'altro non deve vederla ancora
	_hud.hide_kamae()
	_hud.hide_played_card()
	_clear_overlays()
	_hud.show_confirm("Giocatore %d: tocca a te ▶" % (other + 1))
	_hud.set_info("Giocatore %d ha programmato (coperta)." % (_planning_player + 1))
	_hud.set_hint("Passa il dispositivo al Giocatore %d, poi premi Conferma per programmare la tua carta." % (other + 1))


func _on_fighter_updated(_i: int) -> void:
	_sync_pawns()
	_refresh_status()


## Entrambe le carte rivelate → fase RIVELAZIONE: si fermano le azioni finché il
## giocatore non preme «Avanti», così vede le carte e l'ordine d'iniziativa.
func _on_cards_revealed(planned: Dictionary) -> void:
	_revealed_planned = planned
	_phase_mode = "reveal"
	_hud.show_hand([])   # nascondi la mano: ora si risolve, non si sceglie (e non copre «Avanti»)


## Tocca a `i` risolvere (ordine d'iniziativa). Se sei tu, muovi e attacca;
## se è l'IA, agisce da sola.
func _on_await_resolution(i: int) -> void:
	# Fase RIVELAZIONE: il primo a risolvere aspetta che il giocatore prema «Avanti».
	if _phase_mode == "reveal":
		_reveal_pending = i
		_show_reveal_panel()
		return
	_drive_resolution(i)


## Pannello di rivelazione: carte giocate + ordine d'iniziativa, in attesa di «Avanti».
func _show_reveal_panel() -> void:
	var mine := int(_revealed_planned.get(0, -1))
	var theirs := int(_revealed_planned.get(1, -1))
	_clear_overlays()
	_hud.hide_kamae(); _hud.hide_options(); _hud.hide_instant()
	if not _versus:
		_hud.show_played_card(CardDB.image_for(mine), CardDB.card(mine).get("name", "?"))
	# Ordine d'iniziativa (alta → bassa).
	var parts: Array = []
	var n := 1
	for o in _reveal_order:
		var sp := int(o.get("speed", -1))
		parts.append("%d) %s ⚡%s" % [n, _who(int(o.get("i", 0))), str(sp) if sp >= 0 else "—"])
		n += 1
	var ord_line := ("Ordine di risoluzione: " + "  →  ".join(parts)) if not parts.is_empty() else ""
	var mine_c := CardDB.card(mine)
	var theirs_c := CardDB.card(theirs)
	_hud.show_phase("RIVELAZIONE — Round %d" % state.round_num, Color(0.75, 0.75, 0.75))
	_hud.set_hint("%s: %s (%s)\n%s: %s (%s)\n%s\nPremi «Avanti ▶» per iniziare." % [
		_who(0), mine_c.get("name", "—"), _card_type_it(mine_c.get("type", "")),
		_who(1), theirs_c.get("name", "—"), _card_type_it(theirs_c.get("type", "")),
		ord_line])
	_hud.show_confirm("Avanti ▶ — risolvi")


## Avvia la risoluzione interattiva per il combattente `i` (umano o IA).
func _drive_resolution(i: int) -> void:
	_resolving_index = i
	_instant_mode = ""
	_hud.hide_instant()
	var ini := _duel._speed_of(i) if _duel != null else -1
	var ini_str := str(ini) if ini >= 0 else "—"
	var card_name := CardDB.card(state.fighters[i].planned).get("name", "?")
	var card_type := CardDB.card(state.fighters[i].planned).get("type", "")
	if not state.fighters[i].is_ai:
		# Umano (giocatore solo, oppure entrambi in 1v1): risoluzione interattiva.
		# Sequenza: 1) movimento+rotazione  2) scelte (Kamae/OPPURE)  3) conferma.
		_phase_mode = "resolving"
		_move_used = false
		_kamae_used = false
		_selected_card = CardDB.card(state.fighters[i].planned).duplicate()
		_selected_card["id"] = state.fighters[i].planned
		_setup_kamae_for(i)
		_hud.hide_kamae()
		_hud.hide_options()
		_refresh_overlays()          # calcola _move_states e disegna il movimento
		if not _movable_cells_exist():
			# Niente da muovere: salta direttamente al passo delle scelte.
			_move_used = true
			_refresh_overlays()
			_show_choosers()
		_refresh_status()
		_hud.show_confirm("Fine ▶")
		_hud.show_phase("⚡ Iniziativa %s  ·  %s  ·  %s  (%s)" % [
			ini_str, _who(i), card_name, _card_type_it(card_type)])
	else:
		_phase_mode = "ai"
		_clear_overlays()
		_hud.hide_kamae()
		_hud.hide_options()
		_hud.hide_confirm()
		_hud.show_phase("⚡ Iniziativa %s  ·  %s  ·  %s  (%s)  — l'avversario agisce…" % [
			ini_str, _who(i), card_name, _card_type_it(card_type)], Color(0.7, 0.7, 0.7))
		_run_ai_resolution(i)


## L'IA muove verso il bersaglio, si orienta e poi risolve la sua carta.
func _run_ai_resolution(i: int) -> void:
	var f := state.fighters[i]
	var foe := state.opponent_of(f)
	if foe != null:
		var g := CardDB.geometry(f.planned)
		if not f.movement_cancelled:
			if g.has("move"):
				var plan := AI.plan_move(state, f, g)   # priorità solitario (stance/portata/approccio)
				f.cell = plan["cell"]; f.facing = plan["facing"]
			else:
				f.facing = AI.facing_toward(f.cell, foe.cell)
			_sync_pawns(); _apply_pawn_facing(i)
	# Piccola pausa per leggibilità, poi applica la carta.
	var t := get_tree().create_timer(0.6)
	t.timeout.connect(func():
		if is_instance_valid(self) and _duel != null:
			_duel.resolve_current())


## Conferma la risoluzione della carta del giocatore (movimento già fatto).
func _confirm_resolution() -> void:
	# 1v1: conferma del passaggio dispositivo → l'altro umano programma.
	if _phase_mode == "handoff":
		_planning_player = 1 - _planning_player
		_phase_mode = "planning"
		_resolving_index = -1
		_selected_card = {}
		_move_used = false
		_kamae_used = false
		_hud.hide_confirm()
		_setup_kamae_for(_planning_player)
		_refresh_hand()
		_refresh_status()
		_hud.set_info("Giocatore %d: programma una carta" % (_planning_player + 1))
		_hud.set_hint("Giocatore %d — scegli una carta e premi «Conferma carta»." % (_planning_player + 1))
		return
	# PROGRAMMAZIONE: «Conferma carta» blocca la carta scelta (coperta).
	if _phase_mode == "planning":
		if not _selected_card.is_empty():
			_on_card_played(_selected_card)
		return
	# RIVELAZIONE: «Avanti» avvia la risoluzione per iniziativa.
	if _phase_mode == "reveal":
		_phase_mode = "wait"
		_hud.hide_confirm()
		var idx := _reveal_pending
		_reveal_pending = -1
		_drive_resolution(idx)
		return
	if _phase_mode != "resolving":
		return
	if _resolving_index >= 0 and state.fighters[_resolving_index].is_ai:
		return
	if _split_stage:
		# Conferma della PARTE BASSA (iniziativa divisa): risolvi dall'attuale posizione.
		_split_stage = false
		_phase_mode = "wait"
		_clear_overlays()
		_hud.hide_confirm()
		_selected_card = {}
		_duel.resolve_split_now()
		return
	# Commit To Hit (regolamento p.10): è solo un PROMEMORIA non bloccante — non deve
	# mai impedire di concludere il turno (altrimenti la risoluzione si inceppa).
	_phase_mode = "wait"
	_clear_overlays()
	_hud.hide_kamae()
	_hud.hide_confirm()
	_hud.hide_options()
	_selected_card = {}
	_duel.resolve_current()
	if _duel.has_pending_split():
		_enter_split_stage()


## Entra nella seconda fase di una carta a iniziativa divisa: il giocatore
## posiziona e attacca con la PARTE BASSA, poi Conferma.
func _enter_split_stage() -> void:
	_split_stage = true
	_phase_mode = "resolving"
	# _resolving_index resta quello del combattente che ha appena risolto la parte alta.
	_move_used = false
	_kamae_used = true   # niente cambio Kamae nella parte bassa
	_hud.hide_kamae()
	_hud.hide_options()
	var g := _duel.pending_split_geom()
	var sp_ini := _duel.pending_split_initiative()
	var main_card_name := CardDB.card(state.fighters[_resolving_index].planned).get("name", "?")
	_selected_card = {"id": -1, "type": "attack", "name": "Parte bassa", "geom_override": g}
	_refresh_overlays()
	_hud.show_confirm("Conferma parte bassa ▶")
	_hud.show_phase("⚡ Iniziativa %d  ·  %s  ·  %s  (PARTE BASSA)" % [
		sp_ini, _who(_resolving_index), main_card_name], Color(0.5, 0.75, 1.0))
	_hud.set_hint("PARTE BASSA: questa carta agisce una seconda volta all'iniziativa %d.\nMuovi (giallo) verso il bersaglio, poi attacca (rosso)." % sp_ini)


func _on_turn_resolved(log: Array) -> void:
	_phase_mode = "planning"
	_resolving_index = -1
	_split_stage = false
	_planning_player = 0
	_selected_card = {}
	_clear_overlays()
	_hud.hide_phase()
	_hud.hide_kamae()
	_hud.hide_confirm()
	_hud.hide_options()
	_hud.hide_instant()
	_instant_mode = ""
	_sync_pawns()
	_refresh_hand()
	_refresh_status()
	if not log.is_empty():
		_hud.set_hint(String("\n").join(log).left(420) + "\n— Programma la prossima carta —")


func _on_duel_over(winner: int) -> void:
	var who := "Pareggio" if winner < 0 else "%s vince!" % state.fighters[winner].character
	_hud.set_info("⚔ Duello terminato — %s" % who)
	_hud.show_hand([])
	_clear_overlays()
	_hud.hide_kamae()
	_hud.hide_confirm()
	_hud.hide_options()


## Costruisce la mano del giocatore (pedina 0) come schede dati.
func _refresh_hand() -> void:
	var entries: Array = []
	for id in state.fighters[_planning_player].hand:
		var c := CardDB.card(id).duplicate()
		if c.is_empty():
			continue
		var img := CardDB.image_for(id)
		if img != "":
			c["file"] = img   # mostra l'immagine reale della carta
		entries.append(c)
	_hud.show_hand(entries)


func _status_badges(f: GameState.Fighter) -> String:
	var s := ""
	if f.hobbles.size() > 0:
		s += " ⊘%d" % f.hobbles.size()   # azzoppamenti
	if f.stun > 0:
		s += " ✦%d" % f.stun             # stordimenti
	return s


## Etichetta leggibile della postura/approccio dell'IA (regolamento solo p.20-22).
func _ai_posture(f: GameState.Fighter) -> String:
	if not f.is_ai:
		return ""
	var st := "⚔ Offensiva" if f.ai_stance == "offensive" else "🛡 Difensiva"
	var names := {"front": "fronte", "right": "destra", "rear": "spalle", "left": "sinistra"}
	var appr: String = names.get(f.ai_approach, f.ai_approach)
	return "  ·  IA: %s · approccio %s" % [st, appr]


func _refresh_status() -> void:
	var p := state.fighters[0]
	var e := state.fighters[1]
	_hud.set_info("Round %d  |  %s %s ❤%d/%d ◈%d [%s]%s mazzo%d scarti%d  —  %s %s ❤%d/%d ◈%d [%s]%s mazzo%d%s" % [
		state.round_num,
		_who(0), p.character, p.remaining_wounds(), p.wound_limit, p.focus, Domain.STANCE_NAMES[p.stance], _status_badges(p), p.draw_pile.size(), p.discard.size(),
		_who(1), e.character, e.remaining_wounds(), e.wound_limit, e.focus, Domain.STANCE_NAMES[e.stance], _status_badges(e), e.draw_pile.size(), _ai_posture(e)])
	_hud.set_kamae_marker(Domain.STANCE_SLUG[state.fighters[_kamae_shown].stance])
	var af := _active()
	_hud.set_focus(_who(af), state.fighters[af].focus, GameState.Fighter.MAX_FOCUS)
	_refresh_status_cards()


## Mostra come CARTE (arte reale) le ferite/stordimenti/azzoppamenti/veleni del
## combattente di turno, raggruppate per tipo con un contatore.
func _refresh_status_cards() -> void:
	var i := _active()
	var counts: Dictionary = {}      ## id stato → numero
	for sid in state.fighters[i].status_card_ids():
		counts[sid] = int(counts.get(sid, 0)) + 1
	var entries: Array = []
	for sid in counts:
		var c := CardDB.card(sid)
		entries.append({"file": c.get("file", ""), "name": c.get("name", "?"), "count": counts[sid]})
	_hud.set_status_cards(entries)


func _sync_pawns() -> void:
	for i in range(state.fighters.size()):
		var dest := HexGrid.hex_to_world(state.fighters[i].cell, hex_size)
		if _pawns[i].position.distance_to(dest) > 0.01:
			var tw := create_tween()
			tw.tween_property(_pawns[i], "position", dest, 0.25).set_trans(Tween.TRANS_SINE)
		_apply_pawn_facing(i)
	_refresh_overlays()


# ─── Costruzione scena ───────────────────────────────────────────────────────

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.09, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.42, 0.5)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	_cam_pivot = Node3D.new()
	add_child(_cam_pivot)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	_cam_pivot.add_child(cam)
	_update_camera()


func _build_map() -> void:
	_build_ground()
	_build_tiles()


func _build_tiles() -> void:
	for cell in HexGrid.hexes_in_range(Vector2i.ZERO, map_radius):
		var tile := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = hex_size * 0.92
		mesh.bottom_radius = hex_size * 0.92
		mesh.height = 0.04
		mesh.radial_segments = 6
		tile.mesh = mesh
		tile.rotation_degrees.y = 30.0   # flat-top
		tile.material_override = _tile_mat(cell, "none")
		tile.position = HexGrid.hex_to_world(cell, hex_size)
		tile.position.y = 0.03            # appena sopra la mappa
		tile.add_to_group(TILE_GROUP)
		tile.set_meta("cell", cell)

		# Collisione per il picking col mouse.
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = hex_size * 0.92
		shape.height = 0.2
		col.shape = shape
		body.add_child(col)
		body.set_meta("cell", cell)
		tile.add_child(body)

		add_child(tile)
		_tiles[cell] = tile


## Piano con la texture della mappa reale (Tabelle_Materiali/Senjutsu/MAPPE).
func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(map_world_size, map_world_size)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	var tex := _load_texture("res://assets/maps/arena.webp")
	if tex != null:
		gm.albedo_texture = tex
	else:
		gm.albedo_color = Color(0.15, 0.16, 0.14)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(map_offset.x, -0.01, map_offset.y)
	ground.rotation_degrees.y = map_y_rotation
	add_child(ground)
	_ground = ground


## Materiale semi-trasparente della tessera. mode: "none" | "move" | "attack".
func _tile_mat(cell: Vector2i, mode: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	match mode:
		"move":
			m.albedo_color = Color(0.95, 0.82, 0.25, 0.5)
			m.emission = Color(0.5, 0.42, 0.1)
		"attack":
			m.albedo_color = Color(0.95, 0.25, 0.2, 0.55)
			m.emission = Color(0.5, 0.1, 0.08)
		_:
			m.emission_enabled = false
			var alt := ((cell.x + cell.y) & 1) != 0
			m.albedo_color = Color(0.85, 0.9, 1.0, 0.18) if alt else Color(0.55, 0.7, 0.9, 0.14)
	return m


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


func _spawn_pawns() -> void:
	var Pawn := preload("res://scenes/Pawn.gd")
	var starts := [Vector2i(-3, 1), Vector2i(3, -1)]
	var chars := Domain.PLAYABLE   ## ["Warrior", "Ronin"]
	var colors := [Color(0.85, 0.2, 0.2), Color(0.2, 0.4, 0.9)]
	for i in range(2):
		var f := state.add_fighter(chars[i], starts[i])
		# Solo: pedina 0 = giocatore, pedina 1 = IA. 1v1: entrambe umane.
		f.is_ai = (i == 1) and not _versus
		if f.is_ai:
			# Mazzo SOLO dell'avversario (sottoinsieme curato) + parametri IA.
			f.draw_pile = CardDB.solo_deck_for(chars[i].to_lower())
			f.ai_stance = "offensive"
			f.ai_preferred_range = 1
			f.ai_approach = "front"
		else:
			# Mazzo del giocatore dai dati autorevoli (foglio Custom Decks).
			f.draw_pile = CardDB.draw_pile_for(chars[i].to_lower())
		f.draw_pile.shuffle()
		# Limiti dalla carta personaggio (se trascritta).
		var cs := CardDB.character_stats(chars[i])
		if not cs.is_empty():
			f.wound_limit = int(cs.get("wound_limit", f.wound_limit))
			f.hand_limit = int(cs.get("hand_limit", f.hand_limit))
		var pawn: Node3D = Pawn.new()
		pawn.set("tint", colors[i])
		# Miniatura a colori (.glb con texture) se presente, altrimenti il vecchio .obj.
		var slug: String = String(chars[i]).to_lower()
		var glb: String = "res://assets/miniatures/%s.glb" % slug
		pawn.set("mesh_path", glb if ResourceLoader.exists(glb) else "res://assets/miniatures/%s.obj" % slug)
		pawn.set("cell_size", hex_size)
		add_child(pawn)
		pawn.position = HexGrid.hex_to_world(f.cell, hex_size)
		pawn.set_meta("fighter_index", i)
		_pawns.append(pawn)
	# Orientamento iniziale: ciascuno verso l'avversario.
	state.fighters[0].facing = AI.facing_toward(state.fighters[0].cell, state.fighters[1].cell)
	state.fighters[1].facing = AI.facing_toward(state.fighters[1].cell, state.fighters[0].cell)
	# Posizione Kamae iniziale dall'albero del personaggio.
	for i in range(2):
		var tree := CardDB.kamae_tree_for(state.fighters[i].character.to_lower())
		var start_slug: String = tree.get("start", "neutral")
		state.fighters[i].stance = Domain.STANCE_FROM_SLUG.get(start_slug, Domain.Stance.NEUTRAL)


# ─── Selezione e movimento ───────────────────────────────────────────────────

func _clear_overlays() -> void:
	for cell in _highlighted:
		if _tiles.has(cell):
			(_tiles[cell] as MeshInstance3D).material_override = _tile_mat(cell, "none")
	for cell in _attack_preview:
		if _tiles.has(cell):
			(_tiles[cell] as MeshInstance3D).material_override = _tile_mat(cell, "none")
	_highlighted.clear()
	_attack_preview.clear()


## Evidenziazione a DUE FASI come sulla carta:
##  1) prima il MOVIMENTO consentito (giallo) — passi/rotazioni della carta;
##  2) dopo aver mosso (o se la carta non muove), i BERSAGLI d'attacco (rosso).
func _refresh_overlays() -> void:
	_draw_overlays_for(_selected_card, _move_used)


## Disegna sulla mappa l'azione contestuale della carta `card`:
##  giallo = movimento (FASE 1), rosso = bersagli d'attacco (FASE 2).
## `move_used` = true salta la fase movimento (già mossa o anteprima post-mossa).
## Usata sia per la carta selezionata/in risoluzione sia per l'anteprima al
## passaggio del mouse.
func _draw_overlays_for(card: Dictionary, move_used: bool) -> void:
	_clear_overlays()
	if card.is_empty():
		return
	var f := state.fighters[_active()]
	var id := int(card.get("id", -1))
	# La parte bassa (iniziativa divisa) porta la sua geometria esplicita.
	var g: Dictionary = card.get("geom_override", CardDB.geometry(id))
	# Carta non giocabile nella Kamae attuale: nessun overlay.
	if not Duel.playable(f, id):
		var req: String = g.get("kamae_req", "")
		_hud.set_hint("⛔ %s: giocabile solo in Kamae %s (sei in %s)" % [
			card.get("name", "?"),
			Domain.STANCE_NAMES.get(Domain.STANCE_FROM_SLUG.get(req, -1), req),
			Domain.STANCE_NAMES[f.stance]])
		return
	# Celle di movimento (solo se non già mosso).
	var move_cells: Array = []
	if not move_used:
		_move_states = {}
		if g.has("move"):
			_move_states = Move.reachable_by_cell(f.cell, f.facing, g["move"], state.is_blocked, Domain.STANCE_SLUG[f.stance])
			for cell in _move_states.keys():
				if cell != f.cell:
					move_cells.append(cell)
		elif int(g.get("steps", 0)) > 0:
			move_cells = HexGrid.reachable(f.cell, int(g.get("steps", 0)), state.is_blocked)
	var cost: int = int(CardDB.card(id).get("focus", 0))
	var sfx := (" · costo ◈%d (hai %d)" % [cost, f.focus]) if cost > 0 else ""
	sfx += _gated_note(g)
	if not move_cells.is_empty():
		# FASE 1 — movimento (giallo). SPAZIO per non muovere.
		for cell in move_cells:
			_highlighted.append(cell)
			if _tiles.has(cell):
				(_tiles[cell] as MeshInstance3D).material_override = _tile_mat(cell, "move")
		_hud.set_hint("FASE 1 — MOVIMENTO: tocca un esagono giallo · Q/E per ruotare · SPAZIO = resta fermo · INVIO = risolvi" + sfx)
	elif card.get("type", "") == "attack":
		# FASE 2 — bersagli attaccabili (rosso). Schema v2 (celle per-esagono).
		for cell in Duel.attack_v2_cells(f.cell, f.facing, g, 1, f.stance):
			if _tiles.has(cell):
				_attack_preview.append(cell)
				(_tiles[cell] as MeshInstance3D).material_override = _tile_mat(cell, "attack")
		_hud.set_hint("FASE 2 — ATTACCO: tocca un esagono rosso per colpire · INVIO per saltare · Q/E per ruotare" + sfx)
	else:
		_hud.set_hint("Nessun movimento disponibile — INVIO per risolvere gli effetti · Q/E per ruotare" + sfx)


## Indica quali Kamae sbloccherebbero ulteriori movimenti della carta selezionata.
func _gated_note(g: Dictionary) -> String:
	if not g.has("move"):
		return ""
	var cur: String = Domain.STANCE_SLUG[state.fighters[_active()].stance]
	var locked := {}
	for opt in g["move"].get("opts", []):
		for a in opt.get("atoms", []):
			var k: String = a.get("kamae", "")
			if k != "" and k != cur:
				locked[k] = true
	if locked.is_empty():
		return ""
	var names: Array = []
	for k in locked:
		names.append(Domain.STANCE_NAMES[Domain.STANCE_FROM_SLUG[k]])
	return " · altri movimenti in: " + ", ".join(names)


# ─── Orientamento (facing) ───────────────────────────────────────────────────

## Angolo mondo (attorno a Y) per orientare la pedina nella direzione `facing`.
func _facing_angle(cell: Vector2i, facing: int) -> float:
	var a := HexGrid.hex_to_world(cell, hex_size)
	var b := HexGrid.hex_to_world(cell + HexGrid.DIRS[facing % 6], hex_size)
	var d := b - a
	return atan2(d.x, d.z)


## Selezione di una carta: mostra i passi consentiti e l'arco d'attacco.
func _on_card_selected(card_data: Dictionary) -> void:
	if _phase_mode != "planning":
		return   # durante la risoluzione la mano non cambia l'anteprima
	_selected_card = card_data
	_move_used = false
	_kamae_used = false
	_refresh_overlays()   # anteprima informativa (il movimento avverrà in risoluzione)
	_hud.hide_kamae()
	# Flusso A: scegli la carta, poi CONFERMA per bloccarla (coperta). Il movimento
	# e l'attacco avverranno DOPO, in risoluzione, secondo l'ordine d'iniziativa.
	if Duel.playable(state.fighters[_planning_player], int(card_data.get("id", -1))):
		_hud.show_confirm("✓ Conferma carta")
	else:
		_hud.hide_confirm()
	var ct := _card_type_it(card_data.get("type", ""))
	var ini_v := str(card_data.get("initiative", "-"))
	_hud.set_hint("Selezionata: %s · %s · iniziativa %s\nGiallo = movimenti possibili · Rosso = arco d'attacco\nPremi «Conferma carta» per programmarla (coperta)." % [
		card_data.get("name", "?"), ct, ini_v])


## Passaggio del mouse su una carta in mano: la carta si alza (CardView) e qui
## mostriamo la sua azione contestuale sulla mappa. Uscendo, la mappa torna allo
## stato precedente (overlay della carta selezionata, se c'è, altrimenti pulita).
## Attivo solo in pianificazione: durante la risoluzione gli overlay sono guidati
## dalla carta in corso e non vanno disturbati.
func _on_card_hovered(card_data: Dictionary, entered: bool) -> void:
	if _phase_mode != "planning":
		return
	if entered:
		_draw_overlays_for(card_data, false)   # anteprima: movimento da fermo
	else:
		_refresh_overlays()                     # ripristina la selezione (o pulisci)


## Parametri dell'effetto "change_kamae" della carta (dentro `effects`):
## {n, gate} oppure {} se assente o non applicabile nella Kamae attuale.
func _change_kamae_params(g: Dictionary) -> Dictionary:
	for e in g.get("effects", []):
		if str(e.get("do", "")) == "change_kamae":
			return {"n": int(e.get("n", 1)), "gate": str(e.get("kamae", ""))}
	return {}


## Mostra il selettore Kamae se la carta consente di cambiare posizione.
func _refresh_kamae_chooser() -> void:
	if _selected_card.is_empty() or _kamae_used:
		_hud.hide_kamae()
		return
	var g := CardDB.geometry(int(_selected_card.get("id", -1)))
	var params := _change_kamae_params(g)
	if params.is_empty():
		_hud.hide_kamae()
		return
	var f := state.fighters[_active()]
	# Il "cambia kamae" di alcune carte vale solo in una certa Kamae.
	var gate: String = params.get("gate", "")
	if gate != "" and gate != Domain.STANCE_SLUG[f.stance]:
		_hud.hide_kamae()
		return
	var tree := CardDB.kamae_tree_for(f.character.to_lower())
	var cur: String = Domain.STANCE_SLUG[f.stance]
	var targets := Kamae.change_targets(tree, cur, int(params.get("n", 1)))
	_hud.show_kamae(cur, targets)


## Mostra il selettore "OPPURE" se la carta in risoluzione ha opzioni alternative.
## Pre-seleziona la prima (così c'è sempre un default applicato).
func _refresh_option_chooser() -> void:
	var ri := _resolving_index
	var keys: Array = _duel.option_keys(ri)
	if keys.is_empty():
		_hud.hide_options()
		return
	var g := CardDB.geometry(state.fighters[ri].planned)
	var opts: Array = []
	for k in keys:
		opts.append({"alt": k, "label": _option_label(g, k)})
	_hud.show_options(opts)
	_duel.set_option_choice(ri, keys[0])
	_hud.mark_option(String(keys[0]))


## Etichetta leggibile di un'opzione OPPURE: concatena le frasi dei suoi effetti.
func _option_label(g: Dictionary, alt) -> String:
	var parts: Array = []
	for e in g.get("effects", []):
		if str(e.get("alt", "")) != str(alt):
			continue
		parts.append(_effect_phrase(e))
	return " + ".join(parts) if not parts.is_empty() else str(alt)


func _effect_phrase(e: Dictionary) -> String:
	var n := int(e.get("n", 1))
	var s := ""
	match str(e.get("do", "")):
		"draw": s = "Pesca %d" % n
		"search_draw": s = "Cerca+pesca %d" % n
		"focus": s = "+%d focus" % n
		"change_kamae": s = "Cambia Kamae %d" % n
		"switch_kamae": s = "Passa a %s" % Domain.STANCE_NAMES.get(Domain.STANCE_FROM_SLUG.get(str(e.get("to","")), -1), str(e.get("to","")))
		"discard_self": s = "Scarta %d" % n
		"stun_self": s = "Prendi %d stordito" % n
		"push": s = "Spingi %d" % n
		"pull": s = "Tira %d" % n
		"rotate_target": s = "Ruota avv. %d" % n
		"foe_lose_focus": s = "Avv. −%d focus" % n
		"foe_discard": s = "Avv. scarta %d" % n
		"spend_focus": s = "Spendi focus"
		"replace_wound_bleed": s = "Ferita→sanguinante"
		"bleed": s = "Sanguinante"
		_: s = str(e.get("do", "?"))
	if int(e.get("focus_cost", 0)) > 0:
		s += " (◈%d)" % int(e.get("focus_cost", 0))
	return s


func _on_option_chosen(alt: String) -> void:
	if _phase_mode != "resolving" or _resolving_index < 0 or state.fighters[_resolving_index].is_ai:
		return
	_duel.set_option_choice(_resolving_index, alt)
	_hud.mark_option(alt)


## Etichetta breve per il selettore istantanee (nome · tipo · costo focus).
func _instant_label(id: int) -> String:
	var c := CardDB.card(id)
	var typ: int = Domain.parse_card_type(str(c.get("type", "")))
	var cost := int(c.get("focus", 0))
	var s := "%s\n%s" % [c.get("name", "?"), Domain.CARD_TYPE_LABELS.get(typ, "?")]
	if cost > 0:
		s += " · ◈%d" % cost
	return s


func _instant_options(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		out.append({"id": int(id), "label": _instant_label(int(id))})
	return out


## Rivelazione: offri la SOSTITUZIONE istantanea della carta rivelata di `i`.
func _on_await_instant_replace(i: int, options: Array) -> void:
	_instant_mode = "replace"
	_instant_index = i
	_phase_mode = "instant"
	_clear_overlays()
	_hud.hide_kamae(); _hud.hide_options(); _hud.hide_confirm()
	_setup_kamae_for(i)
	_refresh_status()
	_hud.set_info("Sostituzione — %s: puoi sostituire la carta rivelata con un'istantanea" % _who(i))
	_hud.set_hint("ISTANTANEA DI SOSTITUZIONE: scegli una carta (tipo diverso) o «Tieni / Salta».")
	_hud.show_instant("%s — Sostituire la carta rivelata?" % _who(i), _instant_options(options))


## Risoluzione: offri di giocare 1 carta istantanea aggiuntiva dopo la carta di `i`.
func _on_await_instant_play(i: int, options: Array) -> void:
	_instant_mode = "play"
	_instant_index = i
	_phase_mode = "instant"
	_hud.hide_kamae(); _hud.hide_options(); _hud.hide_confirm()
	_hud.set_info("Istantanea — %s: puoi giocare 1 carta istantanea aggiuntiva" % _who(i))
	_hud.set_hint("ISTANTANEA AGGIUNTIVA: gioca 1 carta istantanea oppure «Tieni / Salta».")
	_hud.show_instant("%s — Giocare un'istantanea aggiuntiva?" % _who(i), _instant_options(options))


func _on_instant_chosen(id: int) -> void:
	if _instant_mode == "":
		return
	var mode := _instant_mode
	var idx := _instant_index
	_instant_mode = ""
	_instant_index = -1
	_hud.hide_instant()
	if mode == "replace":
		_duel.apply_instant_replace(idx, id)   # → finalizza e parte la risoluzione
	elif mode == "play":
		_duel.apply_instant_play(idx, id)      # → prosegue l'ordine d'iniziativa


## Il giocatore sceglie la nuova posizione Kamae (con focus dai rami rosa).
func _on_kamae_chosen(slug: String) -> void:
	if _kamae_used or _selected_card.is_empty():
		return
	var f := state.fighters[_active()]
	var g := CardDB.geometry(int(_selected_card.get("id", -1)))
	var params := _change_kamae_params(g)
	if params.is_empty():
		return
	var tree := CardDB.kamae_tree_for(f.character.to_lower())
	var targets := Kamae.change_targets(tree, Domain.STANCE_SLUG[f.stance], int(params.get("n", 1)))
	if not targets.has(slug):
		return
	f.gain_focus(int(targets[slug]))          # focus dai rami rosa
	f.stance = Domain.STANCE_FROM_SLUG[slug]
	_kamae_used = true
	_hud.hide_kamae()
	_refresh_status()


## Ruota il giocatore solo tra i facing consentiti dalla carta selezionata.
## La maggior parte delle carte permette di ruotare solo in una certa Kamae: se non
## è possibile, lo spieghiamo (così si capisce perché Q/E non gira la miniatura).
func _rotate_player(delta: int) -> void:
	if _selected_card.is_empty():
		return
	var idx_f := _active()
	var f := state.fighters[idx_f]
	var g: Dictionary = _selected_card.get("geom_override", CardDB.geometry(int(_selected_card.get("id", -1))))
	var facings: Array = (_move_states.get(f.cell, []) as Array).duplicate()
	# Includi anche il facing attuale tra le scelte (se la rotazione è opzionale lo è già;
	# se è obbligatoria resta escluso). Serve a ciclare correttamente con un solo valore.
	if facings.size() <= 1:
		# Rotazione libera legacy (carte senza spec move ma con 'rotates').
		if not g.has("move") and int(g.get("rotates", 0)) > 0:
			f.facing = (f.facing + delta + 6) % 6
			_apply_pawn_facing(idx_f)
			_refresh_overlays()
			return
		# Nessuna rotazione disponibile: spiega perché.
		_hud.set_hint("⟳ Rotazione non disponibile con questa carta" + _rotation_gate_hint(g))
		return
	facings.sort()
	var idx: int = facings.find(f.facing)
	if idx == -1:
		idx = 0
	f.facing = int(facings[(idx + delta + facings.size()) % facings.size()])
	_apply_pawn_facing(idx_f)
	_refresh_overlays()


## Quali Kamae sbloccherebbero la rotazione della carta selezionata (per il suggerimento).
func _rotation_gate_hint(g: Dictionary) -> String:
	if not g.has("move"):
		return ""
	var cur: String = Domain.STANCE_SLUG[state.fighters[_active()].stance]
	var gates := {}
	for opt in g["move"].get("opts", []):
		for a in opt.get("atoms", []):
			if a.get("t", "") == "rot":
				var k: String = a.get("kamae", "")
				if k != "" and k != cur:
					gates[k] = true
	if gates.is_empty():
		return ""
	var names: Array = []
	for k in gates:
		names.append(Domain.STANCE_NAMES[Domain.STANCE_FROM_SLUG[k]])
	return " — ruota solo in Kamae: " + ", ".join(names)


func _apply_pawn_facing(i: int) -> void:
	_pawns[i].call("face", _facing_angle(state.fighters[i].cell, state.fighters[i].facing))


## Aggiorna ogni frame le frecce di rotazione: visibili sulla pedina del giocatore
## di turno SOLO quando la carta consente di ruotare.
func _process(_dt: float) -> void:
	if _hud == null:
		return
	if _phase_mode == "resolving" and _resolving_index >= 0 \
			and not state.fighters[_resolving_index].is_ai and _rotation_allowed():
		var cam: Camera3D = _cam_pivot.get_node("Camera3D")
		var wp: Vector3 = _pawns[_resolving_index].global_position + Vector3(0, hex_size * 1.7, 0)
		if not cam.is_position_behind(wp):
			_hud.show_rotation(cam.unproject_position(wp))
		else:
			_hud.hide_rotation()
	else:
		_hud.hide_rotation()


# ─── Animazioni di combattimento (solo presentazione) ────────────────────────

## Evento di combattimento dal motore: anima affondo, impatto, parata, urto.
func _on_combat_event(kind: String, attacker: int, target: int, _info: Dictionary) -> void:
	if not _visuals:
		return
	match kind:
		"hit":
			_lunge_pawn(attacker, state.fighters[target].cell)
			_spawn_impact(state.fighters[target].cell, Color(1.0, 0.32, 0.2), 1.4)
			_camera_shake(0.05)
		"blocked":
			_lunge_pawn(attacker, state.fighters[target].cell)
			_spawn_impact(state.fighters[target].cell, Color(0.55, 0.8, 1.0), 1.1)
			_camera_shake(0.025)
		"counter":
			_spawn_impact(state.fighters[target].cell, Color(1.0, 0.5, 0.15), 1.2)
			_camera_shake(0.04)
		"collision":
			_spawn_impact(state.fighters[target].cell, Color(1.0, 0.75, 0.2), 1.6)
			_camera_shake(0.08)


## Affondo della pedina `idx` verso `toward_cell` e ritorno (colpo).
func _lunge_pawn(idx: int, toward_cell: Vector2i) -> void:
	if idx < 0 or idx >= _pawns.size():
		return
	var pawn := _pawns[idx]
	var start: Vector3 = pawn.position
	var tgt := HexGrid.hex_to_world(toward_cell, hex_size)
	var peak := start.lerp(tgt, 0.4)
	peak.y = start.y
	var tw := create_tween()
	tw.tween_property(pawn, "position", peak, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(pawn, "position", start, 0.13).set_trans(Tween.TRANS_SINE)


## Lampo d'impatto sulla cella: sfera emissiva che cresce e svanisce.
func _spawn_impact(cell: Vector2i, color: Color, peak: float) -> void:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = hex_size * 0.45
	sph.height = hex_size * 0.9
	mi.mesh = sph
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	var c := color
	c.a = 0.8
	m.albedo_color = c
	mi.material_override = m
	add_child(mi)
	mi.position = HexGrid.hex_to_world(cell, hex_size) + Vector3(0, hex_size * 0.9, 0)
	mi.scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * peak, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.30)
	tw.chain().tween_callback(mi.queue_free)


## Breve scossa della camera (sfasamento del frustum), intensità `amt`.
func _camera_shake(amt: float) -> void:
	var cam: Camera3D = _cam_pivot.get_node("Camera3D")
	var tw := create_tween()
	for k in range(5):
		tw.tween_property(cam, "h_offset", randf_range(-amt, amt), 0.035)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)


## La carta in risoluzione consente di ruotare la pedina del giocatore attivo?
func _rotation_allowed() -> bool:
	if _selected_card.is_empty():
		return false
	var f := state.fighters[_active()]
	var facings: Array = _move_states.get(f.cell, [])
	if facings.size() > 1:
		return true
	var g: Dictionary = _selected_card.get("geom_override", CardDB.geometry(int(_selected_card.get("id", -1))))
	return not g.has("move") and int(g.get("rotates", 0)) > 0


## Esistono celle di movimento (diverse dalla cella attuale) per la carta attiva?
func _movable_cells_exist() -> bool:
	var f := state.fighters[_active()]
	for cell in _move_states.keys():
		if cell != f.cell:
			return true
	return false


## Dopo il movimento/rotazione: mostra le SCELTE della carta (Kamae, OPPURE).
func _show_choosers() -> void:
	if _phase_mode == "resolving" and _resolving_index >= 0 and not state.fighters[_resolving_index].is_ai:
		_refresh_kamae_chooser()
		_refresh_option_chooser()


# ─── Calibrazione live griglia↔mappa ─────────────────────────────────────────

func _set_hex_size(v: float) -> void:
	hex_size = clampf(v, 1.0, 8.0)
	_rebuild_grid()
	_update_calib_hint()


func _nudge_map(d: Vector2) -> void:
	map_offset += d
	if _ground:
		_ground.position = Vector3(map_offset.x, -0.01, map_offset.y)
	_update_calib_hint()


func _rebuild_grid() -> void:
	for t in _tiles.values():
		t.queue_free()
	_tiles.clear()
	_highlighted.clear()
	_attack_preview.clear()
	_build_tiles()
	for i in range(_pawns.size()):
		_pawns[i].position = HexGrid.hex_to_world(state.fighters[i].cell, hex_size)
		_pawns[i].call("rescale", hex_size)
		_apply_pawn_facing(i)
	_refresh_overlays()


func _update_calib_hint() -> void:
	_hud.set_hint("Calibrazione: hex_size=%.1f  offset=(%.1f, %.1f)  ·  +/- scala · frecce sposta mappa · R reset camera" % [
		hex_size, map_offset.x, map_offset.y])


func _move_active_to(cell: Vector2i) -> void:
	# Il movimento è possibile solo durante la risoluzione del combattente umano attivo.
	if _phase_mode != "resolving" or _resolving_index < 0 or state.fighters[_resolving_index].is_ai:
		return
	var idx_f := _resolving_index
	if state.fighters[idx_f].movement_cancelled:
		_hud.set_hint("⛔ Movimento annullato dall'avversario questo turno")
		return
	# Muovi solo verso le celle consentite dalla carta selezionata.
	if _move_used or not _highlighted.has(cell):
		return
	var f := state.fighters[idx_f]
	f.cell = cell
	# Facing alla destinazione: MANTIENI l'orientamento attuale (niente auto-mira al
	# nemico). Se non è tra quelli legali della carta, prendi il legale più vicino a
	# quello corrente. La rotazione resta una SCELTA del giocatore (Q/E).
	var facings: Array = _move_states.get(cell, [])
	if not facings.is_empty() and not facings.has(f.facing):
		var cur: int = f.facing
		var best: int = int(facings[0])
		var best_d: int = 99
		for fc in facings:
			var dd: int = mini((int(fc) - cur + 6) % 6, (cur - int(fc) + 6) % 6)
			if dd < best_d:
				best_d = dd
				best = int(fc)
		f.facing = best
	var pawn := _pawns[idx_f]
	var dest := HexGrid.hex_to_world(cell, hex_size)
	var tw := create_tween()
	tw.tween_property(pawn, "position", dest, 0.25).set_trans(Tween.TRANS_SINE)
	_move_used = true            # movimento della carta speso
	_apply_pawn_facing(idx_f)
	_refresh_overlays()          # ora mostra solo l'arco d'attacco aggiornato
	_show_choosers()             # passo successivo: scelte (Kamae/OPPURE)


# ─── Input: camera orbitale + picking ────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# "+"/"-" via unicode (indipendente dal layout di tastiera).
		if event.unicode == 43:  # '+'
			_set_hex_size(hex_size + 0.05); return
		if event.unicode == 45:  # '-'
			_set_hex_size(hex_size - 0.05); return
		var my_turn := _phase_mode == "resolving" and _resolving_index >= 0 and not state.fighters[_resolving_index].is_ai
		match event.keycode:
			KEY_Q:
				if my_turn: _rotate_player(-1)
				return
			KEY_E:
				if my_turn: _rotate_player(1)
				return
			KEY_SPACE:   # non muovere: passa al passo bersagli/scelte
				if my_turn and not _move_used:
					_move_used = true
					_refresh_overlays()
					_show_choosers()
				return
			KEY_ENTER, KEY_KP_ENTER:   # conferma: applica attacco/effetti
				if my_turn:
					_confirm_resolution()
				return
			# ── Calibrazione griglia↔mappa ──
			KEY_KP_ADD: _set_hex_size(hex_size + 0.05); return
			KEY_KP_SUBTRACT: _set_hex_size(hex_size - 0.05); return
			KEY_LEFT: _nudge_map(Vector2(-0.25, 0)); return
			KEY_RIGHT: _nudge_map(Vector2(0.25, 0)); return
			KEY_UP: _nudge_map(Vector2(0, -0.25)); return
			KEY_DOWN: _nudge_map(Vector2(0, 0.25)); return
			KEY_R: _cam_yaw = 0.0; _cam_pitch = 0.62; _cam_dist = 34.0; _update_camera(); return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_dist = max(6.0, _cam_dist - 1.0); _update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_dist = min(55.0, _cam_dist + 1.0); _update_camera()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_pick(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_cam_yaw -= event.relative.x * 0.005
		_cam_pitch = clamp(_cam_pitch - event.relative.y * 0.005, 0.2, 1.4)
		_update_camera()


func _update_camera() -> void:
	var cam: Camera3D = _cam_pivot.get_node("Camera3D")
	var x := _cam_dist * sin(_cam_pitch) * sin(_cam_yaw)
	var y := _cam_dist * cos(_cam_pitch)
	var z := _cam_dist * sin(_cam_pitch) * cos(_cam_yaw)
	cam.position = Vector3(x, y, z)
	cam.look_at(Vector3.ZERO, Vector3.UP)


func _try_pick(screen_pos: Vector2) -> void:
	var cam: Camera3D = _cam_pivot.get_node("Camera3D")
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var collider = hit["collider"]
	if collider and collider.has_meta("cell"):
		_click_cell(collider.get_meta("cell"))


## Click su una cella durante la TUA risoluzione:
##  · cella gialla (movimento) → muovi lì;
##  · cella rossa (bersaglio)  → conferma l'attacco (chiude il turno).
func _click_cell(cell: Vector2i) -> void:
	if _phase_mode == "resolving" and _resolving_index >= 0 \
			and not state.fighters[_resolving_index].is_ai and _attack_preview.has(cell):
		_confirm_resolution()
		return
	_move_active_to(cell)
