## METADATA -------------------------------------------------------------------
## nombre script    : getCR2MET_dataPuntos2XLSX.R
## autor            : Fernando Neira-Román / fneira.roman@gmail.com
## version R        : R version 4.4.3 (2025-02-28 ucrt) / 2025-05-13

## LIMPIAR --------------------------------------------------------------------
cat('\014')                 # limpiar consola
try(dev.off(), silent = T)  # limpia graficos
rm(list = ls())             # limpiar ambiente
gc()                        # ejecuta garbage collection


## AMBIENTE -------------------------------------------------------------------
readRenviron(".env")
DATA_ENT <- Sys.getenv("DATA_ENT")
DATA_OUT <- Sys.getenv("DATA_OUT")
CUT_REG <-Sys.getenv("CUT_REG")
DIR_CR2 <-Sys.getenv("DIR_CR2")
DIR_CR2_OUT <-Sys.getenv("DIR_CR2_OUT")

## LIBRERIAS ------------------------------------------------------------------
libs <- c('tidyr', 'dplyr','tidync','terra','tidyterra','ggplot2', 'ggspatial')
sapply(libs, require, character.only = TRUE, quietly = TRUE)


## FUNCIONES ------------------------------------------------------------------
source('src/utils_carga_BASEMAPS.R')



## DIRECTORIOS -----------------------------------------------------------------
dirEnt <- DIR_CR2
dirOut <- DIR_CR2_OUT

## CODIGO ----------------------------------------------------------------------

lst <- list.files(
  path = file.path(dirEnt, 'txn'),
  recursive = TRUE,
  pattern =  "(199[0-9]|20[0-1][0-9]|202[0-2])\\_.*\\.nc$",
  full.names = TRUE
); lst  # ;head(lst, 20); tail(lst, 20)

lstPP <- list.files(
  path = file.path(dirEnt, 'pr'),
  recursive = TRUE,
  pattern =  "(199[0-9]|20[0-1][0-9]|202[0-2])\\_.*\\.nc$",
  full.names = TRUE
); lstPP  # ;head(lst, 20); tail(lst, 20)

fechas <- seq(
  lubridate::as_date('1990.01.01', format = '%Y.%m.%d'),
  lubridate::as_date('2021.12.31', format = '%Y.%m.%d'),
  by = 'day'
)

mascara <- terra::rast(lst[1], subds = 3, drivers = 'netCDF')  %>%
  terra::crop(bbox_lim %>% terra::project('OGC:CRS84'))

tn <- terra::rast(lst, subds = 1, drivers = 'netCDF') %>%
  terra::crop(mascara, mask = T) %>%
  terra::project('EPSG:32719') %>%
  terra::crop( bbox_lim ) %>%
  # `names<-`(c(1:terra::nlyr(.)))
  `names<-`(fechas)


tx <- terra::rast(lst, subds = 2, drivers = 'netCDF') %>%
  terra::crop(mascara, mask = T) %>%
  terra::project('EPSG:32719') %>%
  terra::crop( bbox_lim ) %>%
  # `names<-`(c(1:terra::nlyr(.)))
  `names<-`(fechas)

pp <- terra::rast(lstPP, subds = 1, drivers = 'netCDF') %>%
  terra::crop(mascara, mask = T) %>%
  terra::project('EPSG:32719') %>%
  terra::crop( bbox_lim ) %>%
  # `names<-`(c(1:terra::nlyr(.)))
  `names<-`(fechas)


# writeLines(
#     sprintf(
#         '%6d %6d %s',
#         length(fechas),
#         nlyr(temp),
#         nlyr(temp) == length(fechas)
#     )
# )


p <- ggplot() +
  geom_spatraster_contour_filled(data = tx[[1]], mapping = aes()) +
  geom_spatvector(data = dpa, fill = NA) +
  geom_spatvector(data = bbox_reg, mapping = aes(), col = 'red', fill = NA, lwd = 1) +
  geom_spatvector(data = dpa_lim, mapping = aes(), col = 'magenta', fill = NA, lwd = 1) +
  geom_spatvector(data = bbox_lim, mapping = aes(), col = 'black', fill = NA, lwd = 1) +
  labs(title = 'CR2MET', fill = 'unidades') +
  coord_sf(
    # crs = crs,
    crs = "EPSG:32719",
    datum = sf::st_crs("EPSG:32719"),
    clip = "on",
    expand = FALSE,
    lims_method = "orthogonal"
  ) +
  theme_void() +
  theme(
    text = element_text(family = "JetBrains Mono", face = "bold")
  )

