# Investigación previa: interacción y animaciones

Consulta realizada el 20 de octubre de 2026, antes de implementar los componentes de entrenamiento. Se consultaron fuentes primarias de Flutter/Dart y el paquete publicado por Flutter en pub.dev.

| Fuente | Decisión aplicada |
| --- | --- |
| [AnimatedSwitcher](https://api.flutter.dev/flutter/widgets/AnimatedSwitcher-class.html) | Cada estímulo tiene una `ValueKey` distinta. La transición combina desvanecimiento y desplazamiento corto, sin bloquear las respuestas. |
| [CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html) | Cuadrículas, puntos y figuras se dibujan con coordenadas proporcionales. `shouldRepaint` limita repintados y el parpadeo usa un `Listenable` para evitar reconstruir el árbol por cuadro. |
| [InkWell](https://api.flutter.dev/flutter/material/InkWell-class.html) | Las selecciones usan `Material` e `InkWell`, con tinta visible y recorte en el propio Material. El toque confirma la selección visualmente sin comunicar si fue correcta. |
| [LinearProgressIndicator](https://api.flutter.dev/flutter/material/LinearProgressIndicator-class.html) | Barra determinada según el tiempo real restante. El valor está limitado al intervalo 0–1 y tiene descripción semántica. |
| [Timer.periodic](https://api.dart.dev/dart-async/Timer/Timer.periodic.html), [Stopwatch](https://api.dart.dev/dart-core/Stopwatch-class.html) | Los callbacks no garantizan intervalos exactos: la vista observa el tiempo calculado por el controlador y no descuenta segundos localmente. El controlador gestiona y dispone el temporizador. |
| [MediaQuery.disableAnimationsOf](https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html), [reduceMotion](https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures/reduceMotion.html) | Se eliminan desplazamientos y parpadeos decorativos al solicitar movimiento reducido en Android o iOS. |
| [Semantics](https://api.flutter.dev/flutter/widgets/Semantics-class.html), [accesibilidad](https://docs.flutter.dev/ui/accessibility) | Celdas seleccionables con fila/columna y estado; descripciones de patrones; controles de al menos 48 px; texto adaptable y etiquetas de acciones. |
| [SafeArea y MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery), [diseño adaptativo](https://docs.flutter.dev/ui/adaptive-responsive/general) | Área segura, ancho máximo y contenido desplazable, sin bloquear la orientación. El espacio disponible se consulta con `LayoutBuilder`. |
| [PopScope](https://api.flutter.dev/flutter/widgets/PopScope-class.html) | La salida de una sesión activa requiere confirmar el abandono. |
| [animations en pub.dev](https://pub.dev/packages/animations) | Se revisó el paquete oficial publicado por `flutter.dev` (versión visible 3.0.0). Las transiciones necesarias se resuelven con widgets del SDK, sin añadir una dependencia únicamente para fade/slide. |

Las versiones y API de la documentación en línea se contrastan con el SDK instalado al analizar y compilar el proyecto; no se añaden banderas experimentales ni API nuevas que el SDK local no soporte.

## Instrucciones visuales previas a cada reto

La revisión del flujo añade una etapa explícita de aceptación antes de cada juego, tanto en práctica individual como en el test completo. Las demostraciones usan `AnimationController` y `CustomPainter(repaint:)` del SDK: no crean un `RoundController` ni consumen tiempo de la prueba. Al tocar **Entendido, empezar** se crea el controlador de la ronda con su duración completa. Cada ronda terminada conduce primero a las instrucciones del siguiente juego y espera otra aceptación.

Los ejemplos enseñan la secuencia observar/ocultar/repetir de memoria, un giro de 90° con respuesta Sí/No, dos filtros de posiciones y el cálculo `8 × 4 + 2 = 34`. Las animaciones se sustituyen por ejemplos guiados estáticos cuando el sistema solicita movimiento reducido; cada demostración incluye una descripción semántica y tres pasos visibles.

## Menú y explicación de cada juego

El menú ofrece cinco entradas de práctica individuales y un Test completo con los cinco juegos prácticos. Las guías de consulta no son pruebas y no se incluyen en el Test completo.

Cada juego presenta una demostración visual animada antes de comenzar; también la siguiente ronda de un test. Se usa un estado explícito de instrucciones y se espera la acción «Entendido, empezar». El controlador y el reloj de ronda se crean después de aceptar. La demostración usa su propio controlador de animación y no consume tiempo de juego.

Los iconos de plataforma adaptativos se incluyen mediante [cupertino_icons 2.0.0](https://pub.dev/packages/cupertino_icons), publicado por Flutter y verificado en pub.dev. Las ilustraciones y el icono de la aplicación son vectores propios; Fira Sans se incluye localmente con la licencia OFL.


## Ampliación: secuencias mixtas, tarjetas y animación por fases

Se amplió la investigación antes de modificar los componentes. Además del SDK y pub.dev se revisaron ejemplos originales en GitHub y trabajos de sus autores:

- [Flutter: staggered animations](https://docs.flutter.dev/ui/animations/staggered-animations): una línea de tiempo con intervalos permite ordenar desplazamiento, reordenamiento y demostración de opciones sin encadenar retardos de estado.
- [TweenSequence](https://api.flutter.dev/flutter/animation/TweenSequence-class.html) y [ejemplos de Flutter en GitHub](https://github.com/flutter/samples/blob/main/animations/README.md): se contrastaron los patrones de secuencias y animaciones repetidas.
- [gskinner: Flutter Vignettes](https://github.com/gskinnerTeam/flutter_vignettes): revisión de ejemplos de composición con Stack, Transform y dibujo vectorial en su repositorio original. No se copiaron assets ni código de estos ejemplos.
- [gskinner: Rendering Optimization Tips](https://blog.gskinner.com/archives/2022/09/flutter-rendering-optimization-tips.html): el equipo autor documenta su experiencia al construir Wonderous. Se contrastó con [las buenas prácticas de Flutter](https://docs.flutter.dev/perf/best-practices); se usan colores con alpha y límites de repintado en las ilustraciones animadas, evitando capas de opacidad innecesarias.
- [WidgetTester.pump](https://api.flutter.dev/flutter/flutter_test/WidgetTester/pump.html) y [pumpAndSettle](https://api.flutter.dev/flutter/flutter_test/WidgetTester/pumpAndSettle.html): pruebas con avances de tiempo explícitos para demos en bucle y reloj de dominio inyectado para las fases mixtas.

El flash se monta en una vista compacta sin transición de entrada, para que no quede oculto por el desplazamiento de la pregunta anterior. Su brillo dura aproximadamente 120 ms; el gestor de dominio controla por separado el plazo de la fase. El movimiento reducido ofrece un punto resaltado estable durante esa misma ventana. La recuperación conserva exactamente la misma plantilla y muestra números de selección neutrales, con edición y confirmación única.

La fila objetivo de Switch queda fuera del subárbol animado. Se desactivan también las transiciones del contenedor de preguntas de Switch para evitar mover o desvanecer el objetivo. El usuario confirmó que las opciones solo se resuelven automáticamente en las instrucciones. Los recursos siguen siendo vectores propios dibujados con Flutter, sin descargas durante el entrenamiento.
