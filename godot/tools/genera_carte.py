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
def atk(cells): return {"t": "grid", "mode": "atk", "cells": dict(cells)}
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

# ───────────── ALLIEVO ─────────────
card(38, "Carta Speciale Allievo", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("search", rank="Wood")), fx(e("change", n=1)))), core=True)
card(70, "Fendente di Katana", "attack", 4,
    seg(fx(e("discard", n=1)), move(rot(2), f=1), atk({"0": "w1"})),
    seg(move(step(ANY, 1), rot(1)), init=2), core=True, weapon="Katana")
card(40, "Coda Fulminea", "attack", 9, seg(
    move(step([5, 1], 1, False)), move(step([5, 1], 1), rot(1)),
    atk({"5": "w1", "0": "w1", "1": "w1"}), fx(e("switch", to=AG))), focus=2, req=BA)
card(42, "Specchio d'Acqua", "meditation", 8, seg(
    fx(e("search_discard", rank="Wood")), fx(e("search_discard", rank="Steel"), f=1),
    fx(e("nota", txt="gioca la carta presa come Sostituzione istantanea"), f=2)))
card(43, "Tigre Appostata", "meditation", "=", seg(
    fx(e("t_rot", n=1)), fx(e("t_step", n=1, dir=0)), fx(e("t_discard", n=1)), fx(e("switch", to="any"))),
    focus=1, instant="add", when="block_ok")
card(44, "Colpo Astuto", "attack", 5,
    seg(alt(7, k=AG), atk({"5": "w1", "0": "w1", "1": "w1"}), IFS, fx(e("t_discard", n=1), k=DE)),
    seg(fx(e("view_hand")), move(step(ANY, 1), rot(1)), init=3), prepared=True)
card(45, "Obbedienza", "defence", [7, 3], seg(
    blk("0", "1", "2"), IFS, fx(e("t_switch", to="any")), fx(e("steal_focus", n=1)),
    fx(e("change", n=1)), fx(e("advantage"))), req=[BA, DE], prepared=True)
card(46, "Colpo della Roccia", "attack", 3, seg(
    OR(move(rot(1)), move(step([5, 1], 1), rot(1), f=1)), atk({"0": "w1", "1": "w1"})), req=DE)
card(47, "Squarcio Rotante", "attack", 6, seg(
    move(rot(1), f=1), atk({"0": "w1", "1": "w1"}), IFS, fx(e("t_rot", n=1), k=AG)), instant="rep")
card(48, "Cascata Fendente", "attack", 7,
    seg(atk({"5": "w1", "0": "w1"})),
    seg(OR(move(step(F, 1)), move(rot(1))), g(atk({"5": "w1", "0": "w1"}), f=1), init=4))
card(49, "Scambio della Montagna", "defence", 7,
    seg(g(atk({"0": "a"}), k=[BA, DE]), ast(e("swap")), IFS, fx(e("focus", n=1))),
    seg(move(step([4, 2], 1), rot(2)), init=5))
card(50, "Mente Placida", "meditation", 3, seg(
    move(step(ANY, 1), rot(1)), fx(e("change", n=1)), fx(e("search_top", n=3), k=DE), move(rot(2), k=BA)))
card(84, "Calma Composta", "meditation", "=", seg(
    fx(e("draw", n=2)), fx(e("focus", n=1)), fx(e("switch", to="any"))), instant="add", when="after_card")
card(90, "Passo Evasivo", "defence", [9, 6], seg(
    OR(move(step(FANDN, 1, False), f=1), move(step(FANDN, 1, False), k=DE)), fx(e("switch", to="neutral"))),
    instant="rep")
gr99 = blk("1", "2"); gr99["cells"]["0"] = "sa"; gr99["ak"] = BA
card(99, "Difesa Accerchiante", "defence", [7, 3],
    seg(gr99),
    seg(move(step([5, 1], 1, False), rot(1, False)), move(step([5, 1], 1), rot(1), f=1), fx(e("draw", n=1), k=DE), init=2))
card(100, "Squarcio Diagonale", "attack", 5, seg(
    alt(7, k=BA), move(step(B, 1)), move(rot(1), k=DE),
    atk({"0": "a", "1": "w2", "2": "w2"}), ast(e("add_wound", n=1), k=AG)))
card(105, "Taglio Orizzontale", "attack", 6, seg(
    alt(8, k=BA), OR(move(step([5, 1], 1, False)), move(step([1, 2, 4, 5], 1, False), k=AG)),
    atk({"5": "w1", "0": "w1", "1": "w1"}), fx(e("switch", to=BA))))
card(115, "Blocco Rapido", "defence", [8, 6], seg(
    blk("0"), IFS, fx(e("push", n=1)), fx(e("focus", n=1), k=DE), move(step(ANY, 1), k=BA), fx(e("switch", to=AG))),
    instant="rep")
card(117, "Mente Addestrata", "meditation", 2, seg(
    OR(move(step(FANUP, 2), rot(1), seq=True), move(step(FANUP, 2), rot(3), seq=True, k=BA)),
    OR(fx(e("change", n=2)), fx(e("search", rank=["Wood", "Steel"]))),
    fx(e("view_hand"), k=DE)))
card(121, "Difesa Tranquilla", "defence", [6, 2],
    seg(move(rot(1), k=BA), blk("5", "0", "1"), IFS, fx(e("focus", n=1), k=DE)),
    seg(move(step(FANDN, 1), rot(1), seq=True), fx(e("change", n=1)), init=1), prepared=True)
card(122, "Meditazione Profonda", "meditation", 1, seg(
    move(step(ANY, 1), rot(2), seq=True), fx(e("focus", n=1), k=DE),
    OR(fx(e("draw", n=2)), fx(e("view_hand"))), fx(e("switch", to=DE))))
card(124, "Fasciature da Campo", "defence", 1, seg(
    move(step(ANY, 1), rot(1)), OR(fx(e("discard_stun", n=2)), fx(e("bleed_to_wound"))),
    fx(e("draw", n=1), k=BA), fx(e("draw", n=2), k=DE)), prepared=True)

# ───────────── MAESTRO ─────────────
card(8, "Carta Speciale Maestro", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("trade", drop="Steel", rank="Wood")), fx(e("change", n=1)))), core=True)
card(75, "Taglio di Tachi", "attack", 5, seg(
    fx(e("discard", n=1)), OR(move(step(FANUP, 1)), move(rot(2), f=1)), atk({"1": "w1"})),
    core=True, weapon="Tachi")
card(10, "Zanna Celata della Vipera", "attack", 8, seg(
    move(step([5, 1], 1, False), rot(1)), atk({"1": "w1"}),
    IFS, fx(e("t_poison"), f=1), fx(e("switch", to="any"), k=BA)))
card(12, "Intuizione Oscura", "meditation", 7, seg(
    fx(e("view_hand")), fx(e("t_shuffle_type", type="attack")), fx(e("t_shuffle_type", type="defence")),
    fx(e("t_shuffle_type", type="meditation")), fx(e("t_draw", n=3)), fx(e("switch", to="any"))), focus=1)
card(13, "Occhio del Dragone", "meditation", "=", seg(
    fx(e("t_lose_focus", n=2), f=1), fx(e("t_draw", n=2), f=1), move(step(ANY, 1), k=AG),
    fx(e("draw", n=2), k=DE), fx(e("pull_or_push", n=1), k=BA)), focus=1, instant="add", when="after_card")
