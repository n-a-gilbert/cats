# Code for Gilbert et al. "Synergistic effects of cats and urbanization on wildlife"
# This one script is used for data prepartion, modeling fitting, and visualization
# Lines 20-759 are data preparation and formatting; these are commented out, and the
# resulting output of formatted data can be loaded in Line 762. 
# The original data files cannot be shared due to UWIN data policies; geographic
# coordinates of sites and resulting data cannot be shared to protect the data from
# being used for other analyses/purposes without approval from the UWIN committee

library(here)
library(tidyverse)
library(readxl)
library(sf)
library(janitor)
library(glmmTMB)
library(flextable)
library(officer)
library(patchwork)
library(MetBrewer)
library(rnaturalearth)
library(rnaturalearthdata)
library(wesanderson)
library(tidyterra)
library(terra)

#### Data formatting ####

# A number of cities did not use the UWIN database to store data, and as a result,
# we have many files with slightly different formats that need to be aligned
# In files from the various cities, rows represent individual photo observations
# While format and information varied, the basic information required for inclusion are:
# 1) camera site name
# 2) latitude
# 3) longitude
# 4) sampling campaign start date
# 5) sampling campaign end date
# 6) species classification
# 7) date and timestamp of photo

# BARILOCHE, ARGENTINA
# baar <- readxl::read_xlsx(here::here("data/not_in_db/bariloche.xlsx")) |> 
#   janitor::clean_names() |> 
#   dplyr::select( date_time = date_and_time, 
#                  site = site, 
#                  season = season, 
#                  year = year, 
#                  lat = latitude, 
#                  lon = longitude, 
#                  species = species, 
#                  start = campaign_start_date, 
#                  end = campaign_end_date) |>
#   dplyr::mutate(lon2 = readr::parse_number(lon)) |> 
#   dplyr::mutate(lon3 = ifelse(lon2 > 0, -1*lon2, lon2)) |> 
#   dplyr::mutate(lat_corrected = as.numeric(stringr::str_replace(lat, "^(-?\\d{2})(\\d+)$", "\\1.\\2")),
#                 lon_corrected = as.numeric(stringr::str_replace(lon3, "^(-?\\d{2})(\\d+)$", "\\1.\\2"))) |> 
#   dplyr::mutate(across(c(start, end), function(x) lubridate::as_date(x))) |> 
#   dplyr::mutate(start = ifelse(site == "BAR06", lubridate::ymd("2025-04-05"), start)) |> 
#   dplyr::mutate(start = ifelse(site == "BAR35", lubridate::ymd("2025-04-04"), start)) |> 
#   dplyr::filter(!site == "BAR29") |> 
#   dplyr::mutate(start = lubridate::as_date(start))
# 
# start_end <- baar |> 
#   dplyr::select(site, lat = lat_corrected, lon = lon_corrected, season, year, start, end) |> 
#   dplyr::distinct() |> 
#   dplyr::filter(!is.na(start)) |> 
#   dplyr::filter(!is.na(end)) |> 
#   dplyr::group_by(site, season, year, start, end) |> 
#   dplyr::summarise(lat = mean(lat), 
#                    lon = mean(lon)) |> 
#   dplyr::ungroup()
# 
# baar_sp_key <- tibble::tribble(
#   ~species, ~sp, 
#   "Cervus elaphus", "elk",
#   "Felis catus", "domestic_cat",
#   "Leopardus geoffroyi", "geoffroys_cat",
#   "Lepus europaeus", "hare_rabbit",
#   "Lycalopex culpaeus", "culpeo",
#   "Sus scrofa", "wild_boar",
#   "Zaedyus pichiy", "pichi")
# 
# baar_clean <- baar |> 
#   dplyr::select(site, season, year, species, date_time) |> 
#   dplyr::left_join(start_end) |> 
#   tidyr::separate(col = species,
#                   into = paste0("sp", 1:4),
#                   sep = ";",
#                   fill = "right",
#                   extra = "merge") |> 
#   dplyr::mutate(photo_id = dplyr::row_number()) |> 
#   tidyr::pivot_longer(cols = sp1:sp4, names_to = "class_number", values_to = "species") |> 
#   dplyr::filter(!is.na(species)) |> 
#   dplyr::filter(!grepl("Birds", species)) |> 
#   dplyr::filter(!grepl("Homo sapiens", species)) |> 
#   dplyr::filter(!grepl("Equus sp.", species)) |> 
#   dplyr::filter(!grepl("Canis lupus familiaris", species)) |> 
#   dplyr::filter(!species == "") |> 
#   dplyr::filter(!grepl("Insect", species)) |> 
#   dplyr::filter(! species %in% c("Reviewing", "None", "Installing", "Uninstalling")) |> 
#   dplyr::filter(!species %in% c(" Mamma", "Mammals|Rodent", "Brds|Theristicus melanopis", 
#                                 "F. Species|", "F. Species|None", "F. Species|Uninstalling")) |> 
#   dplyr::filter(!grepl("sp.", species)) |> 
#   dplyr::mutate(species = str_remove_all(species, "Mammals")) |> 
#   dplyr::mutate(species = str_remove_all(species, "\\|")) |> 
#   dplyr::mutate(species = str_remove(species, "Species")) |> 
#   dplyr::mutate(species = str_remove(species, "F. ")) |> 
#   dplyr::mutate(species = str_trim(species, side = "left")) |> 
#   dplyr::filter(!species %in% c("Canis lupus", "Rodent")) |> 
#   dplyr::filter(!species %in% c("Phryhgilus patagonicus", "Turdus falklandii", "Vanellus chilensis")) |> 
#   tibble::add_column( city = "baar") |> 
#   dplyr::mutate(date = lubridate::as_date(date_time)) |> 
#   dplyr::left_join(baar_sp_key) |> 
#   dplyr::select(
#     city, 
#     site,
#     lat, 
#     lon, 
#     date,
#     start, 
#     end, 
#     sp) |> 
#   tibble::add_column(y = 1) |> 
#   dplyr::group_by( city, site, lat, lon, start, end, sp, date) |> 
#   dplyr::summarise( ndets = sum(y)) |> 
#   dplyr::ungroup() |> 
#   dplyr::filter( date >= start & date <= end)
# 
# # CLEVELAND
# cle <- readr::read_csv( here::here("data/not_in_db/cleveland.csv"))
# 
# cle_clean <- cle |> 
#   tidyr::separate( DateTimeStamp, into = c("date", "time"), sep = " ") |> 
#   dplyr::mutate( start = lubridate::mdy(Campaign_Start),
#                  end = lubridate::mdy(Campaign_End),
#                  date2 = lubridate::mdy(date)) |> 
#   dplyr::mutate( date3 = lubridate::ymd(date)) |> 
#   dplyr::mutate( date4 = dplyr::if_else( is.na(date3), date2, date3)) |>
#   tibble::add_column( city = "cloh") |> 
#   dplyr::select(
#     city,
#     site = Site, 
#     lat = Latitude, 
#     lon = Longitude, 
#     date = date4, 
#     start, 
#     end, 
#     sp = Species_Classification) |> 
#   tibble::add_column(y = 1) |> 
#   dplyr::group_by( city, site, lat, lon, start, end, sp, date) |> 
#   dplyr::summarise( ndets = sum(y)) |> 
#   dplyr::ungroup()
# 
# # SEATTLE
# sea <- readr::read_csv( here::here("data/not_in_db/seattle.csv"))
# 
# sea_names <- readr::read_csv( here::here("data/species_keys/names_seattle.csv")) |> 
#   dplyr::rename(sp = species)
# 
# key <- readr::read_csv( here::here("data/species_keys/species_key.csv"))
# 
# sea_clean <- sea |> 
#   tidyr::separate( timestamp, into = c("date", "time"), sep = " ") |> 
#   dplyr::mutate( start = lubridate::mdy(campaign_start), 
#                  end = lubridate::mdy(campaign_end),
#                  date = lubridate::mdy(date)) |> 
#   tibble::add_column( city = "sewa") |> 
#   dplyr::select(
#     city,
#     site = locationid, 
#     lat = latitude, 
#     lon = longitude, 
#     date, 
#     start, 
#     end,
#     sp = species) |> 
#   tibble::add_column(y = 1) |> 
#   dplyr::group_by( city, site, lat, lon, start, end, sp, date) |> 
#   dplyr::summarise( ndets = sum(y)) |> 
#   dplyr::ungroup() |> 
#   dplyr::left_join( sea_names ) |> 
#   dplyr::filter(omit == "no") |> 
#   dplyr::select(-omit) |> 
#   dplyr::left_join(
#     key |>
#       dplyr::select(sp = sea_sp, uwin_sp) |>
#       dplyr::filter(!is.na(sp))) |> 
#   dplyr::select(
#     city,
#     site, 
#     lat , 
#     lon , 
#     date, 
#     start, 
#     end,
#     sp = uwin_sp,
#     ndets) 
# 
# # ROCHESTER
# rony <- readr::read_csv( here::here("data/not_in_db/rochester/images_2002904_CLEAN.csv"))
# 
# rony_deploy <- readr::read_csv( here::here("data/not_in_db/rochester/deployments.csv"))
# 
# rony_clean <- rony |> 
#   dplyr::select( deployment_id, 
#                  roc_sp,
#                  timestamp) |> 
#   dplyr::left_join(
#     rony_deploy |> 
#       dplyr::select(
#         deployment_id, 
#         site = placename,
#         lat = latitude, 
#         lon = longitude, 
#         start = start_date, 
#         end = end_date)) |>
#   dplyr::left_join(
#     key |>
#       dplyr::select(uwin_sp, roc_sp) |>
#       dplyr::filter(!is.na(roc_sp))) |> 
#   tibble::add_column(city = "rony") |> 
#   dplyr::select(city, deployment_id, site, lat, lon, start, end, date = timestamp, sp = uwin_sp) |> 
#   dplyr::mutate(date = lubridate::as_date(date)) |>
#   dplyr::group_by(city, deployment_id, site, lat, lon, start, end, date, sp) |> 
#   tibble::add_column(y = 1) |> 
#   dplyr::summarise( ndets = sum(y)) |> 
#   dplyr::ungroup() |> 
#   dplyr::mutate( dplyr::across(start:end, function(x) lubridate::as_date(x))) |> 
#   dplyr::filter( date >= start & date <= end) |> 
#   dplyr::select(-deployment_id)
# 
# # BERLIN, GERMANY
# berlin_photo <- readxl::read_excel( 
#   path = here::here("data/not_in_db/berlin.xlsx"), 
#   sheet = "Observation")
# 
# berlin_deploy <- readxl::read_excel(
#   path = here::here("data/not_in_db/berlin.xlsx"), 
#   sheet = "Deployment") |> 
#   dplyr::select(deployment_id, camera_id, lat = garden_lat, lon = garden_long, start, end )
# 
# be_sf <- berlin_deploy |> 
#   sf::st_as_sf(coords = c("lon", "lat"), 
#                crs = 32633) |> 
#   sf::st_transform(crs = 4326) 
# 
# ber_names <- readr::read_csv( here::here("data/species_keys/names_berlin.csv"))
# 
# ber_clean <-
#   sf::st_coordinates(be_sf) |> 
#   tibble::as_tibble() |> 
#   dplyr::rename(lon = X, lat = Y) |> 
#   cbind( berlin_deploy |> 
#            dplyr::select(-lat, -lon)) |> 
#   tibble::as_tibble() |> 
#   dplyr::mutate( dplyr::across(start:end, function(x) lubridate::as_date(x))) |> 
#   dplyr::right_join(
#     berlin_photo |> 
#       dplyr::select(deployment_id, camera_id, timestamp, scientific_name)) |> 
#   dplyr::mutate(date = lubridate::as_date(timestamp)) |> 
#   dplyr::group_by(deployment_id, camera_id, lat, lon, start, end, date, scientific_name) |> 
#   tibble::add_column(y = 1) |> 
#   dplyr::summarise( ndets = sum(y),
#                     y = max(y)) |> 
#   dplyr::ungroup() |> 
#   dplyr::left_join(
#     ber_names |> 
#       dplyr::select(scientific_name = ber_name, sp = name, omit)) |> 
#   dplyr::filter( omit == "no") |> 
#   tibble::add_column(city = "bege") |> 
#   dplyr::select(city, site = camera_id, lat, lon, start, end, date, sp, ndets)
# 
# # FREIBURG, GERMANY
# fre_sf <- sf::st_read( here::here("data/not_in_db/freiburg/LocationsFreiburg.shp")) |> 
#   dplyr::select(ID = Label_ID, geometry) |> 
#   sf::st_transform(4326)
# 
# fre_coords <- sf::st_coordinates(fre_sf) |> 
#   tibble::as_tibble() |> 
#   tibble::add_column(ID = fre_sf$ID) |> 
#   dplyr::filter(!is.na(X)) |> 
#   dplyr::select(ID, lat = Y, lon = X) |> 
#   dplyr::arrange(ID)
# 
# fre <- readxl::read_excel( here::here("data/not_in_db/freiburg/freiburg.xlsx"))
# 
# fre_deploy <- fre |> 
#   dplyr::mutate(ID = as.numeric( stringr::str_replace_all(ID, "ID_", ""))) |> 
#   dplyr::left_join(fre_coords) |> 
#   dplyr::select(ID, lat, lon, DateTime, Season, Year) |> 
#   dplyr::mutate(date = lubridate::as_date(DateTime)) |> 
#   dplyr::select(-DateTime) |> 
#   dplyr::distinct() |> 
#   dplyr::group_by(ID, lat, lon, Season, Year) |> 
#   dplyr::mutate( start = min(date), 
#                  end = max(date)) |> 
#   dplyr::select(-date) |> 
#   dplyr::distinct() |> 
#   dplyr::ungroup()
# 
# readr::write_csv( fre_deploy, here::here("data/not_in_db/freiburg/freiburg_deployments.csv"))
# 
# fre_sp <- tibble(
#   sp = unique(c(unique(fre$Species), unique(fre$Species2), unique(fre$Species3))))
# 
# # write_csv( fre_sp, here::here("data/species_keys/names_freiburg.csv"))
# 
# fre_sp <- read_csv( here::here("data/species_keys/names_freiburg.csv")) |> 
#   dplyr::filter(omit == "no") |> 
#   pull(sp)
# 
# fre_omit <- read_csv( here::here("data/species_keys/names_freiburg.csv")) |> 
#   dplyr::filter(omit == "yes") |> 
#   dplyr::pull(sp)
# 
# fre_key <- read_csv( here::here("data/species_keys/names_freiburg.csv")) |> 
#   dplyr::filter(omit == "no")
# 
# fre_clean <- fre |> 
#   dplyr::filter(Species %in% fre_sp | Species2 %in% fre_sp | Species3 %in% fre_sp) |> 
#   dplyr::mutate(Species2 = ifelse(Species2 == "Empty", NA, Species2), 
#                 Species3 = ifelse(Species3 == "Empty", NA, Species3),
#                 Species2 = ifelse(Species2 == "NA", NA, Species2), 
#                 Species3 = ifelse(Species3 == "NA", NA, Species3)) |>
#   dplyr::select(ID, File, Species, Species2, Species3, DateTime, Season, Year) |> 
#   dplyr::mutate(Species = ifelse(Species %in% fre_omit, NA, Species), 
#                 Species2 = ifelse(Species2 %in% fre_omit, NA, Species2), 
#                 Species3 = ifelse(Species3 %in% fre_omit, NA, Species3)) |> 
#   tidyr::pivot_longer(Species:Species3, names_to = "sp_no", values_to = "sp") |> 
#   dplyr::filter(!is.na(sp)) |> 
#   dplyr::left_join(fre_key) |> 
#   dplyr::mutate(sp = ifelse(!is.na(replace), replace, sp)) |> 
#   dplyr::select(-omit, -replace, -sp_no) |> 
#   dplyr::distinct() |> 
#   dplyr::mutate(ID = as.numeric( stringr::str_replace_all(ID, "ID_", ""))) |> 
#   dplyr::left_join(fre_coords) |> 
#   dplyr::left_join(fre_deploy) |> 
#   dplyr::mutate(date = lubridate::as_date(DateTime)) |> 
#   dplyr::select(-DateTime) |> 
#   dplyr::select(-File) |> 
#   dplyr::group_by(ID, Season, Year, date, sp, lat, lon, start, end) |> 
#   dplyr::summarise(ndet = n()) |> 
#   dplyr::ungroup() |> 
#   dplyr::select(id = ID, lat, lon, season = Season, year = Year, start, end, date, sp, ndet ) |> 
#   dplyr::filter(!sp %in% fre_omit) |> 
#   dplyr::mutate(sp = tolower(sp)) |> 
#   dplyr::mutate(sp = stringr::str_replace_all(sp, " ", "_")) |> 
#   tibble::add_column( city = "frge") |> 
#   dplyr::select( city, site = id, lat, lon, start, end, date, sp, ndets = ndet) |> 
#   dplyr::mutate( sp = ifelse(sp == "red_squirrel", "european_red_squirrel", sp)) |> 
#   dplyr::mutate( sp = ifelse(sp == "beaver", "eurasian_beaver", sp))
# 
# readr::write_csv( fre_clean, here::here("data/not_in_db/freiburg/freiburg_wildlife_clean.csv"))
# 
# # CAPE TOWN, SOUTH AFRICA
# cpt <- readxl::read_excel( here::here("data/not_in_db/cape_town.xlsx"), sheet = "indep_records_final")
# 
# cpt_clean <- cpt |> 
#   dplyr::mutate(date = lubridate::as_date(date)) |> 
#   dplyr::group_by(station, lat, long) |> 
#   dplyr::mutate(start = min(date), 
#                 end = max(date)) |> 
#   dplyr::select(station, lat, long, start, end, date, species) |> 
#   dplyr::filter(!grepl("human", species)) |> 
#   dplyr::filter(!grepl("tech", species)) |> 
#   dplyr::filter(!species %in% c("bird", "train", "vehicle", "domestic_dog")) |> 
#   dplyr::group_by(station, lat, long, start, end, date, species) |> 
#   dplyr::summarise(ndets = n()) |> 
#   dplyr::ungroup() |> 
#   tibble::add_column(city = "ctsa") |> 
#   dplyr::select(city, site = station, lat, lon = long, start, end, date, sp = species, ndets) |> 
#   dplyr::filter(!sp %in% c("cow", "horse"))
# 
# # EDMONTON, CANADA
# edm <- readxl::read_excel( here::here("data/not_in_db/edmonton.xlsx")) |> 
#   janitor::clean_names() |> 
#   dplyr::mutate(photo_date = lubridate::as_date(photo_date),
#                 camera_start_date_and_time = lubridate::as_date(camera_start_date_and_time), 
#                 camera_end_date_and_time = lubridate::as_date(camera_end_date_and_time)) |> 
#   dplyr::select(-photo_time)
# 
# edm_cam <- readxl::read_excel( here::here("data/not_in_db/edmonton_camera_info.xlsx"),
#                                sheet = "CameraData") |> 
#   janitor::clean_names() |> 
#   dplyr::select(site_name = site_vm, lat, lon = long)
# 
# edm_sp <- readr::read_csv( here::here("data/species_keys/names_edmonton.csv")) |> 
#   dplyr::full_join(
#     tibble::tribble(
#       ~edm_sp, ~omit, ~uwin_sp, 
#       "Domestic cat", "no", "domestic_cat")) |> 
#   dplyr::filter(omit == "no") 
# 
# edm_cat <- readr::read_csv( here::here("data/not_in_db/2022.02.22_UWIN_DetectionData_Edmonton_CATS_2025-09-06.csv")) |> 
#   janitor::clean_names() |> 
#   dplyr::rename( bait_lure_used = baited_unbaited) |> 
#   dplyr::mutate(photo_date = lubridate::mdy(photo_date),
#                 camera_start_date_and_time = lubridate::mdy(camera_start_date_and_time), 
#                 camera_end_date_and_time = lubridate::mdy(camera_end_date_and_time)) |> 
#   dplyr::select(-photo_time)
# 
# edm_clean <-
#   dplyr::full_join(edm, edm_cat) |> 
#   dplyr::select( site_name, photo_date, start = camera_start_date_and_time, end = camera_end_date_and_time, 
#                  sp = common_name) |> 
#   dplyr::mutate(across(c(photo_date, start, end), function(x) lubridate::as_date(x))) |> 
#   dplyr::left_join(edm_cam) |> 
#   dplyr::right_join( edm_sp |> 
#                        dplyr::rename(sp = edm_sp )) |> 
#   tibble::add_column(city = "edca") |> 
#   dplyr::select(city, site = site_name, lat, lon, start, end, date = photo_date, sp = uwin_sp) |> 
#   dplyr::group_by(city, site, lat, lon, start, end, date, sp) |> 
#   dplyr::summarise(ndets = n()) |> 
#   dplyr::ungroup() |> 
#   dplyr::filter(date >= start & date <= end)
# 
# # SALT LAKE CITY
# slc_site <- readr::read_csv( here::here( "data/not_in_db/salt_lake/site.csv") ) |> 
#   dplyr::mutate(start = lubridate::mdy( Begin ),
#                 end = lubridate::mdy( End )) |> 
#   dplyr::select(site = Site, start, end, lat = Latitude, lon = Longitude)
# 
# slc <- readr::read_csv( here::here( "data/not_in_db/salt_lake/detection.csv")) |>
#   dplyr::mutate(date = lubridate::mdy(Photo.Date)) |> 
#   dplyr::select(site = Site, date, sp = Species) |> 
#   dplyr::left_join(slc_site) |> 
#   dplyr::full_join(
#     readr::read_csv( here::here( "data/not_in_db/salt_lake/Rabbit.Hare.2018.2022.csv")) |> 
#       dplyr::filter(!is.na(Site)) |>
#       dplyr::mutate(date = lubridate::mdy(Photo.Date)) |> 
#       dplyr::select(site = Site, date, sp = Species) |> 
#       dplyr::left_join(slc_site))
# 
# # read out unique species for annotation
# # slc |> 
# #   dplyr::select(sp) |> 
# #   dplyr::distinct() |> 
# #   dplyr::arrange(sp) |> 
# #   readr::write_csv( here::here("data/species_keys/names_salt_lake_city.csv"))
# 
# slc_clean <-
#   slc |> 
#   dplyr::left_join(
#     readr::read_csv( here::here("data/species_keys/names_salt_lake_city.csv"))) |> 
#   dplyr::filter(omit == "no") |> 
#   tibble::add_column(city = "sluh") |> 
#   dplyr::select(city, site, lat, lon, start, end, date, sp = uwin_sp) |> 
#   dplyr::group_by(city, site, lat, lon, start, end, date, sp) |> 
#   dplyr::summarise(ndets = n()) |> 
#   dplyr::ungroup()  |> 
#   dplyr::mutate(flag = ifelse(lat < 0, "negative latitude", "okay")) |> 
#   dplyr::mutate( lon_new = ifelse(lat < 0, lat, lon), 
#                  lat_new = ifelse(lat < 0, lon, lat)) |> 
#   dplyr::select(city, site, lat = lat_new, lon = lon_new, start, end, date, sp, ndets) |> 
#   dplyr::filter(date >= start & date <= end)
# 
# # readr::write_csv( here::here( "data/not_in_db/CLEAN/salt_lake.csv"))
# 
# rm( list = setdiff(ls(), names(mget(ls(pattern = "clean")))))
# 
# not_in_db_clean <- dplyr::full_join(dplyr::mutate(ber_clean, site = as.character(site)), cle_clean) |> 
#   dplyr::full_join(cpt_clean) |> 
#   dplyr::full_join(edm_clean) |> 
#   dplyr::full_join(dplyr::mutate(fre_clean, site = as.character(site))) |> 
#   dplyr::full_join(rony_clean) |> 
#   dplyr::full_join(sea_clean) |> 
#   dplyr::full_join(slc_clean) |>
#   dplyr::full_join(baar_clean) |> 
#   dplyr::filter(!is.na(sp))
# 
# # readr::read_csv( here::here("data/UWIN_det_hist.csv")) |> 
# #   dplyr::select(Species) |> 
# #   dplyr::distinct() |> 
# #   readr::write_csv( here::here("data/species_keys/uwin_species.csv"))
# 
# # not_in_db_clean |>
# #   select(sp) |>
# #   distinct() |>
# #   arrange(sp) |>
# #   dplyr::full_join(
# #     readr::read_csv( here::here("data/UWIN_det_hist.csv")) |>
# #       dplyr::select(sp = Species) |>
# #       dplyr::distinct()) |>
# #   #   readr::write_csv( here::here("data/create_final_species_list.csv"))
# 
# focal <- not_in_db_clean |>
#   dplyr::select(sp) |>
#   dplyr::distinct() |>
#   dplyr::arrange(sp) |>
#   dplyr::full_join(
#     readr::read_csv( here::here("data/UWIN_det_hist_daily.csv")) |>
#       dplyr::select(sp = Species) |>
#       dplyr::distinct()) |> 
#   dplyr::left_join(
#     readr::read_csv(here::here("data/create_final_species_list.csv"))) |>
#   dplyr::mutate( final_sp = ifelse(sp == "culpeo", "culpeo", final_sp),
#                  omit = ifelse(sp == "culpeo", "no", omit)) |> 
#   dplyr::mutate( final_sp = ifelse(sp == "geoffroys_cat", "geoffroys_cat", final_sp),
#                  omit = ifelse(sp == "geoffroys_cat", "no", omit)) |> 
#   dplyr::mutate( final_sp = ifelse(sp == "hare_rabbit", "hare_rabbit", final_sp),
#                  omit = ifelse(sp == "hare_rabbit", "no", omit)) |> 
#   dplyr::mutate(final_sp = ifelse(sp == "pichi", "pichi", final_sp), 
#                 omit = ifelse(sp == "pichi", "no", omit)) |> 
#   dplyr::select(sp, final_sp, omit) |> 
#   dplyr::mutate(final_sp = ifelse(sp == "european_edible_dormouse", "european_edible_dormouse", final_sp), 
#                 omit = ifelse(sp == "european_edible_dormouse", "yes", omit)) |>
#   dplyr::mutate(final_sp = ifelse(sp == "rabbit_hare", "hare_rabbit", final_sp), 
#                 omit = ifelse(sp == "rabbit_hare", "no", omit)) |>
#   dplyr::mutate(final_sp = ifelse(sp == "snowshoe_hare", "hare_rabbit", final_sp), 
#                 omit = ifelse(sp == "snowshoe_hare", "no", omit)) |>
#   dplyr::mutate(final_sp = ifelse(sp == "white_tailed_jackrabbit", "hare_rabbit", final_sp), 
#                 omit = ifelse(sp == "white_tailed_jackrabbit", "no", omit)) 
# 
# write_csv(focal, here::here("data/create_final_species_list.csv"))
# 
# not_in_db <- not_in_db_clean |> 
#   dplyr::left_join(readr::read_csv(here::here("data/create_final_species_list.csv"))) |> 
#   dplyr::filter(omit == "no") |> 
#   dplyr::select(city, site, lat, lon, start, end, date, sp = final_sp, ndets) |> 
#   dplyr::group_by( city, site, lat, lon, start, end, date, sp) |> 
#   dplyr::summarise( ndets = sum(ndets)) |> 
#   dplyr::ungroup() 
# 
# uwin <- readr::read_csv( here::here("data/UWIN_det_hist_daily.csv"))
# names <- readr::read_csv( here::here("data/uwin_names_resolve.csv"))
# 
# # filter to species that are going to be aggregated 
# ag_species <- uwin |> 
#   dplyr::left_join(names) |> 
#   dplyr::filter(omit == "no") |> 
#   dplyr::filter(Species != final_sp) |> 
#   dplyr::group_by( final_sp, Season, Site, Start, End, City, Long, Lat, Crs) |> 
#   dplyr::summarise( across(starts_with("Day"), function(x) sum(x))) |> 
#   dplyr::group_by( final_sp, Season, Site, Start, End, City, Long, Lat, Crs) |> 
#   dplyr::mutate( across(starts_with("Day"), function(x) ifelse(x > 1, 1, x))) |> 
#   dplyr::ungroup() |> 
#   dplyr::arrange( final_sp, City, Season, Site) |> 
#   dplyr::rename(Species = final_sp)
# 
# uwin_updated <- uwin |> 
#   dplyr::left_join(names) |> 
#   dplyr::filter(omit == "no") |> 
#   dplyr::filter(Species == final_sp) |>
#   dplyr::full_join(ag_species) |> 
#   dplyr::mutate(Species = ifelse( City == "cait" &
#                                     Species == "north_american_red_squirrel", 
#                                   "european_red_squirrel", 
#                                   Species)) |> 
#   dplyr::full_join(
#     uwin |> 
#       dplyr::left_join(names) |> 
#       dplyr::filter(omit == "no") |> 
#       dplyr::filter(Species == final_sp) |>
#       dplyr::select(-final_sp, -omit) |> 
#       dplyr::full_join(ag_species) |> 
#       dplyr::mutate(Species = ifelse( City == "cait" &
#                                         Species == "north_american_red_squirrel", 
#                                       "european_red_squirrel", 
#                                       Species)) |> 
#       dplyr::filter(City == "cait") |> 
#       dplyr::select(Season, Site, Start, End, City, Long, Lat, Crs, Day_1:Day_75) |> 
#       dplyr::distinct() |> 
#       dplyr::mutate(across(Day_1:Day_75, function(x) ifelse(x > 0, 0, x))) |> 
#       dplyr::distinct() |> 
#       tibble::add_column(Species = "north_american_red_squirrel") |> 
#       dplyr::select(Species, Season:Day_75))
# 
# nsamp <- length(grepl("^Day_|^Week_", colnames(uwin_updated)))
# 
# J <- nsamp - rowSums(
#   is.na(
#     uwin_updated[, grepl("^Day_|^Week_", colnames(uwin_updated))]
#   )
# )
# 
# Y <- rowSums(
#   uwin_updated[, grepl("^Day_|^Week_", colnames(uwin_updated))],
#   na.rm = TRUE
# )
# 
# uwin_dh <- uwin_updated |> 
#   dplyr::select(city = City, 
#                 site = Site,
#                 lat = Lat,
#                 lon = Long,
#                 start = Start,
#                 end = End,
#                 sp = Species) |> 
#   tibble::add_column(y = Y, 
#                      j = J) |> 
#   dplyr::mutate( sp = ifelse(city == "tawa" & sp == "eastern_chipmunk", "western_chipmunk", sp)) |>
#   dplyr::group_by( city, site, lat, lon, start, end, sp) |> 
#   dplyr::summarise(y = sum(y), 
#                    j = unique(j)) |> 
#   dplyr::filter(!(city == "rony")) |> 
#   dplyr::ungroup() # rochester provided separate data later
# 
# not_in_db_clean <- not_in_db |> 
#   dplyr::left_join( readr::read_csv( here::here("data/create_final_species_list.csv")) |>
#                       dplyr::select(sp, final_sp, omit)) |>
#   dplyr::filter(omit == "no") |>
#   dplyr::group_by(sp, city, site, lat, lon, start, end, date) |> 
#   dplyr::summarise( ndets = sum(ndets, na.rm = TRUE)) |> 
#   dplyr::filter(ndets > 0) |> 
#   dplyr::ungroup() |> 
#   dplyr::filter(!is.na(start))
# 
# not_in_db_dh <- not_in_db_clean |> 
#   dplyr::select( city, site, lat, lon, start, end) |> 
#   dplyr::distinct() |> 
#   dplyr::cross_join(
#     readr::read_csv( here::here("data/create_final_species_list.csv")) |>
#       dplyr::filter(omit == "no") |> 
#       dplyr::select(sp = final_sp) |> 
#       dplyr::distinct()) |>
#   dplyr::filter(!is.na(start)) |> 
#   dplyr::rowwise() |> 
#   dplyr::mutate(date = list(seq(from = start, to = end, by = 1))) |>
#   tidyr::unnest(cols = c(date)) |> 
#   dplyr::full_join(not_in_db_clean) |> 
#   dplyr::mutate(across(c(ndets), function(x) tidyr::replace_na(x, 0))) |> 
#   dplyr::group_by(city, site, lat, lon, start, end, sp) |> 
#   dplyr::summarise( y = sum(ndets > 0), 
#                     j = length(!is.na(date))) |> 
#   dplyr::ungroup()
# 
# # there are a few more species that sneak in from non-DB cities
# # these will have all-0 detection histories
# uwin_extra_species_dh <- readr::read_csv( here::here("data/create_final_species_list.csv")) |>
#   dplyr::filter(omit == "no") |> 
#   dplyr::select(sp = final_sp) |> 
#   dplyr::distinct() |> 
#   dplyr::anti_join( uwin_dh |> 
#                       dplyr::ungroup() |> 
#                       dplyr::select(sp) |> 
#                       dplyr::distinct()) |> 
#   dplyr::cross_join(
#     uwin_dh |> 
#       dplyr::ungroup() |> 
#       dplyr::select(site, start, end, city, lat, lon, j) |> 
#       dplyr::distinct()) |> 
#   tibble::add_column(y = 0) |> 
#   dplyr::select(
#     city, site, lat, lon, start, end, sp, y, j)
# 
# all <- full_join(uwin_dh, uwin_extra_species_dh) |> 
#   dplyr::full_join( not_in_db_dh )
# 
# new_xy <- readxl::read_excel( here::here("data/updated_lat_lon.xlsx")) |> 
#   dplyr::filter(!is.na(lat))
# 
# all_dh_updated_xy <- all |> 
#   dplyr::filter( site %in% unique(new_xy$site)) |> 
#   dplyr::select(-lat, -lon) |> 
#   dplyr::left_join(new_xy) |> 
#   dplyr::select(city, site, lat, lon, start, end, sp, y, j) |> 
#   dplyr::full_join(
#     all |> 
#       dplyr::filter( !(site %in% unique(new_xy$site)))) |> 
#   dplyr::arrange(city, site, start, sp) |> 
#   dplyr::group_by(city, site, lat, lon) |> 
#   dplyr::mutate(unique_id = dplyr::cur_group_id()) |> 
#   dplyr::ungroup()
# 
# all_dh_updated_xy |> 
#   dplyr::select(unique_id, city, site, lat, lon) |> 
#   dplyr::distinct() |>  
#   readr::write_csv(paste0( here::here("data/unique_coords_"), Sys.Date(), ".csv"))
# 
# ghm <- readr::read_csv(here::here("data/uwin_coords_ghm_1km.csv")) |> 
#   dplyr::select(city, site, unique_id, ghm = mean)
# 
# sp_stats <- all_dh_updated_xy |> 
#   dplyr::group_by(sp) |> 
#   dplyr::summarise( ny = sum(y)) |> 
#   dplyr::full_join(
#     all_dh_updated_xy |> 
#       dplyr::group_by(sp) |> 
#       dplyr::filter(y > 0)|> 
#       dplyr::summarise( ncity = length(unique(city)))) |> 
#   dplyr::full_join(
#     all_dh_updated_xy |> 
#       dplyr::group_by(sp) |> 
#       dplyr::filter(y > 0) |> 
#       dplyr::summarise(nsite = length(unique(site))))
# 
# # maybe as a first pass try using 50 total detections as the threshold for inclusion
# sp_stats |> 
#   filter(ny > 50) |>
#   add_column(iucn_name = NA) |> 
#   dplyr::select(sp, iucn_name, ncity, nsite, ny) |> 
#   readr::write_csv( here::here("data/focal_species_list.csv"))
# 
# focal <- readr::read_csv( here::here("data/focal_species_list.csv"))
# 
# season_codes <- tibble::tribble(
#   ~mo_start, ~season,
#   1, "WI",
#   2, "WI", 
#   3, "SP", 
#   4, "SP", 
#   5, "SP", 
#   6, "SU", 
#   7, "SU", 
#   8, "SU", 
#   9, "FA", 
#   10, "FA", 
#   11, "FA", 
#   12, "WI")
# 
# noncats <- all_dh_updated_xy |> 
#   dplyr::filter( sp %in% unique(focal$sp) ) |> 
#   dplyr::filter(! sp == "domestic_cat" ) |> 
#   dplyr::mutate( yr_start = lubridate::year(start), 
#                  mo_start = lubridate::month(start)) |> 
#   dplyr::mutate(yr_ab = stringr::str_sub(yr_start, -2)) |> 
#   dplyr::left_join(season_codes) |> 
#   dplyr::mutate( Season = paste0(season, yr_ab)) |>
#   tibble::add_column(Crs = 4326) |> 
#   dplyr::select( Species = sp, 
#                  Season, 
#                  Site = site, 
#                  City = city,
#                  Long = lon, 
#                  Lat = lat, 
#                  Crs,
#                  Y = y, 
#                  J = j, 
#                  start, 
#                  end) 
# 
# #CSV too big, trying the ole RData tricky-trick
# # save(noncats, file = here::here("data/detection_data.RData"))
# 
# kitty <- all_dh_updated_xy |> 
#   dplyr::filter(sp == "domestic_cat" ) |> 
#   dplyr::mutate(pcat = y / j ) |> 
#   dplyr::select( Site = site,
#                  City = city,
#                  Long = lon,
#                  Lat = lat,
#                  start,
#                  end,
#                  ncat = y,
#                  pcat )
# 
# all <- noncats |> 
#   dplyr::left_join(
#     ghm |> 
#       dplyr::select(City = city, 
#                     Site = site,
#                     ghm) |> 
#       dplyr::distinct()) |> 
#   dplyr::left_join(kitty) |> 
#   dplyr::ungroup() |> 
#   dplyr::select(-Long, -Lat) # drop lat-long per data sharing policies
# 
# rm( list = setdiff(ls(), "all"))
# 
# save(all, file = here::here("data/formatted_data.RData"))

