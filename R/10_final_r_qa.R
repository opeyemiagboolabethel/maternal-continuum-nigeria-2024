# ============================================================
# FINAL R ANALYTICAL QA AND RECONCILIATION
# MATERNAL CONTINUUM OF CARE
# 2024 NIGERIA DEMOGRAPHIC AND HEALTH SURVEY
# ============================================================

source(
  here::here(
    "R",
    "01_setup.R"
  )
)

# ============================================================
# 1. DEFINE REQUIRED ANALYTICAL FILES
# ============================================================

required_files <- c(
  
  analytical_dataset =
    here::here(
      "data",
      "processed",
      "maternal_continuum_analytic.rds"
    ),
  
  national_estimates =
    here::here(
      "outputs",
      "tables",
      "weighted_national_indicator_estimates.csv"
    ),
  
  national_qa =
    here::here(
      "outputs",
      "tables",
      "weighted_analysis_quality_summary.csv"
    ),
  
  equity_estimates =
    here::here(
      "outputs",
      "tables",
      "weighted_equity_estimates_public.csv"
    ),
  
  equity_qa =
    here::here(
      "outputs",
      "tables",
      "equity_analysis_quality_summary.csv"
    ),
  
  equity_gap_summary =
    here::here(
      "outputs",
      "tables",
      "equity_gap_summary.csv"
    ),
  
  equity_gap_qa =
    here::here(
      "outputs",
      "tables",
      "equity_gap_quality_summary.csv"
    ),
  
  state_estimates =
    here::here(
      "outputs",
      "tables",
      "state_indicator_estimates_public.csv"
    ),
  
  state_ranking =
    here::here(
      "outputs",
      "tables",
      "complete_continuum_state_ranking.csv"
    ),
  
  geographic_national =
    here::here(
      "outputs",
      "tables",
      "national_geographic_comparison.csv"
    ),
  
  geographic_qa =
    here::here(
      "outputs",
      "tables",
      "geographic_analysis_quality_summary.csv"
    ),
  
  adjusted_model =
    here::here(
      "outputs",
      "tables",
      "adjusted_odds_ratios.csv"
    ),
  
  model_qa =
    here::here(
      "outputs",
      "tables",
      "statistical_model_quality_summary.csv"
    ),
  
  model_outcome_summary =
    here::here(
      "outputs",
      "tables",
      "model_outcome_summary.csv"
    ),
  
  sensitivity_prevalence =
    here::here(
      "outputs",
      "tables",
      "sensitivity_prevalence_comparison.csv"
    ),
  
  sensitivity_models =
    here::here(
      "outputs",
      "tables",
      "sensitivity_adjusted_models.csv"
    ),
  
  sensitivity_qa =
    here::here(
      "outputs",
      "tables",
      "sensitivity_analysis_quality_summary.csv"
    )
)

# ============================================================
# 2. CHECK THAT ALL REQUIRED FILES EXIST
# ============================================================

file_existence_table <- tibble::tibble(
  
  object =
    names(
      required_files
    ),
  
  file =
    unname(
      required_files
    ),
  
  exists =
    file.exists(
      required_files
    )
)

missing_required_files <- file_existence_table |>
  dplyr::filter(
    !exists
  )

if (
  nrow(
    missing_required_files
  ) > 0
) {
  
  print(
    missing_required_files,
    n = Inf,
    width = Inf
  )
  
  stop(
    paste0(
      "Required analytical files are missing:\n",
      paste(
        missing_required_files$file,
        collapse = "\n"
      )
    )
  )
}

message(
  "All required analytical files are present."
)

# ============================================================
# 3. LOAD ANALYTICAL DATA AND OUTPUTS
# ============================================================

analytic <- readRDS(
  required_files[["analytical_dataset"]]
)

national_estimates <- readr::read_csv(
  required_files[["national_estimates"]],
  show_col_types = FALSE
)

national_qa <- readr::read_csv(
  required_files[["national_qa"]],
  show_col_types = FALSE
)

equity_estimates <- readr::read_csv(
  required_files[["equity_estimates"]],
  show_col_types = FALSE
)

equity_qa <- readr::read_csv(
  required_files[["equity_qa"]],
  show_col_types = FALSE
)

equity_gap_summary <- readr::read_csv(
  required_files[["equity_gap_summary"]],
  show_col_types = FALSE
)

