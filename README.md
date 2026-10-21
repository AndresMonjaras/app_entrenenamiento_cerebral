# Los Mojarrules · P&G Prep Mobile

App Flutter de práctica cognitiva, en español, con cinco modos principales y cuatro modos de Los Mojarrules. Grid + Memoria y Simetría + Memoria duran 3 minutos; los demás modos principales duran 5 o 6 minutos según los ajustes. Incluye instrucciones visuales animadas y retroalimentación diferida.

## Iniciar

Requiere Flutter con Dart 3.13.1 o posterior. Implementada y comprobada con Flutter 3.47.1 estable.

```bash
flutter pub get
flutter run
```

Para navegador:

```bash
flutter run -d chrome
```

## Experiencia

- **Menú principal:** tarjetas para Grid + Memoria, Simetría + Memoria, Switch Challenge, Reto numérico y Ecuaciones de trazos. Cada tarjeta, incluida la ilustración, abre Practicar.
- **Test completo:** recorre los cinco modos principales. La guía de consulta queda fuera del test.
- **Antes de cada juego:** una demostración animada explica la dinámica. Hay que pulsar **Entendido, empezar** para iniciar la ronda. El reloj comienza después de aceptar, también en las transiciones entre juegos. Switch incluye un ejemplo animado más lento de 24 segundos donde solo en las instrucciones se ejecutan pruebas automáticas con solver hasta coincidir con el objetivo.
- **Durante cada ronda:** sin explicaciones repetidas ni reloj numérico; el tiempo se visualiza únicamente como barra superior de progreso, acompañada de los controles táctiles y datos del estímulo. Estímulos ilimitados generados localmente, selección táctil inmediata y avance sin mostrar aciertos/errores en la partida. Fases y rondas avanzan automáticamente al vencer el tiempo asignado y registran omisión; se rechaza cualquier input tardío que alcanzaría la fase siguiente. El tiempo sigue contando si se abandona la app temporalmente.
- **Al terminar:** reporte con precisión, tiempos, omisiones, desglose por habilidad y revisión de respuestas. Las rondas completadas y los ajustes se guardan en el dispositivo.
- **Los Mojarrules:** Switch V2, Memoria progresiva, Chimp Test y Mixto V2 aparecen en la pantalla principal junto con las demás tarjetas. Incluye test de los cuatro modos, instrucciones por ronda, reporte acumulado e historial propio. [Detalles y fuentes de la integración](docs/mojarrules_v2.md).
- **Ajustes:** duración configurable de 5 o 6 minutos para Switch Challenge, Reto numérico y Ecuaciones de trazos. Grid + Memoria y Simetría + Memoria tienen 3 minutos fijos. Selector de dificultad (Avanzado / Experto) y vibración si el dispositivo la admite.

Es posible terminar una ronda anticipadamente desde su botón. La siguiente ronda vuelve a presentar sus instrucciones. Salir de una sesión activa requiere confirmar que se descartará. En el test, el reporte aparece al terminar la última ronda; se preserva la retroalimentación diferida durante toda la sesión.

## Reglas

- **Grid + Memoria:** recuerda puntos numerados entre ejercicios de Grid. Resuelve rotaciones de 90°, 180° o 270° y uniones de celdas activas; al final, marca los puntos en orden sobre la plantilla completa.
- **Simetría + Memoria:** recuerda puntos numerados entre comparaciones de figuras idénticas o reflejadas, con ejes vertical u horizontal. Al final, reconstruye el orden de los puntos sobre la plantilla completa.
- **Switch Challenge:** diagrama vertical con cadena de figuras de entrada, toldo superior que converge al filtro numérico superior, opciones numéricas ramificadas, toldo inferior invertido y meta estática inferior como imagen de referencia. Mantén pulsada una opción para previsualizar la permutación de forma neutra y suelta para enviar. En las instrucciones se ofrece un ejemplo más lento de 24 segundos con solver automático que prueba las opciones hasta coincidir con la meta (el solver automático actúa solo en las instrucciones; la partida real nunca revela la solución ni prueba opciones automáticamente).
- **Ecuaciones de trazos:** superposición geométrica exacta de todos los segmentos. Un trazo faltante, adicional, deformado o desplazado invalida el resultado; se aceptan líneas compartidas y fragmentos colineales que cubran exactamente el mismo dibujo.
- **Reto numérico:** genera aleatoriamente de 2 a 6 espacios con operadores aritméticos aleatorios y solución entera positiva garantizada. Conserva la prioridad formal de operaciones (multiplicación y división antes de suma y resta) y acepta cualquier permutación o alternativa válida que alcance el objetivo respetando la multiplicidad exacta de las fichas disponibles.

