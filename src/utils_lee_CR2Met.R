lee_CR2MET <- function(ruta) {
  nanVals <- c(NA, NaN, NULL, 'NA', 'NaN', 'NULL')
  
  meta <- readxl::read_xlsx(path = ruta, sheet = 'CR2MET_meta')
  
  n <- nrow(meta)
  
  
  tn <- readxl::read_xlsx(
    path = ruta,
    sheet = 'CR2MET_TN',
    col_types = c('date', rep('numeric', n)),
    na = nanVals
  )
  
  tx <- readxl::read_xlsx(
    path = ruta,
    sheet = 'CR2MET_TX',
    col_types = c('date', rep('numeric', n)),
    na = nanVals
  )
  
  pp <- readxl::read_xlsx(
    path = ruta,
    sheet = 'CR2MET_PP',
    col_types = c('date', rep('numeric', n)),
    na = nanVals
  )
  
  return(list(
    meta = meta,
    tn = tn,
    tx = tx,
    pp = pp
  ))
}