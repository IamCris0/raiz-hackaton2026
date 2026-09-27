# Tarea para Cris — Detección de letras invertidas (dislexia)

> Contexto para ti y para tu Claude Code. Léelo completo antes de empezar.
> Preparado por Joel + Claude, 27/09/2026.

---

## 0. Antes de empezar

1. **Haz merge del PR #1** (`feature/modulo2-analisis-visual`) a `main`. Tu trabajo se construye sobre el archivo `analizador_escritura.dart` que trae ese PR.
   El PR #2 (`fix/inicio-estadisticas-visibles`) es independiente; fusiónalo cuando quieras.
2. `git pull` en `main` y crea tu rama: `feature/modulo2-letras-invertidas`.
3. Corre `flutter test` y `flutter analyze`: deben pasar limpios antes de tocar nada.

> **Windows:** si Gradle falla con `Unable to establish loopback connection`, ejecuta una vez
> `setx JAVA_TOOL_OPTIONS "-Djdk.net.unixdomain.tmpdir=C:\Windows\Temp"` y reabre la terminal.

---

## 1. Dónde estamos

"Nueva evaluación" ya analiza la foto de verdad, 100% offline (PR #1):

- `AnalizadorEscritura` limpia la foto (líneas del cuaderno, margen, colores, espiral, agujeros, dibujos), **separa cada letra o trazo** y los agrupa por renglón.
- Mide 3 señales de **disgrafía** (la forma): tamaño de letra, espaciado entre palabras y línea base.
- `deteccion_service.dart` convierte eso en semáforo (bajo, medio o alto) y en frases para el docente.

**Lo que falta** (y prometimos en la primera entrega): señales de **dislexia**, empezando por las **letras invertidas** (b↔d, p↔q). El análisis actual no las ve, porque solo mide forma.

**Descartado (no volver a intentarlo):** ML Kit offline lee muy mal la letra a mano infantil. Se probó incluso con la imagen limpia, renglón por renglón. Por eso **no** usamos OCR para detectar dislexia; usamos un modelo de visión sobre cada letra.

**Decisión del equipo:** nada de APIs pagas ni de enviar fotos a la nube para el hackatón. Todo offline.

---

## 2. El plan

```
foto → AnalizadorEscritura (ya separa las letras)
     → recorte de cada letra (NUEVO)
     → modelo TFLite: normal / invertida / corregida (NUEVO)
     → % de letras invertidas → nueva señal en el semáforo (NUEVO)
```

### 2.1 Dataset

**Dyslexia Handwriting Dataset** (Kaggle):
https://www.kaggle.com/datasets/drizasazanitaisa/dyslexia-handwriting-dataset

- Unas 150 mil imágenes de **letras sueltas** en escala de grises, en 3 clases: `Normal`, `Reversal` y `Corrected`.
- Fuente: letras de NIST, más muestras de niños con dislexia de una escuela de Penang (Malasia).
- **Revisar la licencia en la página de Kaggle** antes de usarlo y citarlo en la entrega.
- **No subir el dataset al repo.** Déjalo fuera, o agrega su carpeta a `.gitignore`.
- Revisa el **tamaño de las imágenes** (alto × ancho) y si ya vienen separadas en train y test. Con eso defines la entrada del modelo.

### 2.2 Entrenamiento (Python, fuera del repo o en `model/`)

Es el mismo flujo del clasificador de bananas de Joel: **PyTorch → TFLite**.

- Modelo pequeño: una CNN simple o **MobileNetV2 / EfficientNet-B0** con entrada de 1 canal, o gris replicado a 3.
- Entrada sugerida: **64×64 en gris**. Usa lo que mejor calce con el dataset.
- Balancea las clases, porque vienen desbalanceadas.
- **Data augmentation con cuidado: NADA de volteo horizontal (flip)**, porque convierte una "b" en "d" y rompe justo lo que queremos detectar. Rotaciones pequeñas, grosor de trazo y ruido sí.
- Reporta **accuracy y la matriz de confusión** en test. Sirve para la presentación.
- Exporta a `.tflite` (con cuantización si pesa mucho) y guarda también un `labels.txt` con el orden de las clases.
- Deja el modelo en `assets/models/letras_invertidas.tflite`. El `pubspec.yaml` ya incluye `assets/models/`.

### 2.3 Integración en la app (Flutter)

**a) Recortar las letras.** En `lib/modules/modulo2_deteccion/analizador_escritura.dart`:

