# Memoria progresiva y Chimp Test

## Organización

Memoria progresiva y Chimp Test aparecen como tarjetas en la misma cuadrícula y con el mismo diseño que los demás retos principales. Switch Challenge V2 y Mixto V2 se retiraron de las opciones visibles. Cada tarjeta abre instrucciones individuales y presenta el reporte al terminar la partida.

La integración vive en `lib/features/minijuegos/hub/`; usa callbacks para enlazar cada tarjeta con su sesión individual. Las partidas muestran los estímulos, datos y controles táctiles con una barra de progreso superior. El modo progresivo usa feedback neutro durante la sesión.

## Secuencias combinadas

Grid + Memoria y Simetría + Memoria mantienen sus secuencias intercaladas. Sus fases y temporizadores se describen en [secuencias temporizadas](timed_sequences.md) y [secuencias combinadas](mixed_sequences.md).

## Resultados y tiempos

`MiniSessionController` controla el plazo de cada modo con `Stopwatch`. Un `ValueNotifier` actualiza únicamente el reloj y la barra. Las instrucciones no consumen tiempo; salir temporalmente de la app sí. Se rechazan respuestas recibidas al vencer el plazo. Terminar manualmente conserva los intentos; abandonar descarta la sesión tras confirmarlo.

El reporte individual incluye precisión, tiempo y revisión de las respuestas dadas y esperadas. Los estímulos pasivos no cuentan como intentos. La exposición de Memoria/Chimp sí forma parte del tiempo del intento.

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
