library(jmastats)
library(tidyverse)

if (file.exists(here::here("data-raw", "201808_kansto_62ws.rds")) == FALSE) {
  
  if (file.exists(here::here("data-raw", "kanto_62ws.rds")) == FALSE) {
    sf_kanto_stations <- 
      stations %>% 
      dplyr::filter(station_type == "四", 
                    pref_code %in% c(str_pad(seq(8, 14), 
                                             width = 2, 
                                             pad = "0"))) %>% 
      dplyr::select(area, station_no, elevation, prec_no, block_no, 
                    pref_code, address) %>% 
      dplyr::mutate(address = str_replace_all(address,
                                              "^(.+市|区|市|.+郡.+町).+", 
                                              replacement = "\\1"))
    
    sf_kanto_stations %>% 
      sf::st_write(here::here("data-raw", "kanto_62ws.geojson"))
  
    }

  sf_stat201808 <-
    sf_kanto_stations %>%
    dplyr::mutate(weather_data = 
                    purrr::map(block_no, 
                               ~ jma_collect(item = "daily", block_no = .x, year = 2018, month = 8)))
  
  sf_stat201808 %>% 
    sf::st_write(here::here("data-raw", "201808_kansto_62ws.geojson"))
}

sf_kanto_stations <- 
  sf::st_read(here::here("data-raw", "kanto_62ws.geojson"))

sf_stat201808 <- 
  sf::st_read(here::here("data-raw", "201808_kansto_62ws.geojson"))

sf_stat201808 <- 
  sf_stat201808 %>% 
  dplyr::mutate(weather_data = purrr::map(weather_data, 
                                   ~ dplyr::select(., 
                                                   date, 
                                                   precipitation_sum_mm = `precipitation_sum(mm)`,
                                                   temperature = `temperature_average(℃)`,
                                                   wind_max_speed = `wind_max_speed(m/s)`
  ) %>% 
    dplyr::mutate_all(funs(str_remove_all(., "\\)"))))) %>% 
  tidyr::unnest() %>% 
  dplyr::mutate_at(vars(c("precipitation_sum_mm", "temperature", "wind_max_speed")), 
                   funs(as.numeric))
