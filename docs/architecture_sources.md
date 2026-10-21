# Investigación de arquitectura

Fuentes oficiales consultadas en la red antes de implementar los componentes.

- [Guía de arquitectura de Flutter](https://docs.flutter.dev/app-architecture/guide): separación de vistas, modelos de vista y repositorios. Las vistas gestionan presentación, animación y eventos; el controlador contiene las reglas de entrenamiento.
- [Recomendaciones oficiales de arquitectura](https://docs.flutter.dev/app-architecture/recommendations): flujo de datos unidireccional, modelos inmutables e inyección de dependencias. `ChangeNotifier` es una opción condicional adecuada para este proyecto; `provider` es el paquete recomendado para la inyección.
- [Ejemplo oficial de la capa de UI](https://docs.flutter.dev/app-architecture/case-study/ui-layer): modelos de vista con `ChangeNotifier`.
- [provider 6.1.5+1](https://pub.dev/packages/provider) y [ChangeNotifierProvider](https://pub.dev/documentation/provider/latest/provider/ChangeNotifierProvider-class.html): usar `create` para instancias nuevas y su liberación automática; reservar `.value` para instancias existentes.
- [Timer.periodic de Dart](https://api.dart.dev/dart-async/Timer/Timer.periodic.html): los intervalos entre callbacks pueden variar. El contador no resta ticks; calcula el tiempo desde una fuente de tiempo transcurrido.
- [Stopwatch de Dart](https://api.dart.dev/dart-core/Stopwatch-class.html): fuente del tiempo transcurrido de una ronda, inyectable en las pruebas. Un `Timer` de 100 ms actualiza un `ValueNotifier<Duration>` independiente del estado de la pregunta.
- [AppLifecycleListener](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html): la vista refresca el reloj al recuperar el foco. El tiempo de simulación sigue transcurriendo en segundo plano; no existe una pausa de entrenamiento.
- [shared_preferences 2.5.6](https://pub.dev/packages/shared_preferences) y [SharedPreferencesAsync](https://pub.dev/documentation/shared_preferences/latest/shared_preferences/SharedPreferencesAsync-class.html): API actual recomendada para nuevos proyectos, sin caché local. Persistencia de preferencias e historial de práctica, con errores recuperables. No es almacenamiento de información crítica.

## Decisiones

Los estímulos se generan localmente con reglas verificables y datos inmutables. El controlador registra cada respuesta sin emitir aciertos o errores a la vista durante la ronda. Las métricas se construyen al finalizar. Los observadores del cronómetro son independientes de los cambios de pregunta para evitar reconstruir el tablero diez veces por segundo.

Las reglas de Switch interpretan cada dígito como una posición de origen (base uno). Grid combina por unión, gira en sentido horario y refleja según el eje indicado. El reto numérico usa todos los operandos exactamente una vez y respeta la precedencia habitual de operaciones. Cada ejercicio generado incluye una solución válida.


## Compatibilidad de las notificaciones añadidas localmente

Al retomar el trabajo se conservó la dependencia local `flutter_local_notifications` 18.0.1. La compilación Android detectó que faltaba habilitar core library desugaring; se añadió la opción y la dependencia en Gradle sin cambiar la versión del complemento. La inicialización se limita a Android/iOS, las plataformas configuradas por este servicio, para permitir el inicio web y de escritorio.

Fuentes consultadas para esta corrección: [documentación del complemento 18.0.1](https://pub.dev/packages/flutter_local_notifications/versions/18.0.1) y [configuración Kotlin DSL de Android para desugaring](https://developer.android.com/studio/write/java8-support). Se agregó una prueba que comprueba que un destino no configurado no intenta iniciar el complemento. La recepción de notificaciones nativas no forma parte de la validación de estos minijuegos.