card(14, "Patto Oscuro", "meditation", 1, seg(
    move(step(ANY, 1), rot(1)), fx(e("search_top", n=3)), fx(e("t_give_top", n=3))), focus=1, range=3)
card(15, "Coda del Dragone", "attack", 6, seg(
    fx(e("switch", to="any")), move(step(FANDN, 1), k=AG), move(rot(1, False), k=[BA, DE]),
    atk({"3": "w1"}), IFS, fx(e("t_stun"), e("t_hobble"), f=1)), instant="rep")
card(16, "Sesto Senso", "defence", [9, 4], seg(
    move(rot(3, False)), blk("5", "0", "1"), IFS, fx(e("t_lose_focus", n=1)), fx(e("view_hand"))), req=[BA, DE])
card(17, "Saggezza Corrotta", "meditation", "=", seg(
    fx(e("counter_now", v2=[9, 8]), k=DE), fx(e("counter_now", v2=[7, 6]), k=BA),
    fx(e("counter_now", v2=[5, 4]), k=AG), fx(e("all_draw", n=2), f=1)), instant="add", when="block_ok")
card(18, "Colpo Indolente", "attack", 3, seg(
    atk({"5": "w1", "0": "w1", "1": "w1"}), move(step(FANDN, 1, False), f=1),
    IFS, fx(e("t_wound_to_bleed"), k=AG), fx(e("t_discard", n=1), k=DE), fx(e("t_hobble"), k=BA)))
card(19, "Taglio Magistrale", "attack", 6, seg(
    move(step(ANY, 1, False), rot(1, False), k=[BA, DE]), move(rot(1, False), k=AG),
    g(atk({"5": "b"}), k=DE), g(atk({"5": "w1", "0": "w1", "1": "w1"}), k=BA), g(atk({"0": "w2"}), k=AG)))
card(20, "Riposizionamento", "meditation", 7, seg(
    move(step([5, 1], 1, False)), move(step(F, 1), k=AG), move(rot(2)),
    fx(e("draw", n=2), k=BA), fx(e("search", rank="Wood"), k=DE), fx(e("change", n=1))))
card(96, "Colpo Squarciante", "attack", 6, seg(
    move(rot(1), k=BA), move(step(F, 2, False)), move(rot(1), f=1), atk({"0": "w2"}), IFS, fx(e("t_stun"), k=AG)))
card(97, "Provocazione", "meditation", "=", seg(
    fx(e("t_switch", to="neutral")), fx(e("advantage"), k=DE), fx(e("t_discard", n=1), f=1)),
    instant="add", when="atk_ok|block_ok", range=5)
card(111, "Blocco di Fiume", "defence", [7, 4],
    seg(move(rot(1)), blk("0", "1"), counter(6, 5, k=DE)),
    seg(move(step(ANY, 1), rot(1), seq=True), fx(e("focus", n=1), k=BA), fx(e("switch", to=BA)), init=3))
card(112, "Squarcio Rotante (Maestro)", "attack", 6, seg(
    OR(move(step([5], 1, False), step([5], 1), seq=True), move(step([1], 1, False), step([1], 1), seq=True)),
    move(rot(1), k=BA), atk({"0": "w1", "5": "w2"}), IFS, fx(e("focus", n=1), k=AG), fx(e("change", n=1), k=DE)))
card(120, "Blocco di Vento", "defence", [8, 5], seg(
    move(rot(1)), blk("0", "1"), counter(8, 7, k=BA), counter(6, 5, k=DE)))
card(128, "Stoccata Rapida", "attack", 8, seg(
    move(step(F, 1, False), k=AG), move(rot(1), k=BA), atk({"0": "w1"}), IFS, fx(e("focus", n=1), k=DE)), focus=1)

# ───────────── ASSASSINO ─────────────
def occ(line): line["o"] = True; return line
card(218, "Carta Speciale Assassino", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("discard", n=1), e("focus", n=1)), fx(e("change", n=1)))), core=True)
card(138, "Taglio di Tanto", "attack", 5, seg(
    fx(e("discard", n=1)), move(step([5, 1], 1)), move(rot(1), f=1), atk({"0": "w1"})), core=True, weapon="Tanto")
gr220 = atk({"0": "x"}); gr220["retro"] = True
card(220, "Puntura d'Ombra", "attack", 6, seg(occ(alt(9)), gr220), focus=2)
card(221, "Passo nell'Ombra", "defence", 7, seg(
    occ(alt(9)), move(step(ANY, 1), step(ANY, 1), seq=True), move(rot(1)), fx(e("conceal"))))
card(222, "Bacio del Ragno", "attack", 1, seg(move(rot(1)), atk({"5": "w2", "0": "w2", "1": "w2"})))
ARCO2 = {"55": "w1", "05": "w1", "00": "w1", "01": "w1", "11": "w1"}
card(223, "Pioggia d'Acciaio", "attack", 7, seg(atk(ARCO2)), seg(atk(ARCO2), init=4))
card(224, "Bomba Fumogena", "defence", 7,
    seg(atk({c: "a" for c in "012345"}), ast(e("push", n=1))),
    seg(move(rot(1)), OR(move(step(B, 1, False)), move(step(FANDN, 1, False), k=DE)), fx(e("conceal")), init=6),
    focus=1, prepared=True)
card(225, "Coltello nella Piaga", "meditation", "=", seg(
    fx(e("t_mill_wounds")), g(fx(e("conceal")), f=1)), instant="add", when="atk_ok",
    note="La riga da 1 focus comprende anche un passo facoltativo in avanti (ventaglio), non automatizzato.")
card(226, "Balzo nell'Ombra", "defence", 8, seg(
    move(step(FANDN, 1, False)), atk({"0": "a"}), ast(e("swap")),
    IFS, fx(e("push", n=1)), move(rot(2), k=BA), move(step(FANDN, 1, False), k=DE), fx(e("conceal"))))
card(227, "Colpo della Vipera", "attack", 5, seg(
    move(step(ANY, 1), rot(1)), atk({"0": "pa"}), occ(ast(e("add_bleed", n=1), f=1)), move(step(FANUP, 1))))
card(228, "Sguardo Disarmante", "meditation", "=", seg(
    fx(e("t_discard_type", type="defence", n=1)), fx(e("focus", n=1), k=BA), fx(e("conceal"))),
    instant="add", when="atk_ok|block_ok")
card(229, "Arteria Recisa", "attack", 5, seg(
    OR(move(step([5, 1], 1)), occ(move(step([5, 1], 2)))), atk({"5": "b", "0": "b", "1": "b"}),
    IFS, fx(e("t_discard", n=1), k=AG)))
card(230, "Taglio Velenoso", "attack", 6, seg(
    occ(alt(9)), atk({"0": "p"}), move(step(FANDN, 1, False)), OR(fx(e("draw", n=1)), fx(e("draw", n=2), k=BA))))
card(108, "Distrazione", "defence", 8,
    seg(atk({"5": "a", "0": "a", "1": "a"}), ast(e("t_rot", n=1)), IFS, fx(e("cancel_rot"))),
    seg(move(step([5, 1], 2, False)), init=7), focus=1)
card(150, "Furia Crescente", "meditation", "=", seg(fx(e("push", n=1), k=AG), fx(e("switch", to=AG))),
    instant="add", when="atk_ok|block_ok", prepared=True,
    note="Sulla carta il «Passa ad Aggressione» avviene a iniziativa 0: qui è immediato.")
