# ============================================================
# SURVEY-WEIGHTED NATIONAL ESTIMATES
# 2024 NIGERIA DEMOGRAPHIC AND HEALTH SURVEY
# ============================================================

source(
  here::here(
    "R",
    "01_setup.R"
  )
)

# ------------------------------------------------------------
# Load derived analytical dataset
# ------------------------------------------------------------

analytic_file <- here::here(
  "data",
  "processed",
  "maternal_continuum_analytic.rds"
)

if (!file.exists(analytic_file)) {
  stop(
    paste0(
      "Derived analytical dataset not found at:\n",
      analytic_file,
      "\nRun R/03_clean_and_derive.R first."
    )
  )
}

analytic <- readRDS(
  analytic_file
)

message(
  "Analytical dataset loaded: ",
  format(
    nrow(analytic),
    big.mark = ","
  ),
  " records."
)

# ------------------------------------------------------------
# Validate survey-design variables
# ------------------------------------------------------------

survey_required_variables <- c(
  "cluster_id",
  "stratum_id",
  "survey_weight"
)

missing_survey_variables <- setdiff(
  survey_required_variables,
  names(analytic)
)

if (length(missing_survey_variables) > 0) {
  stop(
    paste0(
      "Required survey-design variables are missing: ",
      paste(
        missing_survey_variables,
        collapse = ", "
      )
    )
  )
}

missing_psu <- sum(
  is.na(
    analytic$cluster_id
  )
)

missing_strata <- sum(
  is.na(
    analytic$stratum_id
  )
)

missing_weights <- sum(
  is.na(
    analytic$survey_weight
  )
)

nonpositive_weights <- sum(
  analytic$survey_weight <= 0,
  na.rm = TRUE
)

if (missing_psu > 0) {
  stop(
    "Missing primary sampling unit values were detected."
  )
}

if (missing_strata > 0) {
  stop(
    "Missing survey-stratum values were detected."
  )
}

if (missing_weights > 0) {
  stop(
    "Missing survey weights were detected."
  )
}

if (nonpositive_weights > 0) {
  stop(
    "Non-positive survey weights were detected."
  )
}

# ------------------------------------------------------------
# Specify complex survey design
# ------------------------------------------------------------

options(
  survey.lonely.psu = "adjust"
)

dhs_design <- survey::svydesign(
  ids = ~cluster_id,
  strata = ~stratum_id,
  weights = ~survey_weight,
  data = analytic,
  nest = TRUE
)

# ------------------------------------------------------------
# Summarise survey design
# ------------------------------------------------------------

survey_design_summary <- tibble::tibble(
  
  metric = c(
    "Analytical records",
    "Primary sampling units",
    "Sampling strata",
    "Survey design degrees of freedom",
    "Minimum survey weight",
    "Maximum survey weight",
    "Mean survey weight"
  ),
  
  value = c(
    
    nrow(analytic),
    
    dplyr::n_distinct(
      analytic$cluster_id
    ),
    
    dplyr::n_distinct(
      analytic$stratum_id
    ),
    
    survey::degf(
      dhs_design
    ),
    
    min(
      analytic$survey_weight,
      na.rm = TRUE
    ),
    
    max(
      analytic$survey_weight,
      na.rm = TRUE
    ),
    
    mean(
      analytic$survey_weight,
      na.rm = TRUE
    )
  )
)

# ------------------------------------------------------------
# Define national indicators
# ------------------------------------------------------------

indicator_dictionary <- tibble::tribble(
  
  ~variable,
  ~indicator,
  
  "anc_any",
  "Any antenatal care",
  
  "skilled_anc",
  "ANC from skilled provider",
  
  "early_anc",
  "First ANC within first trimester",
  
  "anc_4plus",
  "Four or more ANC contacts",
  
  "anc_8plus",
  "Eight or more ANC contacts",
  
  "complete_anc_content",
  "Complete ANC content",
  
  "facility_delivery",
  "Health facility delivery",
  
  "skilled_birth",
  "Skilled birth attendance",
  
  "mother_pnc_2days",
  "Maternal PNC within 2 days",
  
  "newborn_pnc_2days",
  "Newborn PNC within 2 days",
  
  "paired_pnc_2days",
  "Mother and newborn both received PNC within 2 days",
  
  "complete_continuum",
  "Complete ANC4-skilled birth-paired PNC continuum",
  
  "complete_continuum_anc8",
  "Complete ANC8-skilled birth-paired PNC continuum",
  
  "complete_continuum_facility",
  "Complete ANC4-facility delivery-paired PNC continuum"
)