#### Fit occurrence model ####

load(here::here("data/formatted_data.RData"))

final <- all |> 
  dplyr::group_by(City, Species) |> 
  dplyr::mutate(n = sum(Y)) |> 
  dplyr::filter(n > 0) |> 
  dplyr::mutate(citySp = dplyr::cur_group_id()) |> 
  dplyr::group_by(City, Species, Site) |> 
  dplyr::mutate(citySpSite = dplyr::cur_group_id()) |> 
  dplyr::ungroup() |>
  dplyr::mutate(ghmSc = as.numeric(scale(ghm)), 
                pcatSc = as.numeric(scale(pcat)))

# took a good 20 minutes or so to fit on my fairly beefy desktop.
### ran and then saved model object (code to load below)

# m1 <- glmmTMB::glmmTMB(
#   cbind(Y, J - Y) ~ 1 + ghmSc + pcatSc + ghmSc:pcatSc + (1 + ghmSc + pcatSc + ghmSc:pcatSc|citySp) + (1|citySpSite),
#   family = binomial,
#   data = final )

# save(m1, file = here::here('results/detection_model_v01.RData'))

load(here::here('results/detection_model_v01.RData'))

summary(m1)

#### Create Figure 2a ####

catsc <- scale(final$pcat)
hmsc <- scale(final$ghm)

