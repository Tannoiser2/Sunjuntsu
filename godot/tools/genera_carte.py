#!/usr/bin/env python3
"""Genera data/carte.json: trascrizione fedele delle carte (1a edizione italiana)
di Guerriero e Ronin, riga per riga come stampate.
Direzioni relative al fronte: 0=Fronte 1=Fronte-Dx 2=Retro-Dx 3=Retro 4=Retro-Sx 5=Fronte-Sx.
Celle della griglia: stringa di passi dal personaggio ("0"=fronte, "00"=due avanti,
"01"=avanti poi fronte-dx, ecc.)."""
import json, os
AG, BA, DE = "aggression", "balance", "determination"
ANY = [0, 1, 2, 3, 4, 5]; FANUP = [5, 0, 1]; FANDN = [4, 3, 2]; F = [0]; B = [3]

def step(dirs, n=1, opt=True): return {"m": "step", "dirs": dirs, "n": n, "opt": opt}
def rot(n=1, opt=True): return {"m": "rot", "n": n, "opt": opt}
def g(line, k=None, f=None):
    if k: line["k"] = k
    if f: line["f"] = f
    return line
def move(*parts, k=None, f=None, seq=False):
    l = {"t": "move", "parts": list(parts)}
    if seq: l["seq"] = True
    return g(l, k, f)
def alt(v, k=None, f=None): return g({"t": "alt", "v": v}, k, f)
def atk(cells): return {"t": "grid", "mode": "atk", "cells": cells}
def blk(*cells): return {"t": "grid", "mode": "blk", "cells": {c: "s" for c in cells}}
def fx(*effects, k=None, f=None): return g({"t": "fx", "fx": list(effects)}, k, f)
def ast(*effects, k=None, f=None): return g({"t": "ast", "fx": list(effects)}, k, f)
def e(v, **kw): d = {"v": v}; d.update(kw); return d
def OR(*opts): return {"t": "or", "opts": [o if isinstance(o, list) else [o] for o in opts]}
IFS = {"t": "ifs"}
UNB = {"t": "unblockable"}
def counter(*v, k=None): return g({"t": "counter", "v": list(v)}, k)
def seg(*lines, init=None):
    s = {"lines": list(lines)}
    if init is not None: s["init"] = init
    return s
RING2 = ["00", "01", "11", "12", "22", "23", "33", "34", "44", "45", "55", "50"]

C = {}
def card(id, name, type, init, *segs, focus=0, req=None, instant=None, when=None, core=False,
         weapon=None, range=None, prepared=False, stays=False, note=None):
    c = {"id": id, "name": name, "type": type, "init": init, "focus": focus,
         "segs": [s if "lines" in s else seg(s) for s in segs]}
    for k, v in (("req", req), ("instant", instant), ("when", when), ("weapon", weapon),
                 ("range", range), ("note", note)):
        if v is not None: c[k] = v
    if core: c["core"] = True
    if prepared: c["prepared"] = True
    if stays: c["stays"] = True
    C[str(id)] = c

# ───────────── GUERRIERO ─────────────
card(53, "Carta Speciale Guerriero", "core", 0, seg(
    fx(e("discard", n=1)),
    move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("self_hobble"), e("focus", n=1)), fx(e("change", n=1)))), core=True)
card(54, "Ruggito Ardente", "meditation", "=", seg(
    fx(e("t_wound", n=1)),
    OR(fx(e("push", n=1)), fx(e("t_stun"), e("t_hobble"), f=1), fx(e("t_wound_to_bleed"), f=1))),
    focus=2, req=AG, instant="add", when="atk_ok")
card(55, "Colpo della Fenice Fiammante", "attack", 6, seg(
    move(step([0, 1], 1, False)),
    atk({"00": "w2", "01": "x", "1": "w1", "11": "w1"})), focus=3, req=AG)
card(56, "Punto Cieco", "meditation", "=", seg(
    move(rot(1, False)),
    fx(e("search", rank="Wood", type="defence")),
    fx(e("search", rank="Steel", type="defence"), f=1),
    fx(e("switch", to=DE))), instant="add", when="after_card", prepared=True)
card(57, "Istinto Bruciante", "meditation", 9, seg(
    fx(e("reshuffle")), fx(e("draw_exact", n=5)),
    move(step(FANUP, 1), k=AG), move(step(FANDN, 1), k=DE), move(rot(2), k=BA)),
    focus=1, prepared=True)
card(58, "Finta Falciante", "attack", 6, seg(
    alt(3, k=DE),
    OR(move(step(B, 1)), move(step(FANUP, 1), k=BA)),
    atk({"05": "w1", "0": "w1", "1": "w1"}),
    IFS, fx(e("t_lose_focus", n=2))))
