# ============================================================
# KEY VARIABLE VALIDATION
# 2024 NIGERIA DEMOGRAPHIC AND HEALTH SURVEY
# ============================================================

# Load project configuration, packages, and helper functions
source(
  here::here(
    "R",
    "01_setup.R"
  )
)

# ------------------------------------------------------------
# Load imported DHS dataset
# ------------------------------------------------------------

input_file <- here::here(
  "data",
  "interim",
  "raw_nr_imported.rds"
)

if (!file.exists(input_file)) {
  stop(
    paste0(
      "Imported DHS dataset not found at:\n",
      input_file,
      "\nRun R/02_import_and_audit.R before this script."
    )
  )
}

raw_nr <- readRDS(input_file)

message(
  "Dataset loaded: ",
  format(nrow(raw_nr), big.mark = ","),
  " rows x ",
  format(ncol(raw_nr), big.mark = ","),
  " variables."
)

# ------------------------------------------------------------
# Helper: safely create human-readable values
# ------------------------------------------------------------

get_display_values <- function(x) {
  
  is_labelled <- inherits(x, "haven_labelled") ||
    inherits(x, "labelled")
  
  if (is_labelled) {
    
    return(
      as.character(
        haven::as_factor(
          x,
          levels = "both"
        )
      )
    )
  }
  
  as.character(x)
}

# ------------------------------------------------------------
# Define variables required for analytical validation
# ------------------------------------------------------------

key_variables <- c(
  
  # Survey design and geography
  "v005",
  "v021",
  "v022",
  "v023",
  "v024",
  "v025",
  
  # Demographic and equity characteristics
  "v012",
  "v013",
  "v106",
  "v190",
  "v201",
  "v501",
  "v714",
  "v481",
  "v467d",
  "v743a",
  "v743b",
  "v743d",
  
  # Pregnancy outcome and timing
  "p19",
  "m80",
  
  # Antenatal care providers
  "m2a",
  "m2b",
  "m2c",
  "m2d",
  "m2e",
  "m2f",
  "m2g",
  "m2h",
  "m2i",
  "m2j",
  "m2k",
  "m2l",
  "m2m",
  "m2n",
  
  # ANC timing and number of contacts
  "m13",
  "m14",
  
  # ANC content
  "m42c",
  "m42d",
  "m42e",
  "m42f",
  "m42g",
  "m42h",
  "m42i",
  
  # Delivery place and assistance
  "m15",
  "m3a",
  "m3b",
  "m3c",
  "m3d",
  "m3e",
  "m3f",
  "m3g",
  "m3h",
  "m3i",
  "m3j",
  "m3k",
  "m3l",
  "m3m",
  "m3n",
  
  # Maternal postnatal care
  "m62",
  "m63",
  "m64",
  "m66",
  "m67",
  "m68",
  
  # Newborn postnatal care
  "m70",
  "m71",
  "m72",
  "m74",
  "m75",
  "m76"
)

available_key_variables <- intersect(
  key_variables,
  names(raw_nr)
)

missing_key_variables <- setdiff(
  key_variables,
  names(raw_nr)
)

message(
  "Variables requested: ",
  length(key_variables)
)

message(
  "Variables available: ",
  length(available_key_variables)
)

message(
  "Variables absent: ",
  length(missing_key_variables)
)

# ------------------------------------------------------------
# Build variable metadata table
# ------------------------------------------------------------

key_variable_metadata <- purrr::map_dfr(
  available_key_variables,
  function(variable_name) {
    
    variable_data <- raw_nr[[variable_name]]
    
    tibble::tibble(
      variable = variable_name,
      
      variable_label = get_variable_label(
        variable_data
      ),
      
      value_labels = get_value_labels(
        variable_data
      ),
      
      r_class = paste(
        class(variable_data),
        collapse = ", "
      ),
      
      total_n = length(
        variable_data
      ),
      
      nonmissing_n = sum(
        !is.na(variable_data)
      ),
      
      missing_n = sum(
        is.na(variable_data)
      ),
      
      missing_percent = mean(
        is.na(variable_data)
      ) * 100,
      
      unique_nonmissing_values = dplyr::n_distinct(
        variable_data,
        na.rm = TRUE
      )
    )
  }
)

readr::write_csv(
  key_variable_metadata,
  here::here(
    "outputs",
    "tables",
    "key_variable_metadata.csv"
  )
)

# ------------------------------------------------------------
# Build value-frequency table
# ------------------------------------------------------------

key_variable_value_counts <- purrr::map_dfr(
  available_key_variables,
  function(variable_name) {
    
    variable_data <- raw_nr[[variable_name]]
    
    raw_values <- as.character(
      variable_data
    )
    
    display_values <- get_display_values(
      variable_data
    )
    
    tibble::tibble(
      variable = variable_name,
      
      raw_value = dplyr::if_else(
        is.na(raw_values),
        "<MISSING>",
        raw_values
      ),
      
      display_value = dplyr::if_else(
        is.na(display_values),
        "<MISSING>",
        display_values
      )
    ) |>
      dplyr::count(
        variable,
        raw_value,
        display_value,
        name = "n"
      ) |>
      dplyr::mutate(
        percent = n / sum(n) * 100
      ) |>
      dplyr::arrange(
        variable,
        dplyr::desc(n)
      )
  }
)

readr::write_csv(
  key_variable_value_counts,
  here::here(
    "outputs",
    "tables",
    "key_variable_value_counts.csv"
  )
)

# ------------------------------------------------------------
# Record unavailable expected variables
# ------------------------------------------------------------

missing_variable_report <- tibble::tibble(
  variable = missing_key_variables
)

readr::write_csv(
  missing_variable_report,
  here::here(
    "outputs",
    "tables",
    "missing_key_variables.csv"
  )
)

