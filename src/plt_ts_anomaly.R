
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