card(59, "Concentrazione Ritrovata", "meditation", 5, seg(
    OR(move(step(ANY, 1), rot(1)), move(step(ANY, 2), rot(2), k=BA)),
    fx(e("focus", n=1)), fx(e("switch", to=AG))))
card(60, "Falciata Montante", "attack", 5, seg(
    alt(8, k=DE),
    OR(move(step(B, 1)), move(step(FANUP, 1), k=BA)),
    atk({"5": "w1", "0": "w1", "01": "w1"}),
    g({"t": "mod", "fx": "bleed"}, f=2),
    fx(e("switch", to=AG))))
card(61, "Colpo Corto", "attack", 5, seg(
    move(step(FANUP, 1)), atk({"0": "w1"}), IFS, fx(e("t_lose_focus", n=1))),
    req=AG, instant="rep")
card(62, "Arco Respingente", "attack", 7, seg(
    atk({"00": "w1", "05": "w1", "5": "w1", "01": "w1", "1": "w1"}),
    IFS, fx(e("push", n=1)),
    fx(e("t_discard_type", type="defence", n=1), k=[BA, DE]),
    fx(e("switch", to=AG))))
card(63, "Blocco Cinereo", "defence", [9, 6], seg(
    blk("0", "5", "4"), counter(8),
    IFS, OR(fx(e("push", n=1)), fx(e("t_stun"))),
    fx(e("switch", to=AG), k=DE)))
card(64, "Testata", "attack", 4, seg(
    move(step(FANUP, 1)), move(rot(1), k=AG), atk({"0": "w1"}),
    IFS, fx(e("t_hobble")), fx(e("focus", n=1))))
card(65, "Spirale di Fiamme", "attack", 6,
    seg(alt(7, k=AG), atk({"1": "w1", "2": "w1"}), IFS, fx(e("t_rot", n=2))),
    seg(move(step(ANY, 1), rot(1), k=BA), move(step(FANDN, 1, False), rot(1), k=DE), init=5))
card(72, "Squarcio di Nodachi", "attack", 4, seg(
    fx(e("discard", n=1)),
    OR(move(step(FANDN, 1, False), f=1), move(rot(1))),
    atk({"0": "w1", "01": "w1"})), core=True, weapon="Nodachi")
card(83, "Blocco Ampio", "meditation", "=", seg(fx(e("broad_block"))), focus=1, instant="add",
     when="block_init",
     note="Interpretazione: l'intervallo d'iniziativa del blocco si allarga di 1 a entrambi gli estremi.")
card(86, "Colpo in Affondo", "attack", 6, seg(
    alt(7, k=AG), move(step(FANUP, 1, False)), move(rot(1), k=BA),
    atk({"0": "w1a"}), ast(e("add_wound", n=1), f=1),
    fx(e("switch", to=BA)), fx(e("draw", n=1))))
card(87, "Sabbia negli Occhi", "attack", 5, seg(
    UNB, atk({"5": "a", "0": "a", "1": "a"}), ast(e("t_lose_focus", n=2)),
    IFS, fx(e("t_switch", to="neutral")), fx(e("change", n=1))), instant="rep")
card(103, "Passo Aggraziato", "defence", 8, seg(
    move(step([5, 1], 1, False), k=AG), move(step([4, 2], 1, False), k=BA), fx(e("change", n=1))))
card(107, "Affondo in Spinta", "attack", 3, seg(
    alt(6, k=AG), move(step(F, 1)), move(rot(1), k=DE), atk({"00": "w2"}),
    IFS, fx(e("t_stun")), fx(e("switch", to=AG))))
card(113, "Taglio Troncante", "attack", 5, seg(
    move(rot(1)), move(step([5, 1], 1), k=DE), atk({"0": "ba"}), ast(e("add_wound", n=1), k=AG)))
card(116, "Mente Rapida", "meditation", 6, seg(
    move(step(ANY, 2)), move(step(F, 1, False), k=AG), move(rot(1), k=BA),
    fx(e("draw", n=2)), fx(e("change", n=1), k=DE)))
card(118, "Blocco Selvaggio", "defence", [9, 3],
    seg(blk("0", "5", "1", "4", "2"), counter(7, 6, k=AG),
        fx(e("discard", n=2)),
        OR(fx(e("lose_focus_all")), fx(e("lose_focus_all_but", n=1), k=BA))),
    seg(fx(e("switch", to="neutral")), init=1))
card(119, "Fendente Selvaggio", "attack", 7, seg(
    atk({"0": "w2", "1": "w2"}),
    fx(e("discard", n=2)), fx(e("lose_focus_all")), fx(e("switch", to="neutral"))), focus=1)
