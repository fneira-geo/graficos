## METADATA -------------------------------------------------------------------
## nombre script    : carga_BASEMAPS.R
## proposito        : cargar datos relativos a capas base, como dpa y satelite
## autor            : Fernando Neira-Román
## Email            : fneira.roman@gmail.com



dpa_cl <- terra::vect("D:/DATA/DPA_IDE_2023/REGIONES") %>%
  terra::disagg() %>%
  terra::project("EPSG:32719") %>%
  dplyr::mutate(SUPERFICIE = terra::expanse(., unit = "ha")) %>%
  dplyr::filter(SUPERFICIE > 20000)

cl <- terra::aggregate(dpa_cl)

# regiones contiguas
dpa_lim <- terra::vect("D:/DATA/DPA_IDE_2023/REGIONES") %>%
  dplyr::filter(CUT_REG %in% c("09", "14", "10")) %>%
  terra::disagg() %>%
  terra::project("EPSG:32719") %>%
  dplyr::mutate(SUPERFICIE = terra::expanse(., unit = "ha")) %>%
  dplyr::filter(SUPERFICIE > 20000)

# limite regional
dpa_reg <- terra::vect("D:/DATA/DPA_IDE_2023/REGIONES") %>%
  dplyr::filter(CUT_REG == CUT_REG) %>%
  terra::project("EPSG:32719") %>%
  dplyr::mutate(SUPERFICIE = terra::expanse(., unit = "ha")) %>%
  dplyr::filter(SUPERFICIE > 20000)

# CREA BBOX, con y sin la region asociada.
bbox_reg <- terra::vect(terra::ext(dpa_reg), crs = terra::crs(dpa_reg))
bbox_lim <- terra::vect(terra::ext(dpa_lim), crs = terra::crs(dpa_lim))
bbox_cl <- terra::vect(terra::ext(dpa_cl), crs = terra::crs(dpa_cl))

dpa <- terra::crop(dpa_cl, bbox_lim) %>% dplyr::filter(CUT_REG != CUT_REG)

int_arg <- file.path("D:/DATA/GADM_limites", "gadm41_ARG.gpkg") %>%
  terra::vect(layer = "ADM_ADM_0") %>%
  terra::project("EPSG:32719") %>%
  terra::crop(bbox_lim)

# bbox2 <- erase(bbox, dpa_reg)

# plot(dpa_cl)
# plot(add=T, bbox_lim )
# plot(add=T, bbox_reg )

# print("BBOX, ROI y LIMITES REGIONALES!!!")


col.oleron <- colorRampPalette(
  c(
    "#192659", "#2C386B", "#3F4B7E", "#535F92", "#6874A8", "#7D8ABD",
    "#93A0D2", "#AAB7E7", "#BDCAF4", "#CEDAF8", "#DEEAFC", "#285000",
    "#435800", "#5D6106", "#79711F", "#94823A", "#AE9355", "#CAA871",
    "#E4BF8F", "#F3D4AD", "#F9E8C8", "#FDFDE5"
  )
)

col.PastelRdYwGn <- colorRampPalette(
  c(
    # "#B81D13", "#FF5714", "#EFB700", "#6EEB83", "#008450"
    "#B81D13", "#EFB700", "#008450"
  )
)

# BASEMAPS DATA ----
# basemaps::get_maptypes()


terra::buffer(dpa, width = 20000) %>%
  terra::ext() %>%
  terra::project(from = "EPSG:32719", to = "EPSG:3857")


topo_base <- basemaps::basemap_terra(
  # ext = sf::st_transform(sf::st_bbox(terra::buffer(dpa_reg, width = 20000)), 3857),
  ext = terra::buffer(dpa, width = 20000) %>%
    terra::ext() %>%
    terra::project(from = "EPSG:32719", to = "EPSG:3857") %>%
    terra::vect(crs = "EPSG:3857"),
  # map_service = "osm",
  map_service = "esri",
  map_res = 2,
  force = TRUE,
  # map_type = "streets",
  map_type = "world_terrain_base",
) %>%
  terra::project("EPSG:32719") %>%
  terra::crop(dpa)

