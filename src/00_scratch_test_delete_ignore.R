#' Renombra columnas basado en un dataframe de metadatos
#' @param data tibble/df a renombrar
#' @param metadata df con el mapa de nombres
#' @param old_col nombre de la columna con nombres actuales en 'data'
#' @param new_col nombre de la columna con los nuevos nombres deseados
renombra_con_mapa <- function(
  data,
  metadata,
  old_col = "old_id",
  new_col = "nombre"
) {
  # 1. Crear el vector de mapeo: c("nuevo_nombre" = "viejo_nombre")
  # Nota: dplyr::rename usa la sintaxis nuevo = viejo
  mapa <- setNames(metadata[[old_col]], metadata[[new_col]])

  # 2. Ejecutar rename usando any_of para evitar errores si faltan columnas
  data %>%
    dplyr::rename(dplyr::any_of(mapa))
}

# --- Smoke Test ---
meta_df <- tibble::tibble(
  old_id = c("10360002-2", "08372001-8"),
  nombre = c("ADOLFO_MATTHEI", "ALTO_MALLINES")
)

data_df <- tibble::tibble(
  `10360002-2` = runif(3),
  `08372001-8` = runif(3),
  otro_campo = 1:3
)

res <- renombra_con_mapa(data_df, meta_df)
print(res)