equity_gap_qa <- readr::read_csv(
  required_files[["equity_gap_qa"]],
  show_col_types = FALSE
)

state_estimates <- readr::read_csv(
  required_files[["state_estimates"]],
  show_col_types = FALSE
)

state_ranking <- readr::read_csv(
  required_files[["state_ranking"]],
  show_col_types = FALSE
)

geographic_national <- readr::read_csv(
  required_files[["geographic_national"]],
  show_col_types = FALSE
)

geographic_qa <- readr::read_csv(
  required_files[["geographic_qa"]],
  show_col_types = FALSE
)

adjusted_model_results <- readr::read_csv(
  required_files[["adjusted_model"]],
  show_col_types = FALSE
)

model_qa <- readr::read_csv(
  required_files[["model_qa"]],
  show_col_types = FALSE
)

model_outcome_summary <- readr::read_csv(
  required_files[["model_outcome_summary"]],
  show_col_types = FALSE
)

sensitivity_prevalence <- readr::read_csv(
  required_files[["sensitivity_prevalence"]],
  show_col_types = FALSE
)

sensitivity_models <- readr::read_csv(
  required_files[["sensitivity_models"]],
  show_col_types = FALSE
)

sensitivity_qa <- readr::read_csv(
  required_files[["sensitivity_qa"]],
  show_col_types = FALSE
)

message(
  "All analytical outputs loaded successfully."
)

# ============================================================
# 4. BASIC FINAL DATASET QA
# ============================================================

analytic_records <- nrow(
  analytic
)

analytic_variables <- ncol(
  analytic
)

duplicate_case_rows <- sum(
  duplicated(
    analytic
  )
)

required_final_indicators <- c(
  "anc_4plus",
  "anc_8plus",
  "skilled_birth",
  "facility_delivery",
  "mother_pnc_2days",
  "newborn_pnc_2days",
  "paired_pnc_2days",
  "complete_continuum",
  "complete_continuum_anc8",
  "complete_continuum_facility"
)

missing_final_indicators <- setdiff(
  required_final_indicators,
  names(
    analytic
  )
)

if (
  length(
    missing_final_indicators
  ) > 0
) {
  
  stop(
    paste0(
      "Final analytical dataset is missing indicators: ",
      paste(
        missing_final_indicators,
        collapse = ", "
      )
    )
  )
}

# ============================================================
# 5. VALIDATE FINAL BINARY INDICATORS
# ============================================================

validate_binary_final <- function(
    variable,
    data
) {
  
  values <- unique(
    stats::na.omit(
      data[[variable]]
    )
  )
  
  all(
    values %in%
      c(
        0,
        1
      )
  )
}

binary_validation <- tibble::tibble(
  
  variable =
    required_final_indicators,
  
  valid_binary_coding =
    purrr::map_lgl(
      required_final_indicators,
      ~ validate_binary_final(
        variable = .x,
        data = analytic
      )
    )
)

invalid_binary_indicators <- sum(
  !binary_validation$valid_binary_coding
)

if (
  invalid_binary_indicators > 0
) {
  
  print(
    binary_validation,
    n = Inf
  )
  
  stop(
    "One or more final analytical indicators do not use valid 0/1/NA coding."
  )
}

# ============================================================
# 6. NATIONAL ESTIMATE INTERNAL QA
# ============================================================

required_national_columns <- c(
  "variable",
  "indicator",
  "weighted_percent",
  "confidence_interval_low_percent",
  "confidence_interval_high_percent"
)

missing_national_columns <- setdiff(
  required_national_columns,
  names(
    national_estimates
  )
)

if (
  length(
    missing_national_columns
  ) > 0
) {
  
  stop(
    paste0(
      "National estimate table is missing columns: ",
      paste(
        missing_national_columns,
        collapse = ", "
      )
    )
  )
}

invalid_national_percentages <- sum(
  national_estimates$weighted_percent < 0 |
    national_estimates$weighted_percent > 100,
  na.rm = TRUE
)

invalid_national_ci_order <- sum(
  national_estimates$confidence_interval_low_percent >
    national_estimates$confidence_interval_high_percent,
  na.rm = TRUE
)

missing_national_estimates <- sum(
  is.na(
    national_estimates$weighted_percent
  )
)

if (
  invalid_national_percentages > 0
) {
  stop(
    "Invalid national weighted percentages detected."
  )
}

