## METADATA -------------------------------------------------------------------
## nombre script    : test_RELLENO_SERIES_COMPLEJO.R
## autor            : CLAUDE SONNET 4
## version R        : R version 4.4.3 (2025-02-28 ucrt) / 2025-06-05

## LIMPIAR --------------------------------------------------------------------
cat('\014')                 # limpiar consola
try(dev.off(), silent = T)  # limpia graficos
rm(list = ls())             # limpiar ambiente
gc()                        # ejecuta garbage collection

## DIRECTORIOS ----------------------------------------------------------------
readRenviron(".env")
DATA_ENT <- Sys.getenv("DATA_ENT")
DATA_OUT <- Sys.getenv("DATA_OUT")
CUT_REG <-Sys.getenv("CUT_REG")

## LIBRERIAS ------------------------------------------------------------------
librerias <- c(
  "basemaps",
  "climatol",
  "dplyr",
  "ggplot2",
  "ggspatial",
  "terra",
  "tidync",
  "tidyr",
  "tidyterra"
)
sapply(librerias, require, character.only = TRUE, quietly = TRUE)



## FUNCIONES ------------------------------------------------------------------
# lee_xls_data <- function(ruta){
  
#   lee_xls <- function(ruta, hoja) {
#     readxl::read_excel(path = ruta,
#                        sheet = hoja,
#                        col_types = "text") %>%
#       tidyr::pivot_longer(
#         cols = -c(fecha, año, mes, dia),
#         names_to = "estacion_id",
#         values_to = "valor",
#         values_drop_na = FALSE
#       ) %>%
#       dplyr::mutate(
#         fecha = lubridate::as_date(sprintf('%s-%s-%s', año, mes, dia)),
#         valor = as.numeric(valor),
#         variable = hoja
#       ) %>%
#       dplyr::select(dplyr::all_of(
#         c(
#           "fecha",
#           "año",
#           "mes",
#           "dia",
#           "variable",
#           "estacion_id",
#           "valor"
#         )
#       ))
#   }
#   hojas_interes <- c("tn", "tx", "pp", "rd", "hr", "vv", "ps")
#   hojas <- readxl::excel_sheets(ruta)
#   lista_df <- sapply(
#     hojas[hojas %in% hojas_interes], 
#     lee_xls, 
#     ruta = ruta,
#     simplify = FALSE
#   )
# }


source('src/utils_escribe_climatol.R')

# CODIGO ----------------------------------------------------------------------



# OUTPUT ----------------------------------------------------------------------



lee_xls_data <- function(ruta) {
  
  # 1. Configuración: Fácil de modificar si cambian las hojas o columnas
  hojas_interes <- c("tn", "tx", "pp", "rd", "hr", "vv", "ps")
  cols_finales  <- c("fecha", "año", "mes", "dia", "variable", "estacion_id", "valor")
  
  # 2. Función interna de procesamiento
  # Cambiamos el orden de argumentos para que sea compatible con sapply/lapply de forma natural
  procesar_hoja <- function(hoja, path) {
    readxl::read_excel(path = path, sheet = hoja, col_types = "text") %>%
      tidyr::pivot_longer(
        cols = -c(fecha, año, mes, dia),
        names_to = "estacion_id",
        values_to = "valor",
        values_drop_na = TRUE
      ) %>%
      dplyr::mutate(
        fecha    = lubridate::as_date(sprintf('%s-%s-%s', año, mes, dia)),
        valor    = as.numeric(valor),
        variable = hoja
      ) %>%
      dplyr::select(dplyr::all_of(cols_finales))
  }
  
  # 3. Identificación de hojas (Filtro robusto)
  hojas_reales <- readxl::excel_sheets(ruta)
  hojas_a_leer <- intersect(hojas_reales, hojas_interes)
  
  # 4. Ejecución
  # Usamos setNames para que la lista resultante tenga los nombres de las hojas automáticamente
  lista_df <- stats::setNames(hojas_a_leer, hojas_a_leer) %>% 
    lapply(procesar_hoja, path = ruta)
  
  return(lista_df)
}

calcular_mensuales_pp <- function(lista_datos) {
  
  # Extraemos solo la hoja de precipitación (pp)
  if (!"pp" %in% names(lista_datos)) {
    stop("La hoja 'pp' no se encuentra en la lista de datos.")
  }
  
  df_pp <- lista_datos$pp
  
  df_pp_mensual <- df_pp %>%
    # Agrupamos por estación, año y mes
    dplyr::group_by(estacion_id, año, mes) %>%
    dplyr::summarise(
      # Contamos registros no nulos
      n_datos = dplyr::n(),
      # Si hay más de 20, sumamos; si no, NA
      valor_mensual = dplyr::if_else(n_datos > 20, 
                                     sum(valor, na.rm = TRUE), 
                                     NA_real_),
      .groups = "drop"
    ) %>%
    # Añadimos la variable para mantener consistencia
    dplyr::mutate(variable = "pp_mensual")
  
  return(df_pp_mensual)
}