card(154, "Taglio Sanguinante", "attack", 4, seg(move(step([5, 1], 1), k=AG), atk({"0": "b", "1": "b"})))

# ───────────── MONACO ─────────────
card(260, "Carta Speciale Monaco", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("discard", n=2), e("search_illum")), fx(e("change", n=1)))), core=True)
card(133, "Stoccata di Jumonji Yari", "attack", 2, seg(
    fx(e("discard", n=1)), move(step(FANUP, 1), f=1), atk({"05": "w1", "00": "w1", "01": "w1"})),
    core=True, weapon="Yari")
card(262, "Squarcio dell'Onda Zen", "attack", 6, seg(alt(8, f=2), atk({"5": "x", "0": "x", "1": "x"})),
    focus=2, req=BA)
card(263, "Corpo Illuminato", "meditation", "-", seg(
    fx(e("wounds_to_stun")), fx(e("switch", to=DE)), fx(e("illum_search")), fx(e("illumina", bonus="wounds"))),
    focus=2, when="hit_me")
card(264, "Mente Illuminata", "meditation", "-", seg(fx(e("illum_search")), fx(e("illumina", bonus="hand"))))
card(265, "Anima Illuminata", "meditation", 8, seg(
    move(step([5, 1], 1)), OR(fx(e("search", rank="Jade")), fx(e("search_discard", rank="Jade"))),
    fx(e("switch", to=BA)), fx(e("illum_search")), fx(e("illumina", bonus="focus"))), focus=2)
card(266, "Chiarezza di Intenti", "defence", 8, seg(
    move(step(FANDN, 1)), fx(e("search_illum", scarti=True)), fx(e("focus", n=1), k=DE), fx(e("draw", n=1), k=BA)))
card(267, "Mente Serena", "meditation", 6, seg(
    OR(move(step(FANUP, 2), rot(1)), move(step(FANDN, 1), rot(2), k=BA)), fx(e("focus", n=1)), fx(e("switch", to="any"))))
card(268, "Distruzione Satori", "attack", 4, seg(
    move(step(F, 1), rot(1), seq=True), atk({"1": "w1", "2": "w1"}), IFS, fx(e("t_discard", n=1), k=AG)))
card(269, "Carica del Cervo", "attack", 6, seg(
    move(rot(1)), atk({"0": "w1", "00": "w1"}), IFS, fx(e("push", n=2)), move(step(F, 2, False)), fx(e("advantage"))))
card(270, "Cresta dell'Onda", "attack", 7,
    seg(move(step(B, 1)), atk({"5": "w1", "0": "w1"})),
    seg(g(atk({"0": "w1", "1": "w1", "2": "w1"}), f=1), move(step(F, 1), k=AG), init=5))
card(271, "Colpo del Palmo", "attack", 5, seg(
    atk({"0": "a"}), ast(e("t_stun"), e("t_hobble")), IFS, fx(e("t_lose_focus", n=1)),
    fx(e("push", n=1), k=BA), fx(e("change", n=1))), instant="rep")
card(272, "Blocco Risoluto", "defence", [8, 4],
    seg(move(rot(1), k=DE), blk("5", "0", "1")),
    seg(move(step(FANDN, 1)), fx(e("draw", n=2), k=BA), fx(e("change", n=1)), init=3))
card(140, "Squarcio di Rovescio", "attack", 6, seg(
    alt(2, k=DE), move(step(ANY, 1)), move(rot(1), k=BA), atk({"0": "w1"}), IFS, fx(e("t_discard", n=1))))
card(142, "Calma Convinzione", "meditation", "=", seg(fx(e("focus", n=1), k=BA), fx(e("switch", to=BA))),
    instant="add", when="atk_ok|block_ok", prepared=True,
    note="Sulla carta il «Passa a Equilibrio» avviene a iniziativa 0: qui è immediato.")
card(151, "Blocco della Tempesta", "defence", [8, 5], seg(
    move(rot(1)), blk("5", "0"), counter(8, 7, k=DE), counter(6, 5, k=BA)))
for _i in (263, 264, 265): C[str(_i)]["illum"] = True
C["262"]["req_illum"] = 3
C["264"]["no_play"] = True
for _i in (263, 264, 265): C[str(_i)]["stays"] = True

# ───────────── YASUKE ─────────────
card(349, "Carta Speciale Yasuke", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), move(step(F, 1), f=1), fx(e("change", n=1)))), core=True)
card(350, "Taglio Mancino", "attack", 1, seg(
    fx(e("discard", n=1)), move(rot(1), f=1), atk({"0": "w1"})), core=True, weapon="Wakizashi")
C["350"]["counter_ok"] = True
card(136, "Squarcio di Katana", "attack", 4, seg(
    fx(e("discard", n=1)), move(step([5, 1], 1), f=1), move(rot(1)), atk({"0": "w1"})), core=True, weapon="Katana")
card(352, "Furia Giusta", "attack", 6, seg(
    atk({"0": "x", "5": "w2", "1": "w2", "45": "w1", "12": "w1"}),
    move(step([5, 1], 1, False), rot(1, False), seq=True)), focus=3, req=AG)
card(353, "Carica del Branco", "attack", 3, seg(
    move(rot(1), f=1), move(step(F, 3)), atk({"0": "a"}), ast(e("t_stun")),
    IFS, fx(e("t_stun_per_step"), k=AG), move(rot(1, False)), fx(e("switch", to=AG))), focus=1)
card(354, "Anima Devota", "defence", [8, 6],
    seg(blk("0", "5", "1", "4"), counter(8, 7, 6)),
    seg(blk("0", "5", "1", "4"), counter(5, 4, 3), init=[5, 3]), req=DE)
card(355, "Schianto dell'Elefante", "meditation", "=", seg(fx(e("push_steps"))),
    instant="add", when="atk_ok|block_ok")
card(356, "Chiudere la Distanza", "meditation", 3, seg(
    move(step([5, 1], 1, False), step(F, 1, False), seq=True), move(step(F, 1)),
    fx(e("search", rank="Steel", type="defence"), f=1), fx(e("change", n=2))))
card(357, "Colpo Doppio", "attack", 4, seg(
    move(step(FANUP, 1)), atk({"0": "a", "5": "a", "1": "w1", "2": "w1"}), ast(e("add_wound", n=1), k=BA),
    IFS, fx(e("push", n=1), k=AG)))
card(358, "Artigli dell'Aquila", "attack", 7,
    seg(move(step(FANDN, 1, False), k=AG), atk({"0": "w1", "1": "w1"}), g({"t": "mod", "fx": "bleed"}, f=1)),
    seg(move(rot(1, False), k=BA), g(atk({"5": "w1", "0": "w1"}), f=1), IFS, fx(e("t_hobble")), init=5))
card(359, "Zanne del Leone", "attack", 5, seg(
    move(rot(1), k=DE), move(step(F, 1, False)), atk({"5": "w1", "1": "w1"}),
    IFS, fx(e("t_discard_type", type="meditation", n=1), k=AG), fx(e("draw", n=2), k=BA)), focus=1, instant="rep")
card(360, "Difesa a Due Lame", "defence", [8, 7],
    seg(blk("5", "0", "1"), counter(7, k=DE)),
    seg(blk("5", "0", "1"), counter(5, k=DE), init=[5, 4]))
