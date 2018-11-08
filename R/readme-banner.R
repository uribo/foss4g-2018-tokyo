# 利用するデータの著作権 -----------------------------------------------------------------
# - 日本国内の行政区域データは、国土交通省  国土数値情報が提供するデータです。
#  作成する地図はこれらのデータを、国土地理院長の承認を得て、同院発行の数値地図（国土基本情報）電子国土基本図（地図情報）
#  を使用したものです (承認番号　平28情使、第603号)
# - ALOS全球数値地表モデル (DSM) https://www.eorc.jaxa.jp/ALOS/aw3d30/index_j.htm は宇宙航空研究開発機構 (JAXA)によるものです
# - OpenStreetMapの地図タイルおよびデータは、OpenStreetMapとその協力者によって作成・管理されています https://www.openstreetmap.org/copyright

# 1/4 ---------------------------------------------------------------------
library(tidyverse)
library(jpndistrict)
library(sf)
library(lwgeom)

# まずは関東地方に含まれる県ポリゴンの用意から始めます。具体的には、一都八県のポリゴンデータです。`jpndistrict::jpn_pref()`は国土数値情報の扱う
# 平成27年4月1日時点の行政区域データをRで扱うために利用できますが、一度の処理で指定できる県は1つです。そのため、複数のオブジェクトを単一にまとめる必要があります。

# 下記のコードは、`purrr::map()`で各県のデータを取得した後、`purrr::reduce()`で結合するという処理になります。これにより、個別の県ポリゴンからなる中間オブジェクトを作成する手間が省けます。

# 関東地方の都道府県の行政区域データを用意します
sf_kanto <- 
  # jpn_pref()は与えられた都道府県コードの行政区域データを返却します
  # (国土数値情報行政区域データ)
  seq(8, 14, by = 1) %>% 
  purrr::map(
    jpn_pref
  ) %>% 
  # purrr::map()の返り値はリストですが、rbind()でオブジェクトを結合します
  purrr::reduce(rbind) %>% 
  st_make_valid()

# FOSS4G Tokyo2018 会場 (ここの大まかな座標) のポイントデータを作成
sf_poi <- 
  # 経度 longitude, 緯度 latitude の順に指定
  st_point(c(139.6775, 35.6611)) %>% 
  # 測地系WGS84をSRIDで指定
  st_sfc(crs = 4326)

sf_poi_area <- 
  sf_poi %>% 
  # 参照座標系を世界測地系の平面直角座標系に変更
  st_transform(crs = 2451) %>% 
  # 基点からの半径10kmの距離でバッファを生成する
  st_buffer(dist = units::set_units(10, km)) %>%
  # WGS84に戻す
  st_transform(crs = 4326) %>% 
  st_sf()

sf_poi_buffer <- 
  sf_poi %>% 
  st_transform(crs = 2451) %>% 
  st_buffer(dist = units::set_units(50, km)) %>% 
  st_transform(crs = 4326) %>% 
  st_sf()

sf_kanto_crop <- 
  # バッファ領域に含まれる行政区域を取り出す
  # WGS84は楕円体なので警告のメッセージがでる
  st_intersection(
    sf_kanto, 
    sf_poi_buffer) %>% 
  mutate(check = st_intersects(geometry, 
                               sf_poi_area, 
                               sparse = FALSE)[, 1]) %>% 
  mutate(check = if_else(check == TRUE, 
                         "#FF6B6B10", 
                         "gray30"))

# レイヤを分けて作るように指示
p01_highlight <- 
  ggplot() +
  geom_sf(data = sf_kanto_crop, 
          aes(fill = check), 
          color = "gray60", 
          size = 0.2) +
  geom_sf(data = sf_poi_area, 
          fill = "#FF6B6B", 
          color = NA, 
          alpha = 0.6) +
  scale_fill_identity() +
  coord_sf(datum = NA) +
  theme_void() +
  theme(panel.background = element_rect(fill = "transparent",color = NA),
        panel.grid.minor = element_line(color = NA))

