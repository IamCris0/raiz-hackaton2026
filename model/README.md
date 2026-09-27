# Modelo: letras en espejo (señal de dislexia)

Clasificador **normal / invertida** para cada letra suelta. Lo usa
`lib/modules/modulo2_deteccion/clasificador_letras.dart` sobre los recortes
que produce `AnalizadorEscritura`. Corre 100% en el celular (TFLite).

Archivos que usa la app:

- `assets/models/letras_invertidas.tflite`: CNN pequeña, entrada 28×28×1 en
  [0, 1] (tinta clara sobre fondo oscuro) y salida `[p_normal, p_invertida]`.
- `assets/models/letras_invertidas_labels.txt`: orden de las clases.

## Datos

**Dyslexia Handwriting Dataset** (Kaggle, *drizasazanitaisa*): letras NIST y
muestras de niños de Penang (Malasia), en 3 clases: `Normal`, `Reversal` y
`Corrected`. ⚠️ Antes de publicar, revisa la licencia en la página de Kaggle
y cítalo en la entrega. **El dataset no se sube al repo.** Viene en un `.rar`
con contraseña (está en el nombre del archivo); necesita un extractor con
soporte RAR5 (7-Zip 24+).

Decisiones al prepararlo (`preparar_datos.py`):

| Decisión | Por qué |
|---|---|
| 2 clases: `Corrected` se une a *normal* | Las imágenes de `Corrected` son letras bien formadas de niños de otra fuente. Como clase aparte, el modelo aprendería el *estilo* de escritura, no la corrección. |
| Se descartan `b_` y `d_` de *Reversal* | Una "b" en espejo **es** una "d" correcta. Letra por letra no se puede saber qué quiso escribir el niño: para eso hay que leer la palabra. |
| Letras sintéticas con 14 fuentes manuscritas | Agregan b, d, p, q, ñ y minúsculas **correctas** como *normal*, y espejos de letras que no forman otra letra (e, s, z, j, r, c, a…) como *invertida*. |
| Polaridad y recorte normalizados | El dataset mezcla letra blanca y negra. Todo pasa a tinta clara, se recorta ajustado, se centra en un cuadrado con 12 % de margen y se reduce por promedio de área. |
| **Sin flip** en el aumento de datos | Voltear convierte una letra normal en invertida. |

`preproceso.py` y `AnalizadorEscritura.normalizarLetra()` (Dart) hacen
**exactamente** lo mismo; `test/letras_invertidas_test.dart` lo verifica con
valores calculados en Python. Si cambias uno, cambia el otro.

## Reproducir

```bash
pip install -r model/requirements.txt
python model/preparar_datos.py --dataset RUTA/Gambo --fuentes RUTA/fuentes --salida model/datos
python model/entrenar.py --datos model/datos --salida assets/models
python model/evaluar.py --datos model/datos --modelo assets/models/letras_invertidas.tflite --fuentes RUTA/fuentes
```

Las fuentes son de Google Fonts (OFL): PatrickHand, GochiHand, IndieFlower,
ArchitectsDaughter, Kalam, ShadowsIntoLight, Handlee, Delius, Sniglet,
Schoolbell, Neucha, ReenieBeanie, NothingYouCouldDo, CoveredByYourGrace,
WalterTurncoat, ComingSoon, Andika, Mali y LoveYaLikeASister. Las 5 de
validación (PatrickHand, Kalam, Andika, Schoolbell y Mali) **no** se usan
para entrenar.

## Resultados

Ver `RESULTADOS.md`, que es la salida de `evaluar.py`.

## Límites (decirlos en la app y en la entrega)

- **No detecta b↔d ni p↔q**: por la razón de la tabla de arriba.
- Funciona con **letra de imprenta**. En cursiva las letras van unidas y no se separan.
- Los datos son de Malasia y NIST, no de niños ecuatorianos. Hay que validar con
  10–20 dictados reales, anónimos y con permiso.
- Es una **alerta**, no un diagnóstico.
