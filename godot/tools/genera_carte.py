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

# ───────────── CARTE SOLO (Solitario) ─────────────
# Id: 1000+ Ronin, 2000+ Guerriero, 3000+ generiche (numero stampato + base).
V = [5, 1]; A = [4, 2]; X = [1, 2, 4, 5]
CHG = fx(e("ai_change")); RST = fx(e("ai_reset"))
def solo(id, name, type, init, *segs, range=None, alt=False, nightmare=False):
    c = {"id": id, "name": name, "type": type, "init": init, "focus": 0, "solo": True,
         "segs": [x if "lines" in x else seg(x) for x in segs], "img": "solo/%d.webp" % id,
         "en": "", "rank": "-"}
    if alt: c["or"] = True
    if range: c["range"] = range
    if nightmare: c["nightmare"] = True
    C[str(id)] = c
def oppure(id, name, init, top, init2, bottom, **kw):
    solo(id, name, "attack", init, seg(*top), seg(*bottom, init=init2), alt=True, **kw)

oppure(1001, "Chiatta di Buoi (Solo)", 6,
    [UNB, move(step(F, 1)), move(rot(1)), atk({"0": "a"}), ast(e("t_stun")), IFS, fx(e("push", n=1))],
    4, [move(step(FANUP, 2)), move(rot(1))])
solo(1002, "Difesa d'Acciaio (Solo)", "defence", [8, 3],
    seg(blk("5", "0", "1"), counter(6, 5, 4), IFS, fx(e("t_rot", n=1))),
    seg(CHG, move(step(ANY, 1), rot(1)), RST, init=2))
oppure(1003, "Affondo Invertito di Zanna (Solo)", 8,
    [move(step(FANDN, 1)), atk({"00": "w2"}), IFS, fx(e("push", n=1))],
    5, [move(step(ANY, 1), rot(1))])
oppure(1004, "Spazzata Feroce (Solo)", 6,
    [atk({"00": "w1", "01": "w1", "1": "w1", "2": "w1"})],
    6, [CHG, move(step(FANDN, 1), rot(1))])
solo(1991, "Il Terrore (Solo, Incubo)", "meditation", 7, seg(
    CHG, fx(e("cancel_cards")), fx(e("each_stun")), move(step(ANY, 2), rot(2)), RST), range=3, nightmare=True)

solo(2001, "Blocco Cinereo (Solo)", "defence", [9, 5],
    seg(blk("0", "5", "4"), counter(8), IFS, fx(e("push", n=1))),
    seg(CHG, move(step(ANY, 1), rot(1)), RST, init=4))
oppure(2002, "Falciata Montante (Solo)", 8,
    [move(step(B, 1)), atk({"5": "w1", "0": "w1", "01": "w1"})],
    5, [CHG, move(step(ANY, 1), rot(1))])
oppure(2003, "Arco Respingente (Solo)", 7,
    [atk({"00": "w1", "05": "w1", "01": "w1", "0": "w1", "5": "w1", "1": "w1"}),
     IFS, fx(e("t_discard", n=1), e("push", n=1))],
    5, [CHG, move(step(ANY, 1), rot(1))])
solo(2004, "Concentrazione Ritrovata (Solo)", "meditation", 5, seg(CHG, move(step(ANY, 2), rot(2)), RST))
oppure(2993, "Colpo della Fenice Fiammante (Solo, Incubo)", 6,
    [move(step(FANUP, 1)), atk({"00": "w2", "01": "x", "1": "w1", "11": "w1"}), IFS, RST],
    2, [move(step(FANUP, 1), rot(1)), RST], nightmare=True)

for n in (3001, 3002):
    solo(n, "Mente Aggressiva", "meditation", 2, seg(CHG, move(step(FANUP, 2)), move(rot(3)), fx(e("ai_recycle"))))
for n in (3003, 3004, 3005):
    solo(n, "Mente Risoluta (Solo)", "meditation", 3, seg(move(step(ANY, 2), rot(2))))
for n in (3006, 3007):
    solo(n, "Mente Rapida (Solo)", "meditation", 6, seg(move(step(ANY, 2)), move(step(F, 1)), move(rot(1))))
solo(3008, "Provocazione", "meditation", 7, seg(move(step(ANY, 2)), move(rot(1)), fx(e("t_switch", to="neutral"))), range=5)
solo(3009, "Grido di Guerra (Solo)", "meditation", 7, seg(CHG, move(step(F, 2)), move(rot(1)), fx(e("cancel_move"))), range=5)
oppure(3010, "Colpo alle Caviglie (Solo)", 7, [move(step(FANUP, 1), rot(1)), atk({"00": "w1", "01": "w1"})],
    2, [move(step(ANY, 1), rot(1))])
oppure(3011, "Affondo Lungo", 4, [move(step(FANDN, 1)), move(rot(1)), atk({"0": "w1", "01": "w1"})],
    4, [move(step(ANY, 1), rot(1))])
