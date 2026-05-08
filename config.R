#' @titlte: config.R
#' @description: Configuración Global e Infraestructura
#' @section LIBRERIAS :  Liberias, carga librerias de R usada en el proyecto
#' 
#'


## LIBRERIAS -----------------------------------------------------------------
library(basemaps)
library(climatol)
library(dplyr)
library(ggplot2)
library(ggspatial)
library(lubridate)
library(readxl)
library(terra)
library(tidync)
library(tidyr)
library(tidyterra)
library(writexl)

# library(dotenv)
# library(here)

## AMBIENTE ------------------------------------------------------------------
# 1. Cargar .env
dotenv::load_dot_env()

# 2. Definir Constantes Globales (Inmutables)
# Usamos here() para que las rutas funcionen en cualquier PC
DIR_ENT    <- here::here(Sys.getenv("DATA_ENT"))
DIR_OUT    <- here::here(Sys.getenv("DIR_SAL"))

CUT_REG    <- Sys.getenv("CUT_REG")

DIR_DPA    <- here::here(Sys.getenv("DIR_DPA"))


# 3. Validación de Arquitecto (Fail Fast)
.validar_entorno <- function() {
    dirs <- c(DIR_ENT, DIR_OUT)
    for (d in dirs) {
        if (!dir.exists(d)) {
            warning("⚠️ Directorio no encontrado, intentando crear: ", d)
            dir.create(d, recursive = TRUE)
        }
    }
}

.validar_entorno()

# Mensaje de confirmación silencioso
message("✅ Configuración cargada: ", DIR_ENT)
