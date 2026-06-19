## Canale messaggi LOOPBACK (in-process) — Senjutsu multiplayer (Tappa 2).
##
## Astrazione di trasporto tra il TAVOLO (host autorevole) e i TELEFONI (client).
## Questa implementazione consegna i messaggi nello stesso processo, ma:
##  - in modo ASINCRONO (call_deferred), come farebbe la rete;
##  - facendo passare ogni messaggio per un round-trip JSON, così garantiamo che siano
##    SERIALIZZABILI (pronti per WebSocket in Tappa 3).
## In Tappa 3 basterà fornire un canale con gli stessi metodi/segnali su WebSocket.
class_name LoopbackChannel
extends RefCounted

## Messaggio diretto all'host, dal seat `seat`.
signal to_host(seat: int, msg: Dictionary)
## Messaggio diretto al client del seat `seat` (oppure -1 = broadcast a tutti).
signal to_client(seat: int, msg: Dictionary)


func send_to_host(seat: int, msg: Dictionary) -> void:
	_deliver_host.call_deferred(seat, _roundtrip(msg))


func send_to_client(seat: int, msg: Dictionary) -> void:
	_deliver_client.call_deferred(seat, _roundtrip(msg))


func broadcast(msg: Dictionary) -> void:
	_deliver_client.call_deferred(-1, _roundtrip(msg))


func _deliver_host(seat: int, msg: Dictionary) -> void:
	to_host.emit(seat, msg)


func _deliver_client(seat: int, msg: Dictionary) -> void:
	to_client.emit(seat, msg)


## Forza la serializzabilità: se un messaggio contiene tipi non-JSON (es. Vector2i)
## il round-trip lo evidenzia (consegnerebbe dati errati → i test falliscono).
static func _roundtrip(msg: Dictionary) -> Dictionary:
	var parsed = JSON.parse_string(JSON.stringify(msg))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
