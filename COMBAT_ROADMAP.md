# Hoja de ruta del combate

Objetivo: boxeo cenital para celular horizontal, con intercambios intensos y decisiones de distancia, ritmo, defensa y energía. Completar incrementos jugables antes de sumar otros sistemas.

## Base existente

- Movimiento, joystick y botones multitáctiles.
- Jab rápido, cross de toque y cross cargado con límites de daño y coste.
- Preparación, contacto, recuperación y pulsación anticipada de ataques.
- Estamina, guardia frontal y ruptura básica por falta de energía.
- Tres combos con bonus al remate.
- Vida real y reserva amarilla que se recupera atacando.
- Rival con distancia, ráfagas, defensa y descanso.
- HUD, práctica, sparring y reinicio.

Estas mecánicas existen; todavía necesitan ajustes y validación de sensación al jugar.

## Orden de trabajo

| Paso | Mecánica | Resultado buscado | Estado |
| --- | --- | --- | --- |
| 1 | Alcance y contacto | Golpear sin tener que pegar los cuerpos; puños visibles coherentes con el contacto | Implementado y probado; falta valoración jugando |
| 2 | Empuje físico | Jab desplaza poco; cross y carga desplazan más, sin atravesar cuerdas ni impedir combos | Implementado y probado; falta valoración jugando |
| 3 | Guardia y ruptura | Defensa legible, coste claro y oportunidad breve de castigar una guardia rota | Pulido inicial implementado y probado; falta valoración jugando |
| 4 | Esquiva | Una acción evasiva con coste y recuperación, compatible con joystick y controles móviles | Implementada y probada; falta valoración jugando |
| 5 | Contraataques | Recompensar esquivar o provocar un fallo, con una ventana clara y limitada | Próximo |
| 6 | Ritmo y combos | Conectar secuencias fluidas sin permitir ataques infinitos ni bloqueo permanente del rival | Pulir base |
| 7 | Estamina y agotamiento | Conservar los intercambios largos, pero hacer relevante elegir cuándo gastar o recuperar | Pulir base |
| 8 | Vida recuperable | Hacer comprensible la reserva amarilla y equilibrar el riesgo de recuperarla atacando | Pulir base |
| 9 | Posición y cuerdas | Salidas laterales y presión en las esquinas sin quedar atascado ni sufrir un encierro inevitable | Pendiente |
| 10 | Rival más humano | Usar las reglas finales con reacción limitada, errores y estilos diferentes | Evaluar implementación aquí o en Cursor |
| 11 | Sensación y controles | Afinar pausas, señales, audio provisional y comodidad con varios dedos | Pulido transversal y cierre |
| 12 | Reglas del encuentro | Definir duración, rounds y victoria para el prototipo; conservar reinicio rápido | Después del núcleo |
| 13 | Pausa del juego | Botón touch y Escape para pausar/reanudar; congelar combate, IA y reserva amarilla, y limpiar entradas al volver | Implementada con regreso al inicio y pausa por cambio de app/orientación |

## Primeros ajustes propuestos

### Alcance

Primer ajuste aplicado: jab de 38 a 45 px y cross de 43 a 51 px (aproximadamente +18 %). El rival ajusta su entrada de 60 a 67 px y la distancia neutral de 96 a 104 px. Se conserva daño, coste y tiempos de los golpes. Ajustar mirando la distancia efectiva entre cuerpos, no solo un número de alcance. Mantener una diferencia útil entre jab y cross sin volver irrelevante acercarse o retroceder.

El contacto ahora cubre el recorrido frontal del guante con una cápsula durante la ventana activa, conservando un solo impacto por objetivo. El dibujo del puño utiliza el alcance del recurso. `reach_smoke.gd` verifica contactos cercanos y en el límite en cuatro direcciones, fallos fuera de alcance y exclusión de objetivos laterales, traseros y propios. Pasaron también las pruebas de combate, sensación, ritmo, carga, respuesta del cross, combos, sparring, conducta del rival y ciclo de vida. Falta valorar la sensación manualmente. Algunas pruebas anteriores emiten una advertencia de ObjectDB al cerrar; queda pendiente investigar su limpieza.

### Empuje

Implementado en los boxeadores mediante movimiento con colisiones, separado de la velocidad voluntaria del joystick. El muñeco de práctica permanece fijo para servir como referencia.

Primer balance: velocidad de impulso de 75 px/s para jab y 145 px/s para cross; carga máxima multiplica el impulso por 1,5. Frenado de 1000 px/s², máximo de 260 px/s y guardia que conserva el 25 % del impulso. El bonus de daño de un combo incrementa el impulso con raíz cuadrada del multiplicador (tope de multiplicador 1,5), sin acumulación de velocidades entre impactos.

