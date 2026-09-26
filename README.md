# Raíz 🌱

App móvil **offline-first** para que docentes de escuelas rurales detecten señales tempranas
de riesgo de **dislexia** y **disgrafía** en sus estudiantes, sin depender de conectividad ni
de la presencia de un psicólogo escolar (déficit del 67% de DECE a nivel nacional, Ecuador).

> Raíz genera una **alerta de riesgo**, no un diagnóstico clínico. El objetivo es que el
> docente derive a tiempo a un especialista, algo que hoy tarda años o nunca sucede.

Proyecto para el **1er Hackatón Internacional de Innovación Educativa Juvenil 2026**
(Empower Youth SV) — Equipo **RAÍZ**.

## Equipo
- Cristopher — [@IamCris0](https://github.com/IamCris0)
- Joel Velásquez Rogel — [@JoelVelasquezz](https://github.com/JoelVelasquezz)

## Arquitectura — 3 módulos

| Módulo | Qué hace | Cómo |
|---|---|---|
| **2 · Detección** (núcleo/diferenciador) | Analiza una foto de la escritura del estudiante y calcula una alerta de riesgo (verde/amarillo/rojo) | Heurística de rasgos visuales (tamaño de letra, espaciado, alineación) hoy → modelo TFLite entrenado a futuro |
| **1 · OCR** | Digitaliza el texto escrito a mano, en modo offline (on-device) u online (más preciso) | `google_mlkit_text_recognition` offline · Google Vision API opcional online |
| **3 · Dashboard** | Historial local por estudiante, para que el docente vea la evolución en el tiempo | SQLite local (`sqflite`), sin nube |

Todo funciona **sin internet**; el modo online (Módulo 1) es un plus opcional cuando hay señal.

## Stack técnico

- **Flutter** (UI multiplataforma, offline-first)
- `camera` / `image_picker` — captura de la foto de escritura
- `tflite_flutter` — inferencia on-device (cuando exista un modelo entrenado)
- `google_mlkit_text_recognition` — OCR on-device
- `sqflite` — almacenamiento local
- `connectivity_plus` — decide automáticamente modo online/offline
- `provider` — manejo de estado
- `fl_chart` — gráficos del dashboard docente

## Estructura de carpetas

```
lib/
  core/           # constantes, tema visual, servicios transversales (conectividad, etc.)
  modules/
    modulo1_ocr/          # OCR dual online/offline + corrección docente
    modulo2_deteccion/    # captura de escritura + cálculo de riesgo (el diferenciador)
    modulo3_dashboard/    # historial local SQLite + pantallas del docente
  shared/          # widgets reutilizables, navegación
assets/
  models/          # aquí va el .tflite cuando exista (no se sube a git todavía)
  images/
```

## Cómo levantar el proyecto (primera vez)

Este repo trae `pubspec.yaml` y todo `lib/` ya armado, pero **no** trae las carpetas nativas
(`android/`, `ios/`, `web/`) porque esas las genera el propio Flutter SDK. Después de clonar:

```bash
git clone https://github.com/IamCris0/<NOMBRE_DEL_REPO>.git
cd <NOMBRE_DEL_REPO>

# genera android/ ios/ web/ etc. sin tocar lib/ ni pubspec.yaml que ya existen
flutter create --project-name raiz_app --org com.raiz .

flutter pub get
flutter run
```

## Flujo de trabajo en equipo

Ver [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## Estado

🚧 En construcción — Primera Entrega del hackatón (propuesta) ya enviada; este repo es la
base para el prototipo funcional de las siguientes entregas.
