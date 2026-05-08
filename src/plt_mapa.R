#' Generar Mapa de Aptitud (Versión Terra-Native)
#' 
#' @param rst SpatRaster. Capa principal. Si es NULL, solo se dibuja el marco.
#' @param vct_roi SpatVector. Polígono de interés (ej. Región). Opcional.
#' @param vct_dpa SpatVector. Límites administrativos. Opcional.
#' @param vct_contexto SpatVector. Capa de contexto (Chile/Sudamérica). Opcional.
#' @param config list. Metadatos del mapa (titulo, cultivo, etc.).
#' @param paths list. Rutas a archivos de imagen (logos).
#'
generar_mapa_aptitud <- function(rst = NULL, 
                                 vct_roi = NULL, 
                                 vct_dpa = NULL, 
                                 vct_contexto = NULL,
                                 config = list(
                                   titulo = "MAPA DE APTITUD",
                                   cultivo = "Nombre Cultivo",
                                   region = "O'Higgins",
                                   fuente = "CIREN 2024"
                                 ),
                                 paths = list(
                                   minagri = "minagri.png",
                                   ciren = "logo_ciren_fondo_blanco.jpg",
                                   sub_agri = "color_SubAgricultura.png"
                                 )) {
  
  # 1. SETUP DE VARIABLES INTERNAS (Layout) ---------------------------------
  # Coordenadas relativas [-1, 1] para elementos de la ficha técnica
  COORD_TITULO  <- c(x = 0, y = 0.92)
  COORD_SUBTIT  <- c(x = 0, y = 0.87)
  COORD_LOGO_M  <- c(x1 = -0.98, x2 = -0.80, y1 = 0.75, y2 = 0.95) # Minagri
  COORD_LOGO_C  <- c(x1 = 0.75, x2 = 0.95, y1 = -0.98, y2 = -0.85) # Ciren
  COORD_LEYENDA <- c(x1 = -0.95, x2 = -0.40, y1 = -0.55, y2 = -0.30)
  
  require(terra)
  require(png)
  require(jpeg)

  # Guardar y restaurar par
  opar <- par(no.readonly = TRUE)
  on.exit(par(opar))
  
  # 2. FUNCIONES AUXILIARES (Internal Helpers) ------------------------------
  
  # Crea una capa de dibujo transparente sobre el mapa
  draw_overlay <- function() {
    par(fig = c(0, 1, 0, 1), oma = c(0, 0, 0, 0), mar = c(0, 0, 0, 0), new = TRUE)
    plot(0, 0, type = 'n', bty = 'n', xaxt = 'n', yaxt = 'n', xlim = c(-1, 1), ylim = c(-1, 1))
  }

  safe_draw_img <- function(path, coords) {
    if (file.exists(path)) {
      img <- if(grepl("\\.png$", path)) readPNG(path) else readJPEG(path)
      rasterImage(img, coords["x1"], coords["y1"], coords["x2"], coords["y2"])
    }
  }

  # 3. RENDERIZADO DEL MAPA (Bloque Espacial) -------------------------------
  
  # Determinar extensión base (si no hay raster, usar ROI)
  ext_base <- if (!is.null(rst)) ext(rst) else if (!is.null(vct_roi)) ext(vct_roi) else NULL
  
  if (is.null(ext_base)) stop("Error: Debe proporcionar al menos un Raster o un Vector ROI.")

  # Plot del Raster principal
  if (!is.null(rst)) {
    plot(rst, mar = c(4, 4, 4, 8), main = "", axes = TRUE)
  } else {
    # Si no hay raster, crear frame vacío con la extensión del vector
    plot(ext_base, main = "", axes = TRUE, type = "n")
  }

  # Capas Vectoriales (Uso exclusivo de Terra)
  if (!is.null(vct_dpa)) plot(vct_dpa, add = TRUE, border = "grey60", lwd = 0.4)
  if (!is.null(vct_roi)) plot(vct_roi, add = TRUE, border = "red", lwd = 2)

  # 4. RENDERIZADO DE FICHA (Bloque Gráfico) -------------------------------
  
  draw_overlay()

  # Logos
  safe_draw_img(paths$minagri, COORD_LOGO_M)
  safe_draw_img(paths$ciren, COORD_LOGO_C)
  
  # Títulos
  text(COORD_TITULO["x"], COORD_TITULO["y"], 
       labels = sprintf("%s - %s", config$titulo, config$cultivo), 
       cex = 1.5, font = 2)
  text(COORD_SUBTIT["x"], COORD_SUBTIT["y"], 
       labels = sprintf("Región: %s", config$region), cex = 1.1)

  # Leyenda condicional
  if (!is.null(vct_roi)) {
    rect(COORD_LEYENDA["x1"], COORD_LEYENDA["y1"], COORD_LEYENDA["x2"], COORD_LEYENDA["y2"], col = "white")
    legend(COORD_LEYENDA["x1"] + 0.05, COORD_LEYENDA["y2"] - 0.05, 
           legend = c("Límite Regional", "Límite Comunal"),
           lty = 1, col = c("red", "grey60"), lwd = c(2, 0.5), bty = "n", cex = 0.8)
  }

  # 5. MAPA DE REFERENCIA (Miniatura) --------------------------------------
  if (!is.null(vct_contexto)) {
    # Ubicar en esquina superior derecha
    par(fig = c(0.78, 0.98, 0.65, 0.95), new = TRUE, mar = c(0,0,0,0))
    plot(vct_contexto, col = "grey90", border = "white")
    if (!is.null(vct_roi)) plot(vct_roi, add = TRUE, col = "red", border = "red")
    box(col = "grey70")
  }

  return(invisible(TRUE))
}