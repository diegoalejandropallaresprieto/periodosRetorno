# Análisis de Sensibilidad Algorítmica y Periodos de Retorno - Río Bravo (1950-2025)

**Autor:** Diego Pallares | Braulio Silva

**Módulo:** Periodos de retorno y sensibilidad por modelo (Evaluación de Estimadores)

Este módulo ejecuta el análisis final de frecuencias hidrológicas de los seis tributarios del Río Bravo. A diferencia de las evaluaciones estándar, este análisis no solo compara diferentes familias de distribuciones probabilísticas, sino que cuantifica la **incertidumbre algorítmica** introducida por los métodos de estimación de parámetros.

## Enfoque Analítico
El pipeline evalúa la sensibilidad de los cuantiles de diseño ($T_r$ desde 2 hasta 100 años) a través de 5 aproximaciones programadas en el núcleo del proyecto:
1. `Gumbel` mediante Método de Momentos.
2. `Gumbel` mediante Máxima Verosimilitud (MLE).
3. `Exponencial` de 1 parámetro.
4. `Exponencial` de 2 parámetros.
5. `Distribución Generalizada de Valores Extremos (GEV)` mediante MLE.

## Hallazgos Clave de Sensibilidad
El análisis automatizado permite a los tomadores de decisiones binacionales observar dos fenómenos críticos:

* **Sensibilidad Inter-Modelo:** Divergencia en las colas pesadas. La distribución *GEV* tiende a proyectar volúmenes de diseño más conservadores (altos) en periodos de retorno de 50 y 100 años, contrastando severamente con las distribuciones *Exponenciales*, las cuales subestiman la magnitud de eventos extremos de baja probabilidad.
* **Sensibilidad Intra-Modelo (Incertidumbre Paramétrica):** Al aislar la distribución *Gumbel*, se evidencia que la selección del algoritmo de ajuste altera el volumen final. El *Método de Momentos* demuestra mayor sensibilidad a los valores atípicos históricos respecto a la estimación por *Máxima Verosimilitud (MLE)*, generando deltas de incertidumbre cuantificables en los escenarios de largo plazo.
