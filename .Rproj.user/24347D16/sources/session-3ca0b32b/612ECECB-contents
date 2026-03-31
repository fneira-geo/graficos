##

## DIRECTORIOS ----------------------------------------------------------------
readRenviron(".env")
DATA_ENT <- Sys.getenv("DATA_ENT")
DATA_OUT <- Sys.getenv("DATA_OUT")

## LIBRERIAS ------------------------------------------------------------------
librerias <- c("tidyr", "ggplot", "climatol")
sapply(librerias, require, character.only = TRUE, quietly = TRUE)



## FUNCIONES ------------------------------------------------------------------

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
)

data_pp <- readxl::read_excel(
  file.path(DATA_ENT, "BBDD_2026_LOS_RIOS.xlsx"),
  sheet = "pp"
)

plot(data_pp$`10360002-2`)


library(performance)
library(see)
library(ggplot2)

# Simulación de serie temporal con un outlier
set.seed(123)
df <- data.frame(
  fecha = seq(as.Date("2023-01-01"), by = "day", length.out = 100),
  valor = rnorm(100)
)
df$valor[50] <- 10 # Outlier artificial

# Detección robusta (MAD-based)
outliers_mad <- check_outliers(df$valor, method = "zscore_robust")

# Visualización rápida con 'see' (extensión de ggplot2)
plot(outliers_mad)

