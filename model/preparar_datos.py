"""Convierte el dataset de Kaggle + letras sintéticas en arrays .npz.

Uso:
  python model/preparar_datos.py --dataset /ruta/Gambo --fuentes /ruta/fuentes --salida model/datos

Decisiones (ver model/README.md):
  * 2 clases: 0 = normal, 1 = invertida.
  * "Corrected" se une a normal: son letras bien formadas de niños (Penang);
    separarlas enseñaría al modelo a reconocer el ESTILO de escritura, no la
    corrección.
  * Se descartan los grupos ambiguos b/d/p/q de la clase invertida: una "b"
    en espejo es una "d" correcta, y letra por letra no se puede distinguir.
  * Se agregan letras sintéticas con fuentes tipo manuscrito: normales (todas,
    incluidas b, d, p, q) e invertidas (solo letras cuyo espejo no es otra letra).
"""
import argparse
import os
import random
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps
from scipy import ndimage

from preproceso import a_tinta_clara, normalizar

# Espejo que NO forma otra letra válida (sin b/d/p/q minúsculas ni simétricas).
ESPEJO_OK = list("acefghjkrsyzCDEFGJKLNPRSZ") + ["ñ"]
TODAS = list("abcdefghijklmnopqrstuvwxyzñABCDEFGHIJKLMNOPQRSTUVWXYZÑ")
FUENTES_VALIDACION = {"PatrickHand-Regular.ttf", "Kalam-Regular.ttf", "Andika-Regular.ttf",
                      "Schoolbell-Regular.ttf", "Mali-Regular.ttf"}


def _cargar(ruta):
    try:
        g = np.asarray(Image.open(ruta).convert("L"))
    except Exception:
        return None
    return normalizar(a_tinta_clara(g))


def _descartar(clase: str, nombre: str) -> bool:
    if clase == "Reversal":
        # b_ = "b" en espejo (se ve como "d"), d_ = "d" en espejo (se ve como "b").
        # "b-", "d-", "p-", "q-" son MAYÚSCULAS en espejo: no son ambiguas, se quedan.
        return nombre.startswith(("b_", "d_"))
    return False


def cargar_kaggle(raiz, split):
    rutas, etiquetas = [], []
    for clase, y in (("Normal", 0), ("Corrected", 0), ("Reversal", 1)):
        d = os.path.join(raiz, split, clase)
        for f in os.listdir(d):
            if _descartar(clase, f):
                continue
            rutas.append(os.path.join(d, f))
            etiquetas.append(y)
    with Pool(2) as p:
        X = p.map(_cargar, rutas, chunksize=512)
    keep = [i for i, x in enumerate(X) if x is not None]
    return np.stack([X[i] for i in keep]).astype(np.float16), np.array([etiquetas[i] for i in keep], np.uint8)


# Frecuencia aproximada de letras en español: las más comunes (e, a, o, s, n)
# son las que más falsas alarmas podrían generar en un dictado real.
FRECUENCIA_ES = {
    "e": 13.7, "a": 12.5, "o": 8.7, "s": 8.0, "r": 6.9, "n": 6.7, "i": 6.3, "d": 5.9,
    "l": 5.0, "c": 4.7, "t": 4.6, "u": 3.9, "m": 3.2, "p": 2.5, "b": 1.4, "g": 1.0,
    "v": 0.9, "y": 0.9, "q": 0.9, "h": 0.7, "f": 0.7, "z": 0.5, "j": 0.4, "ñ": 0.3,
    "x": 0.2, "k": 0.1, "w": 0.1,
}


def _mayor_componente(tinta):
    lab, n = ndimage.label(tinta, structure=np.ones((3, 3)))
    if n == 0:
        return None
    tam = ndimage.sum(tinta, lab, range(1, n + 1))
    return (lab == int(np.argmax(tam)) + 1).astype(np.uint8) * 255


def render_letra(fuente, letra, espejo, rnd):
    """Letra de una fuente manuscrita. La mayoría de las veces se procesa
    como en la app: binarizada y quedándose con el trazo principal (el
    punto de la i o la tilde de la ñ son trazos aparte)."""
    tam = rnd.randint(24, 80)
    font = ImageFont.truetype(fuente, tam)
    im = Image.new("L", (tam * 3, tam * 3), 0)
    ImageDraw.Draw(im).text((tam, tam // 2), letra, fill=255, font=font,
                            stroke_width=rnd.choice([0, 0, 0, 1, 1, 2]) if tam > 40 else 0, stroke_fill=255)
    if espejo:
        im = ImageOps.mirror(im)  # espejo de la LETRA (esto sí es la clase invertida)
    im = im.rotate(rnd.uniform(-10, 10), resample=Image.BILINEAR)
    g = np.asarray(im)
    if rnd.random() < 0.7:
        g = _mayor_componente(g > 128)
        if g is None:
            return None
    return normalizar(g)


def _letra_normal(rnd):
    if rnd.random() < 0.65:
        letras, pesos = zip(*FRECUENCIA_ES.items())
        return rnd.choices(letras, pesos)[0]
    return rnd.choice(TODAS)


def sinteticas(fuentes, n_por_fuente, semilla):
    rnd = random.Random(semilla)
    X, y = [], []
    for f in fuentes:
        for _ in range(n_por_fuente):
            if rnd.random() < 0.55:
                x = render_letra(f, _letra_normal(rnd), False, rnd); lab = 0
            else:
                x = render_letra(f, rnd.choice(ESPEJO_OK), True, rnd); lab = 1
            if x is not None:
                X.append(x); y.append(lab)
    return np.stack(X).astype(np.float16), np.array(y, np.uint8)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", required=True)
    ap.add_argument("--fuentes", required=True)
    ap.add_argument("--salida", default="model/datos")
    ap.add_argument("--rehacer-kaggle", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.salida, exist_ok=True)

    fuentes = sorted(os.path.join(a.fuentes, f) for f in os.listdir(a.fuentes) if f.endswith(".ttf"))
    f_ent = [f for f in fuentes if os.path.basename(f) not in FUENTES_VALIDACION]
    f_val = [f for f in fuentes if os.path.basename(f) in FUENTES_VALIDACION]
    print("fuentes entrenamiento:", len(f_ent), "validación:", len(f_val))

    Xs, ys = sinteticas(f_ent, 5000, 1)
    np.savez_compressed(os.path.join(a.salida, "sinteticas.npz"), X=Xs, y=ys)
    print("sintéticas", Xs.shape, np.bincount(ys))

    if os.path.exists(os.path.join(a.salida, "kaggle_test.npz")) and not a.rehacer_kaggle:
        raise SystemExit("Kaggle ya preparado (usa --rehacer-kaggle para rehacerlo).")
    for split in ("Train", "Test"):
        X, y = cargar_kaggle(a.dataset, split)
        np.savez_compressed(os.path.join(a.salida, f"kaggle_{split.lower()}.npz"), X=X, y=y)
        print(split, X.shape, np.bincount(y))