for n, i in ((3012, 3), (3013, 6)):
    oppure(n, "Affondo in Spinta (Solo)", i, [move(step(FANUP, 1)), atk({"00": "w2", "0": "w1"}), IFS, fx(e("t_stun"))],
        3, [CHG, move(step(ANY, 1), rot(1))])
for n, i in ((3014, 2), (3015, 6)):
    oppure(n, "Squarcio di Rovescio", i, [move(step(ANY, 1)), move(rot(1)), atk({"0": "w1"}), IFS, fx(e("t_discard", n=1))],
        2, [move(step(ANY, 1), rot(1))])
oppure(3016, "Taglio Sanguinante", 7, [move(step(V, 1)), atk({"0": "b", "1": "b"})], 1, [move(step(ANY, 1), rot(1))])
oppure(3017, "Taglio Orizzontale", 8, [CHG, move(step(X, 1)), atk({"5": "w1", "0": "w1", "1": "w1"})], 4, [move(step(ANY, 1))])
oppure(3018, "Calcio del Cavallo (Solo)", 6, [atk({"0": "a"}), ast(e("t_stun"), e("push", n=1))], 5, [move(step(ANY, 1))])
oppure(3019, "Colpo d'Elsa (Solo)", 5, [move(step(FANUP, 1)), move(rot(1)), atk({"0": "w1"}), IFS, fx(e("t_lose_focus", n=1))],
    5, [move(step(FANUP, 1), rot(1))])
oppure(3020, "Spinta Indietro (Solo)", 5, [move(rot(1)), atk({"0": "a"}), ast(e("push", n=2))], 2, [move(step(ANY, 1))])
oppure(3021, "Squarcio Rotante", 6, [CHG, move(step(V, 2)), move(rot(1)), atk({"0": "w1", "5": "w2"})], 6, [move(step(X, 2))])
oppure(3022, "Taglio Troncante (Solo)", 4, [move(step(V, 1), rot(1)), atk({"0": "b"})], 1, [move(step(ANY, 1), rot(1))])
for n, i, j in ((3023, 3, 3), (3024, 5, 2), (3025, 7, 1)):
    oppure(n, "Stoccata", i, [move(step(F, 1), rot(1)), atk({"0": "w1"})], j, [move(step(FANUP, 1), rot(1))])
solo(3026, "Difesa Tranquilla", "defence", [6, 2], seg(move(rot(1)), blk("5", "0", "1")),
    seg(CHG, move(step(FANDN, 1), rot(1)), RST, init=1))
solo(3027, "Difesa Accerchiante", "defence", [7, 3], seg(blk("0", "1", "2")),
    seg(move(step(V, 2), rot(2)), RST, init=2))
solo(3028, "Schivata", "defence", 8, seg(CHG, move(step(ANY, 1)), move(step(ANY, 1)), move(rot(1)), RST))
solo(3029, "Respinta (Solo)", "defence", [5, 2], seg(move(rot(1)), blk("5", "0", "1"), IFS, fx(e("push", n=1))),
    seg(move(step(FANDN, 1)), RST, init=1))
solo(3030, "Passo di Foresta", "defence", 7, seg(UNB, atk({"0": "a"}), ast(e("t_rot", n=2))),
    seg(CHG, move(step(ANY, 1), rot(1)), RST, init=2))
for n in (3031, 3032):
    solo(n, "Blocco di Fiume", "defence", [7, 4], seg(move(rot(1)), blk("0", "1"), counter(6, 5)),
        seg(CHG, move(step(ANY, 1), rot(1)), RST, init=3))
solo(3033, "Difesa di Roccia", "defence", [6, 2], seg(blk("5", "0", "1", "4", "2"), counter(5, 4, 3), IFS, fx(e("t_stun"))),
    seg(CHG, move(step(B, 1), rot(1)), RST, init=1))
for n in (3034, 3035):
    solo(n, "Blocco di Vento", "defence", [8, 5], seg(move(rot(1)), blk("0", "1"), counter(8, 7)),
        seg(move(step(FANUP, 1), rot(1)), RST, init=4))

SOLO = {"selezione": {"1": [3001, 3003, 3008, 3009], "2": [3002, 3004, 3005, 3006, 3007],
                      "3": [3010, 3011, 3012, 3013], "4": list(range(3014, 3026)), "5": list(range(3026, 3036))},
        "warrior": {"firma": [2001, 2002, 2003, 2004], "incubo": 2993, "raggio": 1, "mazzi": ["1", "3", "4", "5"], "extra": ["2", "4", "5"]},
        "ronin": {"firma": [1001, 1002, 1003, 1004], "incubo": 1991, "raggio": 2, "mazzi": ["1", "3", "4", "5"], "extra": ["2", "4", "5"]},
        "ferite": 7}

here = os.path.dirname(os.path.abspath(__file__))
pool = {c["id"]: c for c in json.load(open(os.path.join(here, "../data/cards/card_pool.json")))["cards"]}
imgs = json.load(open(os.path.join(here, "../data/cards/card_images.json")))["by_id"]
for k, c in C.items():
    if c.get("solo"): continue
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
 "solo": SOLO,
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
