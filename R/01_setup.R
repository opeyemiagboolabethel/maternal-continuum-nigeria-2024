# ============================================================
# MATERNAL CONTINUUM IN NIGERIA PROJECT: MASTER R SETUP
# ============================================================

library(haven)
library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(forcats)
library(janitor)
library(labelled)
library(survey)
library(srvyr)
library(gtsummary)
library(broom)
library(modelsummary)
library(ggplot2)
library(scales)
library(readr)
library(openxlsx)
library(DBI)
library(RPostgres)
library(here)
library(glue)
library(yaml)
library(testthat)
library(rlang)
library(tibble)

options(
  survey.lonely.psu = "adjust",
  scipen = 999,
  dplyr.summarise.inform = FALSE
)

# ------------------------------------------------------------
# READ PROJECT CONFIGURATION
# ------------------------------------------------------------

project_config <- yaml::read_yaml(
  here::here("config", "config.yml")
)$default

# ------------------------------------------------------------
# CREATE REQUIRED OUTPUT DIRECTORIES IF MISSING
# ------------------------------------------------------------

required_directories <- c(
  "data/interim",
  "data/processed",
  "data/powerbi",
  "outputs/charts",
  "outputs/tables",
  "outputs/models",
  "outputs/reports",
  "powerbi/screenshots"
)

purrr::walk(
  required_directories,
  ~ dir.create(
    here::here(.x),
    recursive = TRUE,
    showWarnings = FALSE
  )
)

# ------------------------------------------------------------
# VARIABLE-LABEL HELPERS
# ------------------------------------------------------------

get_variable_label <- function(x) {
  
  variable_label <- attr(x, "label")
  
  if (is.null(variable_label)) {
    return(NA_character_)
  }
  
  as.character(variable_label)
}

get_value_labels <- function(x) {
  
  labels <- labelled::val_labels(x)
  
  if (length(labels) == 0) {
    return(NA_character_)
  }
  
  paste(
    names(labels),
    labels,
    sep = " = ",
    collapse = " | "
  )
}

labelled_text <- function(x) {
  
  as.character(
    haven::as_factor(
      x,
      levels = "labels"
    )
  )
}

# ------------------------------------------------------------
# DHS POSTNATAL TIMING HELPER
# ------------------------------------------------------------

within_two_days <- function(time_code) {
  
  time_code <- as.numeric(time_code)
  
  dplyr::case_when(
    dplyr::between(time_code, 100, 171) ~ 1L,
    dplyr::between(time_code, 200, 202) ~ 1L,
    TRUE ~ 0L
  )
}

message("Project setup loaded successfully.")
