# ============================================================
# STATE-LEVEL GEOGRAPHIC PERFORMANCE ANALYSIS
# 2024 NIGERIA DEMOGRAPHIC AND HEALTH SURVEY
# ============================================================

source(
  here::here(
    "R",
    "01_setup.R"
  )
)

# ------------------------------------------------------------
# Load analytical dataset
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
# Confirm required geographic and survey variables
# ------------------------------------------------------------

geographic_required_variables <- c(
  "v022",
  "cluster_id",
  "stratum_id",
  "survey_weight",
  "zone"
)

missing_geographic_variables <- setdiff(
  geographic_required_variables,
  names(analytic)
)

if (length(missing_geographic_variables) > 0) {
  stop(
    paste0(
      "Required geographic variables are missing: ",
      paste(
        missing_geographic_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Derive state from validated sampling-stratum labels
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    state_stratum_label =
      labelled_text(v022),
    
    state =
      stringr::str_remove(
        state_stratum_label,
        stringr::regex(
          "\\s+(urban|rural)$",
          ignore_case = TRUE
        )
      ),
    
    state =
      stringr::str_squish(
        state
      ),
    
    state =
      stringr::str_to_title(
        state
      ),
    
    state =
      dplyr::case_when(
        
        stringr::str_detect(
          stringr::str_to_lower(state),
          "^fct"
        ) ~
          "Federal Capital Territory",
        
        TRUE ~
          state
      )
  )

# ------------------------------------------------------------
# Validate derived state field
# ------------------------------------------------------------

missing_state <- sum(
  is.na(analytic$state) |
    analytic$state == ""
)

number_of_states <- dplyr::n_distinct(
  analytic$state[
    !is.na(analytic$state)
  ]
)

if (missing_state > 0) {
  stop(
    paste0(
      "State could not be derived for ",
      missing_state,
      " records."
    )
  )
}

if (number_of_states != 37) {
  stop(
    paste0(
      "Expected 37 state/FCT geographic units but derived ",
      number_of_states,
      ". Review the v022 labels before continuing."
    )
  )
}

# ------------------------------------------------------------
# Create state inventory
# ------------------------------------------------------------

state_inventory <- analytic |>
  dplyr::count(
    zone,
    state,
    name = "unweighted_records"
  ) |>
  dplyr::arrange(
    zone,
    state
  )

# ------------------------------------------------------------
# Validate survey-design variables
# ------------------------------------------------------------

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
    "Missing PSU values were detected."
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
# Define geographic indicators
# ------------------------------------------------------------

geographic_indicator_dictionary <- tibble::tribble(
  
  ~variable,
  ~indicator,
  
  "anc_4plus",
  "Four or more ANC contacts",
  
  "anc_8plus",
  "Eight or more ANC contacts",
  
  "skilled_birth",
  "Skilled birth attendance",
  
  "facility_delivery",
  "Health facility delivery",
  
  "mother_pnc_2days",
  "Maternal PNC within 2 days",
  
  "newborn_pnc_2days",
  "Newborn PNC within 2 days",
  
  "paired_pnc_2days",
  "Mother and newborn both received PNC within 2 days",
  
  "complete_continuum",
  "Complete continuum"
)

# ------------------------------------------------------------
# Confirm indicator availability
# ------------------------------------------------------------

missing_indicators <- setdiff(
  geographic_indicator_dictionary$variable,
  names(analytic)
)

if (length(missing_indicators) > 0) {
  stop(
    paste0(
      "Required indicators are missing: ",
      paste(
        missing_indicators,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Validate binary indicator coding
# ------------------------------------------------------------

validate_binary_indicator <- function(
    variable,
    data
) {
  
  values <- sort(
    unique(
      stats::na.omit(
        data[[variable]]
      )
    )
  )
  
  if (
    !all(
      values %in%
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
  geographic_indicator_dictionary$variable,
  ~ validate_binary_indicator(
    variable = .x,
    data = analytic
  )
)

# ------------------------------------------------------------
# Estimate one indicator for one state
# ------------------------------------------------------------

estimate_geographic_indicator <- function(
    indicator_variable,
    indicator_label,
    state_name,
    design
) {
  
  selected_rows <-
    !is.na(
      design$variables$state
    ) &
    design$variables$state ==
    state_name
  
  subgroup_design <- design[
    selected_rows,
  ]
  
  # Correct dynamic column extraction
  indicator_data <-
    subgroup_design$variables[[indicator_variable]]
  
  unweighted_n <- sum(
    !is.na(
      indicator_data
    )
  )
  
  unweighted_positive_n <- sum(
    indicator_data == 1,
    na.rm = TRUE
  )
  
  zone_values <- unique(
    as.character(
      subgroup_design$variables$zone
    )
  )
  
  zone_values <- zone_values[
    !is.na(zone_values) &
      zone_values != ""
  ]
  
  zone_name <- if (
    length(zone_values) >= 1
  ) {
    zone_values[1]
  } else {
    NA_character_
  }
  
  # ----------------------------------------------------------
  # Return empty estimate when indicator has no valid records
  # ----------------------------------------------------------
  
  if (unweighted_n == 0) {
    
    return(
      tibble::tibble(
        
        state =
          state_name,
        
        zone =
          zone_name,
        
        indicator_variable =
          indicator_variable,
        
        indicator =
          indicator_label,
        
        unweighted_n =
          0L,
        
        unweighted_positive_n =
          0L,
        
        weighted_percent =
          NA_real_,
        
        standard_error_percent =
          NA_real_,
        
        confidence_interval_low_percent =
          NA_real_,
        
        confidence_interval_high_percent =
          NA_real_
      )
    )
  }
  
  # ----------------------------------------------------------
  # Estimate weighted prevalence
  # ----------------------------------------------------------
  
  indicator_formula <- stats::as.formula(
    paste0(
      "~",
      indicator_variable
    )
  )
  
  estimate <- survey::svymean(
    x = indicator_formula,
    design = subgroup_design,
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
  
  tibble::tibble(
    
    state =
      state_name,
    
    zone =
      zone_name,
    
    indicator_variable =
      indicator_variable,
    
    indicator =
      indicator_label,
    
    unweighted_n =
      unweighted_n,
    
    unweighted_positive_n =
      unweighted_positive_n,
    
    weighted_percent =
      estimate_value *
      100,
    
    standard_error_percent =
      standard_error_value *
      100,
    
    confidence_interval_low_percent =
      as.numeric(
        confidence_interval[
          1,
          1
        ]
      ) *
      100,
    
    confidence_interval_high_percent =
      as.numeric(
        confidence_interval[
          1,
          2
        ]
      ) *
      100
  )
}

# ------------------------------------------------------------
# Obtain state names
# ------------------------------------------------------------

state_names <- analytic$state |>
  stats::na.omit() |>
  unique() |>
  sort()

# ------------------------------------------------------------
# Estimate all indicators for all states
# ------------------------------------------------------------

state_indicator_estimates <- purrr::map_dfr(
  
  state_names,
  
  function(state_name) {
    
    purrr::map2_dfr(
      
      geographic_indicator_dictionary$variable,
      
      geographic_indicator_dictionary$indicator,
      
      ~ estimate_geographic_indicator(
        indicator_variable = .x,
        indicator_label = .y,
        state_name = state_name,
        design = dhs_design
      )
    )
  }
)

# ------------------------------------------------------------
# Apply reporting thresholds
# ------------------------------------------------------------

suppression_threshold <-
  project_config$suppression$suppress_below_n

caution_threshold <-
  project_config$suppression$caution_below_n

state_indicator_estimates <- state_indicator_estimates |>
  dplyr::mutate(
    
    reporting_status =
      dplyr::case_when(
        
        unweighted_n <
          suppression_threshold ~
          "Suppress",
        
        unweighted_n <
          caution_threshold ~
          "Caution",
        
        TRUE ~
          "Report"
      )
  )

# ------------------------------------------------------------
# Validate state estimates
# ------------------------------------------------------------

invalid_state_estimates <- sum(
  !is.na(
    state_indicator_estimates$weighted_percent
  ) &
    (
      state_indicator_estimates$weighted_percent < 0 |
        state_indicator_estimates$weighted_percent > 100
    )
)

invalid_state_ci <- sum(
  !is.na(
    state_indicator_estimates$confidence_interval_low_percent
  ) &
    !is.na(
      state_indicator_estimates$confidence_interval_high_percent
    ) &
    state_indicator_estimates$confidence_interval_low_percent >
    state_indicator_estimates$confidence_interval_high_percent
)

if (invalid_state_estimates > 0) {
  stop(
    "State estimates outside the expected 0-100 range were detected."
  )
}

if (invalid_state_ci > 0) {
  stop(
    "Invalid state confidence intervals were detected."
  )
}

# ------------------------------------------------------------
# Round estimates and create formatted values
# ------------------------------------------------------------

state_indicator_estimates <- state_indicator_estimates |>
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
      dplyr::case_when(
        
        is.na(weighted_percent) ~
          NA_character_,
        
        TRUE ~
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
      )
  )

# ------------------------------------------------------------
# Create public-safe state estimates
# ------------------------------------------------------------

state_indicator_public <- state_indicator_estimates |>
  dplyr::mutate(
    
    public_weighted_percent =
      dplyr::if_else(
        reporting_status ==
          "Suppress",
        NA_real_,
        weighted_percent
      ),
    
    public_ci_low =
      dplyr::if_else(
        reporting_status ==
          "Suppress",
        NA_real_,
        confidence_interval_low_percent
      ),
    
    public_ci_high =
      dplyr::if_else(
        reporting_status ==
          "Suppress",
        NA_real_,
        confidence_interval_high_percent
      ),
    
    public_estimate =
      dplyr::case_when(
        
        reporting_status ==
          "Suppress" ~
          paste0(
            "Suppressed (n<",
            suppression_threshold,
            ")"
          ),
        
        reporting_status ==
          "Caution" ~
          paste0(
            estimate_95ci,
            " [Caution: small n]"
          ),
        
        TRUE ~
          estimate_95ci
      )
  )

# ------------------------------------------------------------
# Calculate national estimates for comparison
# ------------------------------------------------------------

estimate_national_indicator <- function(
    indicator_variable,
    indicator_label,
    design
) {
  
  indicator_formula <- stats::as.formula(
    paste0(
      "~",
      indicator_variable
    )
  )
  
  estimate <- survey::svymean(
    x = indicator_formula,
    design = design,
    na.rm = TRUE
  )
  
  tibble::tibble(
    
    indicator_variable =
      indicator_variable,
    
    indicator =
      indicator_label,
    
    national_percent =
      as.numeric(
        stats::coef(
          estimate
        )[1]
      ) *
      100
  )
}

national_geographic_comparison <- purrr::map2_dfr(
  
  geographic_indicator_dictionary$variable,
  
  geographic_indicator_dictionary$indicator,
  
  ~ estimate_national_indicator(
    indicator_variable = .x,
    indicator_label = .y,
    design = dhs_design
  )
) |>
  dplyr::mutate(
    
    national_percent =
      round(
        national_percent,
        2
      )
  )

# ------------------------------------------------------------
# Rank state performance
# ------------------------------------------------------------

state_performance_ranking <- state_indicator_public |>
  dplyr::filter(
    reporting_status !=
      "Suppress",
    !is.na(
      public_weighted_percent
    )
  ) |>
  dplyr::left_join(
    national_geographic_comparison,
    by = c(
      "indicator_variable",
      "indicator"
    )
  ) |>
  dplyr::group_by(
    indicator_variable,
    indicator
  ) |>
  dplyr::mutate(
    
    state_rank =
      dplyr::min_rank(
        dplyr::desc(
          public_weighted_percent
        )
      ),
    
    best_state_percent =
      max(
        public_weighted_percent,
        na.rm = TRUE
      ),
    
    worst_state_percent =
      min(
        public_weighted_percent,
        na.rm = TRUE
      ),
    
    gap_from_best_pp =
      best_state_percent -
      public_weighted_percent,
    
    difference_from_national_pp =
      public_weighted_percent -
      national_percent
  ) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    
    gap_from_best_pp =
      round(
        gap_from_best_pp,
        2
      ),
    
    difference_from_national_pp =
      round(
        difference_from_national_pp,
        2
      )
  ) |>
  dplyr::arrange(
    indicator,
    state_rank
  )

# ------------------------------------------------------------
# Create complete-continuum state ranking
# ------------------------------------------------------------

complete_continuum_state_ranking <-
  state_performance_ranking |>
  dplyr::filter(
    indicator_variable ==
      "complete_continuum"
  ) |>
  dplyr::select(
    state_rank,
    state,
    zone,
    unweighted_n,
    unweighted_positive_n,
    public_weighted_percent,
    public_ci_low,
    public_ci_high,
    national_percent,
    difference_from_national_pp,
    gap_from_best_pp,
    reporting_status,
    public_estimate
  ) |>
  dplyr::arrange(
    state_rank
  )

# ------------------------------------------------------------
# Identify highest- and lowest-performing states
# ------------------------------------------------------------

highest_state_performance <- state_performance_ranking |>
  dplyr::group_by(
    indicator_variable,
    indicator
  ) |>
  dplyr::slice_max(
    order_by = public_weighted_percent,
    n = 1,
    with_ties = FALSE
  ) |>
  dplyr::ungroup() |>
  dplyr::transmute(
    
    indicator_variable,
    indicator,
    
    highest_state =
      state,
    
    highest_percent =
      public_weighted_percent
  )

lowest_state_performance <- state_performance_ranking |>
  dplyr::group_by(
    indicator_variable,
    indicator
  ) |>
  dplyr::slice_min(
    order_by = public_weighted_percent,
    n = 1,
    with_ties = FALSE
  ) |>
  dplyr::ungroup() |>
  dplyr::transmute(
    
    indicator_variable,
    indicator,
    
    lowest_state =
      state,
    
    lowest_percent =
      public_weighted_percent
  )

state_performance_extremes <-
  highest_state_performance |>
  dplyr::left_join(
    lowest_state_performance,
    by = c(
      "indicator_variable",
      "indicator"
    )
  ) |>
  dplyr::mutate(
    
    state_gap_pp =
      highest_percent -
      lowest_percent,
    
    highest_percent =
      round(
        highest_percent,
        2
      ),
    
    lowest_percent =
      round(
        lowest_percent,
        2
      ),
    
    state_gap_pp =
      round(
        state_gap_pp,
        2
      )
  )

# ------------------------------------------------------------
# Create geographic QA summary
# ------------------------------------------------------------

geographic_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Analytical cohort size",
    "State/FCT units identified",
    "Indicators analysed",
    "Expected state-indicator estimates",
    "State-indicator estimates generated",
    "Invalid state percentages",
    "Invalid state confidence intervals",
    "Suppressed estimates",
    "Caution estimates",
    "Reportable estimates",
    "Complete-continuum states ranked"
  ),
  
  result = c(
    
    nrow(
      analytic
    ),
    
    number_of_states,
    
    nrow(
      geographic_indicator_dictionary
    ),
    
    number_of_states *
      nrow(
        geographic_indicator_dictionary
      ),
    
    nrow(
      state_indicator_estimates
    ),
    
    invalid_state_estimates,
    
    invalid_state_ci,
    
    sum(
      state_indicator_estimates$reporting_status ==
        "Suppress"
    ),
    
    sum(
      state_indicator_estimates$reporting_status ==
        "Caution"
    ),
    
    sum(
      state_indicator_estimates$reporting_status ==
        "Report"
    ),
    
    nrow(
      complete_continuum_state_ranking
    )
  )
)

# ------------------------------------------------------------
# Validate expected output size
# ------------------------------------------------------------

expected_state_indicator_estimates <-
  number_of_states *
  nrow(
    geographic_indicator_dictionary
  )

if (
  nrow(
    state_indicator_estimates
  ) !=
  expected_state_indicator_estimates
) {
  stop(
    paste0(
      "Expected ",
      expected_state_indicator_estimates,
      " state-indicator estimates but generated ",
      nrow(
        state_indicator_estimates
      ),
      "."
    )
  )
}

# ------------------------------------------------------------
# Save state inventory
# ------------------------------------------------------------

readr::write_csv(
  state_inventory,
  here::here(
    "outputs",
    "tables",
    "state_inventory.csv"
  )
)

# ------------------------------------------------------------
# Save geographic analytical outputs
# ------------------------------------------------------------

readr::write_csv(
  state_indicator_estimates,
  here::here(
    "outputs",
    "tables",
    "state_indicator_estimates_internal.csv"
  )
)

readr::write_csv(
  state_indicator_public,
  here::here(
    "outputs",
    "tables",
    "state_indicator_estimates_public.csv"
  )
)

readr::write_csv(
  state_performance_ranking,
  here::here(
    "outputs",
    "tables",
    "state_performance_ranking.csv"
  )
)

readr::write_csv(
  complete_continuum_state_ranking,
  here::here(
    "outputs",
    "tables",
    "complete_continuum_state_ranking.csv"
  )
)

readr::write_csv(
  state_performance_extremes,
  here::here(
    "outputs",
    "tables",
    "state_performance_extremes.csv"
  )
)

readr::write_csv(
  national_geographic_comparison,
  here::here(
    "outputs",
    "tables",
    "national_geographic_comparison.csv"
  )
)

readr::write_csv(
  geographic_quality_summary,
  here::here(
    "outputs",
    "tables",
    "geographic_analysis_quality_summary.csv"
  )
)

# ------------------------------------------------------------
# Save Power BI-ready state estimates
# ------------------------------------------------------------

powerbi_state_estimates <- state_indicator_public |>
  dplyr::select(
    state,
    zone,
    indicator,
    unweighted_n,
    public_weighted_percent,
    public_ci_low,
    public_ci_high,
    reporting_status,
    public_estimate
  )

readr::write_csv(
  powerbi_state_estimates,
  here::here(
    "data",
    "powerbi",
    "state_indicator_estimates.csv"
  )
)

# ------------------------------------------------------------
# Save Power BI-ready state rankings
# ------------------------------------------------------------

powerbi_state_ranking <- state_performance_ranking |>
  dplyr::select(
    state,
    zone,
    indicator,
    state_rank,
    public_weighted_percent,
    national_percent,
    difference_from_national_pp,
    gap_from_best_pp,
    reporting_status
  )

readr::write_csv(
  powerbi_state_ranking,
  here::here(
    "data",
    "powerbi",
    "state_performance_ranking.csv"
  )
)

# ------------------------------------------------------------
# Save Power BI-ready geographic extremes
# ------------------------------------------------------------

readr::write_csv(
  state_performance_extremes,
  here::here(
    "data",
    "powerbi",
    "state_performance_extremes.csv"
  )
)

# ------------------------------------------------------------
# Review geographic QA
# ------------------------------------------------------------

print(
  geographic_quality_summary,
  n = Inf
)

# ------------------------------------------------------------
# Review complete-continuum state ranking
# ------------------------------------------------------------

print(
  complete_continuum_state_ranking,
  n = Inf,
  width = Inf
)

# ------------------------------------------------------------
# Review geographic performance extremes
# ------------------------------------------------------------

print(
  state_performance_extremes,
  n = Inf,
  width = Inf
)

message(
  "State-level geographic performance analysis completed successfully."
)