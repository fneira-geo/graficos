#' @description Lee datos meteorológicos diarios desde Excel
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