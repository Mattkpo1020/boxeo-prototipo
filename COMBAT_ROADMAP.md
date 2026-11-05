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
| 5 | Contraataques | Recompensar esquivar o provocar un fallo, con una ventana clara y limitada | Implementado y probado. Falta valoración jugando |
| 6 | Ritmo y combos | Conectar secuencias fluidas y dejar una salida entre ráfagas | Ajuste inicial probado. Falta valorar en sparring |
| 7 | Estamina y agotamiento | Conservar los intercambios largos y hacer relevante elegir cuándo gastar o recuperar | Ajuste inicial probado. Falta valorar en sparring |
| 8 | Vida recuperable | Distinguir la reserva amarilla de la vida recuperada y premiar los golpes limpios | Ajuste inicial probado. Falta valorar en sparring |
| 9 | Posición y cuerdas | Salidas laterales y presión en las esquinas | Ajuste inicial probado en las cuatro esquinas |
| 10 | Rival más humano | Variar las respuestas a ataques visibles y elegir entre tres estilos | Implementado y probado. Falta ajustar jugando |
| 11 | Sensación y controles | Afinar pausas, señales, audio provisional y comodidad con varios dedos | Ajuste inicial probado. Falta probar en iPhone |
| 12 | Reglas del encuentro | Asaltos sin reloj, victoria al ganar dos y reinicio rápido | Implementado y probado. Falta valorar la duración jugando |
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

`dodge_smoke.gd` prueba dirección, coste, protección y vulnerabilidad, un golpe real que sobrevive a la protección, restricciones, paredes, multitouch, teclado y limpieza. Falta valorar sensación y comodidad del botón en juego. La elección de esquivar por parte de la IA queda para su fase de mejora.

### Contraataques

Un jab o cross normal limpio suma 25 % de daño si conecta durante la recuperación de un golpe que falló o dentro de los 0,45 s que abre una esquiva efectiva contra ese mismo rival. El arco dorado marca la oportunidad y el HUD anuncia el acierto. Los combos conservan su propio bonus, que tiene prioridad. El cross cargado conserva su daño habitual.

`counter_smoke.gd` verifica respuesta a un fallo, respuesta tras esquiva, vencimiento de la ventana y bloqueo. Pasaron las 17 pruebas. Falta ajustar la sensación y la legibilidad en sparring real.

### Ritmo y combos

Durante la recuperación se puede adelantar el siguiente golpe hasta 0,20 s al alternar manos y 0,14 s al repetir. Tres golpes unidos por pulsaciones guardadas añaden 0,18 s a la recuperación del tercero y cierran la cadena de combo. El cuarto puede quedar guardado al final de esa recuperación y abre una ráfaga nueva.

`attack_flow_smoke.gd` verifica el margen ampliado, el intervalo antes del cuarto golpe y la vuelta al ritmo habitual. Pasaron las 17 pruebas.

### Estamina y agotamiento

Agotar la reserva muestra **SIN AIRE**. Hasta recuperar el 12 % de la estamina máxima, quedan deshabilitados los golpes, la carga, la esquiva y el sprint. Caminar y cubrirse siguen disponibles. Un golpe ya pagado se completa. Con 300 de estamina máxima, la recuperación exige llegar a 36. Los costes de ataque y el ritmo de regeneración se mantienen.

`combat_smoke.gd` verifica el último jab, la recuperación parcial y completa, el aviso del HUD y el agotamiento al correr. Pasaron las 17 pruebas.

### Vida recuperable

El HUD muestra por un segundo cuánto recuperó cada boxeador con su último golpe limpio. El número entre corchetes sigue indicando cuánta vida queda en la reserva amarilla. Bloquear puede aportar a la reserva por el daño residual, pero no reinicia la demora de una reserva que ya existe. Sigue rigiendo el 50 % de curación sobre el daño efectivo, limitado a la reserva.

`rally_smoke.gd` verifica el aviso, su vencimiento y la decadencia de la reserva tras bloquear. Pasaron las 17 pruebas.

### Posición y cuerdas

Cuando las cuerdas bloquean la retirada del rival, compara las salidas laterales y favorece la que mantiene más distancia del jugador durante el paso. El margen de seguridad frena los pasos hacia afuera y permite volver hacia adentro desde el borde.

`opponent_behavior_smoke.gd` comprueba que el rival elige el lado despejado en las cuatro esquinas. También pasaron las pruebas de sparring, esquiva, empuje y flujo móvil.

### Rival más humano

Cuando decide responder a un ataque visible, el rival puede elegir un paso evasivo diagonal en vez de cubrirse. Por defecto elige intentar esquivar en el 25 % de esas respuestas, después de la demora de reacción. Paga 18 de estamina, necesita reserva para un jab y respeta el enfriamiento y las cuerdas. Si la esquiva no es viable, vuelve a su respuesta de guardia. Contra una carga que sigue sostenida prefiere cubrirse.

El botón **Rival** del inicio alterna entre **Presión**, el comportamiento original de entradas y ráfagas, **Contragolpe**, con más guardia y un jab ocasional ante un fallo visible, y **Movilidad**, con mayor distancia, más desplazamiento lateral y esquivas, y ráfagas más cortas. La selección se conserva durante la sesión.

`opponent_behavior_smoke.gd` verifica la esquiva ante el cross de toque y el castigo a un golpe fallado. `mobile_app_smoke.gd` prueba el selector táctil, la selección al entrar al ring y su conservación al volver al menú. Pasaron las 18 pruebas. Falta valorar los tres estilos jugando.

### Sensación y controles

Un bloqueo efectivo produce un arco azul y un sonido más agudo y suave. Los impactos limpios y los que rompen la guardia usan el efecto de golpe. Los botones de combate aceptan toques hasta un 10 % fuera del círculo dibujado para facilitar las pulsaciones rápidas.

`sparring_smoke.gd` verifica el efecto de bloqueo y `mobile_smoke.gd` prueba un cross tocado justo fuera del círculo. Pasaron las 17 pruebas. La comodidad táctil y el audio quedan por valorar en un iPhone real.

### Reglas del encuentro

El sparring se juega sin reloj. Cada nocaut suma un punto y gana el primero en llegar a dos. El marcador muestra dos puntos por lado y el número de asalto. Tras un descanso de dos segundos, ambos vuelven a sus posiciones iniciales con la vida y la estamina completas y la reserva amarilla vacía.

`rounds_smoke.gd` verifica que no haya límite de tiempo, la pausa durante el descanso, el marcador, la restauración de vida y estamina, el tercer asalto y el reinicio. Pasaron las 18 pruebas.

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

El repaso previo a la publicación comparó tres semillas por estilo contra el mismo jugador automático, que alternaba jab y cross y se retiraba con poca estamina. Tras acortar la retirada de Movilidad y hacer más frecuente su cross, al jugador le quedaron 237 puntos de vida en promedio frente a ese estilo, contra 298 antes del ajuste. Sigue siendo el estilo menos dañino en ese escenario. Los nueve encuentros finales terminaron por nocaut entre 72 y 85 segundos.

Se agrandaron el reloj, la vida, la energía y las indicaciones del HUD, y se acortó la guía de combos. Se revisó el diseño horizontal en Godot y pasaron las 18 pruebas. Queda publicar y comprobar instalación, audio y juego táctil en un iPhone, además de valorar el balance manualmente.

Implementar una mecánica por vez, comprobar los casos relevantes, jugar en práctica y sparring, recoger sensaciones y actualizar PROJECT_CONTEXT.md con los valores realmente aplicados. No añadir todavía arte definitivo, carrera, entrenamiento, estadísticas de progresión o rankings.