En una prueba a 60 Hz contra un rival quieto, los desplazamientos fueron aproximadamente 3,5 px para jab, 11,8 px para cross, 25,5 px para carga máxima y 1 px para cross bloqueado. Cambian si el defensor se mueve o choca con otro cuerpo. `knockback_smoke.gd` verifica estos casos, los tres combos contra un rival móvil por empuje, límites del ring, dirección, frenado, tope, limpieza al detenerse y KO. Pasaron las 13 pruebas del proyecto. La advertencia de ObjectDB de algunas pruebas al cerrar sigue pendiente.

- Intensidad base según el golpe, escalada de forma acotada por su daño y carga.
- Jab: empuje pequeño que permita continuar el combo.
- Cross: empuje más perceptible; cross cargado: mayor separación.
- Guardia: empuje reducido.
- Bonus de combo: aumento moderado, sin multiplicaciones ilimitadas.
- Empuje y aturdimiento son parámetros distintos; desplazar no implica quitar el control durante mucho tiempo.
- Sin atravesar límites del ring ni acumular velocidad indefinidamente.

Los valores finales se eligen jugando. No vincular el empuje únicamente al daño efectivo que queda de vida: un golpe de KO debe conservar su fuerza.

En el prototipo el KO detiene inmediatamente el encuentro y limpia el empuje. La fuerza visual del remate se conserva; un desplazamiento posterior al KO necesitaría una fase de cierre propia y queda fuera de este paso.

### Guardia y ruptura

Primer pulido implementado: se mantienen la cobertura frontal de 140°, la reducción de daño del 75 % y el coste del 80 % del daño entrante. Mantener guardia reduce la regeneración al 35 % del ritmo libre.

La ruptura dura 0,45 s locales: no permite atacar, cargar, bloquear ni correr; sí retirarse al 40 % de velocidad. No regenera energía durante esa ventana. Los golpes posteriores no prolongan la penalización. Un arco rojo y los avisos bajo la energía muestran quién está expuesto. La IA intenta retirarse al romperse su guardia y luego recuperar energía.

`guard_smoke.gd` valida los límites de cobertura, costes, acciones bloqueadas, retirada, regeneración, duración, pausa local, avisos y limpieza al terminar. Pasaron las 14 pruebas del proyecto. Pendiente valorar en juego antes de ajustar duración o coste.

### Esquiva

Implementada con L o ESQ. (cuarto botón táctil). Dirección del joystick al pulsar o paso atrás si no hay dirección. Coste 18; paso de 0,18 s a 300 px/s, recuperación de 0,16 s y enfriamiento de 0,65 s desde el inicio. Protección solo entre los 0,03 y 0,13 s; el resto es vulnerable. No cancela ataques/carga, no evita las paredes y no puede iniciarse durante guardia rota ni pausa de impacto. Puede usarse desde la guardia, sustituyéndola. El enfriamiento se muestra en el botón.

`dodge_smoke.gd` prueba dirección, coste, protección y vulnerabilidad, un golpe real que sobrevive a la protección, restricciones, paredes, multitouch, teclado y limpieza. Pasaron las 15 pruebas del proyecto. Falta valorar sensación y comodidad del nuevo botón en juego. La IA tiene acceso a la misma acción, pero todavía no elige esquivarla por sí sola; se reserva para su fase de mejora. Las recompensas de contraataque también quedan para el siguiente paso.

### Pausa del juego

Implementada: PAUSA y Escape; continuar o volver al inicio. Congela movimiento, golpes, empuje, IA, estamina y pérdida de reserva amarilla; el menú sigue operativo. Limpia entradas touch y cancela cargas al pausar, sin disparar golpes al volver. Cambiar de app o girar a vertical pausa y exige continuar explícitamente. `mobile_app_smoke.gd` prueba inicio por touch, ambos modos, congelación de combate, regreso al menú y cambios de orientación/foco.

## Evaluación del rival y posible tarea para Cursor

Hacerla después de estabilizar alcance, empuje, defensa y esquiva. Puede haber ajustes pequeños del rival en cada paso para mantenerlo jugable.

No está demostrado que un asistente sea más capaz que otro para esta tarea. Comparar una implementación acotada por su resultado y sus pruebas, conservando una copia del estado anterior. Solo un asistente edita a la vez.

Criterios para aceptar una mejora:

- Reacciona a señales visibles con demora; no lee botones ni el futuro.
- Respeta la misma estamina, alcance, guardia y recuperación que el jugador.
- Entra, combina, sale y vuelve a medir la distancia.
- Defiende, falla, se precipita a veces y castiga oportunidades sin acertar siempre.
- Distingue estilos mediante parámetros: presión, contragolpe y movilidad.
- Se recupera de las esquinas y sigue funcionando con poco espacio o energía.
- Permite repetir escenarios con una semilla de azar y observar sus decisiones.
- Supera pruebas de legalidad y se evalúa jugando: más complejidad no garantiza que parezca más humano.

## Cierre de cada paso

Implementar una mecánica por vez, comprobar los casos relevantes, jugar en práctica y sparring, recoger sensaciones y actualizar PROJECT_CONTEXT.md con los valores realmente aplicados. No añadir todavía arte definitivo, carrera, entrenamiento, estadísticas de progresión o rankings.
