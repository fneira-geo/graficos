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
