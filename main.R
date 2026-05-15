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

source('src/qdm_bias_correction_v2.R')

meses <- factor(1:12, labels = 1:12, levels = 1:12, order = TRUE)
años <- factor(1900:2100, labels = 1900:2100, levels = 1900:2100, order = TRUE)


# PIPELINE --------------------------------------------------------------------

# 1.1 Cargar metadatos estaciones
metadata_estaciones <- readxl::read_excel(
  path = file.path(DIR_ENT, "2026-05-13_RAW_DGA-INIA_LOS_RIOS.xlsx"),
  sheet = "metadata"
) %>%
  dplyr::rename(
    codigo = bna,
    latitud = lat,
    longitud = lon,
    altura = alt
  )

# 1.2. Cargar datos diarios
data <- lee_xls_data(file.path(
  DIR_ENT,
  "2026-05-13_RAW_DGA-INIA_LOS_RIOS.xlsx"
))

# 1.3. Calcular agregados mensuales
pp_mensual <- calcular_mensuales(data, "pp", "sum")
tn_mensual <- calcular_mensuales(data, "tn", "min")
tx_mensual <- calcular_mensuales(data, "tx", "max")

# 2.1. Cargar metadata de datos ERA5
metadata_ERA5 <- readxl::read_excel(
  path = file.path(DIR_ENT, "2026-05-13_RAW_ERA5_LOS_RIOS.xlsx"),
  sheet = "metadata"
) %>%
  dplyr::rename(
    codigo = any_of(c("bna", "id")),
    latitud = lat,
    longitud = lon,
    altura = alt
  )

# 2.2 cargar datos era5
data_era5 <- lee_xls_data(file.path(
  DIR_ENT,
  "2026-05-13_RAW_ERA5_LOS_RIOS.xlsx"
))

# pp_era5 <- data_era5$pp %>% dplyr::mutate(valor = valor * 1000 * 30 )
pp_era5 <- data_era5$pp %>%
  dplyr::mutate(
    valor_mensual = valor * 1000 * days_in_month(fecha),
    variable = "pp_mensual",
    n_datos = days_in_month(fecha)
  ) %>%
  dplyr::select(any_of(c(
    "estacion_id",
    "año",
    "mes",
    "valor_mensual",
    "variable"
  )))

tn_era5 <- data_era5$tn %>%
  dplyr::mutate(
    valor = valor - 273.5,
    valor_mensual = valor,
    variable = "tn_mensual"
  ) %>%
  dplyr::select(any_of(c(
    "estacion_id",
    "año",
    "mes",
    "valor_mensual",
    "variable"
  )))

tx_era5 <- data_era5$tx %>%
  dplyr::mutate(
    valor = valor - 273.5,
    valor_mensual = valor,
    variable = "tx_mensual"
  ) %>%
  dplyr::select(any_of(c(
    "estacion_id",
    "año",
    "mes",
    "valor_mensual",
    "variable"
  )))


# 4.5 Quantile Delta Mapping ERA5 bias correction

qdm_apply()

metadata_estaciones$codigo
metadata_ERA5$old_id

a <- setNames(metadata_estaciones$codigo, metadata_estaciones$nombre)
b <- setNames(metadata_ERA5$old_id, metadata_ERA5$codigo)

dplyr::rename(wide_pp, dplyr::any_of(b))

head(metadata_estaciones[, c('codigo', 'nombre')])
head(metadata_ERA5[, c('old_id', 'nombre')])

renombra_data <- function(data, metadata, campoX = 'source', campoY = 'id') {
  rename_map <- setNames(metadata[[campoX]], metadata[[campoY]])
  data <- dplyr::rename(data, dplyr::any_of(rename_map))
  return(data)
}


# 5. Transformar datos estaciones a formato wide para climatología
wide_pp <- tidyr::pivot_wider(
  data = dplyr::rows_append(pp_mensual, pp_era5),
  id_cols = c("año", "mes"),
  names_from = "estacion_id",
  values_from = "valor_mensual"
) %>%
  dplyr::mutate(año = as.character(año)) %>%
  dplyr::filter(año > 1989 & año < 2021) %>%
  dplyr::mutate(
    año = factor(año, levels = años),
    mes = factor(mes, levels = meses),
    date = paste(año, mes, sep = "-"),
    .before = 1
  ) %>%
  dplyr::arrange(año, mes) %>%
  dplyr::select(-c("año", "mes"))


wide_tn <- tidyr::pivot_wider(
  data = dplyr::rows_append(tn_mensual, tn_era5),
  id_cols = c("año", "mes"),
  names_from = "estacion_id",
  values_from = "valor_mensual"
) %>%
  dplyr::mutate(año = as.character(año)) %>%
  dplyr::filter(año > 1989 & año < 2021) %>%
  dplyr::mutate(
    año = factor(año, levels = años),
    mes = factor(mes, levels = meses),
    date = paste(año, mes, sep = "-"),
    .before = 1
  ) %>%
  dplyr::arrange(año, mes) %>%
  dplyr::select(-c("año", "mes"))


wide_tx <- tidyr::pivot_wider(
  data = dplyr::rows_append(tx_mensual, tx_era5),
  id_cols = c("año", "mes"),
  names_from = "estacion_id",
  values_from = "valor_mensual"
) %>%
  dplyr::mutate(año = as.character(año)) %>%
  dplyr::filter(año > 1989 & año < 2021) %>%
  dplyr::mutate(
    año = factor(año, levels = años),
    mes = factor(mes, levels = meses),
    date = paste(año, mes, sep = "-"),
    .before = 1
  ) %>%
  dplyr::arrange(año, mes) %>%
  dplyr::select(-c("año", "mes"))