newdata <- expand.grid(
  ghmSc = seq( from = min(final$ghmSc), to = max(final$ghmSc), length.out = 20), 
  pcatSc = c(0, 0.20),
  citySp = NA,
  citySpSite = NA) |> 
  dplyr::mutate(pcatSc = ( pcatSc - attr(catsc, "scaled:center") ) / attr(catsc, "scaled:scale"))

p <- predict(m1, newdata, type = "response", se = TRUE)

( figure_2a <- tibble(fit = p$fit,
                      se = p$se.fit) |> 
    cbind(newdata) |> 
    dplyr::mutate(ghm = ghmSc * attr(hmsc, "scaled:scale") + attr(hmsc, "scaled:center"),
                  kitty = pcatSc * attr(catsc, "scaled:scale") + attr(catsc, "scaled:center")) |> 
    dplyr::mutate(kitty = paste0(round(100*kitty,0), "%")) |> 
    
    ggplot(aes(x = ghm, y = fit, color = kitty)) +
    geom_ribbon(aes(ymin = fit - se, ymax = fit + se, fill = kitty), color = NA, alpha = 0.4) +
    geom_line(linewidth = 2)  +
    scale_color_manual(
      "days with\ncat detections",
      values = c("#AE8548", "#178F92")) +
    scale_fill_manual(
      "days with\ncat detections",
      values = c("#AE8548", "#178F92")) +
    theme_minimal() +
    labs(x = "urbanization", 
         y = "probability of detection") +
    theme(panel.grid = element_blank(),
          axis.line = element_line(linewidth = 0.2, color = "black"),
          axis.text = element_text(color = "black", size = 8),
          axis.title = element_text(color = "black", size = 10), 
          legend.title = element_text(color = "black", size = 10), 
          legend.text = element_text(color = "black", size = 8),
          legend.position = "top",
          legend.justification.top = 'left',
          legend.margin = margin(5, 0, 0, -20),
          plot.margin = margin(0, 10, 5, 5),
          plot.background = element_rect(color = NA, fill = "white")) )

