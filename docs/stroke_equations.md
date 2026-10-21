# Ecuaciones de trazos y partidas sin explicaciones repetidas

## Presentación

Después de aceptar las instrucciones, las partidas muestran el estímulo y sus controles. Se retiran encabezados, consignas repetidas, mensajes sobre resultados diferidos y cronómetros numéricos. El tiempo se representa con una barra. Los números que forman parte del ejercicio, las marcas de selección y los controles de confirmar/deshacer se conservan.

Grid usa señales visuales para distinguir las tareas: flecha curva con grados para rotación a la derecha, espejo con eje vertical/horizontal para simetría, = para identidad y + para composición. Estas señales se explican antes de la ronda y tienen etiquetas de accesibilidad.

Grid + Memoria y Simetría + Memoria duran **3 minutos fijos**, también en el test completo. Los demás juegos conservan la duración configurada de 5/6 minutos. La duración anunciada en cada tarjeta, sus instrucciones, el cronómetro interno y la estimación del test utilizan la misma regla `TrainingSettings.durationFor`.

## Nuevo ejercicio

La tarjeta **Ecuaciones de trazos** abre sus instrucciones visuales animadas; también forma parte del test completo del menú principal. Su partida presenta dos paneles con + y un resultado con =. Solo se responde Sí/No; los aciertos se revelan en el reporte final.

Los patrones originales tienen numerosos trazos horizontales, verticales y diagonales sobre un plano de siete por siete referencias. Comparten líneas y aumentan su complejidad a medida que avanza la ronda. Los resultados incorrectos incluyen un trazo omitido, añadido, trasladado o deformado. Un desplazamiento de una unidad sobre un plano de 72 unidades ya invalida la figura.

La geometría se calcula con coordenadas enteras. `sameStrokeGeometry` agrupa las rectas por dirección y posición exactas y fusiona los intervalos cubiertos. Así no se confunde el orden de dibujo, un trazo invertido, una línea compartida o una subdivisión colineal con una diferencia geométrica. No se usa una tolerancia que pueda aceptar desplazamientos mínimos. Los dibujos emplean el mismo modelo que el evaluador.

Archivos principales:

- `lib/domain/stroke_equation.dart`: geometría exacta, preguntas y generador.
- `lib/features/training/stroke_equation.dart`: paneles, controles y demostración independiente.
- `lib/domain/models.dart` y `round_controller.dart`: duración por juego y registro diferido.

Se añade `strokes` al final de `GameType`; los nombres persistidos de los juegos existentes no cambian.

## Fuentes oficiales consultadas

- [CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html): renderizado de trazos y criterios de repintado. La demostración y las preguntas comparten la representación vectorial.
- [LinearProgressIndicator](https://api.flutter.dev/flutter/material/LinearProgressIndicator-class.html): barra determinada con valor entre 0 y 1 y descripción accesible.
- [Accesibilidad en Flutter](https://docs.flutter.dev/ui/accessibility): conservar etiquetas semánticas aunque se retire texto visible del juego.

Las figuras y su evaluación son originales de esta aplicación; no se descargaron ejercicios de una evaluación externa.
