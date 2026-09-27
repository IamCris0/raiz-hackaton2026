"""Preprocesamiento compartido: entrenamiento (Python) y app (Dart).

IMPORTANTE: `lib/modules/modulo2_deteccion/analizador_escritura.dart`
(recortesDeLetras) replica EXACTAMENTE estos pasos. Si cambias algo aquí,
cámbialo allá también, o el modelo verá en la app algo distinto a lo que
vio al entrenar.

Pasos, sobre una letra ya aislada:
  1. Escala de grises con la tinta CLARA sobre fondo OSCURO (como el dataset).
  2. Recorte ajustado a la tinta (píxeles > UMBRAL_TINTA).
  3. Cuadrado centrado con margen MARGEN * lado, fondo 0.
  4. Reducción a LADO x LADO por promedio de área (no bilineal: con bilineal
     los trazos finos desaparecen al reducir).
  5. float32 en [0, 1].
"""
import numpy as np

LADO = 28
MARGEN = 0.12
UMBRAL_TINTA = 60


def cuadrar(g: np.ndarray) -> np.ndarray | None:
    """g: uint8 2D, tinta clara. Devuelve cuadrado uint8 con margen, o None."""
    ys, xs = np.nonzero(g > UMBRAL_TINTA)
    if len(xs) == 0:
        return None
    g = g[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = g.shape
    lado = max(h, w)
    m = int(round(lado * MARGEN))
    s = lado + 2 * m
    out = np.zeros((s, s), np.uint8)
    y0 = (s - h) // 2
    x0 = (s - w) // 2
    out[y0:y0 + h, x0:x0 + w] = g
    return out


def reducir_area(c: np.ndarray, lado: int = LADO) -> np.ndarray:
    """Promedio de área: cada píxel de salida = media de los píxeles de
    entrada cuyo centro cae en su celda. Si la celda queda vacía (entrada más
    chica que la salida), se usa el vecino más cercano."""
    s = c.shape[0]
    a, b, nn = _rangos(s, lado)
    S = np.zeros((s + 1, s + 1), np.float64)
    S[1:, 1:] = c.astype(np.float64).cumsum(0).cumsum(1)
    ya, yb = a[:, None], b[:, None]
    xa, xb = a[None, :], b[None, :]
    suma = S[yb, xb] - S[ya, xb] - S[yb, xa] + S[ya, xa]
    n = (yb - ya) * (xb - xa)
    out = np.where(n > 0, suma / np.maximum(n, 1), c[nn[:, None], nn[None, :]])
    return out.astype(np.float32)


_cache: dict = {}


def _rangos(s: int, lado: int):
    """Para la celda i: filas [a[i], b[i]) con centro dentro de la celda."""
    k = (s, lado)
    if k not in _cache:
        f = s / lado
        i = np.arange(lado)
        a = np.clip(np.ceil(i * f - 0.5 + 1e-9).astype(int), 0, s)
        b = np.clip(np.ceil((i + 1) * f - 0.5 + 1e-9).astype(int), 0, s)
        nn = np.minimum(((i + 0.5) * f).astype(int), s - 1)
        _cache[k] = (a, b, nn)
    return _cache[k]


def normalizar(g: np.ndarray) -> np.ndarray | None:
    """g: uint8 2D con tinta clara. -> float32 LADO x LADO en [0,1]."""
    c = cuadrar(g)
    if c is None:
        return None
    return reducir_area(c) / 255.0


def a_tinta_clara(g: np.ndarray) -> np.ndarray:
    """El dataset mezcla letra blanca/fondo negro y letra negra/fondo blanco."""
    return 255 - g if g.mean() > 127 else g