card(361, "Morso del Leone", "attack", 6, seg(
    move(step([5, 1], 1), rot(1)), move(step(F, 1, False)), atk({"5": "w1", "1": "w1"}),
    IFS, fx(e("focus", n=1), k=DE)))
card(362, "Sbilanciamento", "attack", 1, seg(
    fx(e("focus", n=1)), fx(e("draw", n=1)), fx(e("t_discard", n=1)), fx(e("t_switch", to="neutral")),
    fx(e("advantage")), fx(e("switch", to="any"))))
C["362"]["counter_only"] = True
card(114, "Difesa di Roccia", "defence", [6, 2],
    seg(blk("0", "5", "1", "4"), counter(5, 4, 3), IFS, fx(e("t_stun"))),
    seg(fx(e("focus", n=1), k=DE), move(rot(1)), fx(e("switch", to=DE)), init=1))
card(144, "Determinazione", "meditation", "=", seg(fx(e("discard_hobble"), k=DE), fx(e("switch", to=DE))),
    instant="add", when="after_card", prepared=True,
    note="Sulla carta il «Passa a Determinazione» avviene a iniziativa 0: qui è immediato.")
card(145, "Colpo Disorientante", "attack", 3, seg(
    move(step(F, 1), k=DE), move(rot(1), k=BA), atk({"0": "w1", "1": "w1"}), IFS, fx(e("t_switch", to="neutral"))))
card(147, "Passo di Foresta", "defence", 7,
    seg(atk({"0": "a"}), ast(e("t_rot", n=2)), IFS, fx(e("focus", n=1), k=DE)),
    seg(move(step(ANY, 1)), move(step(FANDN, 1), rot(1), k=BA), fx(e("switch", to=BA)), init=2))

# ───────────── YOJIMBO ─────────────
def ranged(eff, r): return {"t": "ranged", "eff": eff, "r": r}
card(316, "Carta Speciale Yojimbo", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("contract_back")), fx(e("change", n=1)))), core=True)
card(317, "Affondo di Nagamaki", "attack", 4, seg(
    fx(e("discard", n=1)), move(step(F, 1)), atk({"0": "w1", "00": "w1"}),
    IFS, OR(fx(e("t_hobble"), f=1), fx(e("t_stun"), f=1))), core=True, weapon="Nagamaki")
card(319, "Zanmato", "attack", 5, seg(move(step([5], 2)), atk({"1": "w1", "2": "w1"})))
C["319"]["zanmato"] = True
card(320, "Colpo Brutale", "attack", 5, seg(
    move(step(F, 1), k=AG), move(step(FANDN, 1, False), rot(1, False)), atk({"5": "w2", "0": "w1"}),
    IFS, fx(e("view_hand")), fx(e("change", n=1))))
card(321, "Reputazione Spaventosa", "meditation", 5, seg(
    fx(e("t_hobble")), fx(e("advantage")), move(step(ANY, 1), rot(1))), focus=1, range=1)
C["321"]["range_contr"] = True
card(322, "Il Mio Lavoro Qui è Finito", "meditation", 6, seg(fx(e("lavoro_finito"))))
card(323, "Guardia di Ferro", "defence", [7, 5],
    seg(blk("5", "0", "1"), counter(6), IFS, fx(e("focus", n=1)), fx(e("push", n=2), k=[BA, AG]), fx(e("advantage"), k=DE)),
    seg(move(step(ANY, 1)), init=4))
card(324, "Pungiglione dello Scorpione", "attack", 6, seg(
    alt(8, k=AG), move(step(F, 1), rot(1)), atk({"0": "w1"}), IFS, fx(e("t_poison"), f=1), fx(e("t_discard", n=1))), focus=1)
card(325, "Lancio di Senbon", "attack", 4, seg(
    alt(6, k=AG), ranged("b", 2), IFS, fx(e("focus", n=1)), fx(e("draw", n=2), k=DE)), range=2)
card(326, "Craniotomia", "attack", 4, seg(
    move(step(FANUP, 1), rot(1)), atk({"0": "w1", "1": "w1"}),
    IFS, fx(e("t_stun"), k=DE), fx(e("t_switch", to="neutral"), k=AG), fx(e("change", n=1))))
card(327, "Aura Oscura", "meditation", 2, seg(
    move(step(F, 2, False), rot(1)), fx(e("t_lose_focus", n=2), f=1), fx(e("t_discard_rand"), f=2), fx(e("advantage"))), range=3)
card(328, "Sicario a Pagamento", "meditation", "-", seg(
    OR(fx(e("search", rank="Wood", type="attack", pers="Yojimbo")),
       fx(e("search", rank="Steel", type="attack", pers="Yojimbo"), f=1),
       fx(e("search", rank="Gold", type="attack", pers="Yojimbo"), f=2))), when="contract", prepared=True)
card(329, "Spezzare le Gambe", "attack", 7, seg(
    move(step(B, 1)), atk({"5": "w1", "4": "w1"}), IFS, fx(e("t_hobble"), k=BA), fx(e("change", n=1))))
card(155, "Contrattacco", "attack", 2, seg(move(step(FANUP, 1), rot(1)), atk({"0": "w1"})))

# ───────────── WAKOU ─────────────
YY = [5, 1, 3]
card(333, "Carta Speciale Wakou", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("discard_stun", n=1), e("self_hobble")), fx(e("change", n=1)))), core=True)
card(134, "Colpo di Kanabo", "attack", 4,
    seg(fx(e("discard", n=1)), atk({"00": "a", "05": "a"}), ast(e("t_stun"))),
    seg(move(step(FANDN, 1), rot(1), f=1), init=1), core=True, weapon="Kanabo")
card(334, "Schianto di Bordata", "attack", 6, seg(
    UNB, move(step([5, 4], 2), rot(1, False)), atk({"0": "a", "5": "a"}), ast(e("t_stun"), e("t_stun")),
    IFS, fx(e("t_wound", n=1), k=AG), fx(e("push", n=1), k=BA), move(step([4], 1))), focus=2,
    note="Le direzioni dei passi (icone a freccia doppia) sono la lettura meno certa di questa carta.")
rb = ranged("b", 2); rb["fx"] = [e("t_hobble"), e("t_stun", k=AG)]
card(336, "Lancio della Brocca", "attack", 5, seg(rb, fx(e("switch", to="neutral"))), range=2)
card(337, "Ariete Bukan", "attack", 5, seg(
    UNB, move(step([5, 1], 2)), atk({"0": "a"}), ast(e("t_stun")), IFS, fx(e("push", n=1)), move(step(F, 1))),
    focus=1, instant="rep", note="Direzione del primo passo (freccia obliqua): lettura incerta.")
card(338, "Piedi da Marinaio", "meditation", 9, seg(
    move(step([5, 1], 1, False), rot(1, False), seq=True), move(step([5, 1], 1, False), rot(1, False), seq=True)),
    instant="rep")
card(339, "Gesticolare da Ubriaco", "meditation", 1, seg(
    move(step(ANY, 1)), fx(e("reveal_take", n=5, pers="Wakou")), fx(e("change", n=2)), fx(e("advantage"))))
card(340, "Gigante Goffo", "attack", 7, seg(move(step(YY, 2), rot(1)), atk({"0": "a"}), ast(e("t_stun"))))
card(341, "Colpo Barcollante", "meditation", "=", seg(
    fx(e("t_stun"), k=AG), fx(e("push", n=2), k=BA), fx(e("advantage"))), focus=1, instant="add", when="atk_ok")
