plt_mapa_calor <- function(data, x, y){
  p <- ggplot(data, aes(x = {{x}}, y = {{y}})) +
    geom_tile() +
    scale_x_continuous(breaks = seq(1940, 1976, by = 4), expand = c(0, 0)) +
    scale_y_reverse(expand = c(0, 0)) +
    scale_fill_gradient2(midpoint = 50, mid = "grey70", limits = c(0, 100))
  
  return(p)
}