ggsave(
  filename = here::here("figures/figure_02a.png"),
  width = 2.5,
  height = 3,
  units = "in",
  dpi = 600)

# calculate percent change
tibble(fit = p$fit,
       se = p$se.fit) |> 
  cbind(newdata) |> 
  dplyr::mutate(ghm = ghmSc * attr(hmsc, "scaled:scale") + attr(hmsc, "scaled:center"),
                kitty = pcatSc * attr(catsc, "scaled:scale") + attr(catsc, "scaled:center")) |> 
  dplyr::mutate(kitty = paste0(round(100*kitty,0), "%")) |> 
  group_by(kitty) |> 
  dplyr::filter(ghm == min(ghm) | ghm == max(ghm)) |> 
  dplyr::mutate(ghm = ifelse(ghm < 0.5, 'lo', 'hi')) |> 
  dplyr::select(kitty, ghm, fit) |> 
  pivot_wider(names_from = ghm, values_from = fit) |> 
  dplyr::mutate( perc = 100 * ( (hi - lo) / lo ))

#### Create Figure 2b: body mass x random slopes ####

species <- readr::read_csv(here::here("data/iucn_name_list_query.csv")) |> 
  dplyr::mutate(sci_name = ifelse(sci_name == "Otospermophilus beecheyi", 
                                  "Spermophilus beecheyi",
                                  ifelse(sci_name == "Cervus canadensis",
                                         "Cervus elaphus",
                                         ifelse(sci_name == "Sylvilagus gabbi",
                                                "Sylvilagus brasiliensis",
                                                ifelse(sci_name == "Sylvilagus tapetillus", "Sylvilagus brasiliensis",
                                                       ifelse(sci_name == "Neotamias minimus",
                                                              "Tamias minimus",
                                                              ifelse(sci_name == "Neogale vison", 
                                                                     "Neovison vison",
                                                                     ifelse(sci_name == "Urocitellus richardsonii",
                                                                            "Spermophilus richardsonii",
                                                                            ifelse(sci_name == "Otospermophilus variegatus",
                                                                                   'Spermophilus variegatus',
                                                                                   ifelse(sci_name == "Xerospermophilus tereticaudus",
                                                                                          "Spermophilus tereticaudus",
                                                                                          ifelse(sci_name == "Ictidomys tridecemlineatus",
                                                                                                 "Spermophilus tridecemlineatus",
                                                                                                 ifelse(sci_name == "Urocitellus armatus", 
                                                                                                        "Spermophilus armatus",
                                                                                                        ifelse(sci_name == "Neotamias townsendii",
                                                                                                               "Tamias townsendii",
                                                                                                               sci_name))))))))))))) |> 
  dplyr::add_row(sp = "culpeo", 
                 sci_name = "Lycalopex culpaeus")