card(342, "Far Due Passi", "defence", 7, seg(move(step([1, 2, 4, 5], 2)), fx(e("draw", n=2)), fx(e("change", n=1))))
card(343, "Testata (Wakou)", "attack", 4, seg(
    move(step(FANDN, 1)), move(rot(1), k=AG), atk({"0": "w1"}), IFS, fx(e("t_hobble")), fx(e("focus", n=1))))
card(344, "Calcio del Mulo", "attack", 5, seg(
    move(rot(1), k=BA), move(step(FANDN, 1)), atk({"4": "w1", "2": "w1"}), IFS, fx(e("t_hobble")), fx(e("change", n=1))),
    note="Sulla carta le due caselle posteriori sono in alternativa (OPPURE): contro un solo avversario è equivalente.")
card(345, "Stella Vagabonda", "meditation", 3, seg(move(step(YY, 2), rot(1)), fx(e("search_stun"), f=1)))
card(152, "Colpo Stordente", "meditation", "=", seg(fx(e("t_stun"))), focus=2, instant="add", when="atk_ok|block_ok")

# ───────────── ONNA-BUGEISHA ─────────────
def dsp(line): line["d"] = True; return line
card(294, "Carta Speciale Onna-Bugeisha", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("self_wound", n=1), e("switch", to="any")), fx(e("change", n=1)))), core=True)
card(137, "Affondo di Naginata", "attack", 4,
    seg(fx(e("discard", n=1)), atk({"00": "w1", "01": "w1", "1": "w1"})),
    seg(move(step(ANY, 1), rot(1), f=1), init=1), core=True, weapon="Naginata")
card(296, "Abbraccio Silenzioso", "attack", 7, seg(move(rot(3)), atk({"00": "w3", "01": "w2", "11": "w1"})), focus=2)
C["296"]["req_d"] = True
card(297, "Morso del Cielo", "attack", 8,
    seg(atk({c: "w1" for c in RING2})),
    seg(dsp(atk({"5": "w1", "0": "w1", "1": "w1"})), dsp(fx(e("draw_exact", n=2))), init=7), focus=2, req=AG)
card(298, "Istinto Furioso", "meditation", 4, seg(
    OR(fx(e("draw_return", n=3)), dsp(fx(e("draw_return", n=5))))), focus=1, instant="rep")
gr299 = blk("5", "0", "1"); gr299["cells"]["4"] = "sa"; gr299["cells"]["2"] = "sa"; gr299["ad"] = True
card(299, "Guardia Furente", "defence", [8, 2],
    seg(gr299, dsp(counter(7, 6, 5))),
    seg(OR(move(step(B, 1)), move(step(FANDN, 1), k=DE)), dsp(fx(e("draw_exact", n=2))), init=1))
card(300, "Colpo in Caduta", "attack", 4,
    seg(atk({"05": "w1", "0": "w1", "1": "w1"}), IFS, fx(e("push", n=1), k=AG)),
    seg(move(step(FANDN, 1)), init=1), instant="rep")
card(301, "Inciampo del Cavallo", "meditation", "=", seg(
    fx(e("t_hobble")), fx(e("t_stun"), f=1), fx(e("t_switch", to="neutral"), f=1)),
    instant="add", when="atk_ok|block_ok")
card(302, "Schivata di Uragano", "defence", 8,
    seg(move(step(ANY, 2)), move(rot(1), k=DE)),
    seg(dsp(move(step(FANDN, 1))), move(rot(1), k=BA), fx(e("switch", to=DE)), init=1), focus=1)
card(303, "Affondo di Montagna", "attack", 6, seg(
    dsp(alt(8)), move(step(B, 1)), move(rot(1, False), k=AG),
    atk({"00": "w1", "0": "w1", "55": "a"}), dsp(ast(e("add_wound", n=2))), fx(e("switch", to=DE))))
card(304, "Colpo alle Caviglie (Onna)", "attack", 3,
    seg(move(step(FANDN, 1, False), rot(1, False)), atk({"00": "w1", "01": "w1"})),
    seg(move(rot(1)), fx(e("draw", n=1)), fx(e("draw", n=2), k=BA), init=2))
card(305, "Mente Strepitante", "meditation", 4, seg(
    move(step(ANY, 1), rot(1)), move(step(ANY, 1), rot(1), k=BA), dsp(move(step(ANY, 1), rot(1))),
    fx(e("view_hand")), dsp(fx(e("draw_exact", n=2))), fx(e("change", n=1), k=DE)))
card(306, "Fiume in Piena", "attack", 6, seg(
    move(rot(1)), atk({"5": "w1", "0": "w1", "1": "w1"}),
    IFS, dsp(fx(e("t_stun"), e("t_hobble"))), move(step(B, 1), k=DE), fx(e("focus", n=1), k=BA)))
card(143, "Calcio Incrociato", "attack", 7, seg(
    alt(4, k=DE), move(step(F, 1)), move(rot(1), k=AG), atk({"0": "w1"}), IFS, fx(e("t_hobble"))), focus=1)

# ───────────── NAVIGATORE ─────────────
RG = "ranged"; FB = [0, 3]
def rng(v, f): return {"t": "rng", "v": v, "f": f}
card(276, "Carta Speciale Navigatore", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("discard", n=2), e("switch", to=RG)), fx(e("change", n=1)))), core=True)
card(277, "Granchio", "attack", 4,
    seg(fx(e("discard", n=1)), move(step(F, 1)), atk({"0": "w1", "1": "w1"})),
    seg(move(step(B, 1), f=1), init=1), core=True, weapon="Granchio")
card(278, "Calcio della Pistola", "attack", 4,
    seg(fx(e("discard", n=1)), move(step(F, 1)), atk({"0": "a", "5": "a"}), ast(e("t_hobble"))),
    seg(move(step(B, 1), rot(1), f=1), init=1), core=True, weapon="Pistola")
card(279, "La Temuta Polvere Nera", "attack", 4, seg(alt(5, f=1), alt(6, f=2), ranged("diff", 6)),
    focus=1, req=RG, range=6)
card(281, "Lancio di Pugnale", "attack", 5, seg(rng(5, 1), ranged("w1", 3)), req=RG, range=3)
card(282, "Squarcio Profondo", "attack", 4, seg(
    move(rot(1)), atk({"0": "w2", "1": "w2"}), IFS, fx(e("draw", n=2), k=BA), fx(e("t_hobble"), k=AG), fx(e("change", n=1))), focus=1)
card(283, "Guardia Alta", "defence", [8, 4],
    seg(OR(move(rot(1)), move(rot(2), f=1)), blk("0", "1")), seg(move(step(FB, 1)), init=2))
card(284, "Reazione dello Sciocco", "meditation", "=", seg(fx(e("counter_now", v2=[8, 7, 6, 5]))),
    focus=2, instant="add", when="block_ok")
card(285, "Affondo di Punta", "attack", 5,
    seg(move(step(F, 1, False), k=AG), g(atk({"00": "w1", "0": "w2"}), k=AG)),
    seg(move(rot(1), k=DE), g(atk({"00": "w1", "0": "w2"}), k=DE), move(step(B, 1, False), k=DE), init=4))
