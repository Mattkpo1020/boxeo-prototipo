# Boxeo — Prototipo

Juego 2D cenital de boxeo táctico para celular horizontal, desarrollado en Godot 4.5.1 con GDScript.

## Jugar

La versión de prueba está en [Jugar al prototipo](https://mattkpo1020.github.io/boxeo-prototipo/).

En iPhone: abrir el enlace en Safari y girar el teléfono en horizontal. El menú inicial permite elegir sparring o práctica. Para usarlo sin las barras de Safari, tocar Compartir → Agregar a pantalla de inicio (con Abrir como app web activado si aparece). La instalación la confirma el usuario. Es una app web, no una app de App Store.

El canvas se adapta al aspecto real del dispositivo y respeta las zonas de cámara e indicador de inicio. En combate, PAUSA o Escape permiten continuar o volver al inicio; cambiar de app o girar a vertical también pausa y requiere continuar explícitamente. Hay una ventana de confirmación para aplicar actualizaciones desde el inicio, sin interrumpir el combate.

Joystick izquierdo para moverse. A la derecha: JAB, CROSS (mantener para cargar), BLOCK y ESQ. (paso en la dirección del joystick o hacia atrás si no se indica dirección).

Teclado: WASD/flechas, Espacio para jab, J para cross/carga, K para guardia, L para esquiva, Shift para correr y R para reiniciar.

## Desarrollo

Abrir `project.godot` con Godot 4.5.1. El combate usa formas provisionales y sonidos generados, sin assets finales. La hoja de ruta está en `COMBAT_ROADMAP.md` y la publicación web en `WEB_PUBLISHING.md`.

Las pruebas de `tests/` comprueban movimiento, touch, ataques, combos, guardia, vida recuperable, empuje, esquiva y ciclo del encuentro. Algunas pruebas aún muestran una advertencia de objetos al cerrar; su limpieza queda pendiente.

Al subir cambios a `main`, GitHub Actions ejecuta las pruebas y publica la exportación web. El primer despliegue debe terminar antes de que el enlace esté disponible.