wide_metadata <- dplyr::bind_rows(
  metadata_estaciones %>%
    select(all_of(c("nombre", "codigo", "latitud", "longitud", "altura"))),
  metadata_ERA5 %>%
    select(all_of(c("nombre", "codigo", "latitud", "longitud", "altura")))
)

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

# WRITE -----------------------------------------------------------------------

# 1. Exportar archivo Climatol
escribe_climatol <- function(meta, data, ruta, nombre, excluidas = NULL) {
  #' @ruta donde queda el archivo
  #' @meta donde salen metadatos
  #' @data de donde salen los datos

  if (!is.null(excluidas)) {
    data <- data %>% select(!any_of(excluidas[['codigo']]))
    meta <- meta %>% filter(!(codigo %in% excluidas[['codigo']]))
  } else {
    data <- data
    meta <- meta
  }

  data <- data %>%
    dplyr::select(dplyr::where(~ sum(!is.na(.)) >= 120))

  meta <- na.omit(meta) %>%
    dplyr::filter(
      codigo %in% c(names(data))
    )

  out <- writeClimatolFiles(meta = meta, data = data)

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

  # return(list(meta, data))
}


# escribe_climatol <- function(meta, data, ruta, nombre, excluidas = NULL) {
#   # Validar existencia de directorio
#   dir_out <- file.path(ruta, "CLIMATOL")
#   if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)

#   # 1. Bypass y filtrado de excluidas (Optimizado con %in%)
#   # No usamos any_of() aquí para mantener consistencia con el filtrado de meta
#   if (!is.null(excluidas) && "codigo" %in% names(excluidas)) {
#     codigos_out <- excluidas[["codigo"]]
#     data <- data[, !(names(data) %in% codigos_out), drop = FALSE]
#     meta <- meta[!(meta$codigo %in% codigos_out), , drop = FALSE]
#   }

#   # 2. Filtrado por disponibilidad de datos (>= 120 registros no NA)
#   # Vectorización pura: evita dplyr::where si la densidad es crítica
#   valid_cols <- vapply(data, function(x) sum(!is.na(x)) >= 120, logical(1))
#   data <- data[, valid_cols, drop = FALSE]

#   # 3. Sincronización de Metadatos
#   # Solo estaciones que sobrevivieron a los filtros anteriores y están en 'data'
#   meta <- na.omit(meta)
#   meta <- meta[meta$codigo %in% names(data), , drop = FALSE]

#   # 4. Generación y Escritura (Climatol)
#   out <- writeClimatolFiles(meta = meta, data = data)

#   # Escritura de Metadatos (.est)
#   write.table(
#     x = out[["meta"]],
#     file = file.path(dir_out, paste0(nombre, ".est")),
#     row.names = FALSE,
#     col.names = FALSE,
#     quote = FALSE # Climatol suele preferir sin comillas
#   )
#
#   # Escritura de Datos (.dat)
#   write(
#     x = out$data,
#     file = file.path(dir_out, paste0(nombre, ".dat"))
#   )
# }

# metadata_wide$codigo
# names(pp_wide)[!(names(pp_wide) %in% na.omit(metadata_wide)$codigo)]
# wide_pp

#' estaciones a excluir!!!
#' existen errores en los metadatos que pude detectar, de momento es mas facil excluirlas.

excluidas <- data.frame(
  nombre = c(
    'Santa Amelia, Collipulli',
    '*ERA5_EXT-181',
    'La Estrella, Futrono',
    '*ERA5_INIA-326',
    'San Rafael, Los Sauces',
    '*ERA5_INIA-132'
  ),
  codigo = c(
    'EXT-1005',
    '*ERA5_EXT-181',
    'EXT-1026',
    '*ERA5_INIA-326',
    'INIA-209',
    '*ERA5_INIA-132'
  )
)

escribe_climatol(
  ruta = "output/",
  meta = wide_metadata,
  data = wide_pp,
  nombre = "PP-m_1990-2020",
  excluidas = NULL #excluidas
)


# climatol::homogen(
#   varcli = "output/CLIMATOL/PP-m",
#   anyi = 1990,
#   anyf = 2020,
#   onlyQC = TRUE,
#   vmin = 0,
#   std = 2,
#   annual = 'total'
# )

# file.rename(
#   'output/CLIMATOL/PP-m-ori_1990-2020.est',
#   'output/CLIMATOL/PP-m_1990-2020.est'
# )
# file.rename(
#   'output/CLIMATOL/PP-m-ori_1990-2020.dat',
#   'output/CLIMATOL/PP-m_1990-2020.dat'
# )

# getwd()
# setwd("H:/PORTFOLIO/graficos")
# setwd("output/CLIMATOL")

climatol::homogen(
  file.path("output/CLIMATOL/PP-m"),
  1990,
  2020,
  onlyQC = F,
  expl = T,
  cex = 0.8,
  std = 2,
  wd = c(0, 30, 100),
  annual = 'total',
  metad = FALSE,
  na.strings = NA,
  vmin = 0,
  gp = 1,
  uni = 'mm'
  # rlemax = 365,
)


# 2. Exportar resultados a Excel
writexl::write_xlsx(
  x = list(
    metadata = metadata_wide,
    pp_mensual = pp_wide,
    tn_mensual = tn_wide,
    tx_mensual = tx_wide #,
    # pp_historica    = pp_anual_historica,
    # resumen_mensual = resumen_historico
  ),
  path = file.path("output/", "_FICHA2026_BBDD_CLIMA_MENSUAL.xlsx")
)