# ------------------------------------------------------------
# Define analytical domains
# ------------------------------------------------------------

cohort_variables <- c(
  "p19",
  "m80"
)

anc_variables <- c(
  paste0(
    "m2",
    letters[1:14]
  ),
  "m13",
  "m14",
  paste0(
    "m42",
    letters[3:9]
  )
)

delivery_variables <- c(
  "m15",
  paste0(
    "m3",
    letters[1:14]
  )
)

pnc_variables <- c(
  "m62",
  "m63",
  "m64",
  "m66",
  "m67",
  "m68",
  "m70",
  "m71",
  "m72",
  "m74",
  "m75",
  "m76"
)

equity_variables <- c(
  "v012",
  "v013",
  "v106",
  "v190",
  "v201",
  "v501",
  "v714",
  "v481",
  "v467d",
  "v743a",
  "v743b",
  "v743d"
)

survey_design_variables <- c(
  "v005",
  "v021",
  "v022",
  "v023",
  "v024",
  "v025"
)

# ------------------------------------------------------------
# Create domain-specific metadata tables
# ------------------------------------------------------------

validation_cohort_variables <- key_variable_metadata |>
  dplyr::filter(
    variable %in% cohort_variables
  )

validation_anc_variables <- key_variable_metadata |>
  dplyr::filter(
    variable %in% anc_variables
  )

validation_delivery_variables <- key_variable_metadata |>
  dplyr::filter(
    variable %in% delivery_variables
  )

validation_pnc_variables <- key_variable_metadata |>
  dplyr::filter(
    variable %in% pnc_variables
  )

validation_equity_variables <- key_variable_metadata |>
  dplyr::filter(
    variable %in% equity_variables
  )

validation_survey_design_variables <- key_variable_metadata |>
  dplyr::filter(
    variable %in% survey_design_variables
  )

# ------------------------------------------------------------
# Save domain-specific metadata tables
# ------------------------------------------------------------

readr::write_csv(
  validation_cohort_variables,
  here::here(
    "outputs",
    "tables",
    "validation_cohort_variables.csv"
  )
)

readr::write_csv(
  validation_anc_variables,
  here::here(
    "outputs",
    "tables",
    "validation_anc_variables.csv"
  )
)

readr::write_csv(
  validation_delivery_variables,
  here::here(
    "outputs",
    "tables",
    "validation_delivery_variables.csv"
  )
)

readr::write_csv(
  validation_pnc_variables,
  here::here(
    "outputs",
    "tables",
    "validation_pnc_variables.csv"
  )
)

readr::write_csv(
  validation_equity_variables,
  here::here(
    "outputs",
    "tables",
    "validation_equity_variables.csv"
  )
)

readr::write_csv(
  validation_survey_design_variables,
  here::here(
    "outputs",
    "tables",
    "validation_survey_design_variables.csv"
  )
)

# ------------------------------------------------------------
# Create focused frequency tables for core indicators
# ------------------------------------------------------------

core_indicator_variables <- c(
  "p19",
  "m80",
  "m2a",
  "m2b",
  "m2n",
  "m13",
  "m14",
  "m15",
  "m3a",
  "m3b",
  "m62",
  "m63",
  "m64",
  "m66",
  "m67",
  "m68",
  "m70",
  "m71",
  "m72",
  "m74",
  "m75",
  "m76",
  "v022",
  "v023"
)

core_indicator_value_counts <- key_variable_value_counts |>
  dplyr::filter(
    variable %in% core_indicator_variables
  )

readr::write_csv(
  core_indicator_value_counts,
  here::here(
    "outputs",
    "tables",
    "core_indicator_value_counts.csv"
  )
)

# ------------------------------------------------------------
# Create domain-specific frequency tables
# ------------------------------------------------------------

anc_value_counts <- key_variable_value_counts |>
  dplyr::filter(
    variable %in% anc_variables
  )

delivery_value_counts <- key_variable_value_counts |>
  dplyr::filter(
    variable %in% delivery_variables
  )

pnc_value_counts <- key_variable_value_counts |>
  dplyr::filter(
    variable %in% pnc_variables
  )

equity_value_counts <- key_variable_value_counts |>
  dplyr::filter(
    variable %in% equity_variables
  )

survey_design_value_counts <- key_variable_value_counts |>
  dplyr::filter(
    variable %in% survey_design_variables
  )

readr::write_csv(
  anc_value_counts,
  here::here(
    "outputs",
    "tables",
    "validation_anc_value_counts.csv"
  )
)

readr::write_csv(
  delivery_value_counts,
  here::here(
    "outputs",
    "tables",
    "validation_delivery_value_counts.csv"
  )
)

readr::write_csv(
  pnc_value_counts,
  here::here(
    "outputs",
    "tables",
    "validation_pnc_value_counts.csv"
  )
)

readr::write_csv(
  equity_value_counts,
  here::here(
    "outputs",
    "tables",
    "validation_equity_value_counts.csv"
  )
)

readr::write_csv(
  survey_design_value_counts,
  here::here(
    "outputs",
    "tables",
    "validation_survey_design_value_counts.csv"
  )
)

# ------------------------------------------------------------
# Print concise core-variable summary
# ------------------------------------------------------------

console_summary <- key_variable_metadata |>
  dplyr::filter(
    variable %in% core_indicator_variables
  ) |>
  dplyr::select(
    variable,
    variable_label,
    value_labels,
    missing_n,
    unique_nonmissing_values
  )

print(
  console_summary,
  n = Inf,
  width = Inf
)

# ------------------------------------------------------------
# Final validation status
# ------------------------------------------------------------

message(
  "Variable validation completed successfully."
)

message(
  "Validation outputs saved to outputs/tables."
)