La precisión es aciertos/ejercicios registrados, incluidas las omisiones. El tiempo medio incluye las respuestas y los ejercicios omitidos. Los flashes pasivos intercalados no son respuestas ni se suman al tiempo medio por ejercicio. Una pregunta que queda abierta al terminar el reloj no se registra como una respuesta. No se calcula una nota oficial ni un percentil sin datos de referencia.

## Arquitectura

```text
lib/
  core/app_theme.dart                 Tema, componentes y rutas
  domain/models.dart                  Modelos inmutables y evaluación
  domain/question_generator.dart      Generadores y transformaciones
  domain/stroke_equation.dart         Superposición geométrica exacta
  domain/round_controller.dart         Estado de ronda y tiempo monotónico
  domain/mixed_sequence_controller.dart  Alternancia y recuperación ordenada
  data/progress_repository.dart        Ajustes e historial locales
  features/home/                      Menú, guía, progreso y ajustes
  features/training/                  Juegos e instrucciones visuales
  features/results/                   Analíticas y revisión final
  features/minijuegos/hub/             Sesión e historial V2 integrados al menú
  features/minijuegos/mixto_v2/         Alternancia por fases de 3.5/5/5 s
  features/minijuegos/common/          Modelos de resultados V2
```

Provider inyecta `AppStore`; `ChangeNotifier` controla cambios de pregunta y fase. Un `ValueNotifier` dedicado actualiza la barra sin reconstruir el tablero. `Stopwatch` es la fuente del tiempo; `Timer.periodic` solo solicita comprobaciones. La vista gestiona el ciclo de vida, las animaciones y los gestos. El almacenamiento usa `SharedPreferencesAsync` y serializa las escrituras.

Los puntos, cuadrículas y figuras se dibujan con `CustomPainter`. Se respetan las preferencias de movimiento reducido de Android e iOS, el escalado de texto y la navegación táctil/por teclado. La fuente Fira Sans se distribuye localmente con su licencia en `assets/fonts/OFL.txt`; la interfaz no descarga tipografías durante el uso.

## Investigación previa

La documentación oficial se investigó antes de implementar los componentes. Decisiones y enlaces:

- [Arquitectura, paquetes y temporizadores](docs/architecture_sources.md).
- [Animaciones, gestos, progreso y accesibilidad](docs/ui_sources.md).
- [Secuencias mixtas y temporizadores](docs/mixed_sequences.md).
- [Fases temporizadas, plantilla dispersa y recuperación ordenada](docs/timed_sequences.md).
- [Nuevo Switch y animaciones por fases](docs/switch_motion_sources.md).
- [Los Mojarrules: integración V2, iconos y temporización](docs/mojarrules_v2.md).
- [Ecuaciones de trazos, barra sin reloj y rondas de 3 minutos](docs/stroke_equations.md).

Dependencias principales verificadas en pub.dev: Provider 6.1.5+1, Shared Preferences 2.5.6 y Cupertino Icons 2.0.0. `pubspec.lock` conserva las versiones resueltas.

## Verificar y compilar

```bash
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```

La versión web se genera en `build/web/`; el APK de desarrollo, en `build/app/outputs/flutter-apk/app-debug.apk`. La instalación iOS requiere macOS, Xcode y configuración de firma; no se valida desde este entorno Linux. El APK debug sirve para pruebas; para publicación se necesita una compilación release con firma propia.