calcular_pp_anual_historica <- function(pp_mensual, min_meses = 12) {

  pp_mensual %>%
    # Solo años con los meses suficientes y sin NA en el valor mensual
    dplyr::filter(!is.na(valor_mensual)) %>%
    dplyr::group_by(estacion_id, año) %>%
    dplyr::summarise(
      n_meses     = dplyr::n(),
      pp_anual    = sum(valor_mensual),
      .groups     = "drop"
    ) %>%
    dplyr::filter(n_meses >= min_meses) %>%
    # Promedio histórico por estación
    dplyr::group_by(estacion_id) %>%
    dplyr::summarise(
      n_anios          = dplyr::n(),
      pp_media_anual   = mean(pp_anual),
      pp_sd_anual      = sd(pp_anual),
      .groups          = "drop"
    )
}

calcular_mensuales_tx <- function(lista_datos) {
  
  # Extraemos solo la hoja de precipitación (pp)
  if (!"pp" %in% names(lista_datos)) {
    stop("La hoja 'pp' no se encuentra en la lista de datos.")
  }
  
  df_pp <- lista_datos$tx
  
  df_pp_mensual <- df_pp %>%
    # Agrupamos por estación, año y mes
    dplyr::group_by(estacion_id, año, mes) %>%
    dplyr::summarise(
      # Contamos registros no nulos
      n_datos = dplyr::n(),
      # Si hay más de 20, sumamos; si no, NA
      valor_mensual = dplyr::if_else(n_datos > 20, 
                                     max(valor, na.rm = TRUE), 
                                     NA_real_),
      .groups = "drop"
    ) %>%
    # Añadimos la variable para mantener consistencia
    dplyr::mutate(variable = "tx_mensual")
  
  return(df_pp_mensual)
}


calcular_mensuales_tn <- function(lista_datos) {
  
  # Extraemos solo la hoja de precipitación (pp)
  if (!"pp" %in% names(lista_datos)) {
    stop("La hoja 'pp' no se encuentra en la lista de datos.")
  }
  
  df_pp <- lista_datos$tn
  
  df_pp_mensual <- df_pp %>%
    # Agrupamos por estación, año y mes
    dplyr::group_by(estacion_id, año, mes) %>%
    dplyr::summarise(
      # Contamos registros no nulos
      n_datos = dplyr::n(),
      # Si hay más de 20, sumamos; si no, NA
      valor_mensual = dplyr::if_else(n_datos > 20, 
                                     min(valor, na.rm = TRUE), 
                                     NA_real_),
      .groups = "drop"
    ) %>%
    # Añadimos la variable para mantener consistencia
    dplyr::mutate(variable = "tn_mensual")
  
  return(df_pp_mensual)
}



# metadata
metadata <- readxl::read_excel(
  path=file.path(DATA_ENT, "BBDD_2026_LOS_RIOS.xlsx"),
  sheet = "metadata"
) %>%
  dplyr::rename(
    codigo = bna,
    latitud = lat,
    longitud = lon,
    altura = alt
  )

data <- lee_xls_data(
  ruta = file.path(DATA_ENT, "BBDD_2026_LOS_RIOS.xlsx")
  #, hoja = "tn"
)

pp_mensual <- calcular_mensuales_pp(data)
tn_mensual <- calcular_mensuales_tn(data)
tx_mensual <- calcular_mensuales_tx(data)


pp_wide <- tidyr::pivot_wider(
  data = pp_mensual,
  id_cols = c("año", "mes"),
  names_from = "estacion_id",
  values_from = "valor_mensual"
)



pp_anual_historica <- calcular_pp_anual_historica(pp_mensual)

writeClimatolFiles(
  meta = metadata,
  data = pp_wide
)

writexl::write_xlsx(
  x = list(
    metadata = metadata,
    pp_mensual = pp_mensual,
    tn_mensual = tn_mensual,
    tx_mensual = tx_mensual,
    pp_historica = pp_anual_historica
  ),
  path = "ASDF.xlsx"
)


resumen_historico <- pp_mensual %>%
  group_by(estacion_id, mes) %>%
  summarise(
    media_historica = mean(valor_mensual, na.rm = TRUE),
    desviacion_std = sd(valor_mensual, na.rm = TRUE),
    .groups = "drop"
)