card(286, "Recupero", "meditation", 3, seg(
    move(step(FB, 1)), fx(e("search_discard", rank="Wood", pers="Sailor")),
    fx(e("search_discard", rank="Steel", pers="Sailor"), f=1), fx(e("switch", to="any"))))
card(287, "Colpo Imponente", "attack", 7, seg(
    move(step([5, 1], 1), rot(1), seq=True), atk({"0": "w1"}), g({"t": "mod", "fx": "bleed"}, f=1),
    IFS, fx(e("t_discard", n=1), k=AG), fx(e("t_lose_focus", n=1), k=BA)), focus=1)
card(288, "Spazzata di Granchio", "attack", 6,
    seg(move(step(F, 1, False)), move(step(F, 1), k=AG), atk({"05": "w1", "5": "w1", "0": "w1"})),
    seg(move(step(B, 1)), init=5))
card(289, "Avanzata in Duello", "meditation", 5, seg(
    move(rot(1)), move(step(FB, 2)), fx(e("draw", n=2), k=DE), fx(e("advantage"), k=BA), fx(e("change", n=1))))
card(290, "Guardia del Bue", "defence", [7, 5],
    seg(move(rot(1), k=[BA, DE]), blk("0"), IFS, fx(e("focus", n=1))), seg(move(step(FB, 1)), init=4))
card(141, "Parata Tranquilla", "defence", [5, 2], seg(move(rot(1)), blk("0", "1"), counter(5, 4), counter(3, 2, k=DE)))
card(146, "Guardia Concentrata", "defence", [7, 4],
    seg(move(rot(1)), blk("0", "1")), seg(move(step(FANDN, 1), rot(1)), init=1),
    note="La riga da 2 focus (intervallo d'iniziativa 8-3) non è automatizzata.")
card(157, "Colpo Esperto", "attack", 6, seg(
    OR(move(step([5, 1], 1, False), rot(1, False)), move(step([5, 1], 1), rot(1), f=1)), atk({"0": "w1"})))

# ───────────── ASHIGARU E HACHIKO ─────────────
card(236, "Carta Speciale Ashigaru", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("flip_dog")), fx(e("change", n=1)))), core=True)
card(139, "Impalamento di Yari", "attack", 1, seg(
    fx(e("discard", n=1)), atk({"000": "w1", "0000": "w1"}), move(step(ANY, 1), rot(1), f=1)),
    core=True, weapon="Yari", note="Griglia letta come distanza 3 e 4 in linea retta: lettura da confermare.")
card(237, "Castello del Cielo", "defence", [9, 2],
    seg(blk("5", "0", "1", "4", "2"), IFS, fx(e("t_rot", n=2))),
    seg(move(step(ANY, 1), rot(1)), fx(e("dog_move")), init=1), focus=1)
card(238, "Per il Daimyo", "attack", 7, seg(
    move(step(ANY, 1)), atk({"000": "w2", "00": "w1", "0": "w1"}), IFS, fx(e("push", n=1), k=AG), fx(e("t_hobble"), k=BA)), focus=1)
card(239, "Sole Calante", "meditation", 7, seg(
    move(step(B, 1, False), step(FANDN, 1), seq=True), fx(e("cancel_move")),
    fx(e("draw", n=2), k=BA), fx(e("advantage"), k=DE), fx(e("change", n=1))))
card(240, "Inciampo del Cavallo (Ashigaru)", "meditation", "=", seg(
    fx(e("t_hobble")), fx(e("t_stun"), f=1), fx(e("t_switch", to="neutral"), f=1)),
    instant="add", when="atk_ok|block_ok")
card(241, "Stoccata in Affondo", "attack", 5, seg(
    move(step([5, 1], 1, False)), atk({"00": "w1", "0": "w1"}),
    IFS, fx(e("t_lose_focus", n=1), k=DE), fx(e("t_stun"), k=AG), move(step(B, 1), f=1)))
card(243, "Accerchiamento", "meditation", 3, seg(
    move(step([5, 1], 1, False), rot(1, False)), move(step([5, 1], 1), rot(1))))
card(244, "Fendente Falciante", "attack", 4, seg(
    move(step([5, 1], 1)), atk({"05": "w1", "01": "w1", "0": "w1"}), fx(e("draw", n=2), k=BA)))
card(245, "Infilzata", "attack", 6, seg(move(rot(1)), atk({"00": "w1", "0": "w1"})))
card(101, "Taglio di Finta", "attack", 6, seg(
    move(step([5, 1], 1), k=BA), atk({"0": "w1"}), IFS, fx(e("t_stun"), k=AG), fx(e("advantage"), k=DE), fx(e("switch", to=DE))),
    instant="rep")
card(106, "Volontà di Ferro", "meditation", 7, seg(move(step(ANY, 1)), fx(e("ferro"))), focus=2)

def cane(id, nomeA, initA, righeA, nomeD, initD, righeD, range=None):
    card(id, nomeA, "attack", initA, seg(*righeA))
    card(id + 4000, nomeD, "defence", initD, seg(*righeD), range=range)
    C[str(id)]["fisica"] = id; C[str(id + 4000)]["fisica"] = id
    C[str(id + 4000)]["img_da"] = str(id)
cane(249, "Morso Selvaggio", 7, [move(step([5, 1], 1, False), rot(1, False), seq=True), g(atk({"0": "w2"}), f=1)],
     "Leccarsi le Ferite", 1, [move(step(FANDN, 1)), OR(fx(e("heal"), f=1), fx(e("bleed1_to_wound"), f=1))])
cane(250, "Morso alla Caviglia", 6, [move(step([5, 1], 1), rot(1), seq=True), atk({"0": "a"}), ast(e("t_hobble"))],
     "Ringhio Minaccioso", 7, [move(step([5, 1], 2)), fx(e("cancel_move"))], range=2)
cane(251, "Attacca", 7, [move(step(FANUP, 2), step(FANUP, 1), seq=True), move(rot(1))],
     "Al Piede", 5, [move(step(FANDN, 1), step(FANDN, 1), seq=True), move(step(FANDN, 1))])
cane(252, "Morso Rapido", 7, [move(step(FANDN, 1, False), rot(1), seq=True), atk({"0": "w1"}), fx(e("flip_dog"))],
     "Ululato Feroce", 6, [move(step(FANUP, 1)), OR(fx(e("t_discard", n=1)), fx(e("t_lose_focus", n=1)))], range=2)
cane(253, "Morso alla Gola", 5, [move(rot(1)), atk({"0": "b"})],
     "All'Angolo", 7, [move(step(FANDN, 2)), fx(e("flip_dog"))])
cane(254, "Riporta la Preda", 7, [atk({"0": "a"}), ast(e("drag"))],
     "Bravo Cane", 9, [fx(e("dog_adjacent_focus"))])
cane(256, "Strisciata", 6, [move(step(FANUP, 1)), atk({"0": "w1", "1": "w1"})],
     "In Caccia", 3, [move(step([5, 1], 1, False), rot(1, False)), move(step([5, 1], 1), rot(1))])

# ───────────── NINJA ─────────────
card(163, "Carta Speciale Ninja", "core", 0, seg(
    fx(e("discard", n=1)), move(step(ANY, 1), rot(2)),
    OR(fx(e("draw", n=2)), fx(e("search_prep", pers="Ninja")), fx(e("change", n=1)))), core=True)