elton <- read.delim(here::here("data/elton_mammal.txt")) |> 
  janitor::clean_names() |> 
  dplyr::select( family = msw_family_latin, 
                 sci_name = scientific,
                 mass = body_mass_value)

mass <- species |> 
  dplyr::left_join(elton) |> 
  dplyr::filter(! is.na(mass)) |> 
  dplyr::group_by(sp) |> 
  dplyr::summarise(mass = mean(mass))

m1r <- ranef(m1)

spuh <- m1r$cond$citySp |> 
  tibble::as_tibble(rownames = "citySp") |> 
  dplyr::mutate(citySp = as.numeric(citySp)) |> 
  dplyr::left_join(
    final |> 
      dplyr::select(citySp, City, Species) |> 
      dplyr::distinct()) |> 
  janitor::clean_names() |> 
  tidyr::pivot_longer(intercept:ghm_sc_pcat_sc, names_to = "param", values_to = "estimate") |> 
  dplyr::filter(!param == "intercept") |> 
  dplyr::mutate(name = dplyr::case_when(
    param == "ghm_sc" ~ "urbanization", 
    param == "pcat_sc" ~ "cat",
    param == "ghm_sc_pcat_sc" ~ "urban x cat")) |> 
  dplyr::mutate(name = factor(name, levels = c("urbanization", "cat", "urban x cat"))) |> 
  dplyr::group_by(name) |> 
  dplyr::mutate(hi = ifelse(estimate >= quantile(estimate, 0.975), 1, 0),
                lo = ifelse(estimate <= quantile(estimate, 0.025), 1, 0))

slope_mass <- spuh |> 
  dplyr::rename(sp = species) |> 
  dplyr::left_join(mass)

name_list <- unique(slope_mass$param)
res_tab <- list(list())
# post hoc analysis: do random slopes vary with body mass?
for(i in 1:length(name_list)){
  
  print(name_list[i])
  
  slope_m <- glmmTMB::glmmTMB(
    estimate ~ 1 + log(mass) + (1|sp),
    data = filter(slope_mass, param == name_list[i]))
  
  res_tab[[i]] <- summary(slope_m)$coefficients$cond |>
    tibble::as_tibble(rownames = "param") |>
    dplyr::filter(param == "log(mass)") |>
    janitor::clean_names() |>
    tibble::add_column(param_name = name_list[i] )
  
  rm(slope_m)
}

slopes <- bind_rows(res_tab) |> 
  dplyr::select(-param) |> 
  dplyr::rename(param = param_name) |> 
  dplyr::left_join(
    slope_mass |> 
      dplyr::ungroup() |> 
      dplyr::select(param, name) |> 
      dplyr::distinct()) |> 
  dplyr::mutate(pval = round(pr_z, 2)) |> 
  dplyr::mutate(pval = ifelse(pval == 0, "p < 0.01",
                              paste0( "p = ", pval))) |> 
  
  dplyr::mutate(label = paste0( sprintf( "%.2f", round(estimate, 2)), " ± ",
                                sprintf("%.2f", round(std_error, 2)), ", ", pval)) |> 
  dplyr::select(name, label) |> 
  tibble::add_column( mass = exp(8.35), 
                      estimate = -2)

com <- fixef(m1)$cond |> 
  tibble::as_tibble(rownames = "param") |>  
  dplyr::filter(!param == "(Intercept)") |> 
  dplyr::mutate(name = dplyr::case_when(
    param == "ghmSc" ~ "urbanization", 
    param == "pcatSc" ~ "cat",
    param == "ghmSc:pcatSc" ~ "urban x cat"))  |> 
  dplyr::rename(estimate = value) |> 
  dplyr::mutate(name = factor(name, levels = c("urbanization", "cat", "urban x cat")))

( figure_2b <- ggplot() +
    geom_hline(yintercept = 0, color = "black", linetype = "dashed") +
    geom_hline(data = com, aes(yintercept = estimate), color = MetBrewer::MetPalettes$Tam[[1]][4],
               linetype = "dashed") +
    geom_point(data = slope_mass, aes(x = log(mass), 
                                      y = estimate),
               alpha = 0.1,
               color = MetBrewer::MetPalettes$Hokusai3[[1]][c(4)]) +
    facet_wrap(~name) +
    theme_minimal() +
    labs(y = "slope (species x city combination)") +
    geom_smooth(data = slope_mass, aes(x = log(mass), 
                                       y = estimate),
                method = "lm",
                color = MetBrewer::MetPalettes$Hokusai3[[1]][c(5)],
                fill = MetBrewer::MetPalettes$Hokusai3[[1]][c(5)]) +
    geom_label(
      data = slopes, 
      aes(x = log(mass), 
          y = estimate, 
          label = label),
      size = 7 / .pt,
      color =MetBrewer::MetPalettes$Hokusai3[[1]][c(5)]) +
    theme(axis.line = element_line(linewidth = 0.2, color = "black"),
          axis.title = element_text(color = "black", 
                                    size = 10),
          axis.text = element_text(color = "black", 
                                   size = 8),
          strip.text = element_text(color = "black", 
                                    size = 10),
          plot.background = element_rect(fill = "white", 
                                         color = NA)) )

