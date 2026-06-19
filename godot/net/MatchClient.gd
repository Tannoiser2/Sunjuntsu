## CLIENT (telefono) — Senjutsu multiplayer (Tappa 2).
##
## Rappresenta UN giocatore (seat) collegato al tavolo tramite un CANALE. Riceve i
## prompt destinati al suo seat (e gli eventi pubblici), e invia le risposte. Non
## conosce le regole né lo stato completo: solo ciò che gli arriva nei messaggi
## (così la mano resta privata e il client può essere una pagina leggera sul telefono).
class_name MatchClient
extends RefCounted

signal prompt_received(kind: String, data: Dictionary)   ## devi decidere
signal event_received(kind: String, data: Dictionary)    ## stato pubblico del tavolo
signal finished(winner: int)

var seat: int
var channel


func _init(seat_index: int, ch) -> void:
	seat = seat_index
	channel = ch
	channel.to_client.connect(_on_client_msg)


## Invia la risposta a un prompt (es. respond("plan", {"card": 64})).
func respond(kind: String, data: Dictionary) -> void:
	channel.send_to_host(seat, {"t": "respond", "kind": kind, "data": data})


func _on_client_msg(target: int, msg: Dictionary) -> void:
	if target != seat and target != -1:
		return   # non è per me
	match str(msg.get("t", "")):
		"prompt":
			prompt_received.emit(str(msg.get("kind", "")), msg.get("data", {}))
		"event":
			event_received.emit(str(msg.get("kind", "")), msg.get("data", {}))
		"finished":
			finished.emit(int(msg.get("winner", -1)))
