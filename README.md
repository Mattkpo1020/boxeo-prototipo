# Boxeo — Prototipo

Juego 2D cenital de boxeo táctico para celular horizontal, desarrollado en Godot 4.5.1 con GDScript.

## Jugar

La versión de prueba está en [Jugar al prototipo](https://mattkpo1020.github.io/boxeo-prototipo/).

En iPhone: abrir el enlace en Safari, girar el teléfono en horizontal y tocar la pantalla para habilitar el audio si hace falta. Es un prototipo de navegador; todavía no es una app de App Store.

Joystick izquierdo para moverse. A la derecha: JAB, CROSS (mantener para cargar), BLOCK y ESQ. (paso en la dirección del joystick o hacia atrás si no se indica dirección).

Teclado: WASD/flechas, Espacio para jab, J para cross/carga, K para guardia, L para esquiva, Shift para correr y R para reiniciar.

## Desarrollo

Abrir `project.godot` con Godot 4.5.1. El combate usa formas provisionales y sonidos generados, sin assets finales. La hoja de ruta está en `COMBAT_ROADMAP.md` y la publicación web en `WEB_PUBLISHING.md`.

Las pruebas de `tests/` comprueban movimiento, touch, ataques, combos, guardia, vida recuperable, empuje, esquiva y ciclo del encuentro. Algunas pruebas aún muestran una advertencia de objetos al cerrar; su limpieza queda pendiente.

Al subir cambios a `main`, GitHub Actions ejecuta las pruebas y publica la exportación web. El primer despliegue debe terminar antes de que el enlace esté disponible.