ggsave(
  filename = here::here("figures/figure_02b.png"),
  width = 4,
  height = 3,
  units = "in",
  dpi = 600)

#### Create Figure S1: visualizations of correlated random slopes ####

( figure_s1a <- slope_mass |> 
    ungroup() |> 
    select(city_sp, city, sp, param, estimate) |> 
    tidyr::pivot_wider(names_from = param, values_from = estimate) |> 
    
    ggplot(aes(x = ghm_sc, y = pcat_sc)) +
    geom_hline(yintercept = 0, color = "black", linetype = "dashed") +
    geom_vline(xintercept = 0, color = "black", linetype = "dashed") +
    ylim(c(-1.1, 1.46)) +
    xlim(c(-2.24, 1.95)) +
    geom_point(color = MetBrewer::MetPalettes$Ingres[[1]][c(3)],
               alpha = 0.1,
               size = 1) +
    geom_smooth(method = "lm", 
                color = MetBrewer::MetPalettes$Ingres[[1]][c(2)],
                fill = MetBrewer::MetPalettes$Ingres[[1]][c(3)]) +
    labs(x = "urbanization",
         y = "cat activity") +
    theme_minimal() +
    theme(axis.line = element_line(color = "black", linewidth = 0.2), 
          panel.grid = element_blank(), 
          plot.background = element_rect(color = NA, fill = "white"),
          axis.title = element_text(color = "black", size = 11), 
          axis.text = element_text(color = "black", size = 9),
          plot.margin = margin(5, 10, 5, 5)) )

( figure_s1b <- slope_mass |> 
    ungroup() |> 
    select(city_sp, city, sp, param, estimate) |> 
    tidyr::pivot_wider(names_from = param, values_from = estimate) |> 
    
    ggplot(aes(x = ghm_sc, y = ghm_sc_pcat_sc)) +
    geom_hline(yintercept = 0, color = "black", linetype = "dashed") +
    geom_vline(xintercept = 0, color = "black", linetype = "dashed") +
    ylim(c(-1.1, 1.46)) +
    xlim(c(-2.24, 1.95)) +
    geom_point(color = MetBrewer::MetPalettes$Ingres[[1]][c(3)],
               alpha = 0.1,
               size = 1) +
    geom_smooth(method = "lm", 
                color = MetBrewer::MetPalettes$Ingres[[1]][c(2)],
                fill = MetBrewer::MetPalettes$Ingres[[1]][c(3)]) +
    labs(x = "urbanization",
         y = "urban x cat") +
    theme_minimal() +
    theme(axis.line = element_line(color = "black", linewidth = 0.2), 
          panel.grid = element_blank(), 
          plot.background = element_rect(color = NA, fill = "white"),
          axis.title = element_text(color = "black", size = 11), 
          axis.text = element_text(color = "black", size = 9),
          plot.margin = margin(5, 10, 5, 5)) )

( figure_s1c <- slope_mass |> 
    ungroup() |> 
    select(city_sp, city, sp, param, estimate) |> 
    tidyr::pivot_wider(names_from = param, values_from = estimate) |> 
    
    ggplot(aes(x = pcat_sc, y = ghm_sc_pcat_sc)) +
    geom_hline(yintercept = 0, color = "black", linetype = "dashed") +
    geom_vline(xintercept = 0, color = "black", linetype = "dashed") +
    ylim(c(-1.1, 1.46)) +
    xlim(c(-2.24, 1.95)) +
    geom_point(color = MetBrewer::MetPalettes$Ingres[[1]][c(3)],
               alpha = 0.1,
               size = 1) +
    geom_smooth(method = "lm", 
                color = MetBrewer::MetPalettes$Ingres[[1]][c(2)],
                fill = MetBrewer::MetPalettes$Ingres[[1]][c(3)]) +
    labs(x = "cat activity",
         y = "urban x cat") +
    theme_minimal() +
    theme(axis.line = element_line(color = "black", linewidth = 0.2), 
          panel.grid = element_blank(), 
          plot.background = element_rect(color = NA, fill = "white"),
          axis.title = element_text(color = "black", size = 11), 
          axis.text = element_text(color = "black", size = 9),
          plot.margin = margin(5, 10, 5, 5)) )

figure_s1a | figure_s1b | figure_s1c

ggsave(
  filename = here::here("figures/figure_s01.png"), 
  width = 5, 
  height = 3, 
  units = "in", 
  dpi = 600)

#### Fit richness model ####

sr_df <- final |> 
  dplyr::group_by(City, Site, start, end, ghm, pcat) |> 
  dplyr::summarise( sr = sum(Y > 0)) |> 
  dplyr::ungroup() |> 
  dplyr::mutate(pcatSc = as.numeric(scale(pcat))) |> 
  dplyr::mutate(ghmSc = as.numeric(scale(ghm))) |> 
  dplyr::group_by(City, Site) |> 
  dplyr::mutate(citySite = dplyr::cur_group_id()) |> 
  dplyr::ungroup() 

# proportion of campaigns with 0 detections
( sr_df |> 
    filter(sr == 0) |> 
    nrow() ) / nrow(sr_df)

# Fit model - took a little bit of time (few minutes), so commenting out and 
# you can load the model object below

# sr_m1 <- glmmTMB(
#   sr ~ 1 + ghmSc*pcatSc + (1+ghmSc*pcatSc | City) + (1|citySite),
#   ziformula = ~ 1 + (1|citySite), 
#   family = poisson, 
#   data = sr_df)

# save(sr_m1, file = here::here('results/richness_model_v01.RData'))

#### Compare linear & quadratic terms of urbanization ####

# compare performance of simplified models with linear and quadratic terms of urbanization
# ( quadratic verision of original model did not converge )
sr_m1_simplified_linear <- glmmTMB(
  sr ~ 1 + ghmSc*pcatSc + (1|citySite),
  ziformula = ~ 1 + (1|citySite),
  family = poisson,
  data = sr_df)

sr_m1_simplified_quadratic <- glmmTMB(
  sr ~ 1 + (ghmSc + I(ghmSc^2))*pcatSc + (1|citySite),
  ziformula = ~ 1 + (1|citySite),
  family = poisson,
  data = sr_df)

AIC(sr_m1, sr_m1_simplified_linear, sr_m1_simplified_quadratic) |> 
  tibble::as_tibble(rownames = "mod") |> 
  dplyr::mutate(dAIC = AIC - min(AIC)) |> 
  dplyr::arrange(dAIC) |> 
  dplyr::mutate(cAIC = lead(AIC) - AIC)

#### Create Figure 3a ####

load(here::here('results/richness_model_v01.RData'))

summary(sr_m1)

catsc_sr <- scale(sr_df$pcat)
ghmsc_sr <- scale(sr_df$ghm)

sr_nd <- tidyr::expand_grid(
  ghmSc = seq( from = min(sr_df$ghmSc), to = max(sr_df$ghmSc), length.out = 20), 
  pcatSc = c(0, 0.20),
  City = NA,
  citySite = NA) |> 
  dplyr::mutate(pcatSc = ( pcatSc - attr(catsc_sr, "scaled:center") ) / attr(catsc_sr, "scaled:scale"))

p_sr <- predict(sr_m1, sr_nd, type = "response", se = TRUE)

( figure_3a <- tibble::tibble(fit = p_sr$fit,
                              se = p_sr$se.fit) |> 
    tibble::add_column(sr_nd) |> 
    dplyr::mutate(ghm = ghmSc*attr(ghmsc_sr, "scaled:scale") + attr(ghmsc_sr, "scaled:center")) |> 
    dplyr::mutate(cat = pcatSc*attr(catsc_sr, "scaled:scale") + attr(catsc_sr, "scaled:center")) |>
    dplyr::mutate(catlab = paste0(round(cat*100, 0), "%")) |> 
    
    ggplot(aes(x = ghm, y = fit, color = catlab)) +
    geom_ribbon(aes(ymin = fit - se, ymax = fit + se, fill = catlab), color = NA, alpha = 0.4) +
    geom_line(linewidth = 1.5)  +
    scale_color_manual(
      "days with cat detections",
      values = c("#AE8548", "#178F92")) +
    scale_fill_manual(
      "days with cat detections",
      values = c("#AE8548", "#178F92")) +
    theme_minimal() +
    labs(x = "urbanization", 
         y = "species richness") +
    theme(panel.grid = element_blank(),
          axis.line = element_line(linewidth = 0.2, color = "black"),
          axis.text = element_text(color = "black", size = 8),
          axis.title = element_text(color = "black", size = 10), 
          legend.title = element_text(color = "black", size = 10), 
          legend.text = element_text(color = "black", size = 8),
          legend.position = "none",
          plot.margin = margin(0, 10, 5, 5),
          plot.background = element_rect(color = NA, fill = "white")) )

ggsave(
  filename = here::here("figures/figure_03a.png"), 
  width = 2.5, 
  height = 2.5, 
  units = "in", 
  dpi = 600)

# calculate species richness loss over urbanization gradient under lo/hi cat activity
tibble::tibble(fit = p_sr$fit,
               se = p_sr$se.fit) |> 
  tibble::add_column(sr_nd) |> 
  dplyr::mutate(ghm = ghmSc*attr(ghmsc_sr, "scaled:scale") + attr(ghmsc_sr, "scaled:center")) |> 
  dplyr::mutate(cat = pcatSc*attr(catsc_sr, "scaled:scale") + attr(catsc_sr, "scaled:center")) |>
  dplyr::mutate(catlab = paste0(round(cat*100, 0), "%")) |> 
  dplyr::filter(ghm == min(ghm) | ghm == max(ghm)) |> 
  dplyr::select(catlab, ghm, fit) |> 
  dplyr::mutate(ghm = ifelse(ghm < 0.5, 'lo', 'hi')) |> 
  tidyr::pivot_wider(names_from = ghm, values_from = fit) |> 
  dplyr::mutate( diff = lo - hi)

