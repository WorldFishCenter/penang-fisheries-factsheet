# Prepare workspace -------------------------------------------------------

library(magrittr)
library(drake)

# load functions
f <- lapply(list.files(path = here::here("R"), full.names = TRUE,
                       include.dirs = TRUE, pattern = "*.R"), source)

# Variables
# raw_data_object_uri <- "gs://penang-catch/penang-fisheries-landings.xlsx"

# Authenticate
# googleCloudStorageR::gcs_auth(json_file = "auth/penang-catch-auth.json")
# bigrquery::bq_auth(path = "auth/tracking-auth.json")
# Tracks bigquery connection
# con <- DBI::dbConnect(
#   bigrquery::bigquery(),
#   project = "peskas",
#   dataset = "tracking",
#   billing = "peskas")
#
# tracking_raw <- dplyr::tbl(con, "tracking_raw")

# Plan analysis ------------------------------------------------------------

get_data <- drake_plan(
  # data_download = target(
    # command = googleCloudStorageR::gcs_get_object(
    #   object_name = raw_data_object_uri,
    #   saveToDisk = file_out("data/raw/penang-fisheries-landings.xlsx"),
    #   overwrite = TRUE)),
  landings = readxl::read_excel(
    path = file_in("data/raw/penang-fisheries-landings.xlsx"),
    sheet = "catch"),
  species = readxl::read_excel(
    path = file_in("data/raw/penang-fisheries-landings.xlsx"),
    sheet = "species"),
  report_dates = c(as.Date("2019-09-01"), as.Date("2021-08-31")),
)

clean_data <- drake_plan(
  landings_clean = clean_landings(landings),
  species_clean = clean_species(species),
  points = clean_points(file_in("data/raw/points.csv")),
  boats = clean_boats(file_in("data/raw/boats.csv")),
  landing_sites = clean_landing_sites(file_in("data/raw/landingsites_coords.txt")),
  trips = process_trips(landings_clean, points, boats, report_dates),

)

modeling <- drake_plan(
  base_formula = brms::brmsformula(. ~ 1 + (1 | fisher) + (1 | wday) + (1 | week)),
  landing_model = model_landings(trips, base_formula),
  vessel_model = model_vessel(trips, base_formula),
)

test_plan <- drake_plan(
  trip_id_tests = test_trip_id(landings_clean),
  # rec_id_tests = test_rec_id(landings),
  imei_tests = test_imei(landings_clean),
  # species_tests = test_species(landings_clean, species_clean),
  weight_tests = test_weight(landings_clean),
  price_tests = test_price(landings_clean),
)

report_plan <- drake_plan(
  readme = target(
    command = rmarkdown::render(knitr_in("README.Rmd"))
  )
)

full_plan <- dplyr::bind_rows(get_data,
                   clean_data,
                   test_plan,
                   modeling,
                   report_plan,
                   )

# Execute plan ------------------------------------------------------------

if (!is.null(full_plan)) {
  make(full_plan, lock_envir = FALSE)
}
