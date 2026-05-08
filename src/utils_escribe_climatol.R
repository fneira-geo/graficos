#' @title:  utils_escribe_climatol.R  
#' @description:  Formatea dataframe wide y metadata al formato .est/.dat de CLIMATOL.
#' @section CONTRATO:
#' - data: columnas = estaciones (codigos), más opcionalmente "date" (ignorada).
#'         Cualquier otra columna no-estacion genera error.
#' - meta: una fila por estacion. meta$codigo debe ser subconjunto exacto de
#'         names(data) (excluyendo "date"). Si meta tiene estaciones ausentes
#'         en data, o data tiene columnas ausentes en meta, se lanza error.
#' @note El alineamiento entre meta y data debe resolverse ANTES de llamar
#'       a esta función (ver escribe_climatol en main.R). Esta función
#'       solo verifica y escribe; no imputa ni descarta silenciosamente.
 
 
writeClimatolFiles <- function(meta, data) {
 
  # --- 1. Columnas de data excluyendo "date" -----------------------------------
  data_cols <- setdiff(names(data), "date")
 
  # --- 2. Verificación: sin columnas no numéricas (excepto "date") ------------
  non_num <- data_cols[!vapply(data[data_cols], is.numeric, logical(1))]
  if (length(non_num) > 0) {
    stop(
      "writeClimatolFiles: columnas no numéricas en data ",
      "(solo 'date' está permitida como excepción): ",
      paste(non_num, collapse = ", ")
    )
  }
 
  # --- 3. Verificación bidireccional meta <-> data ----------------------------
  meta_codes <- meta$codigo
 
  in_meta_not_data <- setdiff(meta_codes, data_cols)
  in_data_not_meta <- setdiff(data_cols,  meta_codes)
 
  if (length(in_meta_not_data) > 0) {
    stop(
      "writeClimatolFiles: estaciones en meta sin columna en data: ",
      paste(in_meta_not_data, collapse = ", ")
    )
  }
  if (length(in_data_not_meta) > 0) {
    stop(
      "writeClimatolFiles: columnas en data sin fila en meta: ",
      paste(in_data_not_meta, collapse = ", ")
    )
  }
 
  # --- 4. Ordenar data según orden de meta (columna i == estacion i en .est) --
  data <- data[, meta_codes, drop = FALSE]
 
  # --- 5. Construir .est -------------------------------------------------------
  out.meta <- data.frame(
    X      = meta$longitud,
    Y      = meta$latitud,
    Z      = meta$altura,
    CODE   = gsub("-", "_", meta$codigo),
    NOMBRE = toupper(meta$nombre),
    stringsAsFactors = FALSE
  )
 
  # --- 6. Construir .dat (matriz numérica pura, sin nombres) ------------------
  out.data <- as.matrix(data)
  dimnames(out.data) <- NULL
 
  return(list(meta = out.meta, data = out.data))
}