# ggsave(filename = here::here("figures", "banner-p01-highlight.png"),
#        p01_highlight,
#        width = 6,
#        height = 4,
#        dpi = "retina",
#        bg = "transparent")

# 2/4 ---------------------------------------------------------------------
library(mapview)
library(leaflet)

# thunderforest.com のタイルを背景に利用する
# APIキーの値を入力する
api_key <-
  rstudioapi::askForPassword()

basemap <- 
  leaflet() %>% 
  # 画像タイルを取得するためのURLを記述
  addTiles(paste0("http://tile.thunderforest.com/transport/{z}/{x}/{y}.png", 
                  "?apikey=", 
                  api_key),
           attribution = "Maps \u00a9 <a href='https://wiki.openstreetmap.org/wiki/User:Gravitystorm' target='_blank'>Andy Allan</a>| Data \u00a9 <a href='https://www.openstreetmap.org/copyright' target='_blank'>OpenStreetMap contributors</a>")

# APIキーを利用しない場合
# basemap <- 
#   leaflet() %>% 
#   addTiles()

p02_osm <- 
  mapview(sf_poi, 
          map = basemap, 
          label = "We are in HERE!",
          labelOptions = labelOptions(noHide = TRUE, 
                                      textOnly = TRUE,
                                      direction = "bottom",
                                      offset = c(0, 10),
                                      style = list(
                                        "color" = '#F7FFF7',
                                        "background-color" = "#FF6B6B",
                                        "font-size" = "36px",
                                        "font-weight" = "bold"
                                      )))

p02_osm <- 
  p02_osm@map %>% 
  # 基点の座標と縮尺を固定
  setView(lng = 139.6775, lat = 35.6611, zoom = 16)

# mapshot(
#   p02_osm,
#   file = here::here("figures", "banner-p03-osm.png")
# )

# 3/4 ---------------------------------------------------------------------
library(rayshader)
library(raster)
r_dsm <- 
  raster::raster(here::here("data-raw", "N035E139_AVE_DSM.tif"))

# ラスタデータの標高値を行列に変換
elmat <- 
  r_dsm %>% 
  raster::extract(
    raster::extent(r_dsm), 
    buffer = 1000) %>% 
  matrix(nrow = ncol(r_dsm),
         ncol = nrow(r_dsm))

elmat_shd <- 
  elmat %>%
  sphere_shade(texture = "imhof1") %>%
  add_water(detect_water(elmat), color = "desert")

elmat_shd %>% 
  plot_map()


elmat_shd %>%
  plot_3d(elmat, 
          zscale = 5, 
          background = "transparent",
          water = TRUE,
          theta = 35,
          waterdepth = 0, 
          wateralpha = 0.6, 
          watercolor = "#88DDFF",
          waterlinecolor = "white", waterlinealpha = 0.5)

# save_3dprint(here::here("figures", "banner-p04-rayshader.png"))

# 4/4 ----------------------------------------------------------------------
library(jpmesh)

sf_tokyo_mesh <- 
  c(5338, 5339) %>% 
  purrr::map(fine_separate) %>% 
  purrr::reduce(c) %>% 
  unique() %>% 
  export_meshes()

sf_tokyo <- 
  jpndistrict::jpn_pref(13, district = TRUE) %>% 
  filter(city_code < 13361)

sf_tokyo23 <- 
  sf_tokyo %>% 
  filter(stringr::str_detect(city, "区$"))

sf_tokyo23_meguro <- 
  sf_tokyo %>% 
  filter(stringr::str_detect(city, "目黒区$"))

sf_tokyo_mesh_10km <- 
  sf_tokyo_mesh %>% 
  st_join(sf_tokyo, join = st_intersects, left = FALSE) %>% 
  distinct(meshcode, geometry) %>% 
  mutate(is_intersects = st_intersects(geometry, st_union(sf_tokyo23), sparse = FALSE)[, 1])

