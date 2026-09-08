# ============================================================
# SURVEY-WEIGHTED EQUITY ANALYSIS
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
# Define equity dimensions
# ------------------------------------------------------------

equity_dictionary <- tibble::tribble(
  
  ~equity_variable,
  ~equity_dimension,
  
  "zone",
  "Zone",
  
  "residence",
  "Residence",
  
  "wealth_quintile",
  "Wealth quintile",
  
  "education",
  "Education",
  
  "age_group",
  "Age group"
)

# ------------------------------------------------------------
# Define indicators for equity analysis
# ------------------------------------------------------------

equity_indicator_dictionary <- tibble::tribble(
  
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
# Confirm required analytical variables
# ------------------------------------------------------------

required_equity_variables <- unique(
  c(
    equity_dictionary$equity_variable,
    equity_indicator_dictionary$variable
  )
)

missing_equity_variables <- setdiff(
  required_equity_variables,
  names(analytic)
)

if (length(missing_equity_variables) > 0) {
  stop(
    paste0(
      "Variables required for equity analysis are missing: ",
      paste(
        missing_equity_variables,
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
  equity_indicator_dictionary$variable,
  ~ validate_binary_indicator(
    variable = .x,
    data = analytic
  )
)

# ------------------------------------------------------------
# Estimate one indicator within one subgroup
# ------------------------------------------------------------

estimate_subgroup_indicator <- function(
    indicator_variable,
    indicator_label,
    equity_variable,
    equity_dimension,
    equity_category,
    design
) {
  
  group_values <- as.character(
    design$variables[[equity_variable]]
  )
  
  indicator_values <- design$variables[[indicator_variable]]
  
  selected_rows <-
    !is.na(group_values) &
    group_values == equity_category
  
  subgroup_design <- design[
    selected_rows,
  ]
  
  subgroup_indicator <-
    subgroup_design$variables[[indicator_variable]]
  
  unweighted_n <- sum(
    !is.na(
      subgroup_indicator
    )
  )
  
  unweighted_positive_n <- sum(
    subgroup_indicator == 1,
    na.rm = TRUE
  )
  
  if (unweighted_n == 0) {
    
    return(
      tibble::tibble(
        
        equity_variable =
          equity_variable,
        
        equity_dimension =
          equity_dimension,
        
        equity_category =
          equity_category,
        
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
  
  standard_error_value <- as.numeric(
    sqrt(
      diag(
        stats::vcov(
          estimate
        )
      )
    )[1]
  )
  
  confidence_interval <- stats::confint(
    estimate,
    level = 0.95
  )
  
  tibble::tibble(
    
    equity_variable =
      equity_variable,
    
    equity_dimension =
      equity_dimension,
    
    equity_category =
      equity_category,
    
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
# Estimate all indicators within one equity dimension
# ------------------------------------------------------------

estimate_equity_dimension <- function(
    equity_variable,
    equity_dimension,
    design
) {
  
  categories <- design$variables[[equity_variable]] |>
    as.character() |>
    stats::na.omit() |>
    unique() |>
    sort()
  
  purrr::map_dfr(
    
    categories,
    
    function(category_value) {
      
      purrr::map2_dfr(
        
        equity_indicator_dictionary$variable,
        
        equity_indicator_dictionary$indicator,
        
        ~ estimate_subgroup_indicator(
          indicator_variable = .x,
          indicator_label = .y,
          equity_variable = equity_variable,
          equity_dimension = equity_dimension,
          equity_category = category_value,
          design = design
        )
      )
    }
  )
}

# ------------------------------------------------------------
# Calculate all equity estimates
# ------------------------------------------------------------

weighted_equity_estimates <- purrr::map2_dfr(
  
  equity_dictionary$equity_variable,
  
  equity_dictionary$equity_dimension,
  
  ~ estimate_equity_dimension(
    equity_variable = .x,
    equity_dimension = .y,
    design = dhs_design
  )
)

# ------------------------------------------------------------
# Apply reporting-quality rules
# ------------------------------------------------------------

suppression_threshold <-
  project_config$suppression$suppress_below_n

caution_threshold <-
  project_config$suppression$caution_below_n

weighted_equity_estimates <- weighted_equity_estimates |>
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
# Validate equity estimates
# ------------------------------------------------------------

invalid_equity_estimates <- sum(
  !is.na(
    weighted_equity_estimates$weighted_percent
  ) &
    (
      weighted_equity_estimates$weighted_percent < 0 |
        weighted_equity_estimates$weighted_percent > 100
    )
)

invalid_equity_ci <- sum(
  !is.na(
    weighted_equity_estimates$confidence_interval_low_percent
  ) &
    !is.na(
      weighted_equity_estimates$confidence_interval_high_percent
    ) &
    weighted_equity_estimates$confidence_interval_low_percent >
    weighted_equity_estimates$confidence_interval_high_percent
)

if (invalid_equity_estimates > 0) {
  stop(
    "Equity estimates outside the expected 0-100 range were detected."
  )
}

if (invalid_equity_ci > 0) {
  stop(
    "Invalid equity confidence intervals were detected."
  )
}

# ------------------------------------------------------------
# Create rounded internal analytical table
# ------------------------------------------------------------

weighted_equity_estimates <- weighted_equity_estimates |>
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
# Create public/dashboard-safe table
# ------------------------------------------------------------

weighted_equity_public <- weighted_equity_estimates |>
  dplyr::mutate(
    
    public_weighted_percent =
      dplyr::if_else(
        reporting_status == "Suppress",
        NA_real_,
        weighted_percent
      ),
    
    public_ci_low =
      dplyr::if_else(
        reporting_status == "Suppress",
        NA_real_,
        confidence_interval_low_percent
      ),
    
    public_ci_high =
      dplyr::if_else(
        reporting_status == "Suppress",
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
# Create equity-analysis QA summary
# ------------------------------------------------------------

equity_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Equity dimensions analysed",
    "Indicators analysed",
    "Total subgroup estimates",
    "Invalid weighted percentages",
    "Invalid confidence intervals",
    "Suppressed estimates",
    "Caution estimates",
    "Reportable estimates"
  ),
  
  result = c(
    
    nrow(
      equity_dictionary
    ),
    
    nrow(
      equity_indicator_dictionary
    ),
    
    nrow(
      weighted_equity_estimates
    ),
    
    invalid_equity_estimates,
    
    invalid_equity_ci,
    
    sum(
      weighted_equity_estimates$reporting_status ==
        "Suppress"
    ),
    
    sum(
      weighted_equity_estimates$reporting_status ==
        "Caution"
    ),
    
    sum(
      weighted_equity_estimates$reporting_status ==
        "Report"
    )
  )
)

# ------------------------------------------------------------
# Create focused complete-continuum equity table
# ------------------------------------------------------------

complete_continuum_equity <- weighted_equity_public |>
  dplyr::filter(
    indicator_variable ==
      "complete_continuum"
  ) |>
  dplyr::select(
    equity_dimension,
    equity_category,
    unweighted_n,
    unweighted_positive_n,
    public_weighted_percent,
    public_ci_low,
    public_ci_high,
    reporting_status,
    public_estimate
  )

# ------------------------------------------------------------
# Save internal analytical outputs
# ------------------------------------------------------------

readr::write_csv(
  weighted_equity_estimates,
  here::here(
    "outputs",
    "tables",
    "weighted_equity_estimates_internal.csv"
  )
)

readr::write_csv(
  weighted_equity_public,
  here::here(
    "outputs",
    "tables",
    "weighted_equity_estimates_public.csv"
  )
)

readr::write_csv(
  complete_continuum_equity,
  here::here(
    "outputs",
    "tables",
    "complete_continuum_equity.csv"
  )
)

readr::write_csv(
  equity_quality_summary,
  here::here(
    "outputs",
    "tables",
    "equity_analysis_quality_summary.csv"
  )
)

# ------------------------------------------------------------
# Save Power BI-ready equity dataset
# ------------------------------------------------------------

powerbi_equity_data <- weighted_equity_public |>
  dplyr::select(
    equity_dimension,
    equity_category,
    indicator,
    unweighted_n,
    public_weighted_percent,
    public_ci_low,
    public_ci_high,
    reporting_status,
    public_estimate
  )

readr::write_csv(
  powerbi_equity_data,
  here::here(
    "data",
    "powerbi",
    "equity_indicator_estimates.csv"
  )
)

# ------------------------------------------------------------
# Review QA
# ------------------------------------------------------------

print(
  equity_quality_summary,
  n = Inf
)

# ------------------------------------------------------------
# Review complete-continuum inequalities
# ------------------------------------------------------------

print(
  complete_continuum_equity,
  n = Inf,
  width = Inf
)

message(
  "Survey-weighted equity analysis completed successfully."
)