- `_procesar()` ya devuelve los renglones con cada trazo (`_Trazo` tiene `minX`, `maxX`, `minY` y `maxY` en la imagen de trabajo de 1000 px de ancho).
- Agrega un método público, por ejemplo:
  ```dart
  static List<img.Image> recortesDeLetras(img.Image original, {int lado = 64})
  ```
  Debe tomar los trazos de `_bloquePrincipal(_procesar(original).renglones)`, recortar cada uno de la imagen en gris con un pequeño margen, dejarlo cuadrado (rellenando con blanco) y redimensionarlo a `lado × lado`. **Tiene que coincidir con el preprocesamiento del entrenamiento**: mismo tamaño, fondo y tinta con la misma polaridad (si el dataset es letra negra sobre fondo blanco o al revés) y la misma normalización.
- Ojo: un trazo puede ser **una letra o una palabra entera en cursiva**. Filtra los recortes con proporción ancho/alto razonable (más o menos entre 0.3 y 1.6) para quedarte solo con las letras sueltas.

**b) Correr el modelo.**

- Agrega `tflite_flutter` a `pubspec.yaml` y comprueba que compile con el Gradle 9 del proyecto.
- Crea `lib/modules/modulo2_deteccion/clasificador_letras.dart`: carga el modelo una sola vez y clasifica los recortes por lotes.
- El análisis actual corre en `Isolate.run` dentro de `deteccion_service.dart`. **El intérprete de TFLite no se puede pasar a otro isolate**, así que debes decidir entre:
  - (1) cargar el modelo dentro del isolate a partir de sus bytes, o
  - (2) calcular los recortes en el isolate y clasificarlos en el isolate principal.

**c) Nueva señal.** En `lib/modules/modulo2_deteccion/deteccion_service.dart`:

- Hoy: `puntaje = 0.4*tamaño + 0.3*espaciado + 0.3*lineaBase`, con umbrales en las constantes `_tamano`, `_espaciado` y `_lineaBase`.
- Añade una medida `inversiones` = **% de letras clasificadas como `Reversal` con confianza ≥ 0.8**.
  - Solo cuenta si hay **al menos ~15 letras** analizadas; con menos, no es confiable.
- Escálala con umbrales como los demás, por ejemplo `normal: 0.03`, `alto: 0.15`.
- Rebalancea los pesos, por ejemplo **0.3 inversiones · 0.3 tamaño · 0.2 espaciado · 0.2 línea base**.
- Nueva frase para el docente, en el mismo tono:
  - fuerte: *"Se observan varias letras escritas en espejo (por ejemplo b/d o p/q)."*
  - leve: *"Algunas letras podrían estar invertidas (b/d, p/q)."*

**d) Tests.** En `test/analizador_escritura_test.dart` ya hay tests del análisis visual. Agrega al menos uno que verifique que `recortesDeLetras` devuelve recortes del tamaño correcto sobre la hoja sintética.

---

## 3. Cómo probar

Fotos de prueba (pídeselas a Joel; están en su emulador como `dictado_prueba`, `hoja_A` y `hoja_B`):

| Foto | Qué esperar |
|---|---|
| `hoja_A` (adulto, letra normal) | ~0% de letras invertidas → sin señal nueva |
| `dictado_prueba` (niño, buena letra) | ~0% → sin señal nueva |
| Una hoja nueva escrita **a propósito con b/d y p/q al revés**, en **letra de imprenta** | Debe aparecer la señal de letras invertidas |

Para ver qué letras detecta el analizador, usa `AnalizadorEscritura.diagnostico(foto)`: dibuja un recuadro por letra, con un color por renglón.

---

## 4. Limitaciones que hay que decir con honestidad (en la app y en la entrega)

- Funciona mejor con **letra de imprenta**. En cursiva las letras van unidas y no se pueden separar una por una.
- El dataset es de **Malasia y NIST**, no de niños ecuatorianos. Hay que validar con muestras reales (10 a 20 dictados anónimos y con permiso).
- Sigue siendo una **alerta, no un diagnóstico**. No cambiar el aviso ético.

---

## 5. Checklist

- [ ] Merge del PR #1, `git pull`, crear rama `feature/modulo2-letras-invertidas`
- [ ] Descargar el dataset y revisar su licencia, tamaño de imagen y clases
- [ ] Entrenar sin flips; anotar accuracy y matriz de confusión
- [ ] Exportar `letras_invertidas.tflite` y `labels.txt` a `assets/models/`
- [ ] `recortesDeLetras()` en `analizador_escritura.dart`, con el mismo preprocesamiento que el entrenamiento
- [ ] `clasificador_letras.dart` con `tflite_flutter`
- [ ] Señal `inversiones` + pesos + frases en `deteccion_service.dart`
- [ ] Test nuevo; `flutter test` y `flutter analyze` limpios
- [ ] Probar en el emulador con hoja_A, dictado_prueba y una hoja con letras invertidas
- [ ] PR a `main` con resultados (accuracy del modelo + capturas)
