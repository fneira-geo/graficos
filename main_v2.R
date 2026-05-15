#' @title:  main_v2.R
#' @autor:  Fernando Neira-Román | fneira.roman@gmail.com
#' @description: Variante de main.R que incorpora corrección de sesgo QDM
#' (Quantile Delta Mapping, Cannon et al. 2015) sobre las series ERA5
#' mensuales antes del pivot a formato wide para CLIMATOL. La calibración
#' usa, por estación ERA5, la estación observacional pareada vía
#' metadata_ERA5$old_id. El resto del pipeline (pivot, escritura CLIMATOL,
#' homogen, export xlsx) permanece sin cambios.
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
source('src/plt_qdm_comparacion.R')

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


# 3. CORRECCIÓN DE SESGO QDM (ERA5 vs. observaciones) -------------------------
# Para cada grilla ERA5 con estación observacional pareada (metadata_ERA5$old_id
# coincide con metadata_estaciones$codigo), aplica QDM mensual (por calendario)
# y reemplaza los valores ERA5 crudos por los corregidos. Las grillas ERA5 sin
# pareo (old_id NA) o con muy pocos meses observacionales (<12 finitos)
# permanecen sin modificar.

corregir_era5_qdm <- function(
  obs_mensual,
  era5_mensual,
  metadata_ERA5,
  type = "ratio",
  min_val = 0,
  zero_threshold = 0,
  evaluar = FALSE
) {
  pares <- metadata_ERA5 %>%
    dplyr::filter(
      !is.na(old_id),
      old_id %in% unique(obs_mensual$estacion_id)
    ) %>%
    dplyr::transmute(era5_id = codigo, obs_id = old_id)

  resultado <- era5_mensual
  diagnosticos <- list()

  for (i in seq_len(nrow(pares))) {
    era5_id <- pares$era5_id[i]
    obs_id <- pares$obs_id[i]

    serie_era5 <- era5_mensual %>%
      dplyr::filter(estacion_id == era5_id) %>%
      dplyr::select(año, mes, mod = valor_mensual)

    serie_obs <- obs_mensual %>%
      dplyr::filter(estacion_id == obs_id) %>%
      dplyr::select(año, mes, obs = valor_mensual)

    pareado <- serie_era5 %>%
      dplyr::left_join(serie_obs, by = c("año", "mes")) %>%
      dplyr::mutate(
        date = as.Date(paste(año, mes, "01", sep = "-"))
      ) %>%
      dplyr::arrange(date)

    if (sum(is.finite(pareado$obs)) < 12) {
      next
    }

    corregido <- qdm_station(
      obs = pareado$obs,
      mod = pareado$mod,
      dates = pareado$date,
      by_month = TRUE,
      type = type,
      min_val = min_val,
      zero_threshold = zero_threshold
    )

    actualizado <- pareado %>%
      dplyr::transmute(
        estacion_id = era5_id,
        año,
        mes,
        valor_mensual = corregido
      )

    resultado <- resultado %>%
      dplyr::rows_update(
        actualizado,
        by = c("estacion_id", "año", "mes"),
        unmatched = "ignore"
      )

    if (evaluar) {
      cv <- qdm_loyo_cv(
        obs = pareado$obs,
        mod = pareado$mod,
        dates = pareado$date,
        type = type,
        min_val = min_val
      )
      diagnosticos[[era5_id]] <- qdm_eval(cv)
    }
  }

  list(data = resultado, eval = diagnosticos)
}

# 3.1 Precipitación (multiplicativo)
qdm_pp <- corregir_era5_qdm(
  obs_mensual = pp_mensual,
  era5_mensual = pp_era5,
  metadata_ERA5 = metadata_ERA5,
  type = "ratio",
  min_val = 0,
  zero_threshold = 0.1,
  evaluar = TRUE
)
pp_era5_qdm <- qdm_pp$data

# 3.2 Temperatura mínima (aditivo)
qdm_tn <- corregir_era5_qdm(
  obs_mensual = tn_mensual,
  era5_mensual = tn_era5,
  metadata_ERA5 = metadata_ERA5,
  type = "difference"
)
tn_era5_qdm <- qdm_tn$data

# 3.3 Temperatura máxima (aditivo)
qdm_tx <- corregir_era5_qdm(
  obs_mensual = tx_mensual,
  era5_mensual = tx_era5,
  metadata_ERA5 = metadata_ERA5,
  type = "difference"
)
tx_era5_qdm <- qdm_tx$data