sate_base <- basemaps::basemap_terra(
  ext = terra::buffer(dpa, width = 20000) %>%
    terra::ext() %>%
    terra::project(from = "EPSG:32719", to = "EPSG:3857") %>%
    terra::vect(crs = "EPSG:3857"),
  # map_service = "osm",
  map_service = "esri",
  map_res = 2,
  force = TRUE,
  # map_type = "streets",
  map_type = "world_imagery",
) %>%
  terra::project("EPSG:32719") %>%
  terra::crop(dpa)

print("MAPA BASE!!! TOPO | ESRI")

# MAPA SIMPLE -----
figBase <- function(data,
                    titulo = "titulo",
                    subtitulo = "subtitulo",
                    fill = "fill",
                    base = topo_base,
                    alfa = 0.5) {
  p <- ggplot()
  coLim <- "grey10"
  
  if (!is.null(base)) {
    p <- p + geom_spatraster_rgb(base, mapping = aes())
  }
  
  # Capa vectorial de polígonos recortados
  if (!is.null(dpa)) {
    p <- p + geom_spatvector(
      data = dpa,
      mapping = aes(),
      col = coLim,
      lwd = 0.2,
      fill = adjustcolor("grey70", 0.1)
    )
  }
  
  # Capa vectorial de polígonos de la región
  if (!is.null(dpa_reg)) {
    p <- p + geom_spatvector(
      data = dpa_reg,
      mapping = aes(),
      # col = "darkred",
      col = adjustcolor("magenta", alfa),
      lwd = 0.6,
      fill = NA # adjustcolor('red', 0.1)
    )
  }
  
  # Capa vectorial de polígonos de la región
  if (!is.null(int_arg)) {
    p <- p + geom_spatvector(
      data = int_arg,
      mapping = aes(),
      # col = "darkred",
      col = coLim,
      lwd = 0.2,
      fill = adjustcolor("#EEE8AA", 0.2)
      # c("#FFFFE0", "#E3C565", '#EEE8AA')
    )
  }
  
  # Etiquetas y títulos
  p <- p + labs(
    x = "UTM E",
    y = "UTM N",
    title = titulo,
    fill = "fill",
    subtitle = subtitulo,
    caption = format(Sys.Date(), "%m - %Y")
  )
  
  # tema y formato
  p <- p +
    theme_bw() +
    theme(
      text = element_text(family = "Century Gothic", face = "bold"),
      plot.title = element_text(
        face = "bold",
        colour = "black",
        size = 13
      ),
      plot.subtitle = element_text(
        face = "bold",
        colour = "grey60",
        size = 9
      ),
      plot.caption = element_text(
        face = "bold",
        colour = "grey90",
        size = 6
      ),
      strip.text = element_text(colour = "white"),
      strip.background = element_rect(
        fill = "grey20",
        color = "grey80",
        linewidth = 1
      ),
      axis.text.x = element_text(size = 8),
      axis.text.y = element_text(size = 8),
      axis.title.x = element_text(face = "bold", size = 10),
      axis.title.y = element_text(face = "bold", size = 10)
    )
  
  # norte y escalas
  p <- p +
    annotation_scale(
      location = "br",
      style = "bar", # ticks
      unit_category = "metric",
      text_face = "bold",
      width_hint = 0.5
    ) +
    
    annotation_north_arrow(
      location = "tl",
      which_north = "true",
      pad_x = unit(0.2, "cm"),
      pad_y = unit(0.5, "cm"),
      style = north_arrow_fancy_orienteering
    )
  
  return(p)
}

coordBase <- function(p) {
  p + coord_sf(
    # crs = crs,
    crs = "EPSG:32719",
    datum = sf::st_crs("EPSG:32719"),
    clip = "on",
    expand = FALSE,
    lims_method = "orthogonal"
  ) +
    scale_x_continuous(labels = scales::label_number(big.mark = ".", decimal.mark = ",")) +
    scale_y_continuous(labels = scales::label_number(big.mark = ".", decimal.mark = ","))
}

# ggsave(
#     plot = plt1,
#     filename = gsub(".png", "_TEST.png", fileOut),
#     width = 22, height = 28, units = "cm", dpi=150,
#     bg="white"
# )


# plot(figMapa())