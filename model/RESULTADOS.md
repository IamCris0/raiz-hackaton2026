# Resultados del modelo de letras en espejo

Modelo: `assets/models/letras_invertidas.tflite`. Es una CNN float32 de 615 KB,
con entrada 28×28, entrenada 9 épocas con 218 mil letras (Kaggle + sintéticas).
La app cuenta una letra como invertida solo si el modelo da **≥ 0,9** de
probabilidad (`ClasificadorLetras.confianzaMinima`).

Todo se midió con el archivo `.tflite` final, el mismo que corre en el celular.

## 1. Test oficial del dataset (55 634 letras que el modelo no vio)

**Accuracy: 96,8 %**

| | Predicho normal | Predicho invertida |
|---|---:|---:|
| **Real normal** (38 841) | 37 547 | 1 294 |
| **Real invertida** (16 793) | 465 | 16 328 |

Con el umbral de la app (0,9):
- **Precisión 97,1 %**: de cada 100 letras marcadas como invertidas, 97 lo son.
- **Detecta el 92,4 %** de las letras invertidas.
- **Falsas alarmas: 1,2 %** de las letras normales.

## 2. Fuentes manuscritas nunca vistas (5 fuentes, letra por letra)

- Falsas alarmas promedio: **1,7 %**
- Detección de espejos promedio: **95,0 %**
- b, d y p normales: **0 %** de falsas alarmas.
- Las más confundidas son la **q** (27 %), la **z** (23 %) y la **l** (20 %).
  La q en espejo es una p, así que es el mismo límite que b/d.
- Los espejos que menos detecta son **a**, **e** y **z** (70–73 %).

## 3. Hoja de dictado simulada (segmentada como en la app)

Seis frases de dictado en español. Se voltea en espejo un porcentaje de las
letras e, s, z, j, r, c y a. La tabla muestra el % de todas las letras de la
hoja que marca el modelo.

| Fuente | Sin espejos | 30 % en espejo | 60 % en espejo |
|---|---:|---:|---:|
| Andika | 0,0 % | 11,3 % | 29,4 % |
| Kalam | 0,0 % | 11,7 % | 29,2 % |
| Mali | 3,3 % | 8,7 % | 21,6 % |
| PatrickHand | 0,0 % | 10,4 % | 22,5 % |
| Schoolbell | 0,8 % | 7,0 % | 20,6 % |

Con la calibración de la app (sin señal por debajo de 3 %, señal máxima desde
15 %):
- Una hoja **sin** espejos queda en 0–3,3 %, así que no hay señal.
- Una hoja con algunos espejos sube a 7–12 % y aparece la señal "Algunas
  letras podrían estar en espejo" o la fuerte.

## Qué NO dicen estos números

- **No hay fotos reales de niños ecuatorianos todavía.** La hoja simulada usa
  fuentes digitales, no lápiz sobre cuaderno. Antes de afirmar precisión en la
  entrega hay que probar con 10–20 dictados reales (anónimos y con permiso).
- **b↔d y p↔q no se detectan**, por diseño: una b en espejo es una d correcta.
- Solo aplica a **letra de imprenta**. En cursiva casi no hay letras sueltas y
  la app lo avisa.