# 4. VALIDACIÓN VISUAL QDM ---------------------------------------------------
# Genera una imagen por estación ERA5 pareada (precipitación) comparando obs,
# ERA5 crudo y ERA5 corregido. Cambia `facetado = TRUE` para tres paneles.

pares_pp <- metadata_ERA5 %>%
  dplyr::filter(!is.na(old_id), old_id %in% unique(pp_mensual$estacion_id)) %>%
  dplyr::pull(codigo)

pares_tn <- metadata_ERA5 %>%
  dplyr::filter(!is.na(old_id), old_id %in% unique(tn_mensual$estacion_id)) %>%
  dplyr::pull(codigo)

pares_tx <- metadata_ERA5 %>%
  dplyr::filter(!is.na(old_id), old_id %in% unique(tx_mensual$estacion_id)) %>%
  dplyr::pull(codigo)

dir.create(file.path("output", "QDM"), showWarnings = FALSE, recursive = TRUE)

for (era5_id in pares_pp) {
  p <- plt_qdm_comparacion(
    era5_id = era5_id,
    obs_mensual = pp_mensual,
    era5_mensual = pp_era5,
    era5_qdm_mensual = pp_era5_qdm,
    metadata_ERA5 = metadata_ERA5,
    variable_label = "Precipitación (mm/mes)",
    facetado = FALSE
  )
  ggplot2::ggsave(
    filename = file.path(
      "output",
      "QDM",
      paste0("qdm_pp_", gsub("[^A-Za-z0-9_-]", "_", era5_id), ".png")
    ),
    plot = p,
    width = 9,
    height = 4.5,
    dpi = 120
  )
}


for (era5_id in pares_tn) {
  p <- plt_qdm_comparacion(
    era5_id = era5_id,
    obs_mensual = tn_mensual,
    era5_mensual = tn_era5,
    era5_qdm_mensual = tn_era5_qdm,
    metadata_ERA5 = metadata_ERA5,
    variable_label = "Temperatura Miníma (°C)",
    facetado = FALSE
  )
  ggplot2::ggsave(
    filename = file.path(
      "output",
      "QDM",
      paste0("qdm_tn_", gsub("[^A-Za-z0-9_-]", "_", era5_id), ".png")
    ),
    plot = p,
    width = 9,
    height = 4.5,
    dpi = 120
  )
}

for (era5_id in pares_tx) {
  p <- plt_qdm_comparacion(
    era5_id = era5_id,
    obs_mensual = tx_mensual,
    era5_mensual = tx_era5,
    era5_qdm_mensual = tx_era5_qdm,
    metadata_ERA5 = metadata_ERA5,
    variable_label = "Temperatura Máxima (°C)",
    facetado = FALSE
  )
  ggplot2::ggsave(
    filename = file.path(
      "output",
      "QDM",
      paste0("qdm_tx_", gsub("[^A-Za-z0-9_-]", "_", era5_id), ".png")
    ),
    plot = p,
    width = 9,
    height = 4.5,
    dpi = 120
  )
}


# 5. Transformar datos estaciones a formato wide para climatología
wide_pp <- tidyr::pivot_wider(
  data = dplyr::rows_append(pp_mensual, pp_era5_qdm),
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
  data = dplyr::rows_append(tn_mensual, tn_era5_qdm),
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
  data = dplyr::rows_append(tx_mensual, tx_era5_qdm),
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
# metadata_estaciones$codigo
# metadata_ERA5$old_id

# a <- setNames(metadata_estaciones$codigo, metadata_estaciones$nombre)
# b <- setNames(metadata_ERA5$old_id, metadata_ERA5$codigo)

# dplyr::rename(wide_pp, dplyr::any_of(b))

# head(metadata_estaciones[, c('codigo', 'nombre')])
# head(metadata_ERA5[, c('old_id', 'nombre')])

# renombra_data <- function(data, metadata, campoX = 'source', campoY = 'id') {
#   rename_map <- setNames(metadata[[campoX]], metadata[[campoY]])
#   data <- dplyr::rename(data, dplyr::any_of(rename_map))
#   return(data)
# }

# SALIDA ----------------------------------------------------------------------

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


climatol::homogen(
  varcli = file.path("output/CLIMATOL/PP-m"),
  anyi = 1990,
  anyf = 2020,
  test = "snht",
  std = 2,
  onlyQC = F,
  expl = T,
  cex = 0.8,

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
