#' @title:  plt_qdm_comparacion.R
#' @autor:  Fernando Neira-Román | fneira.roman@gmail.com
#' @description: Compara visualmente, para una estación ERA5 pareada con su
#' estación observacional, las series mensuales: observada, ERA5 cruda y ERA5
#' con corrección de sesgo QDM. Devuelve un objeto ggplot (no escribe a disco).

# FUNCIONES -------------------------------------------------------------------

plt_qdm_comparacion <- function(era5_id,
                                obs_mensual,
                                era5_mensual,
                                era5_qdm_mensual,
                                metadata_ERA5,
                                variable_label = "valor mensual",
                                facetado       = FALSE) {
  #' @param era5_id          codigo de la estación ERA5 (ej. "*ERA5_10360002-2")
  #' @param obs_mensual      data.frame long: estacion_id, año, mes, valor_mensual
  #' @param era5_mensual     data.frame ERA5 sin corregir (mismo esquema)
  #' @param era5_qdm_mensual data.frame ERA5 corregido (mismo esquema)
  #' @param metadata_ERA5    metadata con columnas codigo, old_id
  #' @param variable_label   etiqueta del eje Y
  #' @param facetado         FALSE = un panel; TRUE = 3 paneles apilados
  #' @return                 objeto ggplot

  obs_id <- metadata_ERA5 %>%
    dplyr::filter(codigo == era5_id) %>%
    dplyr::pull(old_id)

  if (length(obs_id) == 0L || is.na(obs_id[1L])) {
    stop("Sin pareo old_id para ERA5: ", era5_id)
  }
  obs_id <- obs_id[1L]

  arma_serie <- function(df, id, etiqueta) {
    df %>%
      dplyr::filter(estacion_id == id) %>%
      dplyr::transmute(
        date  = as.Date(paste(año, mes, "01", sep = "-")),
        valor = valor_mensual,
        serie = etiqueta
      )
  }

  df_plot <- dplyr::bind_rows(
    arma_serie(obs_mensual,      obs_id,  "Observado"),
    arma_serie(era5_mensual,     era5_id, "ERA5 crudo"),
    arma_serie(era5_qdm_mensual, era5_id, "ERA5 corregido (QDM)")
  ) %>%
    dplyr::mutate(serie = factor(
      serie,
      levels = c("Observado", "ERA5 crudo", "ERA5 corregido (QDM)")
    ))

  paleta <- c(
    "Observado"            = "#1B1B1B",
    "ERA5 crudo"           = "#D55E00",
    "ERA5 corregido (QDM)" = "#0072B2"
  )

  p <- ggplot2::ggplot(
    df_plot,
    ggplot2::aes(x = date, y = valor, color = serie)
  ) +
    ggplot2::geom_line(alpha = 0.85, linewidth = 0.4) +
    ggplot2::scale_color_manual(values = paleta) +
    ggplot2::labs(
      title    = paste0("QDM bias correction — ", era5_id),
      subtitle = paste0("Pareado con observación: ", obs_id),
      x = NULL, y = variable_label, color = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  if (facetado) {
    p <- p +
      ggplot2::facet_wrap(~serie, ncol = 1, scales = "fixed") +
      ggplot2::theme(legend.position = "none")
  }

  p
}