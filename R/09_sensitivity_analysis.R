# ============================================================
# SENSITIVITY AND ROBUSTNESS ANALYSIS
# MATERNAL CONTINUUM OF CARE
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
# Define sensitivity outcomes
# ------------------------------------------------------------

outcome_dictionary <- tibble::tribble(
  
  ~outcome_variable,
  ~outcome_definition,
  
  "complete_continuum",
  "Primary: ANC4 + skilled birth + paired PNC",
  
  "complete_continuum_anc8",
  "Sensitivity 1: ANC8 + skilled birth + paired PNC",
  
  "complete_continuum_facility",
  "Sensitivity 2: ANC4 + facility delivery + paired PNC"
)

# ------------------------------------------------------------
# Define required variables
# ------------------------------------------------------------

required_variables <- c(
  outcome_dictionary$outcome_variable,
  "age_group",
  "education",
  "wealth_quintile",
  "residence",
  "zone",
  "cluster_id",
  "stratum_id",
  "survey_weight"
)

missing_variables <- setdiff(
  required_variables,
  names(analytic)
)

if (length(missing_variables) > 0) {
  stop(
    paste0(
      "Variables required for sensitivity analysis are missing: ",
      paste(
        missing_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Validate binary outcomes
# ------------------------------------------------------------

validate_binary_variable <- function(
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
        "Variable '",
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
  outcome_dictionary$outcome_variable,
  ~ validate_binary_variable(
    variable = .x,
    data = analytic
  )
)

# ------------------------------------------------------------
# Helper for reference categories
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
# Prepare common modelling dataset
#
# A single common sample is used for all three models so
# differences between results are not caused by different
# observations entering different models.
# ------------------------------------------------------------

sensitivity_data <- analytic |>
  dplyr::transmute(
    
    complete_continuum =
      as.integer(
        complete_continuum
      ),
    
    complete_continuum_anc8 =
      as.integer(
        complete_continuum_anc8
      ),
    
    complete_continuum_facility =
      as.integer(
        complete_continuum_facility
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
# Identify common complete-case sample
# ------------------------------------------------------------

complete_rows <- stats::complete.cases(
  sensitivity_data
)

common_sample_n <- sum(
  complete_rows
)

sensitivity_data <- sensitivity_data[
  complete_rows,
]

sensitivity_data <- droplevels(
  sensitivity_data
)

if (
  nrow(
    sensitivity_data
  ) == 0
) {
  stop(
    "No complete observations remain for sensitivity analysis."
  )
}

# ------------------------------------------------------------
# Document sensitivity-analysis sample
# ------------------------------------------------------------

sensitivity_sample_summary <- tibble::tibble(
  
  metric = c(
    "Original analytical cohort",
    "Common complete-case sensitivity sample",
    "Records excluded from common sensitivity sample"
  ),
  
  value = c(
    nrow(
      analytic
    ),
    
    common_sample_n,
    
    nrow(
      analytic
    ) -
      common_sample_n
  )
)

# ------------------------------------------------------------
# Validate survey-design variables
# ------------------------------------------------------------

missing_psu <- sum(
  is.na(
    sensitivity_data$cluster_id
  )
)

missing_strata <- sum(
  is.na(
    sensitivity_data$stratum_id
  )
)

missing_weights <- sum(
  is.na(
    sensitivity_data$survey_weight
  )
)

nonpositive_weights <- sum(
  sensitivity_data$survey_weight <= 0,
  na.rm = TRUE
)

if (missing_psu > 0) {
  stop(
    "Missing PSU values detected."
  )
}

if (missing_strata > 0) {
  stop(
    "Missing survey-stratum values detected."
  )
}

if (missing_weights > 0) {
  stop(
    "Missing survey weights detected."
  )
}

if (nonpositive_weights > 0) {
  stop(
    "Non-positive survey weights detected."
  )
}

# ------------------------------------------------------------
# Specify survey design
# ------------------------------------------------------------

options(
  survey.lonely.psu = "adjust"
)

sensitivity_design <- survey::svydesign(
  ids = ~cluster_id,
  strata = ~stratum_id,
  weights = ~survey_weight,
  data = sensitivity_data,
  nest = TRUE
)

# ------------------------------------------------------------
# Estimate weighted prevalence for each definition
# ------------------------------------------------------------

estimate_outcome_prevalence <- function(
    outcome_variable,
    outcome_definition,
    design
) {
  
  formula_object <- stats::as.formula(
    paste0(
      "~",
      outcome_variable
    )
  )
  
  estimate <- survey::svymean(
    x = formula_object,
    design = design,
    na.rm = TRUE
  )
  
  ci <- stats::confint(
    estimate,
    level = 0.95
  )
  
  tibble::tibble(
    
    outcome_variable =
      outcome_variable,
    
    outcome_definition =
      outcome_definition,
    
    unweighted_n =
      sum(
        !is.na(
          design$variables[[outcome_variable]]
        )
      ),
    
    unweighted_positive_n =
      sum(
        design$variables[[outcome_variable]] == 1,
        na.rm = TRUE
      ),
    
    weighted_percent =
      as.numeric(
        stats::coef(
          estimate
        )[1]
      ) *
      100,
    
    confidence_interval_low_percent =
      as.numeric(
        ci[
          1,
          1
        ]
      ) *
      100,
    
    confidence_interval_high_percent =
      as.numeric(
        ci[
          1,
          2
        ]
      ) *
      100
  )
}

sensitivity_prevalence <- purrr::map2_dfr(
  
  outcome_dictionary$outcome_variable,
  
  outcome_dictionary$outcome_definition,
  
  ~ estimate_outcome_prevalence(
    outcome_variable = .x,
    outcome_definition = .y,
    design = sensitivity_design
  )
) |>
  dplyr::mutate(
    
    weighted_percent =
      round(
        weighted_percent,
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
  )

# ------------------------------------------------------------
# Compare prevalence against primary definition
# ------------------------------------------------------------

primary_prevalence <- sensitivity_prevalence |>
  dplyr::filter(
    outcome_variable ==
      "complete_continuum"
  ) |>
  dplyr::pull(
    weighted_percent
  )

sensitivity_prevalence <- sensitivity_prevalence |>
  dplyr::mutate(
    
    difference_from_primary_pp =
      round(
        weighted_percent -
          primary_prevalence,
        2
      )
  )

# ------------------------------------------------------------
# Validate ANC8 subset relationship
#
# Because ANC8 is stricter than ANC4, a case satisfying the
# ANC8 continuum should also satisfy the primary ANC4
# continuum.
# ------------------------------------------------------------

anc8_subset_violations <- sum(
  sensitivity_data$complete_continuum_anc8 == 1 &
    sensitivity_data$complete_continuum != 1,
  na.rm = TRUE
)

if (
  anc8_subset_violations > 0
) {
  stop(
    paste0(
      "ANC8 sensitivity outcome violates the expected subset relationship in ",
      anc8_subset_violations,
      " records."
    )
  )
}

# ------------------------------------------------------------
# Create pairwise agreement indicators
# ------------------------------------------------------------

sensitivity_data <- sensitivity_data |>
  dplyr::mutate(
    
    agreement_primary_anc8 =
      as.integer(
        complete_continuum ==
          complete_continuum_anc8
      ),
    
    agreement_primary_facility =
      as.integer(
        complete_continuum ==
          complete_continuum_facility
      ),
    
    agreement_anc8_facility =
      as.integer(
        complete_continuum_anc8 ==
          complete_continuum_facility
      )
  )

# Rebuild design after creating agreement variables
sensitivity_design <- survey::svydesign(
  ids = ~cluster_id,
  strata = ~stratum_id,
  weights = ~survey_weight,
  data = sensitivity_data,
  nest = TRUE
)

# ------------------------------------------------------------
# Estimate weighted agreement
# ------------------------------------------------------------

agreement_dictionary <- tibble::tribble(
  
  ~agreement_variable,
  ~comparison,
  
  "agreement_primary_anc8",
  "Primary vs ANC8 definition",
  
  "agreement_primary_facility",
  "Primary vs facility-delivery definition",
  
  "agreement_anc8_facility",
  "ANC8 vs facility-delivery definition"
)

estimate_agreement <- function(
    agreement_variable,
    comparison_label,
    design
) {
  
  formula_object <- stats::as.formula(
    paste0(
      "~",
      agreement_variable
    )
  )
  
  estimate <- survey::svymean(
    x = formula_object,
    design = design,
    na.rm = TRUE
  )
  
  ci <- stats::confint(
    estimate,
    level = 0.95
  )
  
  tibble::tibble(
    
    comparison =
      comparison_label,
    
    weighted_agreement_percent =
      as.numeric(
        stats::coef(
          estimate
        )[1]
      ) *
      100,
    
    confidence_interval_low_percent =
      as.numeric(
        ci[
          1,
          1
        ]
      ) *
      100,
    
    confidence_interval_high_percent =
      as.numeric(
        ci[
          1,
          2
        ]
      ) *
      100
  )
}

outcome_agreement <- purrr::map2_dfr(
  
  agreement_dictionary$agreement_variable,
  
  agreement_dictionary$comparison,
  
  ~ estimate_agreement(
    agreement_variable = .x,
    comparison_label = .y,
    design = sensitivity_design
  )
) |>
  dplyr::mutate(
    
    dplyr::across(
      c(
        weighted_agreement_percent,
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
# Define adjusted model formula components
# ------------------------------------------------------------

predictor_terms <- c(
  "age_group_model",
  "education_model",
  "wealth_model",
  "residence_model",
  "zone_model"
)

# ------------------------------------------------------------
# Fit adjusted sensitivity model
# ------------------------------------------------------------

fit_sensitivity_model <- function(
    outcome_variable,
    outcome_definition,
    design
) {
  
  model_formula <- stats::as.formula(
    paste(
      outcome_variable,
      "~",
      paste(
        predictor_terms,
        collapse = " + "
      )
    )
  )
  
  model <- survey::svyglm(
    formula =
      model_formula,
    design =
      design,
    family =
      stats::quasibinomial(
        link = "logit"
      )
  )
  
  if (
    !is.null(
      model$converged
    ) &&
    !isTRUE(
      model$converged
    )
  ) {
    stop(
      paste0(
        "Model failed to converge for outcome: ",
        outcome_variable
      )
    )
  }
  
  coefficient_table <- as.data.frame(
    summary(
      model
    )$coefficients
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
  
  estimate_values <- coefficient_table[
    ,
    1
  ]
  
  standard_errors <- coefficient_table[
    ,
    2
  ]
  
  p_values <- coefficient_table[
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
  
  tibble::tibble(
    
    outcome_variable =
      outcome_variable,
    
    outcome_definition =
      outcome_definition,
    
    term =
      coefficient_table$term,
    
    log_odds =
      estimate_values,
    
    standard_error =
      standard_errors,
    
    adjusted_odds_ratio =
      exp(
        estimate_values
      ),
    
    confidence_interval_low =
      exp(
        estimate_values -
          critical_value *
          standard_errors
      ),
    
    confidence_interval_high =
      exp(
        estimate_values +
          critical_value *
          standard_errors
      ),
    
    p_value =
      p_values
  )
}

# ------------------------------------------------------------
# Fit all three adjusted models
# ------------------------------------------------------------

sensitivity_adjusted_models <- purrr::map2_dfr(
  
  outcome_dictionary$outcome_variable,
  
  outcome_dictionary$outcome_definition,
  
  ~ fit_sensitivity_model(
    outcome_variable = .x,
    outcome_definition = .y,
    design = sensitivity_design
  )
)

# ------------------------------------------------------------
# Format model estimates
# ------------------------------------------------------------

sensitivity_adjusted_models <- sensitivity_adjusted_models |>
  dplyr::mutate(
    
    adjusted_odds_ratio =
      round(
        adjusted_odds_ratio,
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
    
    association_direction =
      dplyr::case_when(
        
        adjusted_odds_ratio > 1 ~
          "Positive",
        
        adjusted_odds_ratio < 1 ~
          "Negative",
        
        TRUE ~
          "Null"
      ),
    
    statistically_significant =
      dplyr::case_when(
        
        is.na(
          p_value
        ) ~
          NA_character_,
        
        p_value < 0.05 ~
          "Yes",
        
        TRUE ~
          "No"
      ),
    
    estimate_95ci =
      paste0(
        sprintf(
          "%.2f",
          adjusted_odds_ratio
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

# ------------------------------------------------------------
# Compare effect-direction consistency
# ------------------------------------------------------------

effect_direction_consistency <- sensitivity_adjusted_models |>
  dplyr::select(
    outcome_variable,
    term,
    association_direction,
    statistically_significant
  ) |>
  tidyr::pivot_wider(
    names_from =
      outcome_variable,
    values_from =
      c(
        association_direction,
        statistically_significant
      )
  ) |>
  dplyr::mutate(
    
    direction_consistent =
      dplyr::case_when(
        
        association_direction_complete_continuum ==
          association_direction_complete_continuum_anc8 &
          association_direction_complete_continuum ==
          association_direction_complete_continuum_facility ~
          "Yes",
        
        TRUE ~
          "No"
      ),
    
    significance_consistent =
      dplyr::case_when(
        
        statistically_significant_complete_continuum ==
          statistically_significant_complete_continuum_anc8 &
          statistically_significant_complete_continuum ==
          statistically_significant_complete_continuum_facility ~
          "Yes",
        
        TRUE ~
          "No"
      )
  )

# ------------------------------------------------------------
# Create robustness summary
# ------------------------------------------------------------

direction_inconsistencies <- sum(
  effect_direction_consistency$direction_consistent ==
    "No",
  na.rm = TRUE
)

significance_inconsistencies <- sum(
  effect_direction_consistency$significance_consistent ==
    "No",
  na.rm = TRUE
)

invalid_odds_ratios <- sum(
  !is.finite(
    sensitivity_adjusted_models$adjusted_odds_ratio
  ) |
    sensitivity_adjusted_models$adjusted_odds_ratio <= 0,
  na.rm = TRUE
)

invalid_confidence_intervals <- sum(
  sensitivity_adjusted_models$confidence_interval_low >
    sensitivity_adjusted_models$confidence_interval_high,
  na.rm = TRUE
)

invalid_p_values <- sum(
  sensitivity_adjusted_models$p_value < 0 |
    sensitivity_adjusted_models$p_value > 1,
  na.rm = TRUE
)

if (
  invalid_odds_ratios > 0
) {
  stop(
    "Invalid adjusted odds ratios detected in sensitivity models."
  )
}

if (
  invalid_confidence_intervals > 0
) {
  stop(
    "Invalid confidence intervals detected in sensitivity models."
  )
}

if (
  invalid_p_values > 0
) {
  stop(
    "Invalid p-values detected in sensitivity models."
  )
}

# ------------------------------------------------------------
# Create sensitivity QA summary
# ------------------------------------------------------------

sensitivity_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Common sensitivity-analysis sample",
    "Outcome definitions compared",
    "ANC8 subset violations",
    "Adjusted model coefficient estimates",
    "Invalid adjusted odds ratios",
    "Invalid adjusted confidence intervals",
    "Invalid adjusted-model p-values",
    "Terms with inconsistent association direction",
    "Terms with inconsistent statistical significance"
  ),
  
  result = c(
    
    nrow(
      sensitivity_data
    ),
    
    nrow(
      outcome_dictionary
    ),
    
    anc8_subset_violations,
    
    nrow(
      sensitivity_adjusted_models
    ),
    
    invalid_odds_ratios,
    
    invalid_confidence_intervals,
    
    invalid_p_values,
    
    direction_inconsistencies,
    
    significance_inconsistencies
  )
)

# ------------------------------------------------------------
# Save sensitivity outputs
# ------------------------------------------------------------

readr::write_csv(
  sensitivity_sample_summary,
  here::here(
    "outputs",
    "tables",
    "sensitivity_sample_summary.csv"
  )
)

readr::write_csv(
  sensitivity_prevalence,
  here::here(
    "outputs",
    "tables",
    "sensitivity_prevalence_comparison.csv"
  )
)

readr::write_csv(
  outcome_agreement,
  here::here(
    "outputs",
    "tables",
    "sensitivity_outcome_agreement.csv"
  )
)

readr::write_csv(
  sensitivity_adjusted_models,
  here::here(
    "outputs",
    "tables",
    "sensitivity_adjusted_models.csv"
  )
)

readr::write_csv(
  effect_direction_consistency,
  here::here(
    "outputs",
    "tables",
    "sensitivity_effect_consistency.csv"
  )
)

readr::write_csv(
  sensitivity_quality_summary,
  here::here(
    "outputs",
    "tables",
    "sensitivity_analysis_quality_summary.csv"
  )
)

# ------------------------------------------------------------
# Save Power BI-ready sensitivity results
# ------------------------------------------------------------

powerbi_sensitivity_prevalence <- sensitivity_prevalence |>
  dplyr::select(
    outcome_definition,
    weighted_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    difference_from_primary_pp,
    estimate_95ci
  )

readr::write_csv(
  powerbi_sensitivity_prevalence,
  here::here(
    "data",
    "powerbi",
    "sensitivity_prevalence.csv"
  )
)

powerbi_sensitivity_models <- sensitivity_adjusted_models |>
  dplyr::select(
    outcome_definition,
    term,
    adjusted_odds_ratio,
    confidence_interval_low,
    confidence_interval_high,
    p_value,
    statistically_significant,
    association_direction,
    estimate_95ci
  )

readr::write_csv(
  powerbi_sensitivity_models,
  here::here(
    "data",
    "powerbi",
    "sensitivity_adjusted_models.csv"
  )
)

# ------------------------------------------------------------
# Review prevalence robustness
# ------------------------------------------------------------

print(
  sensitivity_prevalence,
  n = Inf,
  width = Inf
)

# ------------------------------------------------------------
# Review outcome agreement
# ------------------------------------------------------------

print(
  outcome_agreement,
  n = Inf,
  width = Inf
)

# ------------------------------------------------------------
# Review robustness QA
# ------------------------------------------------------------

print(
  sensitivity_quality_summary,
  n = Inf
)

# ------------------------------------------------------------
# Review coefficient consistency
# ------------------------------------------------------------

print(
  effect_direction_consistency,
  n = Inf,
  width = Inf
)

message(
  "Sensitivity and robustness analysis completed successfully."
)