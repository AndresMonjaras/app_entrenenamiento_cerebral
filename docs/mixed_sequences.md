# Secuencias mixtas y memoria ordenada

Investigación consultada el 20 de octubre de 2026 antes de implementar el gestor:

- [Dart: Timer.periodic](https://api.dart.dev/dart-async/Timer/Timer.periodic.html): los intervalos de los callbacks pueden variar. El cronómetro global y los plazos de exposición se calculan con tiempo transcurrido; un callback solamente comprueba el estado.
- [Dart: Stopwatch](https://api.dart.dev/dart-core/Stopwatch-class.html): medición de tiempo transcurrido independiente de la cantidad de callbacks recibidos. Se inyecta el reloj en las pruebas para verificar plazos exactos.
- [Dart: Timer.cancel](https://api.dart.dev/dart-async/Timer/cancel.html): se cancelan tanto el refresco periódico como el timer del flash al finalizar o destruir la ronda.
- [Flutter: AnimationController](https://api.flutter.dev/flutter/animation/AnimationController-class.html) y [su implementación oficial en GitHub](https://github.com/flutter/flutter/blob/stable/packages/flutter/lib/src/animation/animation_controller.dart): las animaciones visuales pertenecen a widgets con `vsync` y sus controladores se liberan en `dispose`. El gestor de dominio no debe depender de que una animación termine para calificar respuestas o para consumir el cronómetro global.
- [Flutter: AppLifecycleState](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html): el sistema puede omitir avisos de ciclo de vida y no presentar frames al estar en segundo plano. `refresh()` vuelve a comprobar el plazo real; un callback tardío avanza la fase vencida y registra omisión, sin inventar respuestas ni consumir fases no alcanzadas.

## Comportamiento

`MixedSequenceController` controla la máquina de estados y las transiciones entre fases. `RoundController` conserva la cuenta regresiva, la recopilación silenciosa de resultados y la propiedad de todos los temporizadores.

```text
Punto 1 (3.5s) → Grid o Simetría/identidad (máx 5s) → Punto 2 (3.5s) → Figura ...
       ↑                                                                   ↓
       └──────── nueva plantilla (24 círculos) ← Recuperación ordenada (5s)┘
```

- **Estructura del ciclo:** comienza por el punto 1 durante 3.5 segundos → tarea de Grid o Simetría/identidad durante un máximo de 5 segundos → punto 2 (3.5 segundos) → figura, repitiéndose durante 3, 4 o 5 pares. Al terminar los pares, se presenta la fase de recuperación ordenada durante 5 segundos.
- **Plantilla visual:** se compone de 24 círculos blancos dispersos aleatoriamente sobre fondo azul. Durante la fase de recuperación se conserva toda la plantilla completa incluyendo distractores, sin resaltar de antemano cuáles fueron los estímulos mostrados.
- **Estímulo de memoria:** cada objetivo es un círculo rojo con número blanco centrado que realiza un fade suave de 500 ms para apagar y 500 ms para prender durante toda la ventana de 3500 ms. No hay corte brusco ni fase neutra de 500 ms final; la última aclaración de especificación prevalece sobre cualquier límite anterior.
- **Grid y Simetría:** Grid genera rotaciones de 90°, 180° o 270° en sentido horario y unión de celdas. Simetría e identidad genera comparaciones de igualdad o reflexiones (vertical u horizontal). Tienen un límite estricto de 5 segundos por ejercicio.
- **Temporización y omisiones:**
  - Si una fase vence su tiempo límite (3.5 s en punto, 5 s en figura o 5 s en recuperación), avanza automáticamente y registra omisión.
  - Al vencer el plazo de la fase de recuperación ordenada: si la selección está completa (se marcaron todos los N puntos requeridos) se evalúa normalmente; si la selección es parcial, se conserva la selección efectuada por el usuario pero se marca formalmente como omisión.
  - Se rechaza estrictamente cualquier input tardío que alcanzaría o afectaría a la fase siguiente.
- **Recuperación ordenada:** cada toque marca el punto con un círculo rojo y su número de orden (1..N). Se exige la secuencia exacta de aparición.
- **Modos principales:** la pantalla muestra **Grid + Memoria** y **Simetría + Memoria** como tarjetas separadas. Cada una intercala sus ejercicios de razonamiento con flashes de puntos y termina con su recuperación ordenada.
- **Mixto V2:** se retiró de las opciones del menú. Grid + Memoria y Simetría + Memoria conservan sus propios flujos intercalados.
- **Duración de ronda:** Grid + Memoria y Simetría + Memoria duran 3 minutos fijos; los demás juegos principales duran 5 o 6 minutos según ajustes. Durante la partida no hay explicaciones repetidas ni reloj numérico, únicamente la barra de progreso y los controles y datos del estímulo.

## Verificación

Las pruebas unitarias y de widgets cubren los plazos de fase (3.5 s y 5 s), la plantilla de 24 puntos dispersos, el desvanecimiento continuo, la evaluación y omisión en vencimiento y rechazo de input extemporáneo. La consolidación de métricas y validación general queda a cargo del coordinador.
