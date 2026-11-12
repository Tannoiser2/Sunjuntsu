#!/usr/bin/env python3
"""Controlla che ogni carattere usato nei testi del gioco esista nei font."""
import glob, json, os, re, sys
from fontTools.ttLib import TTFont
qui = os.path.dirname(os.path.abspath(__file__)); base = os.path.join(qui, "..")
font = {os.path.basename(f): set(TTFont(f).getBestCmap()) for f in glob.glob(os.path.join(base, "assets/fonts/*.ttf"))}
testi = []
for f in glob.glob(os.path.join(base, "scenes/*.gd")) + glob.glob(os.path.join(base, "engine/*.gd")):
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', open(f, encoding="utf-8").read()):
        testi.append((os.path.basename(f), m.group(1)))
d = json.load(open(os.path.join(base, "data/carte.json"), encoding="utf-8"))
for c in d["cards"].values():
    testi.append(("carte.json", c["name"] + c.get("note", "")))
for ch in d["characters"].values():
    testi.append(("carte.json", ch["name"] + ch["title"]))
errori = 0
for nome, cm in font.items():
    mancanti = {}
    for origine, t in testi:
        for ch in t.replace("\\n", " ").replace("\\t", " "):
            if ord(ch) >= 32 and ord(ch) not in cm:
                mancanti.setdefault(ch, origine)
    if mancanti:
        errori += len(mancanti)
        print(f"{nome}: mancano {mancanti}")
print("glifi mancanti:", errori)
sys.exit(1 if errori else 0)