if (
  invalid_national_ci_order > 0
) {
  stop(
    "Invalid national confidence interval ordering detected."
  )
}

if (
  missing_national_estimates > 0
) {
  stop(
    "Missing national weighted estimates detected."
  )
}

# ============================================================
# 7. RECONCILE NATIONAL ESTIMATES WITH GEOGRAPHIC ANALYSIS
# ============================================================

required_geographic_national_columns <- c(
  "indicator_variable",
  "indicator",
  "national_percent"
)

missing_geographic_national_columns <- setdiff(
  required_geographic_national_columns,
  names(
    geographic_national
  )
)

if (
  length(
    missing_geographic_national_columns
  ) > 0
) {
  
  stop(
    paste0(
      "Geographic national comparison table is missing columns: ",
      paste(
        missing_geographic_national_columns,
        collapse = ", "
      )
    )
  )
}

national_geo_reconciliation <- national_estimates |>
  dplyr::inner_join(
    geographic_national,
    by = c(
      "variable" =
        "indicator_variable",
      "indicator"
    )
  ) |>
  dplyr::mutate(
    
    absolute_difference_pp =
      abs(
        weighted_percent -
          national_percent
      ),
    
    reconciliation_status =
      dplyr::case_when(
        
        absolute_difference_pp <=
          0.02 ~
          "PASS",
        
        TRUE ~
          "FAIL"
      )
  )

if (
  nrow(
    national_geo_reconciliation
  ) == 0
) {
  
  stop(
    "No national estimates could be reconciled with geographic national estimates."
  )
}

national_geo_failures <- sum(
  national_geo_reconciliation$reconciliation_status ==
    "FAIL"
)

if (
  national_geo_failures > 0
) {
  
  print(
    national_geo_reconciliation |>
      dplyr::filter(
        reconciliation_status ==
          "FAIL"
      ),
    n = Inf,
    width = Inf
  )
  
  stop(
    paste0(
      "National estimates failed geographic reconciliation for ",
      national_geo_failures,
      " indicators."
    )
  )
}

# ============================================================
# 8. CHECK EXPECTED GEOGRAPHIC COVERAGE
# ============================================================

required_state_columns <- c(
  "state",
  "indicator"
)

missing_state_columns <- setdiff(
  required_state_columns,
  names(
    state_estimates
  )
)

if (
  length(
    missing_state_columns
  ) > 0
) {
  
  stop(
    paste0(
      "State estimate table is missing columns: ",
      paste(
        missing_state_columns,
        collapse = ", "
      )
    )
  )
}

state_units <- dplyr::n_distinct(
  state_estimates$state
)

state_indicator_count <- dplyr::n_distinct(
  state_estimates$indicator
)

expected_state_estimates <-
  state_units *
  state_indicator_count

actual_state_estimates <- nrow(
  state_estimates
)

state_ranking_units <- dplyr::n_distinct(
  state_ranking$state
)

if (
  state_units != 37
) {
  
  stop(
    paste0(
      "Expected 37 state/FCT units but found ",
      state_units,
      "."
    )
  )
}

if (
  actual_state_estimates !=
  expected_state_estimates
) {
  
  stop(
    paste0(
      "Expected ",
      expected_state_estimates,
      " state-indicator rows but found ",
      actual_state_estimates,
      "."
    )
  )
}

if (
  state_ranking_units != 37
) {
  
  stop(
    paste0(
      "Complete-continuum ranking contains ",
      state_ranking_units,
      " geographic units instead of 37."
    )
  )
}

# ============================================================
# 9. PUBLIC REPORTING CONTROL QA
# ============================================================

required_equity_public_columns <- c(
  "reporting_status",
  "public_weighted_percent"
)

missing_equity_public_columns <- setdiff(
  required_equity_public_columns,
  names(
    equity_estimates
  )
)

if (
  length(
    missing_equity_public_columns
  ) > 0
) {
  
  stop(
    paste0(
      "Public equity estimate table is missing columns: ",
      paste(
        missing_equity_public_columns,
        collapse = ", "
      )
    )
  )
}

suppressed_equity_rows <- equity_estimates |>
  dplyr::filter(
    reporting_status ==
      "Suppress"
  )

suppressed_equity_exposure <- sum(
  !is.na(
    suppressed_equity_rows$public_weighted_percent
  )
)

