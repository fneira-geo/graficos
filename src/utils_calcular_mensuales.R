#' @description Calcula agregados mensuales para una variable meteorológica
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