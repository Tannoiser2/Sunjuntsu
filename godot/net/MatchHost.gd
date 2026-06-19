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


func _init(state: GameState, ch) -> void:
	channel = ch
	protocol = MatchProtocol.new(state)
	protocol.prompt.connect(_on_prompt)
	protocol.public_event.connect(func(kind, data): channel.broadcast({"t": "event", "kind": kind, "data": data}))
	protocol.finished.connect(func(w): channel.broadcast({"t": "finished", "winner": w}))
	channel.to_host.connect(_on_host_msg)


func start() -> void:
	protocol.start()


func _on_prompt(seat: int, kind: String, data: Dictionary) -> void:
	channel.send_to_client(seat, {"t": "prompt", "kind": kind, "data": data})
	# Avvisa il TAVOLO di chi sta decidendo (info pubblica, non la scelta).
	channel.broadcast({"t": "event", "kind": "turn_of", "data": {"seat": seat, "step": kind}})


func _on_host_msg(seat: int, msg: Dictionary) -> void:
	if str(msg.get("t", "")) == "respond":
		protocol.respond(seat, str(msg.get("kind", "")), msg.get("data", {}))
