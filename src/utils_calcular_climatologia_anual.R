#' Calcula climatología histórica anual
#' @description hace analisis de media mensual de los datos en formato estandar
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