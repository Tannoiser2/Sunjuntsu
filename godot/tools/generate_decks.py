#!/usr/bin/env python3
"""Genera data/decks/*.json dalle liste mazzo autorevoli dell'Excel.

Sorgente: Senjutsu_Deckbuilding_1.1.xlsx, foglio "Custom Decks" — contiene per
ogni guerriero la lista esatta delle carte (Card ID, copie e statistiche).
Questa è la fonte autorevole per la composizione dei mazzi (a differenza della
lettura del numero stampato sulle immagini, che è inaffidabile).

Uso:
    pip install openpyxl
    python3 tools/generate_decks.py [PATH_XLSX]
"""
import json
import os
import re
import sys

import openpyxl

HERE = os.path.dirname(__file__)
DEFAULT_XLSX = os.environ.get(
    "SENJUTSU_XLSX",
    os.path.join(HERE, "..", "..", "..", "Tabelle_Materiali", "Senjutsu",
                 "Tabelle", "Senjutsu_Deckbuilding_1.1.xlsx"),
)
OUT = os.path.join(HERE, "..", "data", "decks")


def card_type(keywords):
    low = keywords.lower()
    for t in ("attack", "defence", "meditation", "core"):
        if t in low:
            return t
    return "other"


def main():
    xlsx = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_XLSX
    ws = openpyxl.load_workbook(xlsx, data_only=True)["Custom Decks"]
    rows = list(ws.iter_rows(values_only=True))[1:]

    decks = {}
    for r in rows:
        deck, amt, name, cid, rank, typ, kw, init, foc = (list(r) + [None] * 9)[:9]
        if not isinstance(cid, int) or deck in (None, "", "None"):
            continue
        kws = [k.strip() for k in str(kw or "").split(",") if k.strip()]
        decks.setdefault(deck, []).append({
            "id": cid,
            "amount": int(amt) if isinstance(amt, int) else 1,
            "name": str(name).strip() if name else "",
            "rank": str(rank).strip() if rank else "-",
            "type": card_type(str(kw or "")),
            "keywords": kws,
            "initiative": "" if init in (None, "") else str(init).strip(),
            "focus": foc if isinstance(foc, int) else 0,
        })

    os.makedirs(OUT, exist_ok=True)
    index = []
    for deck, cards in decks.items():
        total = sum(c["amount"] for c in cards)
        slug = re.sub(r"[^a-z0-9]+", "_", deck.lower()).strip("_")
        with open(os.path.join(OUT, slug + ".json"), "w", encoding="utf-8") as f:
            json.dump({"deck": deck, "total": total,
                       "source": "Custom Decks (Senjutsu_Deckbuilding_1.1.xlsx)",
                       "cards": cards}, f, ensure_ascii=False, indent=1)
        index.append({"deck": deck, "slug": slug, "unique": len(cards), "total": total})
    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as f:
        json.dump({"decks": index}, f, ensure_ascii=False, indent=1)
    print(f"Generati {len(decks)} mazzi -> {os.path.normpath(OUT)}")
    for d in index:
        print(f"  {d['deck']}: {d['unique']} uniche, {d['total']} totali")


if __name__ == "__main__":
    main()
