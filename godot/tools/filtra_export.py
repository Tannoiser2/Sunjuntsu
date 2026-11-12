#!/usr/bin/env python3
"""Aggiorna export_presets.cfg: esclude dall'esportazione web le immagini di carte non usate dal gioco."""
import glob, json, os, re
qui = os.path.dirname(os.path.abspath(__file__)); base = os.path.join(qui, "..")
d = json.load(open(os.path.join(base, "data/carte.json"), encoding="utf-8"))
usate = {c["img"] for c in d["cards"].values()}
for ch in d["characters"].values():
    usate |= {ch["char_img"], ch["kamae_img"]}
    if "compagno" in ch:
        usate.add(ch["compagno"]["sprite"].replace("res://assets/cards/", ""))
fuori = []
for f in sorted(glob.glob(os.path.join(base, "assets/cards/*/*.webp"))):
    rel = os.path.relpath(f, os.path.join(base, "assets/cards")).replace(os.sep, "/")
    if rel not in usate and not rel.startswith("status/"):
        fuori.append("assets/cards/" + rel)
ex = ",".join(fuori + ["tests/*", "tools/*", "data/cards/*", "data/decks/*"])
p = os.path.join(base, "export_presets.cfg"); s = open(p).read()
s = re.sub(r'exclude_filter=".*"', 'exclude_filter="%s"' % ex, s, count=1)
open(p, "w").write(s)
print("immagini usate:", len(usate), "- escluse:", len(fuori))
