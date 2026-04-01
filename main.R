##

## DIRECTORIOS ----------------------------------------------------------------
readRenviron(".env")
DATA_ENT <- Sys.getenv("DATA_ENT")
DATA_OUT <- Sys.getenv("DATA_OUT")

## LIBRERIAS ------------------------------------------------------------------
librerias <- c("tidyr", "ggplot", "climatol")
sapply(librerias, require, character.only = TRUE, quietly = TRUE)



## FUNCIONES ------------------------------------------------------------------
lee_xls_data <- function(path, sheet){
  readxl::read_excel(
    data = path,
    sheet = sheet
  )
}


# metadata


metadata <- readxl::read_excel(
  file.path(DATA_ENT, "BBDD_2026_LOS_RIOS.xlsx"),
  sheet = "metadata"
)

data_tn <- readxl::read_excel(
  file.path(DATA_ENT, "BBDD_2026_LOS_RIOS.xlsx"),
  sheet = "tn"
)

data_tx <- readxl::read_excel(
  file.path(DATA_ENT, "BBDD_2026_LOS_RIOS.xlsx"),
  sheet = "tx"
) %>%
  pivot_longer(
    cols = -c(fecha, año, mes, dia), # Mantenemos el tiempo fijo
    names_to = "estacion_id",        # Los nombres de columnas pasan a esta variable
    values_to = "valor",             # Los datos numéricos pasan a esta
    values_drop_na = TRUE            # Opcional: elimina las filas con NA para ahorrar memoria
  )

data_pp <- readxl::read_excel(
  file.path(DATA_ENT, "BBDD_2026_LOS_RIOS.xlsx"),
  sheet = "pp"
)

plot(data_pp$`10360002-2`)


tidyr::pivot_longer(
  data = data_tn,
  names_to =  c("fecha", "año", "mes", "dia"),
  valuest_to = "value"
)