card(123, "Respinta", "defence", [5, 2],
    seg(move(rot(1)), blk("5", "0", "1"), IFS, fx(e("push", n=1))),
    seg(move(step(FANDN, 1)), init=1))

# ───────────── RONIN ─────────────
card(23, "Carta Speciale Ronin", "core", 0, seg(
    fx(e("discard", n=1)),
    move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("self_stun"), e("switch", to="any")), fx(e("change", n=1)))), core=True)
card(24, "Vortice Cremisi", "attack", 8,
    seg(atk({c: "w2" for c in RING2})),
    seg(move(step(F, 1, False)), atk({"0": "w2"}), init=5), focus=3, req=AG)
card(25, "Armatura Pesante", "defence", "=", seg(fx(e("armour"))), focus=1, instant="add",
     when="after_card", prepared=True, stays=True)
card(26, "Carica del Toro", "attack", 7,
    seg(move(step(F, 1, False)), atk({"0": "w2", "1": "w2"})),
    seg(move(step(F, 1, False)), atk({"5": "w1", "0": "w1"}), init=5), focus=2, req=AG)
card(27, "Affondo Invertito di Zanna", "attack", 7, seg(
    move(step(FANDN, 1, False)), atk({"00": "w2"}), IFS, fx(e("push", n=1), k=AG)), focus=1)
card(28, "Il Terrore", "meditation", 5, seg(
    fx(e("cancel_cards")), fx(e("each_stun")), fx(e("advantage")),
    move(step(ANY, 2), rot(2), k=AG)), focus=2, range=3)
card(29, "Spazzata Feroce", "attack", 6,
    seg(atk({"00": "w1", "01": "w1", "1": "w1", "2": "w1"})),
    seg(move(step(FANDN, 1)), fx(e("switch", to=AG), k=DE), init=1))
card(30, "Artigli Laceranti", "meditation", "=", seg(fx(e("t_wound_to_bleed"))),
     req=AG, instant="add", when="atk_ok")
card(31, "Difesa d'Acciaio", "defence", [7, 3], seg(
    blk("5", "0", "1"), counter(6, 5, 4),
    IFS, fx(e("t_rot", n=1)),
    move(step(F, 1), rot(1), k=DE), fx(e("change", n=2), k=DE)))
card(32, "Balzo del Lupo", "attack", 7, seg(
    move(step(FANUP, 1, False)), atk({"0": "b"}), IFS, fx(e("t_hobble"))), focus=1, instant="rep")
card(33, "Colpo alle Caviglie", "attack", 3,
    seg(move(step(FANUP, 1, False), rot(1, False)), atk({"00": "w1", "01": "w1"})),
    seg(move(rot(1)), fx(e("draw", n=1)), fx(e("draw", n=2), k=BA), init=2))
card(34, "Ritirata Composta", "meditation", 3, seg(
    alt(5, k=AG),
    OR(move(step(FANDN, 1), rot(1)), move(step(ANY, 1), rot(2), k=BA)),
    fx(e("focus", n=1)), fx(e("draw", n=3))))
card(35, "Chiatta di Buoi", "attack", 5, seg(
    UNB, move(step(F, 1, False), step(F, 1), seq=True), move(rot(1), f=1),
    atk({"0": "a"}), ast(e("t_stun")),
    IFS, fx(e("t_rot", n=1), e("push", n=1)), fx(e("switch", to=AG))))
card(71, "Spazzata di Naginata", "attack", 5,
    seg(fx(e("discard", n=1)), atk({"00": "w1", "05": "w1", "5": "a"}), ast(e("add_wound", n=1), f=1)),
    seg(move(step(ANY, 1), rot(1)), init=2), core=True, weapon="Naginata")
card(89, "Blocco d'Emergenza", "defence", [9, 2], seg(
    move(rot(1), k=BA), move(rot(2), k=DE), blk("0"), fx(e("switch", to="neutral"))),
    focus=1, instant="rep")
card(98, "Grido di Guerra", "meditation", 7, seg(
    move(step(F, 1, False), step(F, 1), seq=True), move(rot(1), k=BA),
    fx(e("cancel_move")), fx(e("advantage")),
    fx(e("draw", n=2), k=DE), fx(e("switch", to=AG))), range=5)
card(102, "Mente Risoluta", "meditation", 3, seg(
    move(step(ANY, 2), rot(2)), move(rot(1), k=DE), fx(e("change", n=1)),
    OR(fx(e("draw", n=2)), fx(e("draw", n=3), k=BA))))
card(104, "Colpo Azzoppante", "meditation", "=", seg(
    fx(e("t_hobble")), fx(e("push", n=1), k=AG), move(step(B, 1), k=DE)),
    instant="add", when="atk_ok")
