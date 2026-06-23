#!/usr/bin/env python3
"""Genera data/cards/card_pool.json dall'Excel di deckbuilding di Senjutsu.

Sorgente attesa (repo Tabelle_Materiali):
    Senjutsu/Tabelle/Senjutsu_Deckbuilding_1.1.xlsx  (foglio "Card Pool")

Uso:
    pip install openpyxl
    python3 tools/generate_cards.py [PATH_XLSX]
"""
import json
import os
import sys

import openpyxl

DEFAULT_XLSX = os.environ.get(
    "SENJUTSU_XLSX",
    "../../Tabelle_Materiali/Senjutsu/Tabelle/Senjutsu_Deckbuilding_1.1.xlsx",
)
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "cards", "card_pool.json")
NAMES_IT = os.path.join(os.path.dirname(__file__), "..", "data", "cards", "names_it.json")


def load_names_it():
    """id (str) -> nome italiano. Sovrascrive i nomi EN dell'Excel quando disponibili."""
    if not os.path.exists(NAMES_IT):
        return {}
    return json.load(open(NAMES_IT, encoding="utf-8")).get("by_id", {})


def kw_list(s):
    if not s:
        return []
    return [k.strip() for k in str(s).split(",") if k.strip()]


def card_type(kws):
    low = [k.lower() for k in kws]
    for t in ("attack", "defence", "meditation", "core"):
        if any(t in k for k in low):
            return t
    return "other"


def main():
    xlsx = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_XLSX
    wb = openpyxl.load_workbook(xlsx, data_only=True)
    ws = wb["Card Pool"]
    rows = list(ws.iter_rows(values_only=True))[1:]

    names_it = load_names_it()
    cards = []
    for r in rows:
        cid, name, char, amt = r[0], r[1], r[2], r[3]
        rank, init, foc, kw = r[6], r[7], r[8], r[9]
        if cid is None or name is None:
            continue
        kws = kw_list(kw)
        # Nome italiano (dalle carte stampate IT) quando disponibile, altrimenti EN.
        it_name = names_it.get(str(cid))
        cards.append({
            "id": cid,
            "name": it_name if it_name else str(name).strip(),
            "char": str(char).strip() if char else "?",
            "amount": amt if isinstance(amt, int) else 1,
            "rank": str(rank).strip() if rank not in (None, "") else "-",
            "initiative": "" if init in (None, "") else str(init).strip(),
            "focus": foc if isinstance(foc, int) else 0,
            "keywords": kws,
            "type": card_type(kws),
        })

    # Preserva le carte NON presenti nell'Excel (es. carte Solo, ids 9xx) che
    # erano state aggiunte a card_pool.json da altre fonti: il foglio "Card Pool"
    # non le contiene e rigenerare le cancellerebbe.
    gen_ids = {c["id"] for c in cards}
    if os.path.exists(OUT):
        try:
            prev = json.load(open(OUT, encoding="utf-8")).get("cards", [])
            extra = [c for c in prev if c.get("id") not in gen_ids]
            if extra:
                cards.extend(extra)
                print(f"Preservate {len(extra)} carte non nell'Excel (es. Solo).")
        except (ValueError, OSError):
            pass

    pool = {
        "source": "Generato da Senjutsu_Deckbuilding_1.1.xlsx (foglio 'Card Pool'); "
                  "nomi IT da names_it.json; carte non-Excel (Solo) preservate.",
        "ranks": ["Wood", "Steel", "Gold", "Jade"],
        "count": len(cards),
        "characters": sorted({c["char"] for c in cards}),
        "cards": cards,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(pool, f, ensure_ascii=False, indent=1)
    print(f"Scritte {len(cards)} carte -> {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