p


# pp[[1]] %>% terra::as.points()
pp[[1]] %>% terra::yres()

# puntos aleatorios ----
set.seed(123)
rnd_pts <- terra::spatSample(x = dpa_lim, size = 200, method = 'regular')

p + geom_spatvector(
  rnd_pts,
  mapping = aes(),
  fill = 'white',
  col = 'black',
  pch = 21,
  cex = 4
)

df_tx <- terra::extract(x = tx, y = rnd_pts, method = 'simple', xy = T)
df_tn <- terra::extract(x = tn, y = rnd_pts, method = 'simple', xy = T)
df_pp <- terra::extract(x = pp, y = rnd_pts, method = 'simple', xy = T)


dem <- terra::rast( x = 'D:/DATA/clima/covar_250m/resampleDEM_250m.tif') %>%
  terra::extract( y = rnd_pts, method = 'simple', xy = T) %>% .[, 2]

latlon <- terra::vect(df_tx[c('ID', 'x', 'y')], geom = c('x', 'y'), crs = 'EPSG:32719') %>%
  terra::project('EPSG:4326') %>%
  terra::crds()


meta <- df_tx[c('ID', 'x', 'y')] %>%
  dplyr::mutate(
    nombre = sprintf('*CR2MET_%04d', ID),
    codigo = sprintf('*CR2MET_%04d', ID),
    latitud  = latlon[,2],
    longitud = latlon[,1],
    fuente = 'CR2MET',
    altura = dem
  )

dataTX <- df_tx[!colnames(df_tx) %in% c('x', 'y')] %>%
  dplyr::mutate(ID = sprintf('*CR2MET_%04d', ID)) %>%
  t() %>%
  `colnames<-`(.[1,]) %>%
  .[-1, ] %>%
  as.data.frame() %>%
  # dplyr::mutate(dplyr::across(dplyr::everything(), function(x) if (is.numeric(x)) round(x, 2) else x)) %>%
  dplyr::mutate(dplyr::across(dplyr::everything(), function(x) as.numeric(x) %>% round(3) )) %>%
  dplyr::mutate(fechas = as.Date(row.names(.)), .before = 1)


dataTN <- df_tx[!colnames(df_tn) %in% c('x', 'y')] %>%
  dplyr::mutate(ID = sprintf('*CR2MET_%04d', ID)) %>%
  t() %>%
  `colnames<-`(.[1,]) %>%
  .[-1, ] %>%
  as.data.frame() %>%
  # dplyr::mutate(dplyr::across(dplyr::everything(), function(x) if (is.numeric(x)) round(x, 2) else x)) %>%
  dplyr::mutate(dplyr::across(dplyr::everything(), function(x) as.numeric(x) %>% round(3) )) %>%
  dplyr::mutate(fechas = as.Date(row.names(.)), .before = 1)

dataPP <- df_pp[!colnames(df_pp) %in% c('x', 'y')] %>%
  dplyr::mutate(ID = sprintf('*CR2MET_%04d', ID)) %>%
  t() %>%
  `colnames<-`(.[1,]) %>%
  .[-1, ] %>%
  as.data.frame() %>%
  # dplyr::mutate(dplyr::across(dplyr::everything(), function(x) if (is.numeric(x)) round(x, 2) else x)) %>%
  dplyr::mutate(dplyr::across(dplyr::everything(), function(x) as.numeric(x) %>% round(3) )) %>%
  dplyr::mutate(fechas = as.Date(row.names(.)), .before = 1)

writexl::write_xlsx(
  list(CR2MET_TN = dataTN, CR2MET_TX = dataTX, CR2MET_PP = dataPP, CR2MET_meta = meta),
  # path = file.path(dirOut, paste0(Sys.Date(),'_CR2MET.xlsx')),
  path = file.path(dirOut, paste0('_CR2MET.xlsx')),
  col_names = TRUE,
  format_headers = TRUE
)