card(110, "Schivata Rapida", "defence", 8, seg(
    OR(move(step(B, 1, False)), move(step(ANY, 1, False), k=DE)), fx(e("change", n=1))))
card(125, "Calcio del Cavallo", "attack", 6,
    seg(atk({"0": "a"}), ast(e("t_stun")), IFS, OR(fx(e("push", n=1)), fx(e("push", n=2), k=AG))),
    seg(OR(move(step(F, 1)), move(step(ANY, 1), k=BA)), init=5))
card(126, "Colpo d'Elsa", "attack", 5, seg(
    move(step(FANUP, 1)), move(rot(1), k=BA), atk({"0": "w1"}),
    IFS, fx(e("t_stun")), fx(e("t_lose_focus", n=1), k=DE), fx(e("focus", n=1), k=AG)))
card(127, "Spinta Indietro", "attack", 4, seg(
    move(rot(1)), atk({"0": "a"}), ast(e("push", n=2))))

here = os.path.dirname(os.path.abspath(__file__))
pool = {c["id"]: c for c in json.load(open(os.path.join(here, "../data/cards/card_pool.json")))["cards"]}
imgs = json.load(open(os.path.join(here, "../data/cards/card_images.json")))["by_id"]
for k, c in C.items():
    p = pool.get(int(k), {})
    c["en"] = p.get("name", ""); c["rank"] = p.get("rank", "-")
    c["img"] = imgs.get(k, "")
    assert c["img"], k

out = {
 "note": "Trascrizione dalle scansioni della 1a edizione italiana. Regole: Rulebook V1 + errata.",
 "cards": C,
 "characters": {
  "warrior": {"name": "Guerriero", "title": "Vendetta sorta dal fuoco", "advantage": 35,
     "hand": 5, "wounds": 5, "char_img": imgs["51"], "kamae_img": imgs["52"],
     "portrait": "warrior.webp", "model": "warrior.glb",
     "deck": {"55":1,"56":1,"58":1,"59":2,"60":2,"61":2,"62":2,"63":2,"64":2,"65":2,"83":1,"86":1,
              "87":1,"103":2,"107":1,"113":1,"116":2,"118":1,"119":1,"123":2},
     "core": [53, 72],
     "kamae": {"nodes": {"balance":[0.66,0.2],"determination":[0.27,0.45],"focus":[0.62,0.46],
                         "neutral":[0.27,0.73],"aggression":[0.62,0.73]},
        "edges": [["aggression","focus",2],["focus","balance",1],["focus","determination",1],
                  ["determination","neutral",1],["neutral","aggression",2],["determination","balance",2]]}},
  "ronin": {"name": "Ronin", "title": "Un lupo solitario senza padrone", "advantage": 27,
     "hand": 5, "wounds": 5, "char_img": imgs["21"], "kamae_img": imgs["22"],
     "portrait": "ronin.webp", "model": "ronin.glb",
     "deck": {"25":1,"26":1,"27":1,"28":1,"29":2,"30":1,"31":2,"32":1,"33":2,"34":2,"35":3,"89":1,
              "98":1,"102":1,"104":1,"107":1,"110":1,"125":2,"126":2,"127":3},
     "core": [23, 71],
     "kamae": {"nodes": {"focus":[0.22,0.17],"aggression":[0.22,0.45],"determination":[0.62,0.48],
                         "neutral":[0.22,0.76],"balance":[0.62,0.79]},
        "edges": [["focus","aggression",2],["neutral","aggression",1],["neutral","balance",2],
                  ["balance","determination",2]]}}},
 # mappa "villaggio in fiamme": celle giocabili (colonna,riga) lette dal contorno arancione
 "maps": {"villaggio": {"img": "arena.webp", "img_size": 1594,
     "hex_px": 108.68, "origin_px": [304.3, 682.5],
     "cells": [[0,0],[1,0],[1,1],[2,-1],[2,0],[2,1],[2,2],[3,-2],[3,-1],[3,0],[3,1],
               [4,-1],[4,0],[4,1],[4,2],[5,-1],[5,0],[6,-1],[6,0]],
     "start": [[[0,0],[1,0],[1,1]], [[5,-1],[5,0],[6,-1],[6,0]]]}}
}
for ch in out["characters"].values():
    assert sum(ch["deck"].values()) == 30, sum(ch["deck"].values())
    for k in list(ch["deck"]) + [str(x) for x in ch["core"]]: assert k in C, k
json.dump(out, open(os.path.join(here, "../data/carte.json"), "w"), ensure_ascii=False, indent=1)
print("carte:", len(C))
