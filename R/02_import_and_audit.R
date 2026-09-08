# ============================================================
# MATERNAL CONTINUUM IN NIGERIA PROJECT
# IMPORT AND AUDIT 2024 NIGERIA DHS NR DATA
# ============================================================

# Load project packages, configuration, and helper functions
source(
  here::here(
    "R",
    "01_setup.R"
  )
)

# ============================================================
# 1. IDENTIFY THE RAW DATA DIRECTORY
# ============================================================

raw_directory <- here::here(
  project_config$raw_data_directory
)

message(
  "Looking for DHS data inside: ",
  raw_directory
)

# ============================================================
# 2. FIND STATA .DTA FILES
# ============================================================

dta_files <- list.files(
  path = raw_directory,
  pattern = "\\.dta$",
  full.names = TRUE,
  ignore.case = TRUE
)

message(
  "Number of .DTA files found: ",
  length(dta_files)
)

# Stop if no file exists
if (length(dta_files) == 0) {
  
  stop(
    paste0(
      "\nNo Stata .DTA file was found inside:\n",
      raw_directory,
      "\n\nPlease confirm that the extracted 2024 Nigeria ",
      "Pregnancy and Postnatal Care Recode .DTA file ",
      "is inside data/raw."
    )
  )
}

# Stop if multiple .DTA files exist
if (length(dta_files) > 1) {
  
  stop(
    paste0(
      "\nMore than one .DTA file was found inside data/raw.\n\n",
      "Files detected:\n",
      paste(
        basename(dta_files),
        collapse = "\n"
      ),
      "\n\nKeep only the 2024 Nigeria Pregnancy and ",
      "Postnatal Care Recode .DTA file in this folder ",
      "before continuing."
    )
  )
}

# Select the only .DTA file
raw_file <- dta_files[[1]]

message(
  "DHS file selected: ",
  basename(raw_file)
)

# ============================================================
# 3. IMPORT THE DHS DATA
# ============================================================

message(
  "Importing DHS data. Please wait..."
)

raw_nr <- haven::read_dta(
  raw_file
) |>
  janitor::clean_names()

message(
  "Import completed."
)

message(
  "Rows imported: ",
  nrow(raw_nr)
)

message(
  "Columns imported: ",
  ncol(raw_nr)
)

# ============================================================
# 4. CREATE A VARIABLE INVENTORY
# ============================================================

variable_inventory <- tibble::tibble(
  
  variable = names(raw_nr),
  
  variable_label = purrr::map_chr(
    raw_nr,
    get_variable_label
  ),
  
  value_labels = purrr::map_chr(
    raw_nr,
    get_value_labels
  ),
  
  r_class = purrr::map_chr(
    raw_nr,
    ~ paste(
      class(.x),
      collapse = ", "
    )
  ),
  
  missing_n = purrr::map_int(
    raw_nr,
    ~ sum(
      is.na(.x)
    )
  ),
  
  missing_percent = purrr::map_dbl(
    raw_nr,
    ~ mean(
      is.na(.x)
    ) * 100
  ),
  
  unique_n = purrr::map_int(
    raw_nr,
    ~ dplyr::n_distinct(
      .x,
      na.rm = TRUE
    )
  )
)

# Save the inventory
readr::write_csv(
  variable_inventory,
  here::here(
    "outputs",
    "tables",
    "variable_inventory.csv"
  )
)

# ============================================================
# 5. SEARCH VARIABLE LABELS FOR IMPORTANT CONCEPTS
# ============================================================

concept_pattern <- paste(
  c(
    "antenatal",
    "prenatal",
    "delivery",
    "postnatal",
    "newborn",
    "insurance",
    "distance",
    "decision",
    "wealth",
    "education",
    "region",
    "residence"
  ),
  collapse = "|"
)

concept_variables <- variable_inventory |>
  dplyr::filter(
    stringr::str_detect(
      stringr::str_to_lower(
        dplyr::coalesce(
          variable_label,
          ""
        )
      ),
      concept_pattern
    )
  )

readr::write_csv(
  concept_variables,
  here::here(
    "outputs",
    "tables",
    "concept_variable_search.csv"
  )
)

# ============================================================
# 6. CHECK FOR EXPECTED CORE VARIABLES
# ============================================================

core_required <- c(
  "v001",
  "v002",
  "v003",
  "v005",
  "v021",
  "v024",
  "v025",
  "v012",
  "v013",
  "v106",
  "v190",
  "p19",
  "m80",
  "m13",
  "m14",
  "m15",
  "m2a",
  "m2b",
  "m2n",
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
  "m76"
)

missing_core <- setdiff(
  core_required,
  names(raw_nr)
)

if (length(missing_core) == 0) {
  
  message(
    "All expected core variables were found."
  )
  
} else {
  
  warning(
    paste0(
      "Some expected variables were not found:\n",
      paste(
        missing_core,
        collapse = ", "
      ),
      "\n\nDo not panic. We will inspect this before deriving indicators."
    )
  )
}

# ============================================================
# 7. CHECK SURVEY STRATA VARIABLES
# ============================================================

v022_available <- "v022" %in% names(raw_nr)
v023_available <- "v023" %in% names(raw_nr)

message(
  "v022 available: ",
  v022_available
)

message(
  "v023 available: ",
  v023_available
)

if (
  !v022_available &&
  !v023_available
) {
  
  stop(
    paste0(
      "Neither v022 nor v023 was found.\n",
      "We cannot specify the complex survey design ",
      "until the survey-stratum variable is identified."
    )
  )
}

# ============================================================
# 8. SAVE PRIVATE LOCAL R COPY
# ============================================================

saveRDS(
  raw_nr,
  here::here(
    "data",
    "interim",
    "raw_nr_imported.rds"
  )
)

# ============================================================
# 9. CREATE IMPORT AUDIT SUMMARY
# ============================================================

audit_summary <- tibble::tibble(
  
  check = c(
    "Source filename",
    "Imported rows",
    "Imported columns",
    "Expected core variables missing",
    "v022 available",
    "v023 available"
  ),
  
  result = c(
    basename(raw_file),
    
    as.character(
      nrow(raw_nr)
    ),
    
    as.character(
      ncol(raw_nr)
    ),
    
    ifelse(
      length(missing_core) == 0,
      "None",
      paste(
        missing_core,
        collapse = ", "
      )
    ),
    
    as.character(
      v022_available
    ),
    
    as.character(
      v023_available
    )
  )
)

readr::write_csv(
  audit_summary,
  here::here(
    "outputs",
    "tables",
    "import_audit_summary.csv"
  )
)

# ============================================================
# 10. FINAL COMPLETION MESSAGE
# ============================================================

message(
  "============================================"
)

message(
  "PART 22 COMPLETED: DHS IMPORT AND AUDIT SUCCESSFUL"
)

message(
  "============================================"
)