#### Create Figure 3b ####

sr_m1_re <- ranef(sr_m1)

com <- fixef(sr_m1)$cond |> 
  as_tibble(rownames = "param") 

city_itx <- sr_m1_re$cond$City |> 
  as_tibble() |> 
  janitor::clean_names() |> 
  tibble::add_column( com_ghm = com |> 
                        dplyr::filter(param == "ghmSc") |> 
                        pull(value),
                      com_pcat = com |> 
                        dplyr::filter(param == "ghmSc") |> 
                        pull(value),
                      com_itx = com |> 
                        dplyr::filter(param == "ghmSc:pcatSc") |> 
                        pull(value)) |> 
  dplyr::mutate(itx = ghm_sc_pcat_sc + com_itx) |> 
  tibble::add_column(sr_df |> dplyr::select(City) |> distinct())

( figure_3b <- ggplot() +
    geom_histogram(data = city_itx, 
                   aes(x = itx),
                   bins = 20,
                   color  = MetBrewer::MetPalettes$Hokusai3[[1]][c(5)], 
                   fill = MetBrewer::MetPalettes$Hokusai3[[1]][c(4)]) +
    geom_vline(xintercept = 0,
               color = "black",
               linetype = "dashed") +
    geom_vline(data = filter(com, param == "ghmSc:pcatSc"),
               aes(xintercept = value), 
               linetype = "dashed", 
               color = "red") +
    theme_minimal() +
    labs(x = "urban x cat interaction", 
         y = "number of cities") +
    theme(panel.grid = element_blank(),
          axis.line = element_line(linewidth = 0.2, color = "black"),
          axis.text = element_text(color = "black", size = 8),
          axis.title = element_text(color = "black", size = 10), 
          legend.title = element_text(color = "black", size = 10), 
          legend.text = element_text(color = "black", size = 8),
          legend.position = "top",
          plot.margin = margin(0, 10, 5, 5),
          plot.background = element_rect(color = NA, fill = "white")) )

ggsave(
  filename = here::here("figures/figure_03b.png"), 
  width = 2.5, 
  height = 2.5, 
  units = "in", 
  dpi = 600)

#### Create Figure 3c ####

# get minimum and maximum values of urbanization for each city
# (we don't want to predict beyond observed values for urbanization)
min_max <- sr_df |> 
  group_by(City) |> 
  summarise(min_ghm = min(ghm), 
            max_ghm = max(ghm)) |> 
  dplyr::filter(City %in% c("chil", "bege")) # chicago and berlin as examples

sr_nd_city <- tidyr::expand_grid(
  ghmSc = seq( from = min(sr_df$ghmSc), to = max(sr_df$ghmSc), length.out = 50), 
  pcatSc = c(0, 0.20),
  City = c("chil", "bege"),
  citySite = NA) |> 
  dplyr::mutate(pcatSc = ( pcatSc - attr(catsc_sr, "scaled:center") ) / attr(catsc_sr, "scaled:scale"))

p_sr_city <- predict(sr_m1, sr_nd_city, type = "response", se = TRUE)

( figure_3c <- tibble::tibble(fit = p_sr_city$fit,
                              se = p_sr_city$se.fit) |> 
    tibble::add_column(sr_nd_city) |> 
    dplyr::mutate(ghm = ghmSc*attr(ghmsc_sr, "scaled:scale") + attr(ghmsc_sr, "scaled:center")) |> 
    dplyr::mutate(cat = pcatSc*attr(catsc_sr, "scaled:scale") + attr(catsc_sr, "scaled:center")) |>
    dplyr::mutate(catlab = paste0(round(cat*100, 0), "%")) |> 
    dplyr::left_join( min_max ) |> 
    dplyr::filter(ghm > min_ghm & ghm < max_ghm ) |> 
    dplyr::mutate( city_lab = dplyr::case_when(
      City == "chil" ~ "Chicago, USA", 
      City == "bege" ~ "Berlin, Germany")) |> 
    dplyr::mutate(city_lab = factor(city_lab, levels = c("Chicago, USA", "Berlin, Germany"))) |> 
    ggplot(aes(x = ghm, y = fit, color = catlab)) +
    facet_wrap(~city_lab) +
    geom_ribbon(aes(ymin = fit - se, ymax = fit + se, fill = catlab), color = NA, alpha = 0.4) +
    geom_line(linewidth = 1.5)  +
    scale_color_manual(
      "days with cat detections",
      values = c("#AE8548", "#178F92")) +
    scale_fill_manual(
      "days with cat detections",
      values = c("#AE8548", "#178F92")) +
    theme_minimal() +
    labs(x = "urbanization", 
         y = "species richness") +
    scale_x_continuous(limits = c(0, 1.0)) +
    theme(panel.grid = element_blank(),
          axis.line = element_line(linewidth = 0.2, color = "black"),
          axis.text = element_text(color = "black", size = 8),
          axis.title = element_text(color = "black", size = 10), 
          legend.title = element_text(color = "black", size = 10), 
          legend.text = element_text(color = "black", size = 8),
          strip.text = element_text(color = "black", size = 10),
          legend.position = "bottom",
          plot.margin = margin(0, 10, 5, 5),
          legend.box.margin = margin(-10, 0, 0, 0),
          plot.background = element_rect(color = NA, fill = "white")) )

ggsave(
  filename = here::here("figures/figure_03c.png"), 
  width = 5, 
  height = 3, 
  units = "in", 
  dpi = 600)

# calculate species richness loss over urbanizaton graident for the two cities
tibble::tibble(fit = p_sr_city$fit,
               se = p_sr_city$se.fit) |> 
  tibble::add_column(sr_nd_city) |> 
  dplyr::mutate(ghm = ghmSc*attr(ghmsc_sr, "scaled:scale") + attr(ghmsc_sr, "scaled:center")) |> 
  dplyr::mutate(cat = pcatSc*attr(catsc_sr, "scaled:scale") + attr(catsc_sr, "scaled:center")) |>
  dplyr::mutate(catlab = paste0(round(cat*100, 0), "%")) |> 
  dplyr::left_join( min_max ) |> 
  dplyr::filter(ghm > min_ghm & ghm < max_ghm ) |> 
  dplyr::mutate( city_lab = dplyr::case_when(
    City == "chil" ~ "Chicago, USA", 
    City == "bege" ~ "Berlin, Germany")) |> 
  dplyr::group_by(city_lab) |> 
  dplyr::filter(ghm == min(ghm) | ghm == max(ghm)) |> 
  dplyr::select(city_lab, ghm, catlab, fit) |> 
  dplyr::mutate(ghm = ifelse(ghm == min(ghm), 'lo', 'hi')) |> 
  tidyr::pivot_wider(names_from = ghm, values_from = fit) |> 
  dplyr::mutate(diff = lo - hi)

sr_nd_all <- tidyr::expand_grid(
  ghmSc = seq( from = min(sr_df$ghmSc), to = max(sr_df$ghmSc), length.out = 20), 
  pcatSc = c(0, 0.20),
  City = unique(sr_df$City),
  citySite = NA) |> 
  dplyr::mutate(pcatSc = ( pcatSc - attr(catsc_sr, "scaled:center") ) / attr(catsc_sr, "scaled:scale"))

all_p <- predict(sr_m1, sr_nd_all, type = "response", se = FALSE)

# across all cities - evaluate the cat x urbanization synergy
sr_nd_all |> 
  tibble::add_column(fit = all_p) |> 
  dplyr::group_by(City) |> 
  dplyr::filter(ghmSc == min(ghmSc) | ghmSc == max(ghmSc)) |> 
  dplyr::mutate(ghmSc = ifelse(ghmSc < 0, "lo", "hi")) |> 
  dplyr::select(-citySite) |> 
  tidyr::pivot_wider(names_from = ghmSc, values_from = fit) |> 
  dplyr::mutate(diff = lo - hi) |> 
  dplyr::mutate(pcatSc = ifelse(pcatSc < 0, 'loCat', 'hiCat')) |> 
  dplyr::select(-lo, -hi) |> 
  tidyr::pivot_wider(names_from = pcatSc, values_from = diff) |> 
  dplyr::mutate(cat_diff = hiCat - loCat) |> 
  arrange(cat_diff) #|> 
# filter(cat_diff >= 1) # 30 sppecies with cat diff > 1, 36 > 0

# number of camera-days
final |> 
  dplyr::ungroup() |> 
  dplyr::select(City, Site, start, end, J) |> 
  dplyr::distinct() |>
  dplyr::summarise( sumJ = sum(J))

# number of sites
final |> 
  dplyr::ungroup() |> 
  dplyr::select(City, Site) |> 
  dplyr::distinct() |> 
  nrow()

# earliest date
final |> 
  dplyr::ungroup() |> 
  dplyr::select(City, Site, start, end, J) |> 
  dplyr::distinct() |> 
  summarise(minstart = min(start))

#### Create Table S1:  sample size table ####
sample_info <- final |>
  dplyr::group_by(Species) |> 
  dplyr::filter(Y > 0) |> 
  dplyr::summarise(nY = sum(Y), 
                   nCity = length(unique(City))) |> 
  dplyr::left_join(species |> 
                     dplyr::rename(Species = sp)) |> 
  dplyr::mutate(sci_name = ifelse(Species == "hare_rabbit", "Leporidae sp.", 
                                  ifelse(Species == "weasel_sp", "Mustela sp.", 
                                         ifelse(Species == "rat", "Rattus sp.", 
                                                ifelse(Species == "flying_squirrel_sp", 
                                                       "Glaucomys sp.",
                                                       ifelse(Species == "gray_squirrel_sp",
                                                              "Sciurus sp.", sci_name)))))) |> 
  dplyr::distinct() |> 
  dplyr::select(common = Species, 
                scientific = sci_name, 
                nCity, 
                nY) |> 
  dplyr::arrange(-nCity)

