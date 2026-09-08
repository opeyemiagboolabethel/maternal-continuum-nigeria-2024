# ============================================================
# SURVEY-WEIGHTED STATISTICAL MODELLING
# COMPLETE MATERNAL CONTINUUM OF CARE
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
# Define outcome and explanatory variables
# ------------------------------------------------------------

model_required_variables <- c(
  "complete_continuum",
  "age_group",
  "education",
  "wealth_quintile",
  "residence",
  "zone",
  "cluster_id",
  "stratum_id",
  "survey_weight"
)

missing_model_variables <- setdiff(
  model_required_variables,
  names(analytic)
)

if (length(missing_model_variables) > 0) {
  stop(
    paste0(
      "Variables required for statistical modelling are missing: ",
      paste(
        missing_model_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Validate binary outcome
# ------------------------------------------------------------

outcome_values <- sort(
  unique(
    stats::na.omit(
      analytic$complete_continuum
    )
  )
)

if (
  !all(
    outcome_values %in%
    c(
      0,
      1
    )
  )
) {
  stop(
    "complete_continuum contains values other than 0, 1 or NA."
  )
}

# ------------------------------------------------------------
# Helper for setting preferred reference categories
# ------------------------------------------------------------

set_reference <- function(
    x,
    preferred_reference
) {
  
  x <- factor(
    as.character(x)
  )
  
  available_levels <- levels(x)
  
  reference_position <- match(
    tolower(
      preferred_reference
    ),
    tolower(
      available_levels
    )
  )
  
  if (
    !is.na(
      reference_position
    )
  ) {
    
    x <- stats::relevel(
      x,
      ref =
        available_levels[
          reference_position
        ]
    )
  }
  
  x
}

# ------------------------------------------------------------
# Prepare modelling variables
# ------------------------------------------------------------

model_data <- analytic |>
  dplyr::transmute(
    
    complete_continuum =
      as.integer(
        complete_continuum
      ),
    
    age_group_model =
      set_reference(
        age_group,
        "20-24"
      ),
    
    education_model =
      set_reference(
        education,
        "no education"
      ),
    
    wealth_model =
      set_reference(
        wealth_quintile,
        "poorest"
      ),
    
    residence_model =
      set_reference(
        residence,
        "rural"
      ),
    
    zone_model =
      set_reference(
        zone,
        "north west"
      ),
    
    cluster_id =
      cluster_id,
    
    stratum_id =
      stratum_id,
    
    survey_weight =
      survey_weight
  )

# ------------------------------------------------------------
# Document modelling sample flow
# ------------------------------------------------------------

total_analytic_records <- nrow(
  model_data
)

outcome_observed_records <- sum(
  !is.na(
    model_data$complete_continuum
  )
)

complete_model_rows <- stats::complete.cases(
  model_data[
    ,
    c(
      "complete_continuum",
      "age_group_model",
      "education_model",
      "wealth_model",
      "residence_model",
      "zone_model",
      "cluster_id",
      "stratum_id",
      "survey_weight"
    )
  ]
)

complete_model_records <- sum(
  complete_model_rows
)

model_sample_flow <- tibble::tibble(
  
  stage = c(
    "Analytical cohort",
    "Complete-continuum outcome observed",
    "Complete cases for adjusted model"
  ),
  
  unweighted_n = c(
    total_analytic_records,
    outcome_observed_records,
    complete_model_records
  )
)

# ------------------------------------------------------------
# Restrict to complete modelling records
# ------------------------------------------------------------

model_data <- model_data[
  complete_model_rows,
]

model_data <- droplevels(
  model_data
)

if (
  nrow(
    model_data
  ) == 0
) {
  stop(
    "No complete observations remain for statistical modelling."
  )
}

# ------------------------------------------------------------
# Validate survey design in modelling sample
# ------------------------------------------------------------

missing_psu <- sum(
  is.na(
    model_data$cluster_id
  )
)

missing_strata <- sum(
  is.na(
    model_data$stratum_id
  )
)

missing_weights <- sum(
  is.na(
    model_data$survey_weight
  )
)

nonpositive_weights <- sum(
  model_data$survey_weight <= 0,
  na.rm = TRUE
)

if (missing_psu > 0) {
  stop(
    "Missing PSU values were detected in the modelling sample."
  )
}

if (missing_strata > 0) {
  stop(
    "Missing stratum values were detected in the modelling sample."
  )
}

if (missing_weights > 0) {
  stop(
    "Missing survey weights were detected in the modelling sample."
  )
}

if (nonpositive_weights > 0) {
  stop(
    "Non-positive survey weights were detected in the modelling sample."
  )
}

# ------------------------------------------------------------
# Check outcome variation
# ------------------------------------------------------------

outcome_zero_n <- sum(
  model_data$complete_continuum == 0
)

outcome_one_n <- sum(
  model_data$complete_continuum == 1
)

if (
  outcome_zero_n == 0 |
  outcome_one_n == 0
) {
  stop(
    "The modelling outcome does not contain both 0 and 1."
  )
}

# ------------------------------------------------------------
# Create predictor dictionary
# ------------------------------------------------------------

predictor_dictionary <- tibble::tribble(
  
  ~variable,
  ~predictor,
  
  "age_group_model",
  "Age group",
  
  "education_model",
  "Education",
  
  "wealth_model",
  "Wealth quintile",
  
  "residence_model",
  "Residence",
  
  "zone_model",
  "Geopolitical zone"
)

# ------------------------------------------------------------
# Create category-count QA table
# ------------------------------------------------------------

count_predictor_categories <- function(
    data,
    variable,
    label
) {
  
  tibble::tibble(
    category =
      as.character(
        data[[variable]]
      )
  ) |>
    dplyr::count(
      category,
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      predictor =
        label,
      variable =
        variable
    ) |>
    dplyr::select(
      variable,
      predictor,
      category,
      unweighted_n
    )
}

model_category_counts <- purrr::map2_dfr(
  
  predictor_dictionary$variable,
  
  predictor_dictionary$predictor,
  
  ~ count_predictor_categories(
    data = model_data,
    variable = .x,
    label = .y
  )
)

# ------------------------------------------------------------
# Check for extremely small predictor categories
# ------------------------------------------------------------

small_model_categories <- sum(
  model_category_counts$unweighted_n <
    project_config$suppression$suppress_below_n
)

# ------------------------------------------------------------
# Document reference categories
# ------------------------------------------------------------

model_reference_categories <- tibble::tibble(
  
  variable = predictor_dictionary$variable,
  
  predictor = predictor_dictionary$predictor,
  
  reference_category = c(
    levels(
      model_data$age_group_model
    )[1],
    
    levels(
      model_data$education_model
    )[1],
    
    levels(
      model_data$wealth_model
    )[1],
    
    levels(
      model_data$residence_model
    )[1],
    
    levels(
      model_data$zone_model
    )[1]
  )
)

# ------------------------------------------------------------
# Specify survey design for modelling sample
# ------------------------------------------------------------

options(
  survey.lonely.psu = "adjust"
)

model_design <- survey::svydesign(
  ids = ~cluster_id,
  strata = ~stratum_id,
  weights = ~survey_weight,
  data = model_data,
  nest = TRUE
)

model_design_df <- survey::degf(
  model_design
)

if (
  model_design_df <= 0
) {
  stop(
    "Survey design degrees of freedom are not positive."
  )
}

# ------------------------------------------------------------
# Estimate weighted outcome prevalence in modelling sample
# ------------------------------------------------------------

model_outcome_estimate <- survey::svymean(
  x = ~complete_continuum,
  design = model_design,
  na.rm = TRUE
)

model_outcome_ci <- stats::confint(
  model_outcome_estimate,
  level = 0.95
)

model_outcome_summary <- tibble::tibble(
  
  modelling_n =
    nrow(
      model_data
    ),
  
  outcome_zero_n =
    outcome_zero_n,
  
  outcome_one_n =
    outcome_one_n,
  
  weighted_complete_continuum_percent =
    as.numeric(
      stats::coef(
        model_outcome_estimate
      )[1]
    ) *
    100,
  
  confidence_interval_low_percent =
    as.numeric(
      model_outcome_ci[
        1,
        1
      ]
    ) *
    100,
  
  confidence_interval_high_percent =
    as.numeric(
      model_outcome_ci[
        1,
        2
      ]
    ) *
    100
) |>
  dplyr::mutate(
    
    dplyr::across(
      c(
        weighted_complete_continuum_percent,
        confidence_interval_low_percent,
        confidence_interval_high_percent
      ),
      ~ round(
        .x,
        2
      )
    )
  )

# ------------------------------------------------------------
# Helper: extract odds ratios from survey logistic model
# ------------------------------------------------------------

extract_odds_ratios <- function(
    model,
    design,
    model_type,
    predictor_label
) {
  
  coefficient_table <- summary(
    model
  )$coefficients
  
  if (
    is.null(
      coefficient_table
    ) |
    nrow(
      coefficient_table
    ) == 0
  ) {
    stop(
      paste0(
        "No coefficients were returned for ",
        model_type,
        "."
      )
    )
  }
  
  coefficient_table <- as.data.frame(
    coefficient_table
  )
  
  coefficient_table$term <- rownames(
    coefficient_table
  )
  
  rownames(
    coefficient_table
  ) <- NULL
  
  coefficient_table <- coefficient_table[
    coefficient_table$term !=
      "(Intercept)",
  ]
  
  if (
    nrow(
      coefficient_table
    ) == 0
  ) {
    return(
      tibble::tibble()
    )
  }
  
  estimate_value <- coefficient_table[
    ,
    1
  ]
  
  standard_error_value <- coefficient_table[
    ,
    2
  ]
  
  p_value <- coefficient_table[
    ,
    4
  ]
  
  critical_value <- stats::qt(
    0.975,
    df =
      survey::degf(
        design
      )
  )
  
  confidence_low_logit <-
    estimate_value -
    critical_value *
    standard_error_value
  
  confidence_high_logit <-
    estimate_value +
    critical_value *
    standard_error_value
  
  tibble::tibble(
    
    model =
      model_type,
    
    predictor =
      predictor_label,
    
    term =
      coefficient_table$term,
    
    log_odds =
      estimate_value,
    
    standard_error =
      standard_error_value,
    
    odds_ratio =
      exp(
        estimate_value
      ),
    
    confidence_interval_low =
      exp(
        confidence_low_logit
      ),
    
    confidence_interval_high =
      exp(
        confidence_high_logit
      ),
    
    p_value =
      p_value
  )
}

# ------------------------------------------------------------
# Fit unadjusted survey-weighted logistic models
# ------------------------------------------------------------

fit_unadjusted_model <- function(
    variable,
    predictor_label,
    design
) {
  
  model_formula <- stats::as.formula(
    paste0(
      "complete_continuum ~ ",
      variable
    )
  )
  
  fitted_model <- survey::svyglm(
    formula =
      model_formula,
    design =
      design,
    family =
      stats::quasibinomial(
        link = "logit"
      )
  )
  
  extract_odds_ratios(
    model =
      fitted_model,
    design =
      design,
    model_type =
      "Unadjusted",
    predictor_label =
      predictor_label
  )
}

unadjusted_odds_ratios <- purrr::map2_dfr(
  
  predictor_dictionary$variable,
  
  predictor_dictionary$predictor,
  
  ~ fit_unadjusted_model(
    variable = .x,
    predictor_label = .y,
    design = model_design
  )
)

# ------------------------------------------------------------
# Fit fully adjusted survey-weighted logistic model
# ------------------------------------------------------------

adjusted_formula <- stats::as.formula(
  paste(
    "complete_continuum ~",
    "age_group_model +",
    "education_model +",
    "wealth_model +",
    "residence_model +",
    "zone_model"
  )
)

adjusted_model <- survey::svyglm(
  formula =
    adjusted_formula,
  design =
    model_design,
  family =
    stats::quasibinomial(
      link = "logit"
    )
)

# ------------------------------------------------------------
# Extract adjusted odds ratios
# ------------------------------------------------------------

adjusted_odds_ratios <- extract_odds_ratios(
  model =
    adjusted_model,
  design =
    model_design,
  model_type =
    "Adjusted",
  predictor_label =
    "Multivariable model"
)

# ------------------------------------------------------------
# Format regression estimates
# ------------------------------------------------------------

format_regression_results <- function(
    data
) {
  
  data |>
    dplyr::mutate(
      
      log_odds =
        round(
          log_odds,
          4
        ),
      
      standard_error =
        round(
          standard_error,
          4
        ),
      
      odds_ratio =
        round(
          odds_ratio,
          3
        ),
      
      confidence_interval_low =
        round(
          confidence_interval_low,
          3
        ),
      
      confidence_interval_high =
        round(
          confidence_interval_high,
          3
        ),
      
      p_value =
        round(
          p_value,
          4
        ),
      
      statistical_significance =
        dplyr::case_when(
          
          is.na(
            p_value
          ) ~
            "Not available",
          
          p_value < 0.001 ~
            "p<0.001",
          
          p_value < 0.01 ~
            "p<0.01",
          
          p_value < 0.05 ~
            "p<0.05",
          
          TRUE ~
            "Not statistically significant"
        ),
      
      estimate_95ci =
        paste0(
          sprintf(
            "%.2f",
            odds_ratio
          ),
          " (95% CI ",
          sprintf(
            "%.2f",
            confidence_interval_low
          ),
          "-",
          sprintf(
            "%.2f",
            confidence_interval_high
          ),
          ")"
        )
    )
}

unadjusted_odds_ratios <- format_regression_results(
  unadjusted_odds_ratios
)

adjusted_odds_ratios <- format_regression_results(
  adjusted_odds_ratios
)

# ------------------------------------------------------------
# Validate regression outputs
# ------------------------------------------------------------

invalid_unadjusted_or <- sum(
  !is.finite(
    unadjusted_odds_ratios$odds_ratio
  ) |
    unadjusted_odds_ratios$odds_ratio <= 0,
  na.rm = TRUE
)

invalid_adjusted_or <- sum(
  !is.finite(
    adjusted_odds_ratios$odds_ratio
  ) |
    adjusted_odds_ratios$odds_ratio <= 0,
  na.rm = TRUE
)

invalid_unadjusted_ci <- sum(
  unadjusted_odds_ratios$confidence_interval_low >
    unadjusted_odds_ratios$confidence_interval_high,
  na.rm = TRUE
)

invalid_adjusted_ci <- sum(
  adjusted_odds_ratios$confidence_interval_low >
    adjusted_odds_ratios$confidence_interval_high,
  na.rm = TRUE
)

invalid_p_values <- sum(
  adjusted_odds_ratios$p_value < 0 |
    adjusted_odds_ratios$p_value > 1,
  na.rm = TRUE
)

adjusted_model_converged <- if (
  is.null(
    adjusted_model$converged
  )
) {
  1L
} else {
  as.integer(
    isTRUE(
      adjusted_model$converged
    )
  )
}

if (invalid_unadjusted_or > 0) {
  stop(
    "Invalid unadjusted odds ratios were detected."
  )
}

if (invalid_adjusted_or > 0) {
  stop(
    "Invalid adjusted odds ratios were detected."
  )
}

if (invalid_unadjusted_ci > 0) {
  stop(
    "Invalid confidence intervals were detected in unadjusted models."
  )
}

if (invalid_adjusted_ci > 0) {
  stop(
    "Invalid confidence intervals were detected in the adjusted model."
  )
}

if (invalid_p_values > 0) {
  stop(
    "Invalid p-values were detected."
  )
}

if (adjusted_model_converged != 1L) {
  stop(
    "The adjusted survey-weighted logistic regression did not converge."
  )
}

# ------------------------------------------------------------
# Calculate number of adjusted model parameters
# ------------------------------------------------------------

adjusted_parameter_count <- length(
  stats::coef(
    adjusted_model
  )
) - 1

# ------------------------------------------------------------
# Calculate events per estimated parameter
#
# This is presented as a diagnostic description only.
# It is not used as a rigid model-selection rule.
# ------------------------------------------------------------

events_per_parameter <- outcome_one_n /
  adjusted_parameter_count

# ------------------------------------------------------------
# Create model QA summary
# ------------------------------------------------------------

model_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Analytical records before model exclusions",
    "Complete modelling records",
    "Complete-continuum events",
    "Complete-continuum non-events",
    "Survey design degrees of freedom",
    "Adjusted model parameters excluding intercept",
    "Events per estimated parameter",
    "Predictor categories below suppression threshold",
    "Invalid unadjusted odds ratios",
    "Invalid adjusted odds ratios",
    "Invalid unadjusted confidence intervals",
    "Invalid adjusted confidence intervals",
    "Invalid adjusted-model p-values",
    "Adjusted model converged"
  ),
  
  result = c(
    
    total_analytic_records,
    
    nrow(
      model_data
    ),
    
    outcome_one_n,
    
    outcome_zero_n,
    
    model_design_df,
    
    adjusted_parameter_count,
    
    round(
      events_per_parameter,
      2
    ),
    
    small_model_categories,
    
    invalid_unadjusted_or,
    
    invalid_adjusted_or,
    
    invalid_unadjusted_ci,
    
    invalid_adjusted_ci,
    
    invalid_p_values,
    
    adjusted_model_converged
  )
)

# ------------------------------------------------------------
# Create combined regression table
# ------------------------------------------------------------

combined_regression_results <- dplyr::bind_rows(
  
  unadjusted_odds_ratios,
  
  adjusted_odds_ratios
)

# ------------------------------------------------------------
# Create adjusted model presentation table
# ------------------------------------------------------------

adjusted_model_presentation <- adjusted_odds_ratios |>
  dplyr::select(
    term,
    odds_ratio,
    confidence_interval_low,
    confidence_interval_high,
    p_value,
    statistical_significance,
    estimate_95ci
  )

# ------------------------------------------------------------
# Create directory for private model object
# ------------------------------------------------------------

private_model_directory <- here::here(
  "data",
  "interim"
)

if (
  !dir.exists(
    private_model_directory
  )
) {
  dir.create(
    private_model_directory,
    recursive = TRUE
  )
}

# ------------------------------------------------------------
# Save private fitted model
# ------------------------------------------------------------

saveRDS(
  adjusted_model,
  here::here(
    "data",
    "interim",
    "complete_continuum_adjusted_model.rds"
  )
)

# ------------------------------------------------------------
# Save model sample documentation
# ------------------------------------------------------------

readr::write_csv(
  model_sample_flow,
  here::here(
    "outputs",
    "tables",
    "model_sample_flow.csv"
  )
)

readr::write_csv(
  model_category_counts,
  here::here(
    "outputs",
    "tables",
    "model_category_counts.csv"
  )
)

readr::write_csv(
  model_reference_categories,
  here::here(
    "outputs",
    "tables",
    "model_reference_categories.csv"
  )
)

readr::write_csv(
  model_outcome_summary,
  here::here(
    "outputs",
    "tables",
    "model_outcome_summary.csv"
  )
)

# ------------------------------------------------------------
# Save regression results
# ------------------------------------------------------------

readr::write_csv(
  unadjusted_odds_ratios,
  here::here(
    "outputs",
    "tables",
    "unadjusted_odds_ratios.csv"
  )
)

readr::write_csv(
  adjusted_odds_ratios,
  here::here(
    "outputs",
    "tables",
    "adjusted_odds_ratios.csv"
  )
)

readr::write_csv(
  combined_regression_results,
  here::here(
    "outputs",
    "tables",
    "combined_regression_results.csv"
  )
)

readr::write_csv(
  model_quality_summary,
  here::here(
    "outputs",
    "tables",
    "statistical_model_quality_summary.csv"
  )
)

# ------------------------------------------------------------
# Save Power BI-ready adjusted model results
# ------------------------------------------------------------

readr::write_csv(
  adjusted_model_presentation,
  here::here(
    "data",
    "powerbi",
    "adjusted_odds_ratios.csv"
  )
)

# ------------------------------------------------------------
# Review modelling sample
# ------------------------------------------------------------

print(
  model_sample_flow,
  n = Inf
)

# ------------------------------------------------------------
# Review reference categories
# ------------------------------------------------------------

print(
  model_reference_categories,
  n = Inf
)

# ------------------------------------------------------------
# Review model QA
# ------------------------------------------------------------

print(
  model_quality_summary,
  n = Inf
)

# ------------------------------------------------------------
# Review adjusted estimates
# ------------------------------------------------------------

print(
  adjusted_odds_ratios,
  n = Inf,
  width = Inf
)

message(
  "Survey-weighted statistical modelling completed successfully."
)