# # Crear un nuevo libro de trabajo
# wb <- openxlsx::createWorkbook()
# # Añadir una hoja al libro de trabajo
# openxlsx::addWorksheet(wb, "meta")
# # Escribir el data frame en la hoja
# openxlsx::writeData(wb, sheet = "meta", x = dataPP)
# # Guardar el libro de trabajo en un archivo
# openxlsx::saveWorkbook(wb, file.path(dirOut, paste0(Sys.Date(),'_CR2MET_V2.xlsx')), overwrite = TRUE)
#



# Create a sample vector (e.g., a rectangle)
v <- bbox_lim

# Define the number of random points you want to generate
num_points <- 50

# Generate random points within the extent of the vector
set.seed(123) # for reproducibility
random_points <- terra::spatSample(x = bbox_lim, size = 100, method='random')
# random_points <- spatSample(v, size = num_points, method = "random", xy = TRUE)





# If you want to ensure the points are strictly *inside* the polygon
# (and not on the boundary), you can use a loop with a tryCatch
inside_points <- list()
attempts <- 0
max_attempts <- num_points * 5 # Try a few times more than needed

while (length(inside_points) < num_points && attempts < max_attempts) {
  pt <- spatSample(v, size = 1, method = "random")
  if (terra::intersect(pt, v)) {
    inside_points <- append(inside_points, pt)
  }
  attempts <- attempts + 1
}

# Combine the list of SpatVector objects into a single SpatVector
if (length(inside_points) > 0) {
  inside_points_vect <- do.call(rbind, inside_points)
} else {
  message("Could not generate any points strictly inside the vector after several attempts.")
  inside_points_vect <- NULL
}

# Print the generated points (if any)
if (!is.null(inside_points_vect)) {
  print("Random points strictly inside the vector:")
  print(inside_points_vect)
}

# You can also plot the vector and the points
plot(v, main = "Random Points Inside Vector")
if (!is.null(inside_points_vect)) {
  points(inside_points_vect, col = "red", pch = 16)
} else {
  points(random_points, col = "blue", pch = 16)
  legend("topright", legend = "Points on or inside (boundary possible)", col = "blue", pch = 16)
}

plot(temp[[1]] / 1000)

ggplot() +
  #geom_spatraster(data = temp[[1]] / 1000, mapping=aes()) +
  geom_spatraster_contour_filled(data = temp[[1]] / 1000, mapping=aes()) +
  theme_minimal() +
  coord_sf(
    # crs = crs,
    crs = "EPSG:32719",
    datum = sf::st_crs("EPSG:32719"),
    clip = "on",
    expand = FALSE,
    lims_method = "orthogonal"
  )


plot(tidync::tidync(lst[[1]]))

library('tidync')


for ( i in seq_along(lst) ) {
  print(i)
  if( i == 1 ){
    out <- tidync(lst[[1]]) %>%
      hyper_filter(
        lat = between(lat, -38.50, -34.60),
        lon = between(lon, -73.75, -70.30)
      ) %>%
      activate('D0,D1,D2') %>%
      hyper_tibble()
  } else{
    out <- rbind(
      out, tidync(lst[[1]]) %>%
        hyper_filter(
          lat = between(lat, -38.50, -34.60),
          lon = between(lon, -73.75, -70.30)
        ) %>%
        activate('D0,D1,D2') %>%
        hyper_tibble()
    )
  }
}


out2 <- out %>%
  left_join(y = cc, by = c('lon', 'lat'))


View(out2)
out2[out2$pto == 1,]

library(tidyr)

oo <- pivot_wider(
  data = out2[out2$pto == 1, c("pto", "tmax", "lon", "lat", "time")],
  id_cols = time,
  # id_expand = T,
  # names_prefix = 'P',
  names_from = pto,
  values_from = tmax
)

names(out)
View(oo)

bb <-  out[c('lon', 'lat')] %>% unique()

cc <- bb %>% mutate( pto = 1:nrow(.) )


filename <- system.file(lst[[1]], package = "tidync")
#lon > -73.75 | lon < -70.30 lat > -38.5 | lat < -34.6
aa <- tidync(lst[[1]]) %>%
  hyper_filter(
    lat = between(lat, -38.50, -34.60),
    lon = between(lon, -73.75, -70.30)
  ) %>%
  activate('D0,D1,D2') %>% hyper_tibble()
aa
View(aa)

rast(lst[[1]], subds=1)