if (
  suppressed_equity_exposure > 0
) {
  
  stop(
    "Suppressed equity estimates remain visible in the public weighted-percentage field."
  )
}

required_state_public_columns <- c(
  "reporting_status",
  "public_weighted_percent"
)

missing_state_public_columns <- setdiff(
  required_state_public_columns,
  names(
    state_estimates
  )
)

if (
  length(
    missing_state_public_columns
  ) > 0
) {
  
  stop(
    paste0(
      "Public state estimate table is missing columns: ",
      paste(
        missing_state_public_columns,
        collapse = ", "
      )
    )
  )
}

suppressed_state_rows <- state_estimates |>
  dplyr::filter(
    reporting_status ==
      "Suppress"
  )

suppressed_state_exposure <- sum(
  !is.na(
    suppressed_state_rows$public_weighted_percent
  )
)

if (
  suppressed_state_exposure > 0
) {
  
  stop(
    "Suppressed state estimates remain visible in the public weighted-percentage field."
  )
}

# ============================================================
# 10. EQUITY GAP QA
# ============================================================

required_equity_gap_columns <- c(
  "absolute_gap_pp",
  "relative_ratio"
)

missing_equity_gap_columns <- setdiff(
  required_equity_gap_columns,
  names(
    equity_gap_summary
  )
)

if (
  length(
    missing_equity_gap_columns
  ) > 0
) {
  
  stop(
    paste0(
      "Equity gap table is missing columns: ",
      paste(
        missing_equity_gap_columns,
        collapse = ", "
      )
    )
  )
}

negative_equity_gaps <- sum(
  equity_gap_summary$absolute_gap_pp < 0,
  na.rm = TRUE
)

equity_ratios_below_one <- sum(
  equity_gap_summary$relative_ratio < 1,
  na.rm = TRUE
)

if (
  negative_equity_gaps > 0
) {
  stop(
    "Negative equity gaps detected in final reconciliation."
  )
}

if (
  equity_ratios_below_one > 0
) {
  stop(
    "Relative equity ratios below one detected."
  )
}

# ============================================================
# 11. REGRESSION OUTPUT QA
# ============================================================

required_model_columns <- c(
  "odds_ratio",
  "confidence_interval_low",
  "confidence_interval_high",
  "p_value"
)

missing_model_columns <- setdiff(
  required_model_columns,
  names(
    adjusted_model_results
  )
)

if (
  length(
    missing_model_columns
  ) > 0
) {
  
  stop(
    paste0(
      "Adjusted model output is missing columns: ",
      paste(
        missing_model_columns,
        collapse = ", "
      )
    )
  )
}

invalid_adjusted_or <- sum(
  !is.finite(
    adjusted_model_results$odds_ratio
  ) |
    adjusted_model_results$odds_ratio <= 0,
  na.rm = TRUE
)

invalid_adjusted_ci <- sum(
  adjusted_model_results$confidence_interval_low >
    adjusted_model_results$confidence_interval_high,
  na.rm = TRUE
)

invalid_adjusted_p <- sum(
  adjusted_model_results$p_value < 0 |
    adjusted_model_results$p_value > 1,
  na.rm = TRUE
)

if (
  invalid_adjusted_or > 0
) {
  stop(
    "Invalid adjusted odds ratios detected."
  )
}

if (
  invalid_adjusted_ci > 0
) {
  stop(
    "Invalid adjusted model confidence intervals detected."
  )
}

if (
  invalid_adjusted_p > 0
) {
  stop(
    "Invalid adjusted model p-values detected."
  )
}

# ============================================================
# 12. SENSITIVITY OUTPUT QA
# ============================================================

required_sensitivity_prevalence_columns <- c(
  "outcome_variable",
  "weighted_percent"
)

missing_sensitivity_prevalence_columns <- setdiff(
  required_sensitivity_prevalence_columns,
  names(
    sensitivity_prevalence
  )
)

if (
  length(
    missing_sensitivity_prevalence_columns
  ) > 0
) {
  
  stop(
    paste0(
      "Sensitivity prevalence table is missing columns: ",
      paste(
        missing_sensitivity_prevalence_columns,
        collapse = ", "
      )
    )
  )
}

required_sensitivity_model_columns <- c(
  "adjusted_odds_ratio",
  "confidence_interval_low",
  "confidence_interval_high",
  "p_value"
)

