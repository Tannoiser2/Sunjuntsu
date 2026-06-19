## Canale WebSocket — Senjutsu multiplayer (Tappa 3).
##
## Stessa interfaccia logica di LoopbackChannel, ma sopra una connessione WebSocket al
## relay (`server/server.js`). Funziona sia per il TAVOLO (host) sia per un TELEFONO
## (client): `MatchHost` usa `send_to_client`/`broadcast` + segnale `to_host`;
## `MatchClient` usa `send_to_host` + segnale `to_client`.
##
## È un Node (si auto-aggiorna in `_process`): va aggiunto all'albero della scena.
class_name WebSocketChannel
extends Node

signal created(code: String)          ## stanza creata (sei il TAVOLO)
signal joined(seat: int)              ## sei entrato come TELEFONO sul seat
signal peer(event: String, seat: int) ## "join"/"leave" di un telefono (avviso al tavolo)
signal to_host(seat: int, msg: Dictionary)
signal to_client(seat: int, msg: Dictionary)
signal closed()

var _ws := WebSocketPeer.new()
var _opened := false
var _initial: Dictionary = {}
var _pending: Array = []
var _url: String = ""


## Apre la connessione al relay e invia l'azione iniziale (create/join) appena pronto.
func open(url: String, initial: Dictionary) -> void:
	_url = url
	_initial = initial
	_do_connect()


## Riapre la connessione (riconnessione), opzionalmente con una nuova azione iniziale
## (es. ricreare la STESSA stanza con {"t":"create","code":...}).
func reopen(initial: Dictionary = {}) -> void:
	if not initial.is_empty():
		_initial = initial
	_do_connect()


func _do_connect() -> void:
	_opened = false
	_ws = WebSocketPeer.new()   # peer pulito a ogni tentativo
	var err := _ws.connect_to_url(_url)
	if err != OK:
		push_warning("[WebSocketChannel] connect_to_url errore %d" % err)
	set_process(true)


func send_to_client(seat: int, msg: Dictionary) -> void:
	_send({"t": "to_client", "seat": seat, "payload": msg})


func broadcast(msg: Dictionary) -> void:
	_send({"t": "broadcast", "payload": msg})


func send_to_host(_seat: int, msg: Dictionary) -> void:
	_send({"t": "to_host", "payload": msg})   # il server conosce già il mio seat


func _send(obj: Dictionary) -> void:
	if _opened:
		_ws.send_text(JSON.stringify(obj))
	else:
		_pending.append(obj)


func _process(_dt: float) -> void:
	_ws.poll()
	var st := _ws.get_ready_state()
	match st:
		WebSocketPeer.STATE_OPEN:
			if not _opened:
				_opened = true
				if not _initial.is_empty():
					_ws.send_text(JSON.stringify(_initial))
				for q in _pending:
					_ws.send_text(JSON.stringify(q))
				_pending.clear()
			while _ws.get_available_packet_count() > 0:
				var txt := _ws.get_packet().get_string_from_utf8()
				var m = JSON.parse_string(txt)
				if typeof(m) == TYPE_DICTIONARY:
					_route(m)
		WebSocketPeer.STATE_CLOSED:
			set_process(false)
			closed.emit()


func _route(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"created":
			created.emit(str(m.get("code", "")))
		"joined":
			joined.emit(int(m.get("seat", -1)))
		"peer":
			peer.emit(str(m.get("event", "")), int(m.get("seat", -1)))
		"from_host":
			to_client.emit(int(m.get("seat", -1)), m.get("payload", {}))
		"from_client":
			to_host.emit(int(m.get("seat", -1)), m.get("payload", {}))
		"error":
			push_warning("[WebSocketChannel] errore: %s" % str(m.get("error", "")))
