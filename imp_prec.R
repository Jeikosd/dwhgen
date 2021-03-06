### implementacion de NLPCA (componentes principales no lineales)

library(pcaMethods)

geometry_to_lonlat <- function(x) {
  if (any(sf::st_geometry_type(x) != "POINT")) {
    stop("Selecting non-points isn't implemented.")
  }
  coord_df <- sf::st_transform(x, sf::st_crs("+proj=longlat +datum=WGS84")) %>%
    sf::st_coordinates() %>%
    dplyr::as_tibble() %>%
    dplyr::select(X, Y) %>%
    dplyr::rename(lon = X, lat = Y)
  out <- sf::st_set_geometry(x, NULL) %>%
    dplyr::bind_cols(coord_df)
  return(out)
}

cluster_sf <- cluster_sf %>% 
  geometry_to_lonlat

# library(pcaMethods)

QM <- function(x){
  obs <- dplyr::pull(x, prec_qc_qm)
  mod <- dplyr::pull(x, prec_imp_qm)
  qm_fit <- fitQmapRQUANT(obs, mod,
                          qstep = 0.01, nboot = 1, wet.day = 0.2)
  
  qm_corrected <- doQmapRQUANT(mod, qm_fit,type="tricub") %>%
    tibble(prec_bias_correction = .) %>% 
    mutate(prec_bias_correction = if_else(prec_bias_correction <= 0.2, 0, prec_bias_correction))
  
  return(qm_corrected)
}

make_correct_date <- function(x, dates){
  
  left_join(dates, x, by = "Date")
  
}


make_nlpca <- function(x){
  
  # x <- cluster_sf %>%
    # group_split(cluster_inside) %>%
    # purrr::pluck(1) # %>%
  
  
    # # filter(row_number()==1) %>%
    # dplyr::select(Code, qc_climate) %>%
    # unnest()
  
  
  seq_dates <- seq(ymd("1981-01-01"), ymd("2010-12-31"), by = "day") %>%
    tibble::enframe(value = "Date",  name = NULL)
  

  x <- x %>% 
  dplyr::select(Code, qc_climate) %>%
    mutate(qc_climate = purrr::map(.x = qc_climate, .f = make_correct_date, seq_dates)) %>% 
    unnest()
    
  
  dates <- x %>%
    dplyr::select(Code, Date, year, month, day)
  
  prec_obs <- dplyr::select(x, prec_qc)
  
  x <- x %>%
    group_by(Code) %>%
    mutate(id = row_number()) %>%
    dplyr::select(Code, id, prec_qc) %>% 
    spread(Code, prec_qc) %>%
    dplyr::select(-id)

  # n_Pcs <- dim()
  if(dim(x)[2] < 10){
    
    nPcs = dim(x)[2]
    
  }else{
    
    nPcs = 10
    
  }


  pc <- pca(x, nPcs = nPcs, method="nlpca",  maxSteps = 70000)
  

  imputed <- completeObs(pc) %>% 
    as_tibble() %>%
    gather(Code, prec_imp) %>%
    bind_cols(prec_obs) %>%
    mutate(prec_imp_qm = if_else(prec_imp <= 0.2, 0, prec_imp),
           prec_qc_qm = if_else(prec_qc <= 0.2, 0, prec_qc)) %>%
    mutate(prec_imp_qm = if_else(prec_imp_qm == 0, runif(n(), 0, 0.2), prec_imp_qm),
           prec_qc_qm = if_else(prec_qc_qm == 0, runif(n(), 0, 0.2), prec_qc_qm)) %>%
    nest(-Code) %>%
    mutate(QM_processing = purrr::map(.x = data, .f = QM)) 
  
  
  dates <- dates %>%
    nest(-Code) # %>%
    # filter(row_number()==1)
  
  imputed <- imputed %>%
    # filter(row_number()==1) %>%
    # unnest() %>%
    mutate(Code = as.integer(Code)) %>% 
    left_join(x = ., y = dates, by = "Code")  %>%
    unnest() %>%
    nest(-Code)
  
  return(imputed)
    # dplyr::select(Date, prec_qc, prec_bias_correction) %>% 
    # gather(key, value, -Date)
    

  
  # grafico <- ggplot() +
  #   geom_line(data = prueba, aes(x = Date, y = value, color = key)) +
  #   theme_bw()
  #   
  # ggsave('comp_obs_mod.pdf', width = 15, height = 10, dpi = 300)

  # library(qmap)
  # 
  # qm.fit <- fitQmapRQUANT(prec_qc_qm, prec_imp_qm,
  #                         qstep = 0.99, nboot = 10, wet.day = 0.2)
  
}
cluster_sf <- bind_rows(cluster_sf)
x <- cluster_sf %>% 
  # filter(row_number() %in% 1:5) %>% 
  group_split(cluster_inside)
# cluster_sf <- cluster_sf %>%
#   group_split(cluster_inside)

library(furrr)
library(future)
x <- pluck(x, 2)
options(future.globals.maxSize= 891289600)
plan(future::cluster, workers = 15)
# plan(future::session, workers = 15)

x <-  furrr::future_map(.x = x, make_nlpca)

x <- bind_rows(x)
write_ideam(x, filename = "fill_prec_IDEAM_1981_2010.json")

install.packages("MixedPoisson")
library(MixedPoisson)
library(extraDistr)

library(MASS)	
index = which(quine$Days<11)
reg = quine[index, -which(names(quine)=="Days")]
pGamma1 = pg.dist(variable=quine$Days)

rgpois(146, 15.73654, 0.9561112, 1.045903)
variable=rpois(30,4)
pseudo_values(variable, mixing="Gamma", lambda=4, gamma.par=0.7, n=100)

x %>% 
  filter(row_number()==1) %>% 
  unnest()