missing_sensitivity_model_columns <- setdiff(
  required_sensitivity_model_columns,
  names(
    sensitivity_models
  )
)

if (
  length(
    missing_sensitivity_model_columns
  ) > 0
) {
  
  stop(
    paste0(
      "Sensitivity model table is missing columns: ",
      paste(
        missing_sensitivity_model_columns,
        collapse = ", "
      )
    )
  )
}

invalid_sensitivity_prevalence <- sum(
  sensitivity_prevalence$weighted_percent < 0 |
    sensitivity_prevalence$weighted_percent > 100,
  na.rm = TRUE
)

invalid_sensitivity_or <- sum(
  !is.finite(
    sensitivity_models$adjusted_odds_ratio
  ) |
    sensitivity_models$adjusted_odds_ratio <= 0,
  na.rm = TRUE
)

invalid_sensitivity_ci <- sum(
  sensitivity_models$confidence_interval_low >
    sensitivity_models$confidence_interval_high,
  na.rm = TRUE
)

invalid_sensitivity_p <- sum(
  sensitivity_models$p_value < 0 |
    sensitivity_models$p_value > 1,
  na.rm = TRUE
)

if (
  invalid_sensitivity_prevalence > 0
) {
  stop(
    "Invalid sensitivity prevalence estimates detected."
  )
}

if (
  invalid_sensitivity_or > 0
) {
  stop(
    "Invalid sensitivity adjusted odds ratios detected."
  )
}

if (
  invalid_sensitivity_ci > 0
) {
  stop(
    "Invalid sensitivity confidence intervals detected."
  )
}

if (
  invalid_sensitivity_p > 0
) {
  stop(
    "Invalid sensitivity p-values detected."
  )
}

# ============================================================
# 13. CHECK ANC8 SUBSET RELATIONSHIP DIRECTLY
# ============================================================

anc8_subset_violations_direct <- sum(
  
  analytic$complete_continuum_anc8 == 1 &
    analytic$complete_continuum != 1,
  
  na.rm = TRUE
)

if (
  anc8_subset_violations_direct > 0
) {
  
  stop(
    paste0(
      "ANC8 subset relationship violated in ",
      anc8_subset_violations_direct,
      " records."
    )
  )
}

# ============================================================
# 14. CREATE QA RESULT EXTRACTION HELPER
# ============================================================

extract_qa_result <- function(
    qa_table,
    quality_label
) {
  
  if (
    !all(
      c(
        "quality_check",
        "result"
      ) %in%
      names(
        qa_table
      )
    )
  ) {
    
    return(
      NA_real_
    )
  }
  
  value <- qa_table |>
    dplyr::filter(
      quality_check ==
        quality_label
    ) |>
    dplyr::pull(
      result
    )
  
  if (
    length(
      value
    ) == 0
  ) {
    
    return(
      NA_real_
    )
  }
  
  suppressWarnings(
    as.numeric(
      value[1]
    )
  )
}

# ============================================================
# 15. EXTRACT CRITICAL HISTORICAL QA RESULTS
# ============================================================