card(164, "Colpo di Kusarigama", "attack", 4,
    seg(fx(e("discard", n=1)), OR(g(atk({"000": "w1", "001": "w1"}), f=1), atk({"5": "w1", "0": "w1"}))),
    seg(move(step(ANY, 1)), init=3), core=True, weapon="Kusarigama")
card(166, "Trappola del Tiratore Lunare", "meditation", 4, seg(
    alt(7, f=1), ranged("w1", 99), IFS, fx(e("t_poison"), f=1)), focus=1)
C["166"]["req_o"] = True
card(167, "Cerbottana Fukiya", "attack", 4, seg(ranged("a", 4), IFS, fx(e("t_hobble")), fx(e("t_poison"), f=1)),
    range=4, prepared=True)
card(168, "Soffio di Metsubushi", "attack", 6, seg(
    UNB, atk({"0": "a", "00": "a", "000": "a", "005": "a", "001": "a"}), ast(e("cancel_move")),
    IFS, fx(e("t_stun"), e("t_stun"), k=BA), fx(e("t_stun"), e("t_discard_type", type="defence", n=1), k=AG),
    fx(e("t_stun"), e("t_discard_type", type="attack", n=1), k=DE)), focus=1, prepared=True)
card(169, "Lancio di Shuriken", "attack", 4, seg(alt(6, f=1), ranged("w1", 4)), focus=1, range=4, prepared=True)
card(170, "Lancio di Piedi di Corvo", "meditation", 3, seg(move(step(B, 1)), fx(e("caltrops"))), prepared=True)
card(171, "Catena e Uncino", "defence", 5, seg(
    atk({"000": "a", "005": "a", "00": "a", "05": "a"}), ast(e("pull", n=1)),
    IFS, fx(e("cancel_move")), fx(e("t_rot", n=2), k=BA), occ(fx(e("t_stun")))))
card(172, "Bomba Fumogena (Ninja)", "defence", 7,
    seg(atk({c: "a" for c in "012345"}), ast(e("push", n=1))),
    seg(move(rot(1)), OR(move(step(B, 1, False)), move(step(FANDN, 1, False), k=DE)), fx(e("conceal")), init=6),
    focus=1, prepared=True)
card(173, "Flagello Sferzante", "attack", 6,
    seg(atk({"05": "w1", "00": "w1", "01": "w1", "11": "w1", "12": "w1"})),
    seg(atk({"55": "w1", "45": "w1", "44": "w1", "34": "w1", "33": "w1"}), init=3))
card(174, "Ombra Evanescente", "meditation", "=", seg(move(step(FANDN, 2)), fx(e("conceal"))),
    instant="add", when="atk_ok|block_ok", prepared=True,
    note="Sulla carta dopo un blocco riuscito il movimento è diverso (passo diagonale 1 + rotazione 1): qui è sempre il passo indietro di 2.")
card(175, "Squarcio di Kama", "attack", 5, seg(
    occ(alt(7)), move(rot(2), k=BA), atk({"5": "w1", "0": "w1"}),
    IFS, fx(e("t_wound_to_bleed"), k=AG), fx(e("switch", to="any"), f=1)))
