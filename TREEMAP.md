# Proyecto: graficos

_Generado: 2026-05-14 10:52_

## Estructura

```
graficos/
├── src
│   ├── plt_heatmap.R  # NOT IMPLEMENTED. Crear y disponibilizar mapas de calor asociados a la cantidad de datos disponibles en la serie de datos
│   ├── plt_mapa.R  # —
│   ├── plt_ts_anomaly.R  # grafico de serie de tiempo y anamolias su enfoque es mostrar aquellos valores anomalos en la serie de tiempo
│   ├── qdm_bias_correction.R  # —
│   ├── qdm_bias_correction_v2.R  # —
│   ├── utils_calcular_climatologia_anual.R  # hace analisis de media mensual de los datos en formato estandar
│   ├── utils_calcular_mensuales.R  # Calcula agregados mensuales para una variable meteorológica
│   ├── utils_carga_BaseMaps.R  # cargar datos relativos a capas base, como dpa y satelite
│   ├── utils_color.R  # distintas paletas de colores y rampas de colores para diseño y uso en graficos, como funciones.
│   ├── utils_escribe_climatol.R  # Formatea dataframe wide y metadata al formato .est/.dat de CLIMATOL.
│   ├── utils_extrae_CR2Met.R  # legacy outdated code extraccion CR2MET
│   ├── utils_getCR2Met.R  # legacy outdated code extraccion CR2MET
│   ├── utils_lee_xls_data.R  # Lee datos meteorológicos diarios desde Excel
│   └── utils_pivotdata.R  # NOT IMPLEMENTED
├── .env
├── config.R  # Configuración Global e Infraestructura
├── graficos.Rproj
├── LICENSE
├── main.py  # —
├── main.R  # Pipeline ETL de análisis climático, procesamiento de datos
├── metadata.yaml
├── PP-m_1990-2020.txt  # HOMOGEN() APPLICATION OUTPUT  (From R's contributed package 'climatol' 4.3-2a)
├── pyproject.toml
├── README.md  # 🌡️ graficos · 📋 Tabla de contenidos · 🔄 Flujo de datos
└── TEMPLATE_R.md  # Plantilla de Scripts R — Proyecto GRAFICOS · Tipos de script y secciones obligatorias · Template: `main.R`
```

## Descripción de archivos

### `plt_heatmap.R`
NOT IMPLEMENTED. Crear y disponibilizar mapas de calor asociados a la cantidad de datos disponibles en la serie de datos

### `plt_mapa.R`
—

### `plt_ts_anomaly.R`
grafico de serie de tiempo y anamolias su enfoque es mostrar aquellos valores anomalos en la serie de tiempo

### `qdm_bias_correction.R`
—

### `qdm_bias_correction_v2.R`
—

### `utils_calcular_climatologia_anual.R`
hace analisis de media mensual de los datos en formato estandar

### `utils_calcular_mensuales.R`
Calcula agregados mensuales para una variable meteorológica

### `utils_carga_BaseMaps.R`
cargar datos relativos a capas base, como dpa y satelite

**BASEMAPS DATA**

**MAPA SIMPLE**
· `figBase(data,
                    titulo = "titulo",
                    subtitulo = "subtitulo",
                    fill = "fill",
                    base = topo_base,
                    alfa = 0.5)`  — —
· `coordBase(p)`  — —

### `utils_color.R`
distintas paletas de colores y rampas de colores para diseño y uso en graficos, como funciones.

**meme_palette**

**classic_palette**

### `utils_escribe_climatol.R`
Formatea dataframe wide y metadata al formato .est/.dat de CLIMATOL.

### `utils_extrae_CR2Met.R`
legacy outdated code extraccion CR2MET

### `utils_getCR2Met.R`
legacy outdated code extraccion CR2MET

**LIMPIAR**

**AMBIENTE**

**LIBRERIAS**

**FUNCIONES**

**DIRECTORIOS**

**CODIGO**

**puntos aleatorios**

### `utils_lee_xls_data.R`
Lee datos meteorológicos diarios desde Excel

### `utils_pivotdata.R`
NOT IMPLEMENTED

### `config.R`
Configuración Global e Infraestructura

**LIBRERIAS -----------------------------------------------------------------**

**AMBIENTE ------------------------------------------------------------------**

### `main.py`
—

· `main()`  — —

### `main.R`
Pipeline ETL de análisis climático, procesamiento de datos

**SETUP**

**DEPENDENCIAS**

**PIPELINE**

**SALIDA**
· `escribe_climatol(meta, data, ruta, nombre, excluidas = NULL)`  — 1. Exportar archivo Climatol

### `PP-m_1990-2020.txt`
HOMOGEN() APPLICATION OUTPUT  (From R's contributed package 'climatol' 4.3-2a)

### `README.md`
🌡️ graficos · 📋 Tabla de contenidos · 🔄 Flujo de datos

### `TEMPLATE_R.md`
Plantilla de Scripts R — Proyecto GRAFICOS · Tipos de script y secciones obligatorias · Template: `main.R`

## Call Graph

### Python

### R

`qdm_bias_correction.R`
  → qdm_bias_correction_v2.R  (qdm_apply, qdm_correct, qdm_eval, qdm_matrix, qdm_station)

`main.R`
  → config.R
  → utils_calcular_climatologia_anual.R  (calcular_climatologia_anual)
  → utils_calcular_mensuales.R  (calcular_mensuales)
  → utils_escribe_climatol.R  (writeClimatolFiles)
  → utils_lee_xls_data.R  (lee_xls_data)