qa_registry <- tibble::tribble(
  
  ~analysis_stage,
  ~quality_check,
  ~result,
  ~expected_result,
  
  "National weighted analysis",
  "Weighted percentages outside 0-100",
  extract_qa_result(
    national_qa,
    "Weighted percentages outside 0-100"
  ),
  0,
  
  "National weighted analysis",
  "Invalid confidence interval ordering",
  extract_qa_result(
    national_qa,
    "Invalid confidence interval ordering"
  ),
  0,
  
  "National weighted analysis",
  "Missing weighted estimates",
  extract_qa_result(
    national_qa,
    "Missing weighted estimates"
  ),
  0,
  
  "Equity analysis",
  "Invalid weighted percentages",
  extract_qa_result(
    equity_qa,
    "Invalid weighted percentages"
  ),
  0,
  
  "Equity analysis",
  "Invalid confidence intervals",
  extract_qa_result(
    equity_qa,
    "Invalid confidence intervals"
  ),
  0,
  
  "Equity gap analysis",
  "Negative absolute gaps",
  extract_qa_result(
    equity_gap_qa,
    "Negative absolute gaps"
  ),
  0,
  
  "Equity gap analysis",
  "Relative ratios below one",
  extract_qa_result(
    equity_gap_qa,
    "Relative ratios below one"
  ),
  0,
  
  "Equity gap analysis",
  "Invalid relative shortfalls",
  extract_qa_result(
    equity_gap_qa,
    "Invalid relative shortfalls"
  ),
  0,
  
  "Geographic analysis",
  "Invalid state percentages",
  extract_qa_result(
    geographic_qa,
    "Invalid state percentages"
  ),
  0,
  
  "Geographic analysis",
  "Invalid state confidence intervals",
  extract_qa_result(
    geographic_qa,
    "Invalid state confidence intervals"
  ),
  0,
  
  "Statistical modelling",
  "Invalid adjusted odds ratios",
  extract_qa_result(
    model_qa,
    "Invalid adjusted odds ratios"
  ),
  0,
  
  "Statistical modelling",
  "Invalid adjusted confidence intervals",
  extract_qa_result(
    model_qa,
    "Invalid adjusted confidence intervals"
  ),
  0,
  
  "Statistical modelling",
  "Invalid adjusted-model p-values",
  extract_qa_result(
    model_qa,
    "Invalid adjusted-model p-values"
  ),
  0,
  
  "Statistical modelling",
  "Adjusted model converged",
  extract_qa_result(
    model_qa,
    "Adjusted model converged"
  ),
  1,
  
  "Sensitivity analysis",
  "ANC8 subset violations",
  extract_qa_result(
    sensitivity_qa,
    "ANC8 subset violations"
  ),
  0,
  
  "Sensitivity analysis",
  "Invalid adjusted odds ratios",
  extract_qa_result(
    sensitivity_qa,
    "Invalid adjusted odds ratios"
  ),
  0,
  
  "Sensitivity analysis",
  "Invalid adjusted confidence intervals",
  extract_qa_result(
    sensitivity_qa,
    "Invalid adjusted confidence intervals"
  ),
  0,
  
  "Sensitivity analysis",
  "Invalid adjusted-model p-values",
  extract_qa_result(
    sensitivity_qa,
    "Invalid adjusted-model p-values"
  ),
  0
)

qa_registry <- qa_registry |>
  dplyr::mutate(
    
    status =
      dplyr::case_when(
        
        is.na(
          result
        ) ~
          "FAIL - missing QA result",
        
        result ==
          expected_result ~
          "PASS",
        
        TRUE ~
          "FAIL"
      )
  )

historical_qa_failures <- sum(
  qa_registry$status !=
    "PASS"
)

if (
  historical_qa_failures > 0
) {
  
  print(
    qa_registry,
    n = Inf,
    width = Inf
  )
  
  stop(
    paste0(
      historical_qa_failures,
      " critical historical QA checks failed."
    )
  )
}

# ============================================================
# 16. COMPARE PRIMARY OUTCOME ACROSS ANALYTICAL CONTEXTS
# ============================================================

national_primary <- national_estimates |>
  dplyr::filter(
    variable ==
      "complete_continuum"
  ) |>
  dplyr::pull(
    weighted_percent
  )

if (
  length(
    national_primary
  ) == 0
) {
  stop(
    "Primary complete-continuum national estimate was not found."
  )
}

if (
  !"weighted_complete_continuum_percent" %in%
  names(
    model_outcome_summary
  )
) {
  stop(
    "model_outcome_summary does not contain weighted_complete_continuum_percent."
  )
}

model_primary <- model_outcome_summary |>
  dplyr::pull(
    weighted_complete_continuum_percent
  )

sensitivity_primary <- sensitivity_prevalence |>
  dplyr::filter(
    outcome_variable ==
      "complete_continuum"
  ) |>
  dplyr::pull(
    weighted_percent
  )

if (
  length(
    sensitivity_primary
  ) == 0
) {
  stop(
    "Primary complete-continuum sensitivity estimate was not found."
  )
}

primary_outcome_context_comparison <- tibble::tibble(
  
  analytical_context = c(
    "Full analytical cohort",
    "Adjusted-model complete-case sample",
    "Sensitivity common complete-case sample"
  ),
  
  weighted_complete_continuum_percent = c(
    national_primary[1],
    model_primary[1],
    sensitivity_primary[1]
  )
) |>
  dplyr::mutate(
    
    difference_from_full_cohort_pp =
      round(
        weighted_complete_continuum_percent -
          dplyr::first(
            weighted_complete_continuum_percent
          ),
        2
      )
  )

