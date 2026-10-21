> Diseño vigente: la referencia más reciente del usuario pide el toldo inferior invertido y la cadena vertical. Ambos Switch comparten ahora ese diagrama, con entrada y meta siempre visibles y ejemplo de 24 segundos. Las notas anteriores sobre flujo lateral y ausencia del toldo inferior describen la versión previa. Véase [secuencias actuales](timed_sequences.md).

# Switch Challenge: investigación y decisiones

Consultado el 20 de octubre de 2026, antes de implementar el nuevo componente.

- [Flutter: staggered animations](https://docs.flutter.dev/ui/animations/staggered-animations). Una sola línea de tiempo coordina el descenso hacia el primer filtro y la salida lateral del nuevo orden. Se usan curvas suaves e intervalos consecutivos.
- [Flutter API: TweenSequence](https://api.flutter.dev/flutter/animation/TweenSequence-class.html). El ejemplo conserva el primer orden intermedio mientras prueba las tres reglas siguientes. `TweenSequence` mantiene esa pausa sin temporizadores independientes.
- [Flutter API: CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html). `CustomPainter(repaint: animation)` actualiza las figuras en cada cuadro sin reconstruir el resto del ejercicio; un `RepaintBoundary` aísla el dibujo.
- [Flutter: AnimationBehavior](https://api.flutter.dev/flutter/animation/AnimationBehavior.html). La preferencia de accesibilidad para reducir movimiento detiene el bucle de instrucciones y muestra el último paso como ejemplo estático. La ronda puntuable muestra directamente el orden intermedio.
- [Repositorio original flutter/samples: animations](https://github.com/flutter/samples/tree/main/animations). Se revisaron los ejemplos mantenidos por Flutter para separar el ciclo de vida del controlador, el dibujo y los controles táctiles.
- [Repositorio original The-ring-io/flutter_staggered_animations](https://github.com/The-ring-io/flutter_staggered_animations). Se evaluó la alternativa de animaciones escalonadas de listas. Esta interacción necesita movimiento explícito entre posiciones y un objetivo inmóvil; se implementó con el SDK sin agregar una dependencia.

Las figuras son vectores dibujados en Dart y conservan tanto forma como color. No se descargaron assets ni se añadieron licencias externas.

## Comportamiento

El ejemplo guiado usa círculo, triángulo, cruz y cuadrado; aplica `1342`, y muestra a la derecha círculo, cruz, cuadrado y triángulo. Prueba `1342`, `2341` y finalmente `3241`, cuya salida coincide con cuadrado, cruz, triángulo y círculo. Solo las instrucciones revelan esa coincidencia.

La ronda conserva una única selección del usuario. Mantener una opción pulsada revela de forma neutra la transformación de sus posiciones; soltarla envía la respuesta. El juego no consulta `correctIndex` y no muestra aciertos o errores. La fila objetivo se dibuja fuera del controlador animado, sin toldo inferior ni transformaciones de entrada. La flecha hacia las opciones es estática.
