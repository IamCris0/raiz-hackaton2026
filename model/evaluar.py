"""Evalúa el modelo .tflite (el mismo archivo que usa la app).

Uso:
  python model/evaluar.py --datos model/datos --modelo assets/models/letras_invertidas.tflite --fuentes /ruta/fuentes

Tres pruebas:
  1. Test oficial del dataset de Kaggle (sin los grupos ambiguos b/d).
  2. Letra por letra con 5 fuentes manuscritas que el modelo NUNCA vio:
     falsos positivos por letra (b, d, p, q incluidas) y detección de espejos.
  3. Hoja simulada: dictado en español, segmentado igual que en la app
     (componentes conexos + filtro de proporción), con y sin letras en espejo.
"""
import argparse
import os
import random

import numpy as np
import tensorflow as tf
from PIL import Image, ImageDraw, ImageFont, ImageOps
from scipy import ndimage

from preparar_datos import ESPEJO_OK, FUENTES_VALIDACION, TODAS, render_letra
from preproceso import normalizar

UMBRAL = 0.9
DICTADO = [
    "el perro de pablo come pan", "la casa de mi abuela es grande",
    "todos los dias bebo agua fresca", "mi mama me quiere mucho",
    "el sol sale detras del cerro", "juego con mis amigos en el patio",
]


class Modelo:
    def __init__(self, ruta):
        self.i = tf.lite.Interpreter(model_path=ruta)
        self.i.allocate_tensors()
        self.inp = self.i.get_input_details()[0]["index"]
        self.out = self.i.get_output_details()[0]["index"]

    def prob(self, X):
        r = np.empty(len(X), np.float32)
        for k, x in enumerate(X):
            self.i.set_tensor(self.inp, x.reshape(1, 28, 28, 1).astype(np.float32))
            self.i.invoke()
            r[k] = self.i.get_tensor(self.out)[0, 1]
        return r


def hoja(fuente, espejos, rnd, tam=46):
    """Dictado en una hoja blanca; `espejos` = prob. de voltear e/s/z/j/r/c/a."""
    font = ImageFont.truetype(fuente, tam)
    im = Image.new("L", (1000, 120 + len(DICTADO) * tam * 2), 255)
    d = ImageDraw.Draw(im)
    y = 60
    for frase in DICTADO:
        x = 50
        for ch in frase:
            if ch == " ":
                x += int(tam * 0.45); continue
            w = int(d.textlength(ch, font=font))
            if ch in "eszjrca" and rnd.random() < espejos:
                g = Image.new("L", (w + tam, tam * 2), 255)
                ImageDraw.Draw(g).text((tam // 2, 0), ch, fill=0, font=font)
                g = ImageOps.mirror(g)
                im.paste(g, (x - tam // 2, y))
            else:
                d.text((x, y), ch, fill=0, font=font)
            x += w + 3
        y += tam * 2
    return np.asarray(im)


def letras_de_hoja(g):
    """Réplica simplificada de la segmentación de la app (sin renglones de cuaderno)."""
    tinta = g < 128
    lab, n = ndimage.label(tinta, structure=np.ones((3, 3)))
    cajas = ndimage.find_objects(lab)
    altos = [s[0].stop - s[0].start for s in cajas]
    alto_tipico = np.median(altos)
    X = []
    for k, s in enumerate(cajas, start=1):
        h = s[0].stop - s[0].start; w = s[1].stop - s[1].start
        if w / h < 0.3 or w / h > 1.6 or h < alto_tipico * 0.6 or h > alto_tipico * 2.2:
            continue
        mascara = (lab[s] == k).astype(np.uint8) * 255
        X.append(normalizar(mascara))
    return np.stack(X)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--datos", default="model/datos")
    ap.add_argument("--modelo", default="assets/models/letras_invertidas.tflite")
    ap.add_argument("--fuentes", required=True)
    ap.add_argument("--umbral", type=float, default=UMBRAL)
    a = ap.parse_args()
    UMBRAL = a.umbral
    m = Modelo(a.modelo)

    # 1. Test de Kaggle
    d = np.load(os.path.join(a.datos, "kaggle_test.npz"))
    X, y = d["X"].astype(np.float32), d["y"]
    p = m.prob(X)
    pred = (p >= 0.5).astype(int)
    cm = np.zeros((2, 2), int)
    for t, q in zip(y, pred):
        cm[t, q] += 1
    print(f"\n1) Test Kaggle ({len(y)} letras): accuracy {np.mean(pred == y):.3f}")
    print("   matriz de confusión (filas = real, columnas = predicho) [normal, invertida]")
    print("  ", cm.tolist())
    alta = p >= UMBRAL
    print(f"   con umbral {UMBRAL}: precisión {np.mean(y[alta] == 1):.3f}, "
          f"detecta {np.mean(alta[y == 1]):.3f} de las invertidas, "
          f"falsas alarmas {np.mean(alta[y == 0]):.3f} de las normales")

    # 2. Fuentes nunca vistas, letra por letra
    fuentes = [os.path.join(a.fuentes, f) for f in sorted(FUENTES_VALIDACION)]
    rnd = random.Random(7)
    fp = {}
    for ch in TODAS:
        Xc = [render_letra(f, ch, False, rnd) for f in fuentes for _ in range(6)]
        fp[ch] = float(np.mean(m.prob(np.stack([x for x in Xc if x is not None])) >= UMBRAL))
    tp = {}
    for ch in ESPEJO_OK:
        Xc = [render_letra(f, ch, True, rnd) for f in fuentes for _ in range(6)]
        tp[ch] = float(np.mean(m.prob(np.stack([x for x in Xc if x is not None])) >= UMBRAL))
    print(f"\n2) Fuentes nuevas: falsas alarmas promedio {np.mean(list(fp.values())):.3f}; "
          f"detección de espejos promedio {np.mean(list(tp.values())):.3f}")
    peores = sorted(fp.items(), key=lambda kv: -kv[1])[:8]
    print("   letras normales más confundidas:", ", ".join(f"{k}={v:.2f}" for k, v in peores))
    print("   b/d/p/q normales:", ", ".join(f"{k}={fp[k]:.2f}" for k in "bdpq"))
    peores = sorted(tp.items(), key=lambda kv: kv[1])[:8]
    print("   espejos menos detectados:", ", ".join(f"{k}={v:.2f}" for k, v in peores))

    # 3. Hoja simulada
    print("\n3) Hoja de dictado simulada (% de letras marcadas como invertidas):")
    for f in fuentes:
        fila = []
        for esp in (0.0, 0.3, 0.6):
            Xh = letras_de_hoja(hoja(f, esp, random.Random(3)))
            fila.append(f"espejos {int(esp*100):>2}% de e/s/z/j/r/c/a -> {np.mean(m.prob(Xh) >= UMBRAL)*100:5.1f}% ({len(Xh)} letras)")
        print("  ", os.path.basename(f)[:22].ljust(22), " | ".join(fila))