# ============================================================
# 17. CREATE FINAL RECONCILIATION SUMMARY
# ============================================================

final_reconciliation_summary <- tibble::tibble(
  
  quality_check = c(
    
    "Required analytical files missing",
    
    "Final analytical records",
    
    "Final analytical variables",
    
    "Invalid final binary indicators",
    
    "Duplicate complete rows in analytical dataset",
    
    "Invalid national percentages",
    
    "Invalid national confidence interval ordering",
    
    "Missing national estimates",
    
    "National-geographic reconciliation failures",
    
    "State/FCT units represented",
    
    "State-indicator estimates expected",
    
    "State-indicator estimates generated",
    
    "Complete-continuum geographic units ranked",
    
    "Suppressed equity estimates exposed",
    
    "Suppressed state estimates exposed",
    
    "Negative final equity gaps",
    
    "Final equity ratios below one",
    
    "Invalid adjusted odds ratios",
    
    "Invalid adjusted confidence intervals",
    
    "Invalid adjusted p-values",
    
    "Invalid sensitivity prevalence values",
    
    "Invalid sensitivity odds ratios",
    
    "Invalid sensitivity confidence intervals",
    
    "Invalid sensitivity p-values",
    
    "Direct ANC8 subset violations",
    
    "Critical historical QA failures"
  ),
  
  result = c(
    
    nrow(
      missing_required_files
    ),
    
    analytic_records,
    
    analytic_variables,
    
    invalid_binary_indicators,
    
    duplicate_case_rows,
    
    invalid_national_percentages,
    
    invalid_national_ci_order,
    
    missing_national_estimates,
    
    national_geo_failures,
    
    state_units,
    
    expected_state_estimates,
    
    actual_state_estimates,
    
    state_ranking_units,
    
    suppressed_equity_exposure,
    
    suppressed_state_exposure,
    
    negative_equity_gaps,
    
    equity_ratios_below_one,
    
    invalid_adjusted_or,
    
    invalid_adjusted_ci,
    
    invalid_adjusted_p,
    
    invalid_sensitivity_prevalence,
    
    invalid_sensitivity_or,
    
    invalid_sensitivity_ci,
    
    invalid_sensitivity_p,
    
    anc8_subset_violations_direct,
    
    historical_qa_failures
  )
)

# ============================================================
# 18. CREATE PIPELINE MANIFEST
# ============================================================

pipeline_manifest <- tibble::tribble(
  
  ~sequence,
  ~script,
  ~purpose,
  
  1,
  "00_install_packages.R",
  "Package installation",
  
  2,
  "01_setup.R",
  "Project configuration and helper functions",
  
  3,
  "02_import_and_audit.R",
  "DHS data import and source audit",
  
  4,
  "02b_validate_variables.R",
  "Variable and metadata validation",
  
  5,
  "03_clean_and_derive.R",
  "Analytical cohort and indicator derivation",
  
  6,
  "04_weighted_analysis.R",
  "Survey-weighted national estimates",
  
  7,
  "05_equity_analysis.R",
  "Survey-weighted subgroup equity analysis",
  
  8,
  "06_equity_gaps.R",
  "Equity gap quantification",
  
  9,
  "07_geographic_analysis.R",
  "State-level geographic analysis",
  
  10,
  "08_statistical_modelling.R",
  "Survey-weighted multivariable modelling",
  
  11,
  "09_sensitivity_analysis.R",
  "Sensitivity and robustness analysis",
  
  12,
  "10_final_r_qa.R",
  "Final analytical QA and reconciliation"
)

# ============================================================
# 19. CREATE FINAL READINESS STATUS
# ============================================================

critical_failure_vector <- c(
  
  nrow(
    missing_required_files
  ),
  
  invalid_binary_indicators,
  
  invalid_national_percentages,
  
  invalid_national_ci_order,
  
  missing_national_estimates,
  
  national_geo_failures,
  
  as.integer(
    state_units != 37
  ),
  
  as.integer(
    actual_state_estimates !=
      expected_state_estimates
  ),
  
  as.integer(
    state_ranking_units != 37
  ),
  
  suppressed_equity_exposure,
  
  suppressed_state_exposure,
  
  negative_equity_gaps,
  
  equity_ratios_below_one,
  
  invalid_adjusted_or,
  
  invalid_adjusted_ci,
  
  invalid_adjusted_p,
  
  invalid_sensitivity_prevalence,
  
  invalid_sensitivity_or,
  
  invalid_sensitivity_ci,
  
  invalid_sensitivity_p,
  
  anc8_subset_violations_direct,
  
  historical_qa_failures
)

