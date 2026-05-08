# Plantilla de Scripts R — Proyecto GRAFICOS

Guía de referencia rápida para nuevos scripts. Copia el bloque del tipo correspondiente
y reemplaza los campos entre `< >`.

---

## Tipos de script y secciones obligatorias

| Sección        | `main.R` | `utils_*.R` | `funcs_*.R` | `plt_*.R` |
|----------------|:--------:|:-----------:|:-----------:|:---------:|
| Header Roxygen | ✅       | ✅          | ✅          | ✅        |
| `# SETUP`      | ✅       | ❌          | ❌          | ❌        |
| `# DEPENDENCIAS` | ✅     | ❌          | ❌          | ❌        |
| `# FUNCIONES`  | ✅       | ✅          | ✅          | ✅        |
| `# PIPELINE`   | ✅       | opcional    | opcional    | opcional  |
| `# SALIDA`     | ✅       | opcional    | opcional    | opcional  |

**Regla crítica:** las librerías solo se cargan en `main.R`. En scripts secundarios
usar siempre la notación `paquete::funcion()`.

---

## Template: `main.R`

```r
#' @title:  main.R
#' @autor:  Fernando Neira-Román | fneira.roman@gmail.com
#' @description: <descripción breve del pipeline, una o dos líneas>
#' @section SETUP:       limpia el ambiente para evitar variables fantasma
#' @section DEPENDENCIAS: carga librerías y scripts auxiliares
#' @section FUNCIONES:   funciones o "code wrap" para el análisis
#' @section PIPELINE:    pipeline de procesamiento propiamente tal
#' @section SALIDA:      archivos de salida o output

# SETUP ------------------------------------------------------------------------
cat('\014')
try(dev.off(), silent = TRUE)
rm(list = ls())
gc()

# DEPENDENCIAS -----------------------------------------------------------------
library(readxl)
library(writexl)
library(dplyr)
library(tidyr)
library(lubridate)
# ... resto de librerías

source('config.R')
source('src/utils_<nombre>.R')
# source('src/plt_<nombre>.R')

# FUNCIONES --------------------------------------------------------------------

#' <Título de la función>
#' @param <param1> <descripción>
#' @param <param2> <descripción>
#' @return <qué retorna>
<nombre_funcion> <- function(<param1>, <param2>) {

  resultado <- dplyr::mutate(<param1>, ...)

  return(resultado)
}

# PIPELINE ---------------------------------------------------------------------

# 1. <Paso 1>
<objeto1> <- <nombre_funcion>(
  <param1> = file.path(DIR_ENT, "<archivo>.xlsx"),
  ...
)

# 2. <Paso 2>
<objeto2> <- <objeto1> %>%
  dplyr::filter(...) %>%
  dplyr::mutate(...)

# SALIDA -----------------------------------------------------------------------

writexl::write_xlsx(
  x    = list(<hoja1> = <objeto1>, <hoja2> = <objeto2>),
  path = file.path(DATA_OUT, "<nombre_output>.xlsx")
)
```

---

## Template: `utils_*.R`

Funciones de utilidad (ETL, transformación, I/O). Sin carga de librerías.

```r
#' @title:  utils_<nombre>.R
#' @description: <qué hace este script en una línea>
#' @section <SECCION1>:
#' - <descripción breve de lo que hace esta sección>
#' @section <SECCION2>:
#' - <descripción breve>

# <SECCION1> -------------------------------------------------------------------

#' <Título de la función>
#' @param <param1> <descripción>
#' @param <param2> <descripción>
#' @return <qué retorna>
<nombre_funcion1> <- function(<param1>, <param2> = <default>) {

  resultado <- <param1> %>%
    dplyr::select(dplyr::all_of(c("<col1>", "<col2>"))) %>%
    dplyr::mutate(
      <col_nueva> = as.numeric(<col1>)
    )

  return(resultado)
}

# <SECCION2> -------------------------------------------------------------------

#' <Título de la función>
#' @param <param1> <descripción>
#' @return <qué retorna>
<nombre_funcion2> <- function(<param1>) {

  out <- as.matrix(<param1>)
  dimnames(out) <- NULL

  return(out)
}
```

---

## Template: `plt_*.R`

Funciones de visualización. Sin carga de librerías; usa `ggplot2::`, `scales::`, etc.

```r
#' @title:  plt_<nombre>.R
#' @description: <qué tipo de gráfico genera en una línea>
#'
#' @section Inputs:
#' - data: <formato esperado, ej: dataframe long con columnas fecha, valor, estacion_id>
#'
#' @section Outputs:
#' - plot: <descripción del gráfico>

# FUNCIONES --------------------------------------------------------------------

#' <Título del gráfico>
#' @param data Dataframe en formato <long|wide> con <columnas requeridas>
#' @param <param2> <descripción, ej: variable meteorológica ("tn", "tx", "pp")>
#' @return ggplot object
plt_<nombre> <- function(data, <param2>) {

  p <- ggplot2::ggplot(
    data = data,
    mapping = ggplot2::aes(x = fecha, y = valor, color = estacion_id)
  ) +
    ggplot2::geom_line(linewidth = 0.6) +
    ggplot2::scale_color_manual(values = pal.RdWhBu(length(unique(data$estacion_id)))) +
    ggplot2::labs(
      title    = "<título>",
      subtitle = "<subtítulo>",
      x        = NULL,
      y        = "<unidad>",
      caption  = format(Sys.Date(), "%m - %Y")
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      text          = ggplot2::element_text(family = "Century Gothic", face = "bold"),
      plot.title    = ggplot2::element_text(size = 13, colour = "black"),
      plot.subtitle = ggplot2::element_text(size = 9,  colour = "grey60"),
      legend.position = "bottom"
    )

  return(p)
}

# SALIDA -----------------------------------------------------------------------

# Ejemplo de guardado (llamar desde main.R o pipeline):
# ggplot2::ggsave(
#   plot     = plt_<nombre>(data = <objeto>, <param2> = "pp"),
#   filename = file.path(DATA_OUT, "<nombre>.png"),
#   width = 22, height = 14, units = "cm", dpi = 150, bg = "white"
# )
```

---

## `config.R` — variables de entorno

`config.R` centraliza la carga del `.env` y define las rutas. Se llama con
`source('config.R')` desde `main.R`. No se modifica por script.

```r
#' @title:  config.R
#' @description: Configuración global e infraestructura de rutas del proyecto

dotenv::load_dot_env()

DIR_ENT  <- Sys.getenv("DATA_ENT")   # carpeta data/
DATA_OUT <- Sys.getenv("DATA_OUT")   # carpeta output/
CUT_REG  <- Sys.getenv("CUT_REG")   # código región (ej: "14")
```

---

## Convenciones rápidas

| Elemento | Convención |
|---|---|
| Variables meteo | `tn` `tx` `pp` `rd` `hr` `vv` `ps` |
| Prefijos script | `plt_` · `utils_` · `funcs_` |
| Rutas | siempre `file.path(DIR_ENT, ...)` — nunca hardcoded |
| Librerías en scripts secundarios | `paquete::funcion()` — nunca `library()` |
| Indentación | 2 espacios |
| Encoding | UTF-8 |
| Secciones | `# NOMBRE --...` (guiones hasta col 80) |
| Header Roxygen | `#' @title` `#' @description` `#' @section` |
