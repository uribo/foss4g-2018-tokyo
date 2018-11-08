#####################################
# 人口 (人口数、増減、就業)データ
# apiでは項目名に統一がなく、フォーマットも年によってバラバラなので
# 公開されているエクセルファイルを用いる
# - 国勢調査
# - 都道府県・市区町村別統計表
# - 都道府県・市区町村別統計表(男女別人口，年齢３区分・割合，就業者，昼間人口など)
# https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200521&tstat=000001049104&cycle=0&tclass1=000001049105
# から3回の調査結果（エクセル）をダウンロード
# ... ここでは data-rawに population_2000.xlsのように保存
#####################################
if(file.exists(here::here("data-raw", "population_h17-h22.rds")) == FALSE) {
  library(dplyr)
  library(readxl)
  
  if (length(list.files(here::here("data-raw"), pattern = "population_.+.xls$", full.names = TRUE)) != 3) {
    library(rvest)
    
    # 1/2 e-statのページから、エクセルファイルをダウンロードするためのボタンのURLを取得 ----------------------
    urls <- 
      read_html(
        "https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00200521&tstat=000001049104&cycle=0&tclass1=000001049105"
      ) %>% 
      html_nodes(css = 'div.stat-dataset_list > div > article > div > ul > li > div > div:nth-child(4) > a') %>% 
      html_attr("href") %>% 
      xml2::url_absolute("https://www.e-stat.go.jp/") %>% 
      magrittr::extract(seq_len(3))
    
    # 2/2 ファイルをダウンロード -----------------------------------------------------------------
    purrr::walk2(.x = urls,
                 .y = paste0("population_", rev(seq(2005, 2015, by = 5)), ".xls"),
                 ~ httr::GET(.x, httr::write_disk(here::here("data-raw", .y), overwrite = TRUE)))
  }
  
  files <- 
    list.files(here::here("data-raw"), 
               pattern = "population_.+.xls$", 
               full.names = TRUE)
  
  # 2005(H17) ---------------------------------------------------------------
  df_h17_geos <- 
    read_xls(
      files[1],
      sheet = 1,
      range = c("A8:E2436"),
      col_types = c("text", "text", "skip", "text", "text"),
      col_names = c("city_code", "pref_code", "city_type", "city")) %>% 
    dplyr::left_join(
      jpndistrict::jpnprefs %>% 
        dplyr::select(jis_code, prefecture),
      by = c("pref_code" = "jis_code")
    ) %>% 
    dplyr::select(pref_code, city_code, city_type, prefecture, city) %>% 
    # なぜかprefectureがintだったので直す (181108)... jpndistrictの開発版でそうしたのだった...
    dplyr::mutate(tmp_var = dplyr::if_else(stringr::str_detect(city, "区$"), NA_character_, city)) %>% 
    tidyr::fill(tmp_var, .direction = "down") %>% 
    dplyr::mutate(city = dplyr::if_else(city == tmp_var, city, paste(tmp_var, city))) %>% 
    dplyr::select(-tmp_var) %>% 
    dplyr::mutate(prefecture = purrr::map_chr(prefecture, 
                                              ~ paste(intToUtf8(.x, multiple = TRUE), collapse = ""))) %>% 
    mutate_all(funs(na_if(., "")))
  
  df_h17_pops <- 
    read_xls(
      files[1],
      sheet = 1,
      range = c("F8:I2436"),
      col_types = c("text", "skip", "text", "text"),
      col_names = c("population", "population_comp", "population_comp_percent")) %>% 
    bind_cols(df_h17_geos, .)
  
  
  # 2010(H22) ---------------------------------------------------------------
  df_h22_geos <- 
    read_xls(
      files[2],
      sheet = 1,
      range = c("A11:H1979"),
      col_types = c("text", "text", "skip", "skip", "skip", "text", "text", "text"),
      col_names = c("pref_code", "city_code", "city_type", "prefecture", "city"))
  
  df_h22_pops <- 
    read_xls(
      files[2],
      sheet = 1,
      range = c("I11:L1979"),
      col_types = c("numeric", "skip", "numeric", "numeric"),
      col_names = c("population", "population_comp", "population_comp_percent")) %>% 
    bind_cols(df_h22_geos, .)
  
  
  # 2015(H27) ---------------------------------------------------------------
  df_h27_geos <- 
    read_xls(
      files[3],
      sheet = 1,
      range = c("A12:H1976"),
      col_types = c("text", "text", "skip", "skip", "skip", "text", "text", "text"),
      col_names = c("pref_code", "city_code", "city_type", "prefecture", "city")
    )
  
  df_h27_pops <- 
    read_xls(
      files[3],
      sheet = 1,
      range = c("I12:L1976"),
      col_types = c("numeric", "skip", "numeric", "numeric"),
      col_names = c("population", "population_comp", "population_comp_percent")
    ) %>% 
    bind_cols(df_h27_geos, .)
  
  # Combine and tidy --------------------------------------------------------
  # H17, 22, 27 の都道府県・市区町村別人口データ
  common_vars <- c("pref_code", "city_code", "city_type", "city", "population")
  
  df_h17to27_pops <- 
    bind_rows(
      df_h17_pops %>% 
        dplyr::select(common_vars) %>% 
        readr::type_convert() %>% 
        mutate(year = 2005),
      df_h22_pops %>% 
        dplyr::select(common_vars) %>% 
        readr::type_convert() %>% 
        mutate(year = 2010),
      df_h27_pops %>% 
        dplyr::select(common_vars) %>% 
        mutate(year = 2015)) %>% 
    select(year, everything())
  
  df_h17to27_pops %>% 
    readr::write_rds(here::here("data-raw", "population_h17-h22.rds"))
} 