sf_tokyo_mesh_1km <- 
  sf_tokyo_mesh_10km %>% 
  st_join(sf_tokyo23, join = st_intersects, left = FALSE) %>% 
  distinct(meshcode, geometry) %>% 
  pull(meshcode) %>% 
  purrr::map(fine_separate) %>% 
  purrr::reduce(c) %>% 
  unique() %>% 
  export_meshes() %>% 
  st_join(sf_tokyo23, join = st_intersects, left = FALSE) %>% 
  distinct(meshcode, geometry) %>% 
  mutate(is_intersects = st_intersects(geometry, st_union(sf_tokyo23_meguro), sparse = FALSE)[, 1])

sf_tokyo_mesh_500m <- 
  sf_tokyo_mesh_1km %>% 
  st_join(sf_tokyo23_meguro, join = st_intersects, left = FALSE) %>% 
  distinct(meshcode, geometry) %>% 
  pull(meshcode) %>% 
  purrr::map(fine_separate) %>% 
  purrr::reduce(c) %>% 
  unique() %>% 
  export_meshes() %>% 
  st_join(sf_tokyo23_meguro, join = st_intersects, left = FALSE) %>% 
  distinct(meshcode, geometry) %>% 
  mutate(is_intersects = st_intersects(geometry, 
                                       st_union(coords_to_mesh(139.6775, 35.6611) %>% 
                                                  export_mesh()), 
                                       sparse = FALSE)[, 1])

tran <- function(geometry, rotang, center) {
  rot = function(a) matrix(c(cos(a), sin(a), -sin(a), cos(a)), 2, 2)
  (geometry - center) * rot(rotang * pi / 180) + center
}

geom_rot2 <- function(geometry, rotang) {
  center <- 
    suppressWarnings(st_centroid(st_combine(geometry)))
  
  inpoly_rot <- 
    tran(st_combine(geometry), 
         rotang, 
         center)
  
  inpoly_rot
}

geom_rot2_hlt <- function(geometry, rotang, base_geometry) {
  center <- 
    suppressWarnings(st_centroid(st_combine(base_geometry)))
  
  inpoly_rot <- 
    tran(st_combine(geometry), 
         rotang, 
         center)
  inpoly_rot
}

sf_tokyo_mesh_10km %>% 
  filter(meshcode %in% c("533924", "533925")) %>% 
  mutate(geometry = st_cast(geometry, "POLYGON"))

sf_tokyo_mesh_10km_hlt <- 
  sf_tokyo_mesh_10km %>% 
  filter(is_intersects == TRUE)

p04_mesh <- 
  ggplot() +
  geom_sf(data = geom_rot2(sf_tokyo, 25)) +
  geom_sf(data = geom_rot2_hlt(sf_tokyo_mesh_10km_hlt, 25, sf_tokyo_mesh_10km),
          fill = "#4ECDC4", alpha = 0.2) +
  geom_sf(data = geom_rot2_hlt(sf_tokyo %>% 
                                 filter(city == "目黒区"), 25,
                               sf_tokyo), fill = "#FF6B6B") +
  geom_sf(data = geom_rot2(sf_tokyo_mesh_1km, 25) + matrix(c(-0.75, -0.05)),
          fill = "#4ECDC4") +
  geom_sf(data = geom_rot2_hlt(sf_tokyo_mesh_1km %>% 
                                 filter(is_intersects == TRUE), 25, sf_tokyo_mesh_1km) + 
            matrix(c(-0.75, -0.06)),
          fill = "#FF6B6B") +
  geom_sf(data = geom_rot2(sf_tokyo_mesh_500m, 25) + matrix(c(-0.9, -0.14)),
          fill = "#FF6B6B") +
  # geom_sf(data = geom_rot2_hlt(sf_tokyo_mesh_500m %>% 
  #                                filter(is_intersects == TRUE), 25, sf_tokyo_mesh_500m) + 
  #           matrix(c(-1.0, -0.14)),
  #         fill = "#4ECDC4", alpha = 0.5) +
  coord_sf(datum = NA) +
  theme_void()

# ggsave(filename = here::here("figures", "banner-p05-mesh_zooming.png"),
#        p04_mesh,
#        width = 6,
#        height = 4,
#        dpi = "retina",
#        bg = "transparent")
