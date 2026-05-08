#' @title:  utils_escribe_climatol.R  
#' @description:  Formatea dataframe wide al formato de archivos .est y .dat
#' requerido por el paquete CLIMATOL.
#' @section ESCRIBE:
#' - Recibe metadata y data en formato wide (solo columnas numéricas de estaciones)
#' - Devuelve lista con: meta (data.frame) y data (matrix numérica)
#' @note: 'data' NO debe incluir columnas de fecha ni auxiliares (date, año, mes).
#'         El filtro y selección de columnas se hace en escribe_climatol() en main.R.


writeClimatolFiles <- function(meta, data) {

  # Metadatos en orden requerido por CLIMATOL: X(lon) Y(lat) Z(alt) CODE NAME
  out.meta <- data.frame(
    X      = meta$longitud,
    Y      = meta$latitud,
    Z      = meta$altura,
    CODE   = gsub("-", "_", meta$codigo),   # CLIMATOL no acepta guiones en códigos
    NOMBRE = toupper(meta$nombre),
    stringsAsFactors = FALSE
  )

  # FIX: eliminar cualquier columna no numérica residual (date, año, mes)
  # antes de convertir a matriz para el .dat
  cols_numericas <- vapply(data, is.numeric, logical(1))
  if (any(!cols_numericas)) {
    warning(
      "writeClimatolFiles: eliminando columnas no numéricas del .dat: ",
      paste(names(data)[!cols_numericas], collapse = ", ")
    )
    data <- data[, cols_numericas, drop = FALSE]
  }

  # Verificación: número de columnas debe coincidir con filas de meta
  if (ncol(data) != nrow(out.meta)) {
    stop(sprintf(
      "Mismatch: data tiene %d columnas de estaciones, meta tiene %d filas. ",
      ncol(data), nrow(out.meta),
      "Revisar alineación codigo <-> nombres de columnas."
    ))

    #print(meta)
  }

  # Convertir a matriz; CLIMATOL lee los valores columna por columna
  out.data <- as.matrix(data)
  dimnames(out.data) <- NULL

  return(list(meta = out.meta, data = out.data))
}
