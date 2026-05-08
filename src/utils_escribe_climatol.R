#' @title:  utils_escribe_climatol.R  
#' @description:  da formato de los datos en dataframe wide, entregar la estructura
#' de datos necesarias para escribir datos para ser leidos por paquete CLIMATOL
#' @section REORDENA:
#' - toma el dataframe y reordena los datos para climatol.
#' @section ESCRIBE:
#' - escribe los datos ordenados en la funcion anterior, para escribir los archivos.


# REORDENA --------------------------------------------------------------------
writeClimatolFiles <- function(meta, data) {

    out.meta <- meta %>%
        data.frame() %>%
        dplyr::select(dplyr::all_of(c("longitud", "latitud", 'altura',"codigo", "nombre"))) %>%
        `colnames<-`(c("X", "Y", "Z", "CODE", "NOMBRE")) %>%
        # mutate(Z = 0, .before = 3) %>%
        dplyr::mutate(NOMBRE = toupper(NOMBRE), CODE = stringr::str_replace_all(CODE, "-", "_"))

    out.data <- data %>%
        `names<-`(NULL) %>%
        `row.names<-`(NULL) %>%
        as.matrix()

    return(list(meta = out.meta, data = out.data))
}



# ESCRIBE ---------------------------------------------------------------------
writeClimatolFiles <- function(meta, data) {
  
  # Faster selection and renaming using basic indexing
  out.meta <- data.frame(
    X = meta$longitud,
    Y = meta$latitud,
    Z = meta$altura,
    CODE = gsub("-", "_", meta$codigo),
    NOMBRE = toupper(meta$nombre),
    stringsAsFactors = FALSE
  )

  # Converting to matrix and stripping names in one go
  out.data <- as.matrix(data)
  dimnames(out.data) <- NULL

  return(list(meta = out.meta, data = out.data))
}