El historial es local: no se configura un servidor ni sincronización de cuentas. La app funciona sin conexión una vez instalada. La versión web compilada necesita servir sus archivos por HTTP; no se agrega un service worker de caché para garantizar uso web sin conexión.

Herramienta de práctica independiente, sin afiliación con P&G ni Aon. Los estímulos son originales; no se promete equivalencia psicométrica ni se reproducen preguntas oficiales.

## Validación realizada

- `flutter analyze`: sin incidencias.
- `flutter test`: 137 pruebas aprobadas, incluyendo límites por fase, selección parcial/completa, rechazo de respuestas tardías, animación de 500 ms por transición y generación numérica de 2–6 espacios.
- Android debug y web release: compilaciones correctas.
- Navegador real: tres pares punto → figura, vencimiento de la última figura, selección sobre los 24 círculos, avance automático tras recuperación y reporte final; Switch con ambos toldos y operación de seis espacios. Sin excepciones JavaScript.

Capturas de la nueva secuencia: [puntos dispersos](docs/screenshots/timed-point-first-phone.png), [selección numerada](docs/screenshots/timed-recall-numbered-phone.png), [Switch vertical](docs/screenshots/switch-reference-phone.png) y [seis espacios numéricos](docs/screenshots/numeric-six-slots-phone.png).

Capturas anteriores: [Ecuaciones de trazos](docs/screenshots/strokes-game-phone.png), [Grid sin explicaciones](docs/screenshots/clean-grid-phone.png) y [recuperación de memoria](docs/screenshots/clean-recall-phone.png).

Capturas V2: [recolección numerada](docs/screenshots/mojarrules-ordered-numbered.png) y [reporte acumulado](docs/screenshots/mojarrules-results.png).

Capturas originales: [menú de escritorio](docs/screenshots/home-desktop.png), [menú móvil](docs/screenshots/home-phone.png) e [instrucciones visuales de Switch](docs/screenshots/instructions-switch.png) y [selección numerada de memoria](docs/screenshots/recall-selected-grid.png).

## Icono de la mojarra

El recurso `images/icon.png` se conserva y se copia a `assets/icon.png`. Los iconos nativos y web se generan con:

```bash
dart run flutter_launcher_icons
```

## Reanudar en un celular por ADB

Con el dispositivo conectado y autorizado:

```bash
flutter devices
flutter run -d <identificador_del_dispositivo>
```

Si hay una sesión anterior de `flutter run`, detenla con `q` y vuelve a ejecutar el comando para incorporar también los cambios nativos de Android.

## Integración de los cambios locales de notificaciones

Se conservó el servicio de recordatorios añadido localmente. Android habilita core library desugaring, requerido por el complemento; el servicio omite su inicialización en web y en plataformas sin configuración nativa para permitir que el entrenamiento abra. No se verificó la entrega real de recordatorios en un teléfono. Los minijuegos locales se integran mediante callbacks opcionales; conservan sus reglas. Se ajustaron la presentación adaptable y el límite de exposición del Chimp Test, además de eliminar los avisos del analizador.


## Icono de la mojarra

El recurso `images/icon.png` se conserva y se copia a `assets/icon.png`. Los iconos nativos y web se generan con:

```bash
dart run flutter_launcher_icons
```

## Reanudar en un celular por ADB

Con el dispositivo conectado y autorizado:

```bash
flutter devices
flutter run -d <identificador_del_dispositivo>
```

Si hay una sesión anterior de `flutter run`, detenla con `q` y vuelve a ejecutar el comando para incorporar también los cambios nativos de Android.

## Integración de los cambios locales de notificaciones

Se conservó el servicio de recordatorios añadido localmente. Android habilita core library desugaring, requerido por el complemento; el servicio omite su inicialización en web y en plataformas sin configuración nativa para permitir que el entrenamiento abra. No se verificó la entrega real de recordatorios en un teléfono. Los minijuegos locales se integran mediante callbacks opcionales; conservan sus reglas. Se ajustaron la presentación adaptable y el límite de exposición del Chimp Test, además de eliminar los avisos del analizador.
