# ============================================================
# SQL SOURCE FILE STRUCTURE INVENTORY
# Maternal Continuum of Care and Postnatal Equity in Nigeria
# ============================================================

library(dplyr)
library(purrr)
library(readr)
library(tibble)
library(here)

# ------------------------------------------------------------
# 1. Define core files proposed for PostgreSQL ingestion
# ------------------------------------------------------------

sql_source_files <- c(
  
  "weighted_national_indicator_estimates.csv",
  
  "weighted_equity_estimates_public.csv",
  
  "equity_gap_summary.csv",
  
  "state_indicator_estimates_public.csv",
  
  "adjusted_odds_ratios.csv",
  
  "unadjusted_odds_ratios.csv",
  
  "sensitivity_adjusted_models.csv",
  
  "sensitivity_prevalence_comparison.csv",
  
  "cohort_demographic_profile.csv",
  
  "cohort_flow.csv",
  
  "continuum_pathway_distribution.csv",
  
  "mother_newborn_pnc_crosstab.csv",
  
  "model_outcome_summary.csv"
)

# ------------------------------------------------------------
# 2. Build full paths
# ------------------------------------------------------------

sql_source_paths <- here::here(
  "outputs",
  "tables",
  sql_source_files
)

# ------------------------------------------------------------
# 3. Check files exist
# ------------------------------------------------------------

file_check <- tibble(
  
  file_name = sql_source_files,
  
  file_path = sql_source_paths,
  
  exists = file.exists(
    sql_source_paths
  )
)

print(
  file_check,
  n = Inf
)

if (
  any(
    !file_check$exists
  )
) {
  
  stop(
    "One or more proposed SQL source files are missing."
  )
}

# ------------------------------------------------------------
# 4. Function to inspect one CSV
# ------------------------------------------------------------

inspect_csv <- function(
    file_path
) {
  
  data <- readr::read_csv(
    file_path,
    show_col_types = FALSE
  )
  
  tibble(
    
    file_name =
      basename(
        file_path
      ),
    
    row_count =
      nrow(
        data
      ),
    
    column_count =
      ncol(
        data
      ),
    
    column_position =
      seq_along(
        names(data)
      ),
    
    column_name =
      names(
        data
      ),
    
    r_class =
      purrr::map_chr(
        data,
        ~ paste(
          class(.x),
          collapse = " | "
        )
      ),
    
    missing_count =
      purrr::map_int(
        data,
        ~ sum(
          is.na(.x)
        )
      ),
    
    distinct_values =
      purrr::map_int(
        data,
        dplyr::n_distinct
      )
  )
}

# ------------------------------------------------------------
# 5. Inspect all proposed SQL source files
# ------------------------------------------------------------

sql_structure_inventory <- purrr::map_dfr(
  sql_source_paths,
  inspect_csv
)

# ------------------------------------------------------------
# 6. Create file-level summary
# ------------------------------------------------------------

sql_file_inventory <- sql_structure_inventory |>
  dplyr::distinct(
    file_name,
    row_count,
    column_count
  ) |>
  dplyr::arrange(
    file_name
  )

# ------------------------------------------------------------
# 7. Save inventories
# ------------------------------------------------------------

readr::write_csv(
  
  sql_file_inventory,
  
  here::here(
    "outputs",
    "tables",
    "sql_source_file_inventory.csv"
  )
)

readr::write_csv(
  
  sql_structure_inventory,
  
  here::here(
    "outputs",
    "tables",
    "sql_source_column_inventory.csv"
  )
)

# ------------------------------------------------------------
# 8. Print results
# ------------------------------------------------------------

message(
  "=============================================="
)

message(
  "SQL SOURCE FILE INVENTORY"
)

message(
  "=============================================="
)

print(
  sql_file_inventory,
  n = Inf,
  width = Inf
)

message(
  "=============================================="
)

message(
  "SQL SOURCE STRUCTURE INVENTORY CREATED"
)

message(
  "=============================================="
)