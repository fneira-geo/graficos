# 🌡️ graficos  
Análisis y visualización de datos meteorológicos históricos para la Región de Los Ríos (Chile), con enfoque en series temporales diarias de temperatura mínima. El proyecto integra herramientas de ETL (extracción, transformación y carga), procesamiento con el paquete `CLIMATOL` para relleno de datos y homogeneidad, y generación de visualizaciones interactivas y estáticas mediante R y Python (Bokeh, Plotly, Matplotlib).  

---

## 📋 Tabla de contenidos  
- [📋 Tabla de contenidos](#-tabla-de-contenidos)  
- [🔄 Flujo de datos](#-flujo-de-datos)  
- [🚀 Inicio rápido](#-inicio-rápido)  
- [🛠️ Instalación](#️-instalación)  
- [⚙️ Configuración](#️-configuración)  
- [📂 Estructura del proyecto](#-estructura-del-proyecto)  
- [📊 Variables y definiciones](#-variables-y-definiciones)  
- [📤 Resultados y salidas](#-resultados-y-salidas)  
- [🔗 Dependencias externas](#-dependencias-externas)  
- [👤 Autoría](#-autoría)  

---

## 🔄 Flujo de datos  
```text
BBDD_2026_LOS_RIOS.xlsx (Excel con hojas CR2MET_meta, CR2MET_TN, etc.)
          ↓
lee_xls_data() → lee_CR2MET() → lee_CR2MET() [TN: temperatura mínima]
          ↓
Procesamiento: limpieza, conversión, relleno (CLIMATOL)
          ↓
Visualización: gráficos interactivos (Plotly/Bokeh), estáticos (ggplot2/Matplotlib)
          ↓
output/ → archivos .xlsx, .csv, .png, .html
```
- **Entrada**: Archivo Excel con metadatos y series diarias de variables meteorológicas.  
- **Procesamiento**: Lectura, limpieza de valores nulos, transformación a formato largo, análisis con `CLIMATOL`.  
- **Salida**: Series corregidas, resúmenes mensuales, gráficos y reportes.  

---

## 🚀 Inicio rápido  
```bash
# Clonar (si aplica) y ejecutar en R
Rscript main.R

# O en Python (actualmente solo muestra mensaje de bienvenida)
uv run python main.py
```

---

## 🛠️ Instalación  
### Python  
```bash
uv sync
```

### R  
Paquetes requeridos (detectados en `main.R` y `utils_getCR2Met.R`):  
- `readxl` (lectura de Excel)  
- `CLIMATOL` (análisis climático: relleno, homogeneidad)  
- `openxlsx` o `writexl` (escritura de resultados)  
- `ggplot2`, `plotly`, `shiny` (visualización)  
- `dotenv` (carga de `.env`)  

Instalar en R:  
```r
install.packages(c("readxl", "CLIMATOL", "openxlsx", "ggplot2", "plotly", "shiny", "dotenv"))
```

---

## ⚙️ Configuración  
### Variables de entorno (`.env` requerido)  
| Variable | Descripción |  
|----------|-------------|  
| `DATA_ENT` | Ruta al directorio de entrada con datos meteorológicos (ej. `./data/`) |  

> El archivo `.env` debe existir en la raíz del proyecto y contener:  
> ```env
> DATA_ENT=./data/
> ```

---

## 📂 Estructura del proyecto  
```
graficos/
├── main.R                 # Script principal: pipeline ETL + llamado a funciones
├── main.py                # Punto de entrada Python (actualmente placeholder)
├── config.R               # Configuración global (no mostrada, pero referenciada en main.R)
├── src/
│   ├── utils_getCR2Met.R  # Código legado para extracción CR2MET (pendiente de limpieza)
│   ├── utils_escribe_climatol.R  # Funciones para escribir salidas compatibles con CLIMATOL
│   ├── utils_pivotdata.R  # Función `pivotear()` no implementada (pivotar datos)
│   └── lee_CR2MET.R       # Función `lee_CR2MET()` para leer hojas Excel (TN, meta)
├── data/                  # Datos de entrada (BBDD_2026_LOS_RIOS.xlsx)
└── output/                # Resultados generados (vacío inicialmente)
```

---

## 📊 Variables y definiciones  
| Variable | Descripción | Unidades |  
|----------|-------------|----------|  
| `TN` | Temperatura mínima diaria | °C |  
| `meta$estacion` | Identificador único de estación | — |  
| `meta$lat`, `meta$lon` | Coordenadas geográficas | Grados decimales |  
| `meta$alt` | Altitud | metros |  
| `NA/NaN/NULL` | Valores faltantes en series | — |  

---

## 📤 Resultados y salidas  
- **Archivos esperados en `output/`**:  
  - `TN_corregida.xlsx`: Series de temperatura mínima con relleno y homogeneidad (formato `CLIMATOL`).  
  - `resumen_mensual.csv`: Promedios mensuales por estación.  
  - `graficos/`:  
    - `TN_serie.png`: Gráfico de series temporales (ggplot2).  
    - `TN_interactivo.html`: Visualización interactiva (Plotly/Bokeh).  
- **Formatos**: Excel (`.xlsx`), CSV (`.csv`), PNG (`.png`), HTML (`.html`).  
- **Interpretación**: Los datos corregidos permiten análisis de tendencias, comparaciones espaciales y detección de cambios climáticos.  

---

## 🔗 Dependencias externas  
- **Datos**:  
  - `BBDD_2026_LOS_RIOS.xlsx`: Base de datos oficial de estaciones meteorológicas (formato Excel con hojas `CR2MET_meta`, `CR2MET_TN`).  
- **Rutas**:  
  - `DATA_ENT` debe apuntar al directorio donde reside `BBDD_2026_LOS_RIOS.xlsx`.  
- **Servicios**: Ninguno.  

---

## 👤 Autoría  
**Fernando Neira-Román**  
📧 fneira.roman@gmail.com  
📅 2024