# ------------------------------------------------------------
# Confirm indicator availability
# ------------------------------------------------------------

missing_indicators <- setdiff(
  indicator_dictionary$variable,
  names(analytic)
)

if (length(missing_indicators) > 0) {
  stop(
    paste0(
      "Required analytical indicators are missing: ",
      paste(
        missing_indicators,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Validate indicator coding
# ------------------------------------------------------------

validate_binary_indicator <- function(
    variable,
    data
) {
  
  indicator_data <- data[[variable]]
  
  valid_values <- sort(
    unique(
      stats::na.omit(
        indicator_data
      )
    )
  )
  
  if (
    !all(
      valid_values %in%
      c(
        0,
        1
      )
    )
  ) {
    stop(
      paste0(
        "Indicator '",
        variable,
        "' contains values other than 0, 1 or NA."
      )
    )
  }
  
  invisible(
    TRUE
  )
}

purrr::walk(
  indicator_dictionary$variable,
  ~ validate_binary_indicator(
    variable = .x,
    data = analytic
  )
)

# ------------------------------------------------------------
# Estimate one survey-weighted binary indicator
# ------------------------------------------------------------

estimate_binary_indicator <- function(
    variable,
    indicator_label,
    design
) {
  
  indicator_data <- design$variables[[variable]]
  
  indicator_formula <- stats::as.formula(
    paste0(
      "~",
      variable
    )
  )
  
  estimate <- survey::svymean(
    x = indicator_formula,
    design = design,
    na.rm = TRUE
  )
  
  estimate_value <- as.numeric(
    stats::coef(
      estimate
    )[1]
  )
  
  variance_matrix <- stats::vcov(
    estimate
  )
  
  standard_error_value <- as.numeric(
    sqrt(
      diag(
        variance_matrix
      )
    )[1]
  )
  
  confidence_interval <- stats::confint(
    estimate,
    level = 0.95
  )
  
  confidence_interval_low <- as.numeric(
    confidence_interval[
      1,
      1
    ]
  )
  
  confidence_interval_high <- as.numeric(
    confidence_interval[
      1,
      2
    ]
  )
  
  tibble::tibble(
    
    variable =
      variable,
    
    indicator =
      indicator_label,
    
    unweighted_n =
      sum(
        !is.na(
          indicator_data
        )
      ),
    
    unweighted_positive_n =
      sum(
        indicator_data == 1,
        na.rm = TRUE
      ),
    
    weighted_proportion =
      estimate_value,
    
    standard_error =
      standard_error_value,
    
    confidence_interval_low =
      confidence_interval_low,
    
    confidence_interval_high =
      confidence_interval_high
  )
}

# ------------------------------------------------------------
# Calculate survey-weighted national estimates
# ------------------------------------------------------------

weighted_national_estimates <- purrr::map2_dfr(
  
  indicator_dictionary$variable,
  
  indicator_dictionary$indicator,
  
  ~ estimate_binary_indicator(
    variable = .x,
    indicator_label = .y,
    design = dhs_design
  )
)

# ------------------------------------------------------------
# Convert estimates to percentages
# ------------------------------------------------------------

weighted_national_estimates <- weighted_national_estimates |>
  dplyr::mutate(
    
    weighted_percent =
      weighted_proportion *
      100,
    
    standard_error_percent =
      standard_error *
      100,
    
    confidence_interval_low_percent =
      confidence_interval_low *
      100,
    
    confidence_interval_high_percent =
      confidence_interval_high *
      100
  )

# ------------------------------------------------------------
# Validate weighted estimates
# ------------------------------------------------------------

invalid_weighted_estimates <- sum(
  
  weighted_national_estimates$weighted_percent < 0 |
    weighted_national_estimates$weighted_percent > 100,
  
  na.rm = TRUE
)

invalid_confidence_intervals <- sum(
  
  weighted_national_estimates$confidence_interval_low_percent >
    weighted_national_estimates$confidence_interval_high_percent,
  
  na.rm = TRUE
)

confidence_bounds_outside_range <- sum(
  
  weighted_national_estimates$confidence_interval_low_percent < 0 |
    weighted_national_estimates$confidence_interval_high_percent > 100,
  
  na.rm = TRUE
)

missing_weighted_estimates <- sum(
  is.na(
    weighted_national_estimates$weighted_percent
  )
)

if (invalid_weighted_estimates > 0) {
  stop(
    "Weighted percentages outside the expected 0-100 range were detected."
  )
}

if (invalid_confidence_intervals > 0) {
  stop(
    "Confidence interval lower bounds exceeded upper bounds."
  )
}

if (missing_weighted_estimates > 0) {
  stop(
    "Missing weighted national estimates were detected."
  )
}

# ------------------------------------------------------------
# Create presentation-ready national estimate table
# ------------------------------------------------------------

weighted_national_estimates <- weighted_national_estimates |>
  dplyr::mutate(
    
    weighted_percent =
      round(
        weighted_percent,
        2
      ),
    
    standard_error_percent =
      round(
        standard_error_percent,
        2
      ),
    
    confidence_interval_low_percent =
      round(
        confidence_interval_low_percent,
        2
      ),
    
    confidence_interval_high_percent =
      round(
        confidence_interval_high_percent,
        2
      ),
    
    estimate_95ci =
      paste0(
        sprintf(
          "%.1f",
          weighted_percent
        ),
        "% (95% CI ",
        sprintf(
          "%.1f",
          confidence_interval_low_percent
        ),
        "-",
        sprintf(
          "%.1f",
          confidence_interval_high_percent
        ),
        "%)"
      )
  ) |>
  dplyr::select(
    variable,
    indicator,
    unweighted_n,
    unweighted_positive_n,
    weighted_percent,
    standard_error_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    estimate_95ci
  )

# ------------------------------------------------------------
# Create analytical quality summary
# ------------------------------------------------------------

weighted_analysis_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Indicators estimated",
    "Weighted percentages outside 0-100",
    "Invalid confidence interval ordering",
    "Confidence interval bounds outside 0-100",
    "Missing weighted estimates",
    "Missing PSU values",
    "Missing stratum values",
    "Missing survey weights",
    "Non-positive survey weights"
  ),
  
  result = c(
    
    nrow(
      weighted_national_estimates
    ),
    
    invalid_weighted_estimates,
    
    invalid_confidence_intervals,
    
    confidence_bounds_outside_range,
    
    missing_weighted_estimates,
    
    missing_psu,
    
    missing_strata,
    
    missing_weights,
    
    nonpositive_weights
  )
)

# ------------------------------------------------------------
# Save survey-design summary
# ------------------------------------------------------------

readr::write_csv(
  survey_design_summary,
  here::here(
    "outputs",
    "tables",
    "survey_design_summary.csv"
  )
)

# ------------------------------------------------------------
# Save national weighted estimates
# ------------------------------------------------------------

readr::write_csv(
  weighted_national_estimates,
  here::here(
    "outputs",
    "tables",
    "weighted_national_indicator_estimates.csv"
  )
)

# ------------------------------------------------------------
# Save analytical QA summary
# ------------------------------------------------------------

readr::write_csv(
  weighted_analysis_quality_summary,
  here::here(
    "outputs",
    "tables",
    "weighted_analysis_quality_summary.csv"
  )
)

# ------------------------------------------------------------
# Save national dashboard-ready dataset
# ------------------------------------------------------------

national_dashboard_data <- weighted_national_estimates |>
  dplyr::select(
    indicator,
    weighted_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    estimate_95ci
  )

readr::write_csv(
  national_dashboard_data,
  here::here(
    "data",
    "powerbi",
    "national_indicator_estimates.csv"
  )
)

# ------------------------------------------------------------
# Review survey design
# ------------------------------------------------------------

print(
  survey_design_summary,
  n = Inf
)

# ------------------------------------------------------------
# Review analytical QA
# ------------------------------------------------------------

print(
  weighted_analysis_quality_summary,
  n = Inf
)

# ------------------------------------------------------------
# Review national estimates
# ------------------------------------------------------------

print(
  weighted_national_estimates,
  n = Inf,
  width = Inf
)

message(
  "Survey-weighted national estimates calculated successfully."
)