card(176, "Ritirata", "defence", 6, seg(
    move(step(FANDN, 2, False)), move(rot(1), k=BA), fx(e("draw", n=1), k=DE), fx(e("focus", n=1)),
    fx(e("conceal")), fx(e("change", n=1))))

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
    c["en"] = p.get("name", ""); c["rank"] = p.get("rank", "-"); c["pers"] = p.get("char", "")
    c["img"] = imgs.get(c.pop("img_da", k), "")
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
                  ["balance","determination",2]]}},
  "student": {"name": "Allievo", "title": "Impavido come una tigre", "advantage": 62,
     "hand": 5, "wounds": 5, "char_img": imgs["36"], "kamae_img": imgs["37"],
     "portrait": "student.webp", "model": "",
     "deck": {"40":1,"42":1,"43":1,"44":2,"45":2,"46":2,"47":2,"48":3,"49":2,"50":2,"84":1,"90":1,
              "99":2,"100":1,"105":2,"115":1,"117":1,"121":1,"122":1,"124":1},
     "core": [38, 70],
     "kamae": {"nodes": {"aggression":[0.66,0.2],"balance":[0.27,0.47],"focus":[0.66,0.47],
                         "neutral":[0.27,0.78],"determination":[0.66,0.78]},
        "edges": [["aggression","focus",2],["balance","focus",2],["balance","neutral",1],
                  ["neutral","determination",2],["determination","focus",1]]}},
  "master": {"name": "Maestro", "title": "Il vecchio dragone", "advantage": 74,
     "hand": 5, "wounds": 5, "char_img": imgs["6"], "kamae_img": imgs["7"],
     "portrait": "master.webp", "model": "",
     "deck": {"10":1,"12":1,"13":1,"14":2,"15":2,"16":1,"17":1,"18":3,"19":3,"20":3,"96":1,"97":1,
              "102":1,"111":2,"112":2,"117":1,"120":2,"128":2},
     "core": [8, 75],
     "kamae": {"nodes": {"aggression":[0.27,0.2],"determination":[0.73,0.2],"focus":[0.27,0.5],
                         "neutral":[0.27,0.8],"balance":[0.73,0.8]},
        "edges": [["aggression","focus",2],["determination","focus",2],["neutral","focus",2],
                  ["balance","focus",2]]}},
  "assassin": {"name": "Assassino", "title": "Morte dalle ombre", "advantage": 92, "occulta": True,
     "hand": 6, "wounds": 4, "char_img": imgs["214"], "kamae_img": imgs["217"],
     "portrait": "assassin.webp", "model": "",
     "deck": {"220":1,"221":1,"222":1,"223":1,"224":2,"225":2,"226":2,"227":2,"228":2,"229":3,"230":3,
              "103":2,"108":1,"110":2,"117":1,"150":1,"154":2},
     "core": [218, 138],
     "kamae": {"nodes": {"determination":[0.27,0.2],"balance":[0.27,0.5],"aggression":[0.73,0.5],
                         "neutral":[0.27,0.8],"focus":[0.73,0.8]},
        "edges": [["determination","balance",2],["balance","neutral",2],["balance","aggression",2],
                  ["determination","aggression",1],["neutral","focus",2],["aggression","focus",2]]}},
  "monk": {"name": "Monaco", "title": "Il guerriero spirituale", "advantage": 45,
     "hand": 5, "wounds": 5, "char_img": imgs["257"], "kamae_img": imgs["259"],
     "portrait": "monk.webp", "model": "",
     "deck": {"262":1,"263":1,"264":1,"265":1,"266":2,"267":2,"268":2,"269":2,"270":3,"271":3,"272":3,
              "99":1,"140":2,"142":2,"151":2,"121":1,"124":1},
     "core": [260, 133],
     "kamae": {"nodes": {"balance":[0.27,0.2],"aggression":[0.73,0.2],"focus":[0.27,0.5],
                         "determination":[0.73,0.5],"neutral":[0.27,0.8]},
        "edges": [["balance","aggression",2],["balance","focus",2],["aggression","determination",2],
                  ["focus","determination",2],["focus","neutral",2]]}},
  "yasuke": {"name": "Yasuke", "title": "Devota guardia del corpo", "advantage": 78,
     "hand": 5, "wounds": 5, "char_img": imgs["346"], "kamae_img": imgs["348"],
     "portrait": "yasuke.webp", "model": "",
     "deck": {"352":1,"353":1,"354":1,"355":1,"356":2,"357":2,"358":2,"359":2,"360":3,"361":3,"362":3,
              "114":1,"144":2,"145":2,"147":2,"121":2},
     "core": [349, 350, 136],
     "kamae": {"nodes": {"focus":[0.27,0.2],"aggression":[0.73,0.2],"determination":[0.27,0.5],
                         "neutral":[0.27,0.8],"balance":[0.73,0.8]},
        "edges": [["focus","determination",2],["aggression","determination",2],["determination","neutral",2],
                  ["determination","balance",2],["neutral","balance",2]]}},
  "yojimbo": {"name": "Yojimbo", "title": "Lealtà al soldo", "advantage": 39, "contratti": True,
     "hand": 5, "wounds": 5, "char_img": imgs["307"], "kamae_img": imgs["315"],
     "portrait": "yojimbo.webp", "model": "",
     "deck": {"319":1,"320":1,"321":1,"322":1,"323":2,"324":2,"325":2,"326":2,"327":3,"328":3,"329":3,
              "96":1,"98":1,"107":1,"115":1,"154":3,"155":3},
     "core": [316, 317],
     "kamae": {"nodes": {"balance":[0.27,0.2],"aggression":[0.27,0.5],"focus":[0.73,0.5],
                         "neutral":[0.27,0.8],"determination":[0.73,0.8]},
        "edges": [["balance","aggression",2],["balance","focus",1],["aggression","focus",2],
                  ["aggression","neutral",2],["neutral","determination",2],["focus","determination",2]]}},
  "wakou": {"name": "Wakou", "title": "Grosso pirata del mare", "advantage": 8, "ubriaco": True,
     "hand": 4, "wounds": 7, "char_img": imgs["2330"], "kamae_img": imgs["2332"],
     "portrait": "wakou.webp", "model": "",
     "deck": {"334":1,"336":1,"337":1,"338":1,"339":2,"340":2,"341":2,"342":2,"343":3,"344":3,"345":3,
              "86":1,"103":1,"108":2,"152":2,"125":2,"155":2},
     "core": [333, 134],
     "kamae": {"nodes": {"balance":[0.73,0.2],"aggression":[0.27,0.5],"focus":[0.73,0.5],
                         "neutral":[0.27,0.8],"determination":[0.73,0.8]},
        "edges": [["balance","focus",2],["aggression","focus",2],["aggression","neutral",2],
                  ["focus","determination",2]]}},
  "onna": {"name": "Onna-Bugeisha", "title": "Agile guerriera furente", "advantage": 50, "disperazione": True,
     "hand": 5, "wounds": 5, "char_img": imgs["2291"], "kamae_img": imgs["2293"],
     "portrait": "onna_bugeisha.webp", "model": "",
     "deck": {"296":1,"297":1,"298":1,"299":1,"300":2,"301":2,"302":2,"303":2,"304":3,"305":3,"306":3,
              "118":1,"143":2,"145":2,"151":2,"152":2},
     "core": [294, 137],
     "kamae": {"nodes": {"focus":[0.27,0.2],"aggression":[0.73,0.2],"determination":[0.27,0.5],
                         "balance":[0.73,0.5],"neutral":[0.27,0.8]},
        "edges": [["focus","aggression",1],["determination","focus",1],["aggression","balance",2],
                  ["determination","balance",2],["determination","neutral",2]]}},
  "sailor": {"name": "Navigatore", "title": "Avventuriero dall'Occidente", "advantage": 6,
     "hand": 5, "wounds": 5, "char_img": imgs["2273"], "kamae_img": imgs["2275"],
     "portrait": "sailor.webp", "model": "",
     "deck": {"279":1,"281":1,"282":1,"283":1,"284":2,"285":2,"286":2,"287":2,"288":3,"289":3,"290":3,
              "100":1,"111":1,"141":2,"146":2,"157":3},
     "core": [276, 277, 278],
     "kamae": {"nodes": {"ranged":[0.27,0.2],"aggression":[0.73,0.2],"focus":[0.27,0.5],
                         "balance":[0.73,0.5],"neutral":[0.27,0.8],"determination":[0.73,0.8]},
        "edges": [["ranged","aggression",2],["aggression","balance",2],["focus","balance",2],
                  ["balance","determination",2],["neutral","determination",2]]}},
  "ashigaru": {"name": "Ashigaru", "title": "Leale fino alla fine", "advantage": 14,
     "hand": 5, "wounds": 4, "char_img": imgs["2231"], "kamae_img": imgs["2235"],
     "portrait": "ashigaru.webp", "model": "",
     "compagno": {"name": "Hachiko", "wounds": 2, "sprite": "res://assets/cards/hachiko/hachiko_01.webp",
                  "deck": {"249":1,"250":1,"251":1,"252":1,"253":1,"254":3,"256":2}},
     "deck": {"237":1,"238":1,"239":1,"240":2,"241":2,"243":3,"244":3,"245":3,"101":1,"102":1,"106":1,
              "107":2,"118":2,"121":2,"123":2,"124":1,"125":2},
     "core": [236, 139],
     "kamae": {"nodes": {"focus":[0.73,0.2],"determination":[0.27,0.5],"aggression":[0.73,0.5],
                         "neutral":[0.27,0.8],"balance":[0.73,0.8]},
        "edges": [["aggression","focus",1],["focus","determination",1],["determination","aggression",2],
                  ["neutral","determination",2],["neutral","balance",2],["aggression","balance",2]]}},
  "ninja": {"name": "Ninja", "title": "Fantasma nella notte", "advantage": 95, "occulta": True,
     "hand": 6, "wounds": 4, "char_img": imgs["2159"], "kamae_img": imgs["2162"],
     "portrait": "ninja.webp", "model": "",
     "deck": {"166":1,"167":1,"168":1,"169":1,"170":1,"171":2,"172":2,"173":2,"174":3,"175":3,"176":3,
              "100":2,"103":1,"105":1,"110":2,"142":2,"147":2},
     "core": [163, 164],
     "kamae": {"nodes": {"focus":[0.73,0.2],"aggression":[0.27,0.5],"balance":[0.73,0.5],
                         "neutral":[0.27,0.8],"determination":[0.73,0.8]},
        "edges": [["focus","balance",2],["aggression","balance",2],["aggression","neutral",1],
                  ["balance","determination",2],["neutral","determination",2]]}}},
 "solo": SOLO,
 # mappa "villaggio in fiamme": celle giocabili (colonna,riga) lette dal contorno arancione
 "maps": {"villaggio": {"img": "arena.webp", "img_size": 1594,
     "hex_px": 108.68, "origin_px": [304.3, 682.5],
     "cells": [[0,0],[1,0],[1,1],[2,-1],[2,0],[2,1],[2,2],[3,-2],[3,-1],[3,0],[3,1],
               [4,-1],[4,0],[4,1],[4,2],[5,-1],[5,0],[6,-1],[6,0]],
     "start": [[[0,0],[1,0],[1,1]], [[5,-1],[5,0],[6,-1],[6,0]]]}}
}
for ch in out["characters"].values():
    assert sum(ch["deck"].values()) in (29, 30, 31), sum(ch["deck"].values())
    for k in list(ch["deck"]) + [str(x) for x in ch["core"]]: assert k in C, k
json.dump(out, open(os.path.join(here, "../data/carte.json"), "w"), ensure_ascii=False, indent=1)
print("carte:", len(C))
