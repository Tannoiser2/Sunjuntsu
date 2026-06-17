#!/usr/bin/env python3
"""Ritaglia le singole carte dai PDF di Senjutsu (griglia 3x3 per pagina).

Sorgenti (repo Tabelle_Materiali):
    Senjutsu/CARTE/Guerriero.pdf  -> assets/cards/warrior/
    Senjutsu/CARTE/Ronin .pdf     -> assets/cards/ronin/
    Senjutsu/CARTE/Ferite.pdf     -> assets/cards/ferite/

Le carte sono in una griglia regolare 3x3; le celle quasi vuote (ultima pagina)
vengono saltate automaticamente. Produce anche assets/cards/cards_manifest.json.

Uso:
    pip install pymupdf pillow numpy
    python3 tools/extract_card_images.py
"""
import io
import json
import os

import fitz  # PyMuPDF
import numpy as np
from PIL import Image

HERE = os.path.dirname(__file__)
SRC = os.environ.get("SENJUTSU_DIR", os.path.join(HERE, "..", "..", "..", "Tabelle_Materiali", "Senjutsu"))
OUT = os.path.join(HERE, "..", "assets", "cards")

# Griglia calibrata a 150 dpi; scalata al dpi scelto.
BASE_DPI = 150
CW, CH, OX, OY = 386, 538, 2, 2
DPI = 180
FMT = os.environ.get("CARD_FMT", "webp")  # webp (leggero) | png
WEBP_Q = 80
BLANK_STD = 10.0  # sotto questa deviazione standard la cella è considerata vuota

DECKS = [
    ("warrior", "CARTE/Guerriero.pdf"),
    ("ronin", "CARTE/Ronin .pdf"),
    ("ferite", "CARTE/Ferite.pdf"),
]


def page_image(pdf, page, dpi):
    pix = fitz.open(pdf)[page].get_pixmap(dpi=dpi)
    return Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB")


def main():
    scale = DPI / BASE_DPI
    cw, ch, ox, oy = int(CW * scale), int(CH * scale), int(OX * scale), int(OY * scale)
    manifest = []
    for deck, rel in DECKS:
        pdf = os.path.join(SRC, rel)
        if not os.path.exists(pdf):
            print(f"[skip] manca {pdf}")
            continue
        out_dir = os.path.join(OUT, deck)
        os.makedirs(out_dir, exist_ok=True)
        doc = fitz.open(pdf)
        idx = 0
        for pi in range(len(doc)):
            full = page_image(pdf, pi, DPI)
            for r in range(3):
                for c in range(3):
                    x0, y0 = ox + c * cw, oy + r * ch
                    cell = full.crop((x0, y0, x0 + cw, y0 + ch))
                    if np.asarray(cell.convert("L")).std() < BLANK_STD:
                        continue  # cella vuota
                    idx += 1
                    fname = f"{deck}_{idx:02d}.{FMT}"
                    if FMT == "webp":
                        cell.save(os.path.join(out_dir, fname), "WEBP", quality=WEBP_Q, method=6)
                    else:
                        cell.save(os.path.join(out_dir, fname))
                    manifest.append({
                        "deck": deck, "index": idx, "page": pi,
                        "row": r, "col": c, "file": f"{deck}/{fname}",
                    })
        print(f"{deck}: {idx} carte")
    with open(os.path.join(OUT, "cards_manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"dpi": DPI, "card_px": [cw, ch], "cards": manifest}, f,
                  ensure_ascii=False, indent=1)
    print(f"Totale {len(manifest)} carte -> {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
