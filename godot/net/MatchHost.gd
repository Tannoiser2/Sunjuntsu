## TAVOLO (host autorevole) — Senjutsu multiplayer (Tappa 2).
##
## Possiede il motore tramite `MatchProtocol` e fa da ponte verso un CANALE:
##  - inoltra ogni `prompt` al client del seat giusto;
##  - trasmette gli eventi pubblici e la fine partita a tutti i client;
##  - riceve le risposte dei client e le applica al protocollo.
## Il canale è iniettato (LoopbackChannel ora, WebSocket in Tappa 3): qui non c'è
## nulla di specifico del trasporto.
class_name MatchHost
extends RefCounted

var protocol: MatchProtocol
var channel                      ## LoopbackChannel (o futuro canale di rete)
var _last_prompt: Dictionary = {}   ## seat -> ultimo prompt inviato (per la riconnessione)


func _init(state: GameState, ch) -> void:
	channel = ch
	protocol = MatchProtocol.new(state)
	protocol.prompt.connect(_on_prompt)
	protocol.public_event.connect(func(kind, data): channel.broadcast({"t": "event", "kind": kind, "data": data}))
	protocol.finished.connect(func(w): channel.broadcast({"t": "finished", "winner": w}))
	channel.to_host.connect(_on_host_msg)
	# Riconnessione: se un telefono rientra sul suo seat, rimanda l'ultimo prompt.
	if channel.has_signal("peer"):
		channel.peer.connect(_on_peer)


func start() -> void:
	protocol.start()


func _on_prompt(seat: int, kind: String, data: Dictionary) -> void:
	_last_prompt[seat] = {"t": "prompt", "kind": kind, "data": data}
	channel.send_to_client(seat, _last_prompt[seat])
	# Avvisa il TAVOLO di chi sta decidendo (info pubblica, non la scelta).
	channel.broadcast({"t": "event", "kind": "turn_of", "data": {"seat": seat, "step": kind}})


## Un telefono è (ri)entrato sul suo seat: rimanda l'ultimo prompt pendente, così
## riprende esattamente da dove si trovava (riconnessione/refresh pagina).
func _on_peer(event: String, seat: int) -> void:
	if event == "join" and _last_prompt.has(seat):
		channel.send_to_client(seat, _last_prompt[seat])


func _on_host_msg(seat: int, msg: Dictionary) -> void:
	if str(msg.get("t", "")) == "respond":
		# La scelta è arrivata: consuma il prompt in cache. Se la risposta non è
		# finale (es. muovi/ruota), il protocollo ne riemette subito uno nuovo.
		_last_prompt.erase(seat)
		protocol.respond(seat, str(msg.get("kind", "")), msg.get("data", {}))
