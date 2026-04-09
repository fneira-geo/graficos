## METADATA -------------------------------------------------------------------
## nombre script    : main.R - Pipeline ETL de análisis climático
## autor            : Fernando Neira-Román
## version R        : 4.4.3+
## descripcion      : Procesamiento de datos meteorológicos de estaciones
##                    en la Región de Los Ríos (Chile). Automatiza:
##                    lectura Excel → procesamiento diario/mensual → salida

## SETUP -----------------------------------------------------------------------
cat('\014')
try(dev.off(), silent = TRUE)
rm(list = ls())
gc()

## ENTORNO --------------------------------------------------------------------
readRenviron(".env")
DATA_ENT <- Sys.getenv("DATA_ENT")
DATA_OUT <- Sys.getenv("DATA_OUT")
CUT_REG  <- Sys.getenv("CUT_REG")

## DEPENDENCIAS ---------------------------------------------------------------
library(basemaps)
library(climatol)
library(dplyr)
library(ggplot2)
library(ggspatial)
library(lubridate)
library(readxl)
library(terra)
library(tidync)
library(tidyr)
library(tidyterra)
library(writexl)

source('src/utils_escribe_climatol.R')


## ============================================================================
## FUNCIONES
## ============================================================================

#' Lee datos meteorológicos diarios desde Excel
#' @param ruta Ruta al archivo BBDD_2026_LOS_RIOS.xlsx
#' @return Lista con dataframes por variable meteorológica
lee_xls_data <- function(ruta) {
  hojas_interes <- c("tn", "tx", "pp", "rd", "hr", "vv", "ps")
  cols_finales  <- c("fecha", "año", "mes", "dia", "variable", "estacion_id", "valor")

  procesar_hoja <- function(hoja, path) {
    readxl::read_excel(path = path, sheet = hoja, col_types = "text") %>%
      tidyr::pivot_longer(
        cols = -c(fecha, año, mes, dia),
        names_to = "estacion_id",
        values_to = "valor",
        values_drop_na = TRUE
      ) %>%
      dplyr::mutate(
        fecha    = as_date(sprintf('%s-%s-%s', año, mes, dia)),
        valor    = as.numeric(valor),
        variable = hoja
      ) %>%
      dplyr::select(all_of(cols_finales))
  }

  hojas_reales <- readxl::excel_sheets(ruta)
  hojas_a_leer <- intersect(hojas_reales, hojas_interes)

  setNames(hojas_a_leer, hojas_a_leer) %>%
    lapply(procesar_hoja, path = ruta)
}

#' Calcula agregados mensuales para una variable meteorológica
#' @param lista_datos Lista de datos diarios por variable
#' @param variable Nombre de variable (ej: "pp", "tn", "tx")
#' @param tipo_agregacion Función de agregación ("sum", "min", "max", "mean")
#' @param min_dias Mínimo de datos diarios para incluir agregado (default: 20)
#' @return Dataframe con agregados mensuales
calcular_mensuales <- function(lista_datos, variable, tipo_agregacion = "sum", min_dias = 20) {
  if (!variable %in% names(lista_datos)) {
    stop(sprintf("Variable '%s' no encontrada en datos.", variable))
  }

  datos <- lista_datos[[variable]]

  # Función de agregación
  fn_agg <- switch(tipo_agregacion,
                   sum = sum,
                   min = min,
                   max = max,
                   mean = mean,
                   stop(sprintf("Tipo de agregación '%s' no soportado.", tipo_agregacion)))

  datos %>%
    group_by(estacion_id, año, mes) %>%
    summarise(
      n_datos = n(),
      valor_mensual = if_else(n_datos >= min_dias,
                              fn_agg(valor, na.rm = TRUE),
                              NA_real_),
      .groups = "drop"
    ) %>%
    mutate(variable = sprintf("%s_mensual", variable))
}

#' Calcula climatología histórica anual
#' @param datos_mensuales Dataframe de datos mensuales
#' @param min_meses Mínimo de meses para considerar año válido (default: 12)
#' @return Dataframe con estadísticas anuales por estación
calcular_climatologia_anual <- function(datos_mensuales, min_meses = 12) {
  if (nrow(datos_mensuales) == 0) {
    stop("Dataframe vacío: no hay datos mensuales para procesar.")
  }

  datos_mensuales %>%
    filter(!is.na(valor_mensual)) %>%
    group_by(estacion_id, año) %>%
    summarise(
      n_meses   = n(),
      valor_anual = sum(valor_mensual),
      .groups   = "drop"
    ) %>%
    filter(n_meses >= min_meses) %>%
    group_by(estacion_id) %>%
    summarise(
      n_anos     = n(),
      media_anual = mean(valor_anual),
      sd_anual   = sd(valor_anual),
      .groups    = "drop"
    )
}


## PIPELINE ------------------------------------------------------------------

# 1. Cargar metadatos
metadata <- read_excel(
  path = file.path(DATA_ENT, "BBDD_2026_LOS_RIOS.xlsx"),
  sheet = "metadata"
) %>%
  rename(
    codigo   = bna,
    latitud  = lat,
    longitud = lon,
    altura   = alt
  )

# 2. Cargar datos diarios
data <- lee_xls_data(file.path(DATA_ENT, "BBDD_2026_LOS_RIOS.xlsx"))

# 3. Calcular agregados mensuales
pp_mensual <- calcular_mensuales(data, "pp", "sum")
tn_mensual <- calcular_mensuales(data, "tn", "min")
tx_mensual <- calcular_mensuales(data, "tx", "max")

# 4. Transformar a formato wide para climatología
pp_wide <- pivot_wider(
  data = pp_mensual,
  id_cols = c("año", "mes"),
  names_from = "estacion_id",
  values_from = "valor_mensual"
)

# 5. Calcular climatología histórica
pp_anual_historica <- calcular_climatologia_anual(pp_mensual)

# 6. Calcular resumen histórico mensual
resumen_historico <- pp_mensual %>%
  group_by(estacion_id, mes) %>%
  summarise(
    media_historica = mean(valor_mensual, na.rm = TRUE),
    desviacion_std = sd(valor_mensual, na.rm = TRUE),
    .groups = "drop"
  )


## SALIDA ---------------------------------------------------------------------

# 1. Exportar archivo Climatol
writeClimatolFiles(meta = metadata, data = pp_wide)

# 2. Exportar resultados a Excel
write_xlsx(
  x = list(
    metadata        = metadata,
    pp_mensual      = pp_mensual,
    tn_mensual      = tn_mensual,
    tx_mensual      = tx_mensual,
    pp_historica    = pp_anual_historica,
    resumen_mensual = resumen_historico
  ),
  path = file.path(DATA_OUT, "ASDF_FICHA2026_MARZO_BBDD_CLIMA_MENSUAL.xlsx")
)


