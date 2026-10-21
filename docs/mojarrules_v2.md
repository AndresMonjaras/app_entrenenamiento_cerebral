# Los Mojarrules: integración de los modos V2

## Organización

La pantalla principal muestra junto con las demás tarjetas los cuatro modos de Los Mojarrules —Switch V2, Memoria progresiva, Chimp Test y Mixto V2— y el **Test completo V2**. Cada ronda presenta una demostración animada y espera **Entendido, empezar**. Switch V2 e instrucciones de Switch incorporan el ejemplo extendido de 24 segundos; el solver automático opera únicamente en las instrucciones visuales previas a la partida y nunca en el modo puntuable. Los ajustes fijan una duración máxima de 5 o 6 minutos por modo. Grid + Memoria y Simetría + Memoria tienen 3 minutos fijos; los demás modos principales usan el ajuste de 5 o 6 minutos. Las fases de puntos, figuras y recuperación conservan sus plazos de 3.5, 5 y 5 segundos. Chimp termina tras seis ejercicios y Memoria progresiva puede terminar antes por sus reglas de vidas.

La integración vive en `lib/features/minijuegos/hub/`; usa callbacks para enlazar los módulos locales con su sesión e historial propios. La pantalla principal también ofrece Grid + Memoria, Simetría + Memoria, Switch Challenge, Reto numérico y Ecuaciones de trazos. Las partidas muestran únicamente los estímulos, datos y controles táctiles, con barra de progreso superior sin reloj numérico ni explicaciones repetidas. El modo progresivo usa feedback neutro durante la sesión y conserva su presentación independiente por defecto.

## Mixto V2 y secuencias combinadas

`mixto_v2_controller.dart` y los controladores de secuencias combinadas estructuran los ciclos de entrenamiento:

1. El ciclo inicia con el punto 1 durante 3.5 segundos en la plantilla dispersa (24 círculos blancos sobre fondo azul; objetivo en círculo rojo con número blanco y fade suave continuo de 500 ms al apagar y 500 ms al encender).
2. Tarea de razonamiento (Grid o Simetría/identidad) con un plazo máximo de 5 segundos.
3. Transición a punto 2 (3.5 segundos) seguido de la siguiente figura.
4. El ciclo se repite durante 3, 4 o 5 pares.
5. Fase de recuperación ordenada de 5 segundos: se conserva toda la plantilla completa con distractores. Cada toque marca números 1..N con indicador rojo.
6. Gestión de tiempos: las fases vencidas avanzan y registran omisión. Si vence la recuperación con la secuencia completa se califica; si es parcial se conserva la selección y se computa omisión. Se rechazan inputs tardíos que coincidan con la transición a la siguiente fase.

Los modos del controlador `grid` y `symmetry` permiten mantener un único tipo de razonamiento; el test V2 y la tarjeta combinada principal utilizan alternancia. Las vistas reutilizan componentes visuales existentes sin modificar su lógica. Un `Timer` cancelable solicita la transición y un reloj monotónico comprueba el plazo. Volver de segundo plano avanza una fase vencida sin consumir pruebas que el usuario no haya respondido.

## Resultados y tiempos

`MiniSessionController` controla el plazo global de cada modo con `Stopwatch`. Un `ValueNotifier` actualiza únicamente el reloj y la barra. Las instrucciones no consumen tiempo; salir temporalmente de la app sí. Se rechazan respuestas recibidas al vencer el plazo. Terminar manualmente conserva los intentos; abandonar descarta la sesión tras confirmarlo. Los diálogos se cierran si vence la ronda para devolver el reporte a la ruta correcta.

Los aciertos y errores se muestran al finalizar la última ronda. El reporte incluye precisión global ponderada por respuestas, tiempo medio, desglose por modo y revisión de la respuesta dada/esperada. Los estímulos pasivos no cuentan como intentos. La exposición de Memoria/Chimp sí forma parte del tiempo del intento. Una pregunta sin contestar al vencer no se añade como error.

`MiniProgressStore` serializa las escrituras con `SharedPreferencesAsync` en la clave independiente `mojarrules.sessions.v1`. Conserva resultados en memoria si falla el guardado e informa el problema. El historial permite reabrir los reportes; no reemplaza el historial original.

El Chimp Test conserva las mismas coordenadas al ocultar los números y cambia a cuadros blancos opacos exactamente al cumplirse 2500 ms, sin una animación que prolongue su exposición. Memoria progresiva finaliza al superar la capacidad de su tablero de 20 celdas, evitando generar posiciones imposibles.

## Icono

`assets/icon.png` es una copia del recurso proporcionado en `images/icon.png`. La configuración de `flutter_launcher_icons` 0.14.4 en `pubspec.yaml` genera Android, iOS y web:

```bash
flutter pub get
dart run flutter_launcher_icons
```

Android usa `@mipmap/ic_launcher`; los nombres de launcher Android/iOS y el manifiesto web muestran **Los Mojarrules**. Generar el icono de iOS no equivale a compilar la aplicación iOS: ese paso requiere macOS/Xcode.

## Fuentes consultadas

- [Flutter: arquitectura de aplicaciones](https://docs.flutter.dev/app-architecture/guide): separación de presentación, estado y datos. Se aplica a los módulos nuevos sin migrar el código base.
- [Flutter: rendimiento](https://docs.flutter.dev/perf/best-practices): limitar reconstrucciones y trabajo dentro de `build`; la barra tiene su propio notificador y el flash usa `CustomPainter(repaint: ...)`.
- [AnimationController](https://api.flutter.dev/flutter/animation/AnimationController-class.html): `vsync`, ciclo de vida y liberación de controladores. Las demostraciones quedan separadas de los relojes evaluados y respetan movimiento reducido.
- [PopScope](https://api.flutter.dev/flutter/widgets/PopScope-class.html): navegación con resultado tipado y confirmación al abandonar una sesión.
- [Timer](https://api.dart.dev/dart-async/Timer-class.html) y [Stopwatch](https://api.dart.dev/dart-core/Stopwatch-class.html): temporización y cancelación. El número de ticks no es la fuente del tiempo restante.
- [Shared Preferences](https://pub.dev/packages/shared_preferences): API asíncrona usada para el historial independiente.
- [Flutter Launcher Icons](https://pub.dev/packages/flutter_launcher_icons): configuración en `pubspec.yaml`, generación por plataforma y eliminación de alfa para iOS.

Los paquetes comunitarios se verificaron en pub.dev; no se presentan como paquetes oficiales de Google. Las recomendaciones de arquitectura y animación proceden de la documentación oficial de Flutter/Dart.
