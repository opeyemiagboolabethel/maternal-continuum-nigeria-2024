required_packages <- c(
  "haven",
  "dplyr",
  "tidyr",
  "purrr",
  "stringr",
  "forcats",
  "janitor",
  "labelled",
  "survey",
  "srvyr",
  "gtsummary",
  "broom",
  "modelsummary",
  "ggplot2",
  "scales",
  "readr",
  "openxlsx",
  "DBI",
  "RPostgres",
  "here",
  "glue",
  "yaml",
  "renv",
  "testthat",
  "rlang",
  "tibble"
)

renv::install(required_packages)

renv::snapshot()

message("Required R packages installed and renv snapshot created.")