# Secuencias temporizadas, plantilla dispersa y recuperación ordenada

Especificación técnica de las secuencias de memoria intercalada y fases temporizadas (`MixedSequenceController` y `RoundController`):

## 1. Estructura de fases y alternancia

El flujo interno de memoria intercalada (**Grid + Memoria** o **Simetría + Memoria**):

```text
Punto 1 (3.5 s) → Razonamiento 1 (máx 5 s) → Punto 2 (3.5 s) → Razonamiento 2 (máx 5 s) ...
       ↑                                                                           ↓
       └────────── Nueva plantilla aleatoria ← Recuperación ordenada (5 s) ────────┘
```

1. **Inicio en Punto 1:** la secuencia inicia siempre con la presentación del primer punto objetivo durante una ventana de 3500 ms (3.5 s).
2. **Razonamiento intercalado:** se presenta un ejercicio de Grid (rotación o unión) o de Simetría e identidad (comparación o reflejo), con un límite estricto de 5 segundos.
3. **Punto 2 y subsiguientes:** se presenta el siguiente punto de la secuencia (3.5 s) seguido de la siguiente figura.
4. **Longitud del ciclo:** el ciclo se compone de 3, 4 o 5 pares (punto + figura) según la dificultad y la progresión.
5. **Recuperación ordenada:** al concluir los pares de estímulo, se activa una fase de recuperación de 5 segundos donde el usuario debe marcar los puntos observados en el orden exacto de aparición.

## 2. Plantilla visual de 24 puntos y estímulo continuo

- **Plantilla:** se genera un plano de fondo azul con 24 círculos blancos dispersos de forma aleatoria guardando distancias mínimas para evitar solapamientos.
- **Estímulo visual:** cada punto objetivo es un círculo rojo que contiene centrado su número blanco correspondiente (1..N).
- **Fade suave continuo:** la animación modula la opacidad continuamente con un ciclo de 500 ms para apagar y 500 ms para encender a lo largo de toda la ventana de 3500 ms.
- **Sin corte brusco:** no existe corte abrupto ni fase neutra estática final de 500 ms; la especificación de 3.5 s con fade continuo prevalece sobre cualquier límite anterior.
- **Persistencia en recuperación:** al llegar a la fase de recuperación se conserva la plantilla completa con los 24 círculos (manteniendo todos los distractores). Los puntos seleccionados por el usuario se marcan en rojo numerados correlativamente `1..N`.

## 3. Temporización, vencimientos y manejo de omisiones

- **Avance automático:** si expira el tiempo límite de una fase activa (3.5 s para punto, 5 s para figura, 5 s para recuperación), el sistema avanza de inmediato a la siguiente fase y registra la prueba como omitida (`skipped = true`).
- **Recuperación al vencer el reloj de 5 s:**
  - **Recuperación completa:** si el usuario ya había seleccionado la cantidad requerida de puntos (los N objetivos) antes de que venza el plazo, la respuesta se evalúa comparando la secuencia elegida contra el orden esperado.
  - **Recuperación parcial:** si el usuario seleccionó menos puntos de los requeridos al expirar el tiempo, se conserva la selección parcial efectuada pero el intento se registra formalmente como omitido.
- **Rechazo de input extemporáneo:** se descarta cualquier interacción o toque táctil tardío que haya ocurrido en la frontera de tiempo y que alcanzaría o afectaría a la fase siguiente.

## 4. Modalidades y duraciones de ronda

- **Memoria de puntos independiente:** entrena la memorización de puntos consecutivos sobre la plantilla de 24 puntos y posterior recuperación ordenada de 5 s.
- **Grid y Simetría independientes:** intercalan sus respectivas tareas de razonamiento con flashes de puntos.
- **Modos principales:** Grid + Memoria y Simetría + Memoria aparecen como dos tarjetas independientes; cada modo intercala su tarea de razonamiento con memoria.
- **Duraciones de ronda:**
  - Rondas de 3 minutos: **Grid + Memoria** y **Simetría + Memoria**.
  - Rondas de 5 o 6 minutos: resto de juegos según la configuración de ajustes.
- **Interfaz en juego:** sin explicaciones repetidas ni relojes numéricos durante la partida; el tiempo restante se visualiza únicamente mediante la barra superior de progreso, conservando solo los controles e información esencial del reto.