critical_final_failures <- sum(
  critical_failure_vector > 0
)

final_r_pipeline_status <- tibble::tibble(
  
  status =
    if (
      critical_final_failures == 0
    ) {
      "PASS"
    } else {
      "FAIL"
    },
  
  critical_failures =
    critical_final_failures,
  
  analytical_records =
    analytic_records,
  
  national_indicators =
    nrow(
      national_estimates
    ),
  
  equity_estimates =
    nrow(
      equity_estimates
    ),
  
  state_indicator_estimates =
    nrow(
      state_estimates
    ),
  
  adjusted_model_terms =
    nrow(
      adjusted_model_results
    ),
  
  sensitivity_model_terms =
    nrow(
      sensitivity_models
    )
)

# ============================================================
# 20. SAVE FINAL QA OUTPUTS
# ============================================================

readr::write_csv(
  file_existence_table,
  here::here(
    "outputs",
    "tables",
    "final_required_file_check.csv"
  )
)

readr::write_csv(
  binary_validation,
  here::here(
    "outputs",
    "tables",
    "final_binary_indicator_validation.csv"
  )
)

readr::write_csv(
  national_geo_reconciliation,
  here::here(
    "outputs",
    "tables",
    "national_geographic_reconciliation.csv"
  )
)

readr::write_csv(
  qa_registry,
  here::here(
    "outputs",
    "tables",
    "historical_qa_registry.csv"
  )
)

readr::write_csv(
  primary_outcome_context_comparison,
  here::here(
    "outputs",
    "tables",
    "primary_outcome_context_comparison.csv"
  )
)

readr::write_csv(
  final_reconciliation_summary,
  here::here(
    "outputs",
    "tables",
    "final_r_reconciliation_summary.csv"
  )
)

readr::write_csv(
  pipeline_manifest,
  here::here(
    "outputs",
    "tables",
    "r_pipeline_manifest.csv"
  )
)

readr::write_csv(
  final_r_pipeline_status,
  here::here(
    "outputs",
    "tables",
    "final_r_pipeline_status.csv"
  )
)

# ============================================================
# 21. SAVE POWER BI-READY QA OUTPUTS
# ============================================================

readr::write_csv(
  final_reconciliation_summary,
  here::here(
    "data",
    "powerbi",
    "project_qa_summary.csv"
  )
)

readr::write_csv(
  final_r_pipeline_status,
  here::here(
    "data",
    "powerbi",
    "project_pipeline_status.csv"
  )
)

# ============================================================
# 22. PRINT FINAL RESULTS
# ============================================================

message(
  "------------------------------------------------------------"
)

message(
  "FINAL R PIPELINE STATUS"
)

message(
  "------------------------------------------------------------"
)

print(
  final_r_pipeline_status,
  n = Inf,
  width = Inf
)

message(
  "------------------------------------------------------------"
)

message(
  "FINAL RECONCILIATION SUMMARY"
)

message(
  "------------------------------------------------------------"
)

print(
  final_reconciliation_summary,
  n = Inf,
  width = Inf
)

message(
  "------------------------------------------------------------"
)

message(
  "NATIONAL-GEOGRAPHIC RECONCILIATION"
)

message(
  "------------------------------------------------------------"
)

print(
  national_geo_reconciliation,
  n = Inf,
  width = Inf
)

message(
  "------------------------------------------------------------"
)

message(
  "PRIMARY OUTCOME ACROSS ANALYTICAL CONTEXTS"
)

message(
  "------------------------------------------------------------"
)

print(
  primary_outcome_context_comparison,
  n = Inf,
  width = Inf
)

# ============================================================
# 23. FINAL COMPLETION CHECK
# ============================================================

if (
  critical_final_failures > 0
) {
  
  stop(
    paste0(
      "Final R analytical QA failed with ",
      critical_final_failures,
      " critical issue(s)."
    )
  )
}

message(
  "============================================================"
)

message(
  "FINAL R ANALYTICAL QA PASSED: analytical pipeline reconciled successfully."
)

message(
  "============================================================"
)