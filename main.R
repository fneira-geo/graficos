#' @title:  main.R
#' @autor:  Fernando Neira-Román | fneira.roman@gmail.com
#' @description: Pipeline ETL de análisis climático, procesamiento de datos 
#' meteorologicos, de estaciones en la región de Los Ríos (Chile). Automatiza
#' lectura de datos diarios -> mensual. Prepara formato de datos y realiza,
#' analisis mediante el paquete CLIMATOL para relleno y analisis de homogeneidad.
#' @section SETUP:  limpia el ambiente para evitar variables fantasma
#' @section ENTORNO: carga variables de entorno para scripts, directorios u otros 
#' @section DEPENDENCIAS: carga de las distitnas librerias necesarias
#' @section FUNCIONES: funciones o "code wrap" para el analisis del codigo
#' @section PIPELINE: pipeline de procesamiento propiamente tal
#' @section SALIDAS:  archivos de salida o output

# SETUP ------------------------------------------------------------------------
cat('\014')
try(dev.off(), silent = TRUE)
rm(list = ls())
gc()

# DEPENDENCIAS ----------------------------------------------------------------
source('config.R')
source('src/utils_escribe_climatol.R')

source('src/utils_lee_xls_data.R')
source('src/utils_calcular_climatologia_anual.R')
source('src/utils_calcular_mensuales.R')

meses <- factor(1:12, labels= 1:12, levels = 1:12, order = TRUE)
años  <- factor(1900:2100, labels=1900:2100, levels = 1900:2100, order = TRUE)


# PIPELINE --------------------------------------------------------------------

# 1.1 Cargar metadatos estaciones
metadata_estaciones <- read_excel(
  path = file.path(DIR_ENT, "BBDD_RAW_2026_DGA-INIA_LOS_RIOS.xlsx"),
  sheet = "metadata"
) %>%
  rename(
    codigo   = bna,
    latitud  = lat,
    longitud = lon,
    altura   = alt
  )

# 1.2. Cargar datos diarios
data <- lee_xls_data(file.path(DIR_ENT, "BBDD_RAW_2026_DGA-INIA_LOS_RIOS.xlsx"))

# 1.3. Calcular agregados mensuales
pp_mensual <- calcular_mensuales(data, "pp", "sum")
tn_mensual <- calcular_mensuales(data, "tn", "min")
tx_mensual <- calcular_mensuales(data, "tx", "max")

# 2.1. Cargar metadata de datos ERA5
metadata_ERA5 <- read_excel(
  path = file.path(DIR_ENT, "BBDD_RAW_2026_ERA5_LOS_RIOS.xlsx"),
  sheet = "metadata"
) %>%
  rename(
    codigo   = bna,
    latitud  = lat,
    longitud = lon,
    altura   = alt
  )

# 2.2 cargar datos era5
data_era5 <- lee_xls_data(file.path(DIR_ENT, "BBDD_RAW_2026_ERA5_LOS_RIOS.xlsx"))

# pp_era5 <- data_era5$pp %>% dplyr::mutate(valor = valor * 1000 * 30 )
pp_era5 <- data_era5$pp %>%
  dplyr::mutate(
    valor_mensual = valor * 1000 * days_in_month(fecha), 
    variable = "pp_mensual", 
    n_datos = days_in_month(fecha)
  ) %>%
  dplyr::select(any_of(c("estacion_id", "año", "mes", "valor_mensual", "variable")))

tn_era5 <- data_era5$tn %>% dplyr::mutate(valor = valor - 273.5, valor_mensual = valor, variable = "tn_mensual") %>%
  dplyr::select(any_of(c("estacion_id", "año", "mes", "valor_mensual", "variable")))

tx_era5 <- data_era5$tx %>% dplyr::mutate(valor = valor - 273.5, valor_mensual = valor, variable = "tx_mensual") %>%
  dplyr::select(any_of(c("estacion_id", "año", "mes", "valor_mensual", "variable")))

# 5. Transformar datos estaciones a formato wide para climatología
pp_wide <- pivot_wider(
  data = dplyr::rows_append(pp_mensual, pp_era5),
  id_cols = c("año", "mes"),
  names_from = "estacion_id",
  values_from = "valor_mensual"
) %>%
  dplyr::mutate(
    año = factor(año, levels = años),
    mes = factor(mes, levels = meses)
) %>%
  arrange(año, mes)


tn_wide <- pivot_wider(
  data = dplyr::rows_append(tn_mensual, tn_era5),
  id_cols = c("año", "mes"),
  names_from = "estacion_id",
  values_from = "valor_mensual"
)

tx_wide <- pivot_wider(
  data = dplyr::rows_append(tx_mensual, tx_era5),
  id_cols = c("año", "mes"),
  names_from = "estacion_id",
  values_from = "valor_mensual"
) %>%
  arrange(año, mes)


metadata_wide <- dplyr::bind_rows(
  metadata_estaciones %>% select( all_of(c("nombre", "codigo", "latitud", "longitud", "altura")) ),
  metadata_ERA5 %>% select( all_of(c("nombre", "codigo", "latitud", "longitud", "altura")) )
) 

names(pp_wide)

metadata_wide


# # 5. Calcular climatología histórica
# pp_anual_historica <- calcular_climatologia_anual(pp_mensual)

# # 6. Calcular resumen histórico mensual
# resumen_historico <- pp_mensual %>%
#   group_by(estacion_id, mes) %>%
#   summarise(
#     media_historica = mean(valor_mensual, na.rm = TRUE),
#     desviacion_std = sd(valor_mensual, na.rm = TRUE),
#     .groups = "drop"
#   )


# SALIDA ----------------------------------------------------------------------

# 1. Exportar archivo Climatol
escribe_climatol <- function(meta, data, ruta, nombre){
  #' @ruta donde queda el archivo
  #' @meta donde salen metadatos
  #' @data de donde salen los datos
  
  meta <- na.omit(meta)
  
  data <- data %>%
    dplyr::mutate(año = as.character(año) ) %>%
    dplyr::filter(año > 1989 & año < 2021)

  #print(min(data[["año"]]))
  #print(max(data[["año"]]))

  out <- writeClimatolFiles( meta = meta, data = data )

  # graba los metadatos de las estaciones
  write.table(
    x = out[["meta"]],
    file = file.path(ruta, "CLIMATOL", paste0(nombre, ".est")),
    row.names = FALSE,
    col.names = FALSE
  )

  # graba los datos diarios
  write(
    x = out$data,
    file = file.path(ruta, "CLIMATOL", paste0(nombre, ".dat"))
  )
}


escribe_climatol(ruta = "output/", meta = metadata_wide, data = pp_wide, nombre = "PP_1990-2020")

# file.exists(
#   file.path(
#     file.path('./output/CLIMATOL', "PP_1990-2020.dat")
#   )
# )

# setwd("h:/PORTFOLIO/graficos/")
# OLD <- getwd()
# setwd("output/CLIMATOL")

list.files()

climatol::homogen(
  varcli = "PP",
  anyi = "1990",
  anyf = "2020"
)

climatol::homogen(
    file.path("PP"),
    1990,
    2020,
    onlyQC = T,
    expl = T,
    cex = 0.8,
    std = 2,
    wd = c(0, 0, 100),
    annual = 'total',
    metad = T,
    na.strings = NA,
    vmin = 0,
    # rlemax = 365,
)


# 2. Exportar resultados a Excel
write_xlsx(
  x = list(
    metadata        = metadata_wide,
    pp_mensual      = pp_wide,
    tn_mensual      = tn_wide,
    tx_mensual      = tx_wide#,
    # pp_historica    = pp_anual_historica,
    # resumen_mensual = resumen_historico
  ),
  path = file.path("output/", "_FICHA2026_BBDD_CLIMA_MENSUAL.xlsx")
)


