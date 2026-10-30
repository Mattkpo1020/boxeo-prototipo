# Pruebas desde el celular

El proyecto incluye un preset Web para Godot 4.5.1 y un flujo de GitHub Actions que verifica el combate, exporta y publica en Pages. La primera publicación completó pruebas, exportación y despliegue correctamente. Se verificaron carga, cambio de modo y jab en un navegador de escritorio con viewport horizontal de 844×390; falta comprobar Safari, sonido y multitouch en un iPhone real.

- Juego: https://mattkpo1020.github.io/boxeo-prototipo/
- Repositorio independiente: https://github.com/Mattkpo1020/boxeo-prototipo
- Primer despliegue: https://github.com/Mattkpo1020/boxeo-prototipo/actions/runs/41097114359

## Primera publicación

1. Elegir un repositorio para este juego. Con GitHub Free, Pages requiere un repositorio público.
2. Subir el contenido de esta carpeta como raíz del repositorio: project.godot, scripts/, scenes/, resources/, tests/, export_presets.cfg y .github/. No subir la carpeta padre del proyecto de ChatGPT.
3. En Settings → Pages → Build and deployment, elegir GitHub Actions.
4. El flujo se ejecuta al subir a main; también permite iniciarlo desde Actions → Prototipo web → Run workflow.
5. Al terminar el despliegue, abrir en el celular la URL que muestra Pages. Usar el teléfono en horizontal y tocar la pantalla si el navegador necesita interacción para activar el audio.

Los cambios locales no aparecen solos en el celular: hay que subirlos al repositorio y esperar a que termine el despliegue. La primera ejecución debe comprobarse en GitHub y luego en el dispositivo. El flujo descarga herramientas oficiales y la colección de plantillas, de la que extrae las plantillas web.

## Configuración web

- Renderizador Compatibility ya usado por el juego.
- Un solo hilo, sin requisitos de aislamiento entre orígenes.
- Exportación a build/web/index.html, con archivos auxiliares sin renombrar.
- Canvas adaptable con aspecto expand, viewport-fit=cover y márgenes de seguridad del iPhone trasladados al HUD y los controles.
- PWA con manifest, iconos, modo standalone y orientación horizontal solicitada. Safari puede exigir girar manualmente: se muestra un aviso en vertical.
- Pantalla inicial en Godot antes del combate. Instrucciones de instalación dentro del menú; no se intenta instalar sin confirmación del usuario.
- Caché gestionada por el service worker de Godot y botón para aplicar una actualización pendiente desde el inicio. La primera carga requiere conexión; el almacenamiento offline depende del navegador y puede ser eliminado por iOS.
- Los scripts de pruebas y la documentación se excluyen del paquete del juego.

El rendimiento, el audio, la instalación y el multitouch deben validarse en el iPhone real; las pruebas automáticas de escritorio no los garantizan. La versión nativa para Android/iOS será un paso separado. La pausa manual y por cambio de app/orientación ya está implementada.

## Exportación manual

Instalar las plantillas oficiales de exportación 4.5.1 desde Godot → Editor → Manage Export Templates. Crear build/web y exportar el preset Web desde Project → Export. Abrir el resultado mediante un servidor HTTP, no haciendo doble clic en el HTML.

## Referencias

- https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html
- https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
