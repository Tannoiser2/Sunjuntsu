#!/usr/bin/env python3
"""Prova completa: finto Firebase + tavolo Godot (xvfb) + due telefoni (Chrome headless con la pagina vera)."""
import os, re, subprocess, sys, time, random
from playwright.sync_api import sync_playwright
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/tel_out"
os.makedirs(OUT, exist_ok=True)
env = dict(os.environ, FR_DB_URL="http://127.0.0.1:8765/db", FR_AUTH_URL="http://127.0.0.1:8765/signup",
           FR_REFRESH_URL="http://127.0.0.1:8765/refresh", TELEFONO_DIR="/tmp/tel")
mock = subprocess.Popen([sys.executable, "tests/firebase_mock.py", "8765"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1)
tv = subprocess.Popen(["xvfb-run", "-a", "-s", "-screen 0 1280x800x24", "godot", "--path", ".", "--rendering-driver", "opengl3",
                       "--resolution", "1280x800", "res://tests/TelefoniProva.tscn", "--", "out=" + OUT],
                      env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
codice = None
righe = []
while codice is None:
    l = tv.stdout.readline()
    if not l:
        break
    righe.append(l)
    m = re.search(r"CODICE (\w{4})", l)
    if m:
        codice = m.group(1)
print("codice", codice, flush=True)
random.seed(3)
with sync_playwright() as pw:
    br = pw.chromium.launch(executable_path="/usr/bin/google-chrome", args=["--no-sandbox"])
    pagine = []
    for g, nome in [(1, "Anna"), (2, "Bruno")]:
        ctx = br.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=2)
        pg = ctx.new_page()
        pg.on("console", lambda m, g=g: print("tel%d console:" % g, m.text) if m.type == "error" else None)
        pg.on("pageerror", lambda e, g=g: print("tel%d ERRORE:" % g, e))
        pg.goto("http://127.0.0.1:8765/telefono/?c=%s&g=%d&frdb=http://127.0.0.1:8765/db" % (codice, g))
        pg.fill("#nome", nome)
        pg.click("#b-entra")
        pagine.append(pg)
    fatte = set()
    fine = time.time() + float(os.environ.get("DURATA", "150"))
    risposte = 0
    import threading
    def leggi():
        for l in tv.stdout:
            righe.append(l)
    threading.Thread(target=leggi, daemon=True).start()
    while time.time() < fine and tv.poll() is None:
        for i, pg in enumerate(pagine):
            try:
                k = pg.evaluate("rich ? rich.k : ''")
            except Exception as e:
                continue
            if k:
                if k not in fatte:
                    fatte.add(k)
                    pg.screenshot(path="%s/tel%d_%s.png" % (OUT, i + 1, k))
                if k in ("move", "place"):
                    # provo una casella e una rotazione, come farebbe un giocatore
                    pg.evaluate("(() => { const ks = Object.keys(celleOpz); selCella = ks[ks.length - 1]; ordina(selCella); selK = 0; mostraRuota(); if (celleOpz[selCella].length > 1) { selK = 1; mostraRuota(); } })()")
                    time.sleep(2.0)
                    pg.screenshot(path="%s/tel%d_prova_%s.png" % (OUT, i + 1, k))
                n = pg.evaluate("rich.o.length")
                pg.evaluate("rispondi(%d)" % random.randrange(n))
                risposte += 1
        time.sleep(0.4)
    pagine[0].screenshot(path="%s/tel1_fine.png" % OUT)
    pagine[1].screenshot(path="%s/tel2_fine.png" % OUT)
    print("risposte dai telefoni:", risposte, "tipi:", sorted(fatte), flush=True)
    br.close()
tv.terminate()
tv.wait(timeout=30)
mock.terminate()
print("".join(l for l in righe if re.search(r"FINE|SCRIPT ERROR|ERROR|schermata|CODICE|TURNO|ANTEPRIMA", l))[:3000])
