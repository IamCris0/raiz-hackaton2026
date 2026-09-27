"""Entrena el clasificador normal / invertida y lo exporta a TFLite.

Uso:
  python model/entrenar.py --datos model/datos --salida assets/models

REGLA DE ORO: nada de volteo horizontal (flip) en el aumento de datos. Voltear
una letra la convierte justo en lo que queremos detectar.
"""
import argparse
import json
import os

import numpy as np
import tensorflow as tf

LADO = 28
ETIQUETAS = ["normal", "invertida"]


def modelo():
    x = inp = tf.keras.Input((LADO, LADO, 1))
    for f in (32, 64):
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.BatchNormalization()(x)
        x = tf.keras.layers.Conv2D(f, 3, padding="same", activation="relu")(x)
        x = tf.keras.layers.MaxPooling2D()(x)
        x = tf.keras.layers.Dropout(0.2)(x)
    x = tf.keras.layers.Conv2D(128, 3, padding="same", activation="relu")(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dense(128, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    out = tf.keras.layers.Dense(len(ETIQUETAS), activation="softmax")(x)
    return tf.keras.Model(inp, out)


_rot = tf.keras.layers.RandomRotation(0.035, fill_mode="constant")  # ±12°
_zoom = tf.keras.layers.RandomZoom((-0.12, 0.12), fill_mode="constant")
_mov = tf.keras.layers.RandomTranslation(0.06, 0.06, fill_mode="constant")


def aumentar(x, y):
    """Rotación y escala pequeñas, desplazamiento, grosor de trazo y
    binarización (la app trabaja con tinta binarizada). SIN flip."""
    x = _mov(_zoom(_rot(x, training=True), training=True), training=True)
    r = tf.random.uniform([])
    x = tf.cond(r < 0.25, lambda: tf.nn.max_pool2d(x, 2, 1, "SAME"),                 # trazo más grueso
                lambda: tf.cond(r < 0.40, lambda: -tf.nn.max_pool2d(-x, 2, 1, "SAME"),  # más fino
                                lambda: x))
    x = tf.cond(tf.random.uniform([]) < 0.5, lambda: tf.cast(x > 0.35, tf.float32), lambda: x)
    return x, y


def cargar(ruta):
    d = np.load(ruta)
    return d["X"].astype(np.float32)[..., None], d["y"].astype(np.int32)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--datos", default="model/datos")
    ap.add_argument("--salida", default="assets/models")
    ap.add_argument("--epocas", type=int, default=8)
    a = ap.parse_args()
    tf.random.set_seed(0)
    np.random.seed(0)

    Xk, yk = cargar(os.path.join(a.datos, "kaggle_train.npz"))
    Xs, ys = cargar(os.path.join(a.datos, "sinteticas.npz"))
    X = np.concatenate([Xk, Xs]); y = np.concatenate([yk, ys])
    p = np.random.permutation(len(X)); X, y = X[p], y[p]
    nval = 8000
    Xv, yv, X, y = X[:nval], y[:nval], X[nval:], y[nval:]

    conteo = np.bincount(y)
    pesos = {i: len(y) / (len(conteo) * c) for i, c in enumerate(conteo)}
    print("entrenamiento", X.shape, conteo, "pesos", pesos)

    ds = (tf.data.Dataset.from_tensor_slices((X, y)).shuffle(20000).batch(256)
          .map(aumentar, num_parallel_calls=tf.data.AUTOTUNE).prefetch(2))
    m = modelo()
    m.compile(tf.keras.optimizers.Adam(1e-3), "sparse_categorical_crossentropy", metrics=["accuracy"])
    m.fit(ds, validation_data=(Xv, yv), epochs=a.epocas, class_weight=pesos,
          callbacks=[tf.keras.callbacks.ReduceLROnPlateau(patience=1, factor=0.5, verbose=1)], verbose=2)

    os.makedirs(a.salida, exist_ok=True)
    m.save(os.path.join(a.datos, "letras_invertidas.keras"))

    # Sin cuantizar a propósito: pesa ~600 KB (nada para una app) y usa solo
    # operaciones float básicas, compatibles con el runtime que trae
    # tflite_flutter. La versión cuantizada daba la misma accuracy.
    tfl = tf.lite.TFLiteConverter.from_keras_model(m).convert()
    with open(os.path.join(a.salida, "letras_invertidas.tflite"), "wb") as f:
        f.write(tfl)
    with open(os.path.join(a.salida, "letras_invertidas_labels.txt"), "w") as f:
        f.write("\n".join(ETIQUETAS) + "\n")
    print("tflite", len(tfl) // 1024, "KB")