flextable::set_flextable_defaults(font.size = 10)
ft <- flextable::flextable(sample_info)  
setwd(here::here("figures"))
tmp <- tempfile(fileext = ".docx")
officer::read_docx() |> 
  flextable::body_add_flextable(ft) |> 
  print(target = tmp)

utils::browseURL(tmp)

#### Supplemental Analysis: where are cats along the urbanization gradient? ####

# linear effect of urbanization on cat activity
catm_l <- glmmTMB(
  pcat ~ 1 + ghmSc + (1 + ghmSc | City) + (1|citySite), 
  data = sr_df, 
  family = ordbeta)

# quadratic effect of urbanization on cat activity
# convergence issues
catm_q <- glmmTMB(
  pcat ~ 1 + ghmSc + I(ghmSc^2) + (1 + ghmSc + I(ghmSc^2) | City) + (1|citySite), 
  data = sr_df, 
  family = ordbeta)

pdat <- expand_grid(
  ghmSc = seq(from = min(sr_df$ghmSc), 
              to = max(sr_df$ghmSc),
              length.out = 30),
  City = NA, 
  citySite = NA)

city_pdat <- sr_df |> 
  dplyr::select(City, ghmSc) |> 
  dplyr::group_by(City) |> 
  dplyr::filter(ghmSc == min(ghmSc) | ghmSc == max(ghmSc)) |> 
  dplyr::distinct() |> 
  dplyr::mutate(cityMin = min(ghmSc), 
                cityMax = max(ghmSc)) |> 
  dplyr::select(-ghmSc) |> 
  dplyr::distinct() |> 
  dplyr::ungroup() |> 
  rowwise() |> 
  dplyr::mutate(ghmSc = list(seq(from = cityMin, 
                                 to = cityMax, 
                                 length.out = 20))) |> 
  ungroup() |> 
  unnest() |> 
  dplyr::select(City, ghmSc) |> 
  add_column(citySite = NA)

pred_q <- predict(catm_q, pdat, type = "response", se = TRUE)
pred_city_q <- predict(catm_q, city_pdat, type = "response", se = TRUE)
pred_l <- predict(catm_l, pdat, type = "response", se = TRUE)
pred_city_l <- predict(catm_l, city_pdat, type = "response", se = TRUE)

ghm.sc <- scale(sr_df$ghm)

cit <- city_pdat |> 
  add_column( fit = pred_city_q$fit) |> 
  dplyr::mutate(ghm = ghmSc*attr(ghm.sc, "scaled:scale") + attr(ghm.sc, "scaled:center"))

overall <- pdat |> 
  cbind(
    fit = pred_q$fit, 
    se = pred_q$se.fit) |> 
  as_tibble() |> 
  dplyr::mutate(ghm = ghmSc*attr(ghm.sc, "scaled:scale") + attr(ghm.sc, "scaled:center"))

# don't really trust this given quadratic model's converngence issues
# but checking it out just for fun
ggplot() +
  geom_line(data = cit, 
            aes(x = ghm, 
                y = fit, 
                group = City),
            color = MetBrewer::MetPalettes$Isfahan1[[1]][c(2)],
            alpha = 0.5) +
  geom_ribbon(
    data = overall, 
    aes(x = ghm,
        ymin = fit - se, 
        ymax = fit + se), 
    color = NA,
    fill = MetBrewer::MetPalettes$Isfahan1[[1]][c(7)],
    alpha = 0.4) +
  geom_line(data = overall, 
            aes(x = ghm, 
                y = fit), 
            linewidth = 1,
            color = MetBrewer::MetPalettes$Isfahan1[[1]][c(7)]) +
  theme_minimal() +
  labs(x = "urbanization", 
       y = "cat activity") +
  theme(axis.line = element_line(color = "black", linewidth = 0.2), 
        panel.grid = element_blank(), 
        plot.background = element_rect(color = NA, fill = "white"),
        axis.title = element_text(color = "black", size = 11), 
        axis.text = element_text(color = "black", size = 9))

cit <- city_pdat |> 
  add_column( fit = pred_city_l$fit) |> 
  dplyr::mutate(ghm = ghmSc*attr(ghm.sc, "scaled:scale") + attr(ghm.sc, "scaled:center"))

overall <- pdat |> 
  cbind(
    fit = pred_l$fit, 
    se = pred_l$se.fit) |> 
  as_tibble() |> 
  dplyr::mutate(ghm = ghmSc*attr(ghm.sc, "scaled:scale") + attr(ghm.sc, "scaled:center"))

( figure_s2 <- ggplot() +
    geom_line(data = cit, 
              aes(x = ghm, 
                  y = fit, 
                  group = City),
              color = MetBrewer::MetPalettes$Hokusai3[[1]][c(2)],
              alpha = 0.4,
              linewidth = 0.4) +
    geom_ribbon(
      data = overall, 
      aes(x = ghm,
          ymin = fit - se, 
          ymax = fit + se), 
      color = NA,
      fill = MetBrewer::MetPalettes$Hokusai3[[1]][c(5)],
      alpha = 0.4) +
    geom_line(data = overall, 
              aes(x = ghm, 
                  y = fit), 
              linewidth = 1,
              color = MetBrewer::MetPalettes$Hokusai3[[1]][c(5)]) +
    theme_minimal() +
    labs(x = "urbanization", 
         y = "cat activity") +
    theme(axis.line = element_line(color = "black", linewidth = 0.2), 
          panel.grid = element_blank(), 
          plot.background = element_rect(color = NA, fill = "white"),
          axis.title = element_text(color = "black", size = 11), 
          axis.text = element_text(color = "black", size = 9),
          plot.margin = margin(5, 10, 5, 5)) )

ggsave(
  filename = here::here("figures/figure_s02.png"), 
  width = 3.5, 
  height = 3, 
  units = "in", 
  dpi = 600)

# do AIC comparison of simplified models with linear and quadratic terms\

catm_l_simplified <- glmmTMB(
  pcat ~ 1 + ghmSc + (1|citySite), 
  data = sr_df, 
  family = ordbeta)

catm_q_simplified <- glmmTMB(
  pcat ~ 1 + ghmSc + I(ghmSc^2) + (1|citySite), 
  data = sr_df, 
  family = ordbeta)

# slight preference for linear model
AIC(catm_l_simplified, catm_q_simplified) |> 
  as_tibble(rownames = "mod") |> 
  mutate(dAIC = AIC - min(AIC)) |> 
  arrange(dAIC)

#### Make maps for Figure 1D-E ####
# land polygon - no borders
land <- rnaturalearth::ne_download(scale = 110, type = "land", category = "physical", returnclass = "sf")

# commenting this out to protect camera coordinates
# # unique camera coordinates
# sites <- readr::read_csv( here::here("data/unique_coords_2026-09-01.csv"))
# 
# # get average location per city for range calculation
# cities <- sites |>
#   dplyr::group_by(city) |>
#   dplyr::summarise( x = mean(lon),
#                     y = mean(lat)) |>
#   sf::st_as_sf(coords = c("x", "y"),
#                crs = 4326)
# 
# # add fuzz to site coordinates
# baar <- sites |> 
#   dplyr::filter(city == "baar") |> 
#   dplyr::mutate(lat = lat + rnorm(33, 0, 0.001),
#                 lon = lon + rnorm(33, 0, 0.001)) |> 
#   sf::st_as_sf(coords = c("lon", "lat"), 
#                crs = 4326)
# 
# sf::st_write( cities, here::here("data/city_locations.shp"))
# sf::st_write( baar, here::here("data/baar_camera_locations_fuzzed.shp"))

# city locations
cities <- sf::st_read(here::here("data/city_locations.shp"))

# fuzzed camera locations for Bariloche
baar <- sf::st_read(here::here("data/baar_camera_locations_fuzzed.shp"))

( figure_01d <- ggplot() +
    geom_sf(data = land, fill = "gray60", color = NA, linewidth = 0.2) +
    geom_sf(data = cities, color = wes_palette("Darjeeling1")[[1]], size = 0.75) +
    theme_void() +
    theme(
      panel.background = element_rect(fill = wes_palette("Darjeeling2")[[4]], color = NA),
      axis.text = element_blank(),
      axis.ticks = element_blank(),
      axis.title = element_blank()) )

ggsave(
  here::here("figures/figure_01d.png"),
  width = 6, 
  height = 3.5, 
  units ="in", 
  dpi = 600)

baar_ghm <- terra::rast(here::here("data/gHM_buffer5km.tif"))

( figure_1e <- ggplot() +
    tidyterra::geom_spatraster(data = baar_ghm) + 
    scale_fill_gradientn(
      "human modification",
      colors = MetBrewer::MetPalettes$Tam[[1]][8:1],
      na.value = "transparent") +
    geom_sf(data = baar, aes(geometry = geometry),
            size = 1) +
    theme_void() +
    theme(legend.position = "top",
          legend.ticks = element_blank(),
          legend.title = element_text(color = "black", size = 8),
          legend.text = element_text(color = "black", size = 8),
          legend.box.margin = margin(0, 0, -8, 0),
          legend.key.spacing = unit(0.05, "cm")) +
    guides(
      fill = guide_colorbar(title.position = "top", 
                            title.hjust = 0.5,
                            barwidth = 5,
                            barheight = 0.25)) )

ggsave(
  here::here("figures/figure_01e.png"),
  width = 3, 
  height = 1.8, 
  units = "in", 
  dpi = 600)