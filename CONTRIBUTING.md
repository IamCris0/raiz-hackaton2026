# Flujo de trabajo — Equipo RAÍZ

Somos 2 personas, así que mantenlo simple. Reglas mínimas para no pisarnos el trabajo:

## Ramas

- `main` — siempre debe compilar y correr. Nunca se le hace push directo.
- `feature/<algo>` — una rama por tarea. Ej: `feature/modulo2-captura-camara`,
  `feature/dashboard-historial`.

## Flujo

1. `git checkout -b feature/lo-que-vas-a-hacer`
2. Trabajas, haces commits chicos y descriptivos (`git commit -m "feat: captura de foto en módulo 2"`).
3. `git push -u origin feature/lo-que-vas-a-hacer`
4. Abres un Pull Request hacia `main` en GitHub.
5. El otro revisa (aunque sea rápido) y aprueba — o comenta si algo no cuadra.
6. Merge a `main`.

## Reparto sugerido (para no chocar en los mismos archivos)

- **Módulo 2 (detección)** — es el corazón del proyecto y el diferenciador frente a otras
  soluciones. Prioridad #1.
- **Módulo 1 (OCR)** — se puede armar en paralelo, tiene poca dependencia del Módulo 2.
- **Módulo 3 (dashboard)** — depende de que el Módulo 2 ya devuelva un resultado con el que
  guardar el historial; conviene empezarlo cuando el Módulo 2 tenga al menos el modelo de
  datos (`RiesgoResultado`) definido, aunque el cálculo interno todavía sea un placeholder.

## Convenciones rápidas

- Comentarios y nombres de clases/pantallas en español (así el equipo y los jueces lo leen
  igual de fácil).
- Un commit = un cambio entendible. Evitar commits gigantes de "avance general".
- Si agregas una dependencia nueva a `pubspec.yaml`, avisa en el chat del equipo antes de
  hacer merge — evita conflictos de versiones.
