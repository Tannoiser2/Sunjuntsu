#!/usr/bin/env python3
"""Collega le immagini ritagliate ai dati di card_pool.json.

Il numero stampato sulla carta == Card ID del pool. Questo script unisce la
mappatura file->id (prodotta via OCR, /tmp/ocr_map.json o tools/ocr_map.json)
ai dati del pool e arricchisce assets/cards/cards_manifest.json con:
    card_id, name, char, type, rank, initiative, focus, keywords

Le carte non riconosciute restano con card_id=null (l'HUD mostra comunque
l'immagine; i dati si potranno completare a mano).
"""
import json
import os

HERE = os.path.dirname(__file__)
POOL = os.path.join(HERE, "..", "data", "cards", "card_pool.json")
MANIFEST = os.path.join(HERE, "..", "assets", "cards", "cards_manifest.json")
OCR_CANDIDATES = [os.path.join(HERE, "ocr_map.json"), "/tmp/ocr_map.json"]

FIELDS = ("name", "char", "type", "rank", "initiative", "focus", "keywords")


def main():
    pool = {int(c["id"]): c for c in json.load(open(POOL))["cards"]}
    ocr_path = next((p for p in OCR_CANDIDATES if os.path.exists(p)), None)
    ocr = json.load(open(ocr_path)) if ocr_path else {}

    man = json.load(open(MANIFEST))
    matched = 0
    for entry in man["cards"]:
        cid = ocr.get(entry["file"])
        entry["card_id"] = cid
        if cid in pool:
            matched += 1
            for f in FIELDS:
                entry[f] = pool[cid].get(f)
    man["linked"] = matched
    json.dump(man, open(MANIFEST, "w"), ensure_ascii=False, indent=1)
    print(f"Collegate {matched}/{len(man['cards'])} carte ai dati del pool")


if __name__ == "__main__":
    main()
