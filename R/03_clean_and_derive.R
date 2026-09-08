# ============================================================
# ANALYTICAL COHORT PREPARATION
# 2024 NIGERIA DEMOGRAPHIC AND HEALTH SURVEY
# ============================================================

source(
  here::here(
    "R",
    "01_setup.R"
  )
)

# ------------------------------------------------------------
# Load validated source data
# ------------------------------------------------------------

input_file <- here::here(
  "data",
  "interim",
  "raw_nr_imported.rds"
)

if (!file.exists(input_file)) {
  stop(
    paste0(
      "Validated DHS source file not found at:\n",
      input_file
    )
  )
}

raw_nr <- readRDS(
  input_file
)

message(
  "Source dataset loaded: ",
  format(
    nrow(raw_nr),
    big.mark = ","
  ),
  " records."
)

# ------------------------------------------------------------
# Confirm required variables
# ------------------------------------------------------------

required_variables <- c(
  "v001",
  "v002",
  "v003",
  "v005",
  "v021",
  "v022",
  "v024",
  "v025",
  "v012",
  "v013",
  "v106",
  "v190",
  "p19",
  "m80"
)

missing_required_variables <- setdiff(
  required_variables,
  names(raw_nr)
)

if (length(missing_required_variables) > 0) {
  stop(
    paste0(
      "Required variables are missing: ",
      paste(
        missing_required_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Confirm validated survey-stratum consistency
# ------------------------------------------------------------

if ("v023" %in% names(raw_nr)) {
  
  strata_comparison <- raw_nr$v022 == raw_nr$v023
  
  if (
    any(
      strata_comparison == FALSE,
      na.rm = TRUE
    )
  ) {
    stop(
      "v022 and v023 are not identical. Review the survey-design specification."
    )
  }
}

# ------------------------------------------------------------
# Document cohort selection
# ------------------------------------------------------------

source_records <- nrow(
  raw_nr
)

most_recent_live_birth_records <- sum(
  raw_nr$m80 ==
    project_config$eligibility$live_birth_code,
  na.rm = TRUE
)

eligible_records <- sum(
  raw_nr$m80 ==
    project_config$eligibility$live_birth_code &
    !is.na(raw_nr$p19) &
    raw_nr$p19 <=
    project_config$eligibility$maximum_months_since_outcome,
  na.rm = TRUE
)

cohort_flow <- tibble::tibble(
  selection_stage = c(
    "Pregnancy outcome records in source dataset",
    "Records classified as most recent live birth",
    "Most recent live birth within previous 24 months"
  ),
  unweighted_n = c(
    source_records,
    most_recent_live_birth_records,
    eligible_records
  )
)

# ------------------------------------------------------------
# Construct analytical cohort
# ------------------------------------------------------------

analytic <- raw_nr |>
  dplyr::filter(
    m80 ==
      project_config$eligibility$live_birth_code,
    !is.na(p19),
    p19 <=
      project_config$eligibility$maximum_months_since_outcome
  )

if (nrow(analytic) == 0) {
  stop(
    "The cohort-selection criteria produced zero eligible records."
  )
}

# ------------------------------------------------------------
# Create record identifier
# ------------------------------------------------------------

if ("pidx" %in% names(analytic)) {
  
  analytic <- analytic |>
    dplyr::mutate(
      record_index = as.integer(pidx)
    )
  
} else {
  
  analytic <- analytic |>
    dplyr::mutate(
      record_index = dplyr::row_number()
    )
}

analytic <- analytic |>
  dplyr::mutate(
    
    case_id = paste(
      as.integer(v001),
      as.integer(v002),
      as.integer(v003),
      record_index,
      sep = "-"
    ),
    
    cluster_id = as.integer(v021),
    
    stratum_id = as.integer(v022),
    
    survey_weight = as.numeric(v005) / 1000000
  )

# ------------------------------------------------------------
# Create demographic and geographic variables
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    age_years = as.integer(v012),
    
    age_group = labelled_text(v013),
    
    education = labelled_text(v106),
    
    wealth_quintile = labelled_text(v190),
    
    zone = labelled_text(v024),
    
    residence = labelled_text(v025),
    
    months_since_live_birth = as.integer(p19)
  )

# ------------------------------------------------------------
# Validate cohort integrity
# ------------------------------------------------------------

duplicate_case_ids <- sum(
  duplicated(
    analytic$case_id
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

invalid_birth_timing <- sum(
  analytic$months_since_live_birth < 0 |
    analytic$months_since_live_birth >
    project_config$eligibility$maximum_months_since_outcome,
  na.rm = TRUE
)

if (duplicate_case_ids > 0) {
  stop(
    "Duplicate case identifiers were detected."
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

if (invalid_birth_timing > 0) {
  stop(
    "Invalid months-since-live-birth values were detected."
  )
}

# ------------------------------------------------------------
# Create cohort quality summary
# ------------------------------------------------------------

cohort_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Analytical cohort size",
    "Unique case identifiers",
    "Duplicate case identifiers",
    "Missing survey weights",
    "Non-positive survey weights",
    "Missing PSU values",
    "Missing stratum values",
    "Minimum months since live birth",
    "Maximum months since live birth",
    "Number of PSUs",
    "Number of strata",
    "Number of zones",
    "Number of residence categories"
  ),
  
  result = c(
    nrow(analytic),
    
    dplyr::n_distinct(
      analytic$case_id
    ),
    
    duplicate_case_ids,
    
    missing_weights,
    
    nonpositive_weights,
    
    missing_psu,
    
    missing_strata,
    
    min(
      analytic$months_since_live_birth,
      na.rm = TRUE
    ),
    
    max(
      analytic$months_since_live_birth,
      na.rm = TRUE
    ),
    
    dplyr::n_distinct(
      analytic$cluster_id
    ),
    
    dplyr::n_distinct(
      analytic$stratum_id
    ),
    
    dplyr::n_distinct(
      analytic$zone,
      na.rm = TRUE
    ),
    
    dplyr::n_distinct(
      analytic$residence,
      na.rm = TRUE
    )
  )
)

# ------------------------------------------------------------
# Create demographic profile
# ------------------------------------------------------------

create_profile <- function(
    data,
    variable,
    dimension_name
) {
  
  data |>
    dplyr::filter(
      !is.na(
        .data[[variable]]
      )
    ) |>
    dplyr::count(
      category = .data[[variable]],
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      dimension = dimension_name,
      percent = unweighted_n /
        sum(unweighted_n) *
        100
    ) |>
    dplyr::select(
      dimension,
      category,
      unweighted_n,
      percent
    )
}

cohort_demographic_profile <- dplyr::bind_rows(
  
  create_profile(
    analytic,
    "age_group",
    "Age group"
  ),
  
  create_profile(
    analytic,
    "education",
    "Education"
  ),
  
  create_profile(
    analytic,
    "wealth_quintile",
    "Wealth quintile"
  ),
  
  create_profile(
    analytic,
    "zone",
    "Zone"
  ),
  
  create_profile(
    analytic,
    "residence",
    "Residence"
  )
)

# ------------------------------------------------------------
# Save quality-assurance outputs
# ------------------------------------------------------------

readr::write_csv(
  cohort_flow,
  here::here(
    "outputs",
    "tables",
    "cohort_flow.csv"
  )
)

readr::write_csv(
  cohort_quality_summary,
  here::here(
    "outputs",
    "tables",
    "cohort_quality_summary.csv"
  )
)

readr::write_csv(
  cohort_demographic_profile,
  here::here(
    "outputs",
    "tables",
    "cohort_demographic_profile.csv"
  )
)

# ------------------------------------------------------------
# Save private base analytical cohort
# ------------------------------------------------------------

cohort_output_file <- here::here(
  "data",
  "interim",
  "analytic_cohort_base.rds"
)

saveRDS(
  analytic,
  cohort_output_file
)

# ------------------------------------------------------------
# Review summary
# ------------------------------------------------------------

print(
  cohort_flow
)

print(
  cohort_quality_summary,
  n = Inf
)

message(
  "Analytical cohort prepared and validated successfully."
)
# ============================================================
# ANTENATAL CARE INDICATORS
# ============================================================

# ------------------------------------------------------------
# Confirm required ANC variables
# ------------------------------------------------------------

anc_required_variables <- c(
  "m2a",
  "m2b",
  "m2n",
  "m13",
  "m14",
  "m42c",
  "m42d",
  "m42e",
  "m42f",
  "m42g",
  "m42h",
  "m42i"
)

missing_anc_variables <- setdiff(
  anc_required_variables,
  names(analytic)
)

if (length(missing_anc_variables) > 0) {
  stop(
    paste0(
      "Required ANC variables are missing: ",
      paste(
        missing_anc_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Derive ANC access and contact indicators
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    anc_any = dplyr::case_when(
      m2n == 0 ~ 1L,
      m2n == 1 ~ 0L,
      TRUE ~ NA_integer_
    ),
    
    skilled_anc = dplyr::case_when(
      m2a == 1 | m2b == 1 ~ 1L,
      m2n %in% c(0, 1) ~ 0L,
      TRUE ~ NA_integer_
    ),
    
    early_anc = dplyr::case_when(
      m13 >= 0 & m13 <= 3 ~ 1L,
      m13 >= 4 & m13 < 90 ~ 0L,
      TRUE ~ NA_integer_
    ),
    
    anc_4plus = dplyr::case_when(
      m14 >= 4 & m14 < 90 ~ 1L,
      m14 >= 0 & m14 < 4 ~ 0L,
      TRUE ~ NA_integer_
    ),
    
    anc_8plus = dplyr::case_when(
      m14 >= 8 & m14 < 90 ~ 1L,
      m14 >= 0 & m14 < 8 ~ 0L,
      TRUE ~ NA_integer_
    )
  )

# ------------------------------------------------------------
# Derive ANC content indicators
# ------------------------------------------------------------

anc_content_variables <- c(
  "m42c",
  "m42d",
  "m42e",
  "m42f",
  "m42g",
  "m42h",
  "m42i"
)

anc_content_matrix <- analytic |>
  dplyr::select(
    dplyr::all_of(
      anc_content_variables
    )
  )

analytic$anc_content_items_observed <- rowSums(
  !is.na(
    anc_content_matrix
  )
)

anc_content_score_raw <- rowSums(
  anc_content_matrix == 1,
  na.rm = TRUE
)

analytic$anc_content_score <- dplyr::if_else(
  analytic$anc_content_items_observed ==
    length(anc_content_variables),
  as.integer(
    anc_content_score_raw
  ),
  NA_integer_
)

analytic$complete_anc_content <- dplyr::case_when(
  analytic$anc_content_score == 7 ~ 1L,
  !is.na(analytic$anc_content_score) ~ 0L,
  TRUE ~ NA_integer_
)

# ------------------------------------------------------------
# Validate logical consistency
# ------------------------------------------------------------

anc8_without_anc4 <- sum(
  analytic$anc_8plus == 1 &
    analytic$anc_4plus != 1,
  na.rm = TRUE
)

skilled_without_any_anc <- sum(
  analytic$skilled_anc == 1 &
    analytic$anc_any != 1,
  na.rm = TRUE
)

invalid_anc_content_score <- sum(
  !is.na(analytic$anc_content_score) &
    (
      analytic$anc_content_score < 0 |
        analytic$anc_content_score > 7
    )
)

if (anc8_without_anc4 > 0) {
  stop(
    "Logical inconsistency detected: ANC 8+ without ANC 4+."
  )
}

if (skilled_without_any_anc > 0) {
  stop(
    "Logical inconsistency detected: skilled ANC without any ANC."
  )
}

if (invalid_anc_content_score > 0) {
  stop(
    "ANC content scores outside the expected 0-7 range were detected."
  )
}

# ------------------------------------------------------------
# Create ANC quality-assurance summary
# ------------------------------------------------------------

anc_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Analytical cohort size",
    "Any ANC non-missing",
    "Skilled ANC non-missing",
    "Early ANC non-missing",
    "ANC 4+ non-missing",
    "ANC 8+ non-missing",
    "Complete ANC content non-missing",
    "ANC 8+ without ANC 4+",
    "Skilled ANC without any ANC",
    "Invalid ANC content scores",
    "Minimum ANC content score",
    "Maximum ANC content score"
  ),
  
  result = c(
    nrow(analytic),
    
    sum(
      !is.na(
        analytic$anc_any
      )
    ),
    
    sum(
      !is.na(
        analytic$skilled_anc
      )
    ),
    
    sum(
      !is.na(
        analytic$early_anc
      )
    ),
    
    sum(
      !is.na(
        analytic$anc_4plus
      )
    ),
    
    sum(
      !is.na(
        analytic$anc_8plus
      )
    ),
    
    sum(
      !is.na(
        analytic$complete_anc_content
      )
    ),
    
    anc8_without_anc4,
    
    skilled_without_any_anc,
    
    invalid_anc_content_score,
    
    min(
      analytic$anc_content_score,
      na.rm = TRUE
    ),
    
    max(
      analytic$anc_content_score,
      na.rm = TRUE
    )
  )
)

# ------------------------------------------------------------
# Create unweighted indicator distribution for QA
# ------------------------------------------------------------

anc_indicator_distribution <- dplyr::bind_rows(
  
  analytic |>
    dplyr::count(
      value = anc_any,
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      indicator = "Any ANC"
    ),
  
  analytic |>
    dplyr::count(
      value = skilled_anc,
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      indicator = "Skilled ANC"
    ),
  
  analytic |>
    dplyr::count(
      value = early_anc,
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      indicator = "Early ANC"
    ),
  
  analytic |>
    dplyr::count(
      value = anc_4plus,
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      indicator = "ANC 4+"
    ),
  
  analytic |>
    dplyr::count(
      value = anc_8plus,
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      indicator = "ANC 8+"
    ),
  
  analytic |>
    dplyr::count(
      value = complete_anc_content,
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      indicator = "Complete ANC content"
    )
) |>
  dplyr::group_by(
    indicator
  ) |>
  dplyr::mutate(
    percent = unweighted_n /
      sum(unweighted_n) *
      100
  ) |>
  dplyr::ungroup() |>
  dplyr::select(
    indicator,
    value,
    unweighted_n,
    percent
  )

# ------------------------------------------------------------
# Save ANC validation outputs
# ------------------------------------------------------------

readr::write_csv(
  anc_quality_summary,
  here::here(
    "outputs",
    "tables",
    "anc_indicator_quality_summary.csv"
  )
)

readr::write_csv(
  anc_indicator_distribution,
  here::here(
    "outputs",
    "tables",
    "anc_indicator_unweighted_distribution.csv"
  )
)

# ------------------------------------------------------------
# Save updated private analytical dataset
# ------------------------------------------------------------

saveRDS(
  analytic,
  here::here(
    "data",
    "interim",
    "analytic_with_anc.rds"
  )
)

# ------------------------------------------------------------
# Review ANC quality checks
# ------------------------------------------------------------

print(
  anc_quality_summary,
  n = Inf
)

message(
  "Antenatal care indicators derived and validated successfully."
)
# ============================================================
# DELIVERY CARE INDICATORS
# ============================================================

# ------------------------------------------------------------
# Confirm required delivery variables
# ------------------------------------------------------------

delivery_required_variables <- c(
  "m15",
  "m3a",
  "m3b"
)

missing_delivery_variables <- setdiff(
  delivery_required_variables,
  names(analytic)
)

if (length(missing_delivery_variables) > 0) {
  stop(
    paste0(
      "Required delivery variables are missing: ",
      paste(
        missing_delivery_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Preserve the detailed place-of-delivery label
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    delivery_place = labelled_text(m15)
  )

# ------------------------------------------------------------
# Derive broad delivery setting
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    delivery_setting = dplyr::case_when(
      
      m15 >= 10 & m15 <= 19 ~
        "Home",
      
      m15 >= 20 & m15 <= 29 ~
        "Public health facility",
      
      m15 >= 30 & m15 <= 39 ~
        "Private health facility",
      
      m15 >= 40 & m15 <= 49 ~
        "Other health facility",
      
      TRUE ~
        "Other or missing"
    )
  )

# ------------------------------------------------------------
# Derive health-facility delivery
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    facility_delivery = dplyr::case_when(
      
      m15 >= 20 & m15 <= 49 ~ 1L,
      
      m15 >= 10 & m15 <= 19 ~ 0L,
      
      TRUE ~ NA_integer_
    )
  )

# ------------------------------------------------------------
# Derive skilled birth attendance
#
# Nigeria DHS definition:
# doctor or nurse/midwife
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    skilled_birth = dplyr::case_when(
      
      m3a == 1 | m3b == 1 ~ 1L,
      
      !is.na(m3a) | !is.na(m3b) ~ 0L,
      
      TRUE ~ NA_integer_
    )
  )

# ------------------------------------------------------------
# Validate binary indicators
# ------------------------------------------------------------

invalid_facility_delivery <- sum(
  !is.na(analytic$facility_delivery) &
    !analytic$facility_delivery %in% c(0L, 1L)
)

invalid_skilled_birth <- sum(
  !is.na(analytic$skilled_birth) &
    !analytic$skilled_birth %in% c(0L, 1L)
)

if (invalid_facility_delivery > 0) {
  stop(
    "Invalid facility-delivery indicator values were detected."
  )
}

if (invalid_skilled_birth > 0) {
  stop(
    "Invalid skilled-birth indicator values were detected."
  )
}

# ------------------------------------------------------------
# Examine potentially unusual combinations
#
# These are not automatically errors.
# Skilled providers can attend some non-facility births,
# while some facility births may not meet the skilled-
# provider definition.
# ------------------------------------------------------------

skilled_birth_outside_facility <- sum(
  analytic$skilled_birth == 1 &
    analytic$facility_delivery == 0,
  na.rm = TRUE
)

facility_birth_without_skilled_provider <- sum(
  analytic$facility_delivery == 1 &
    analytic$skilled_birth == 0,
  na.rm = TRUE
)

# ------------------------------------------------------------
# Create delivery quality-assurance summary
# ------------------------------------------------------------

delivery_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Analytical cohort size",
    "Facility delivery non-missing",
    "Skilled birth attendance non-missing",
    "Invalid facility delivery values",
    "Invalid skilled birth values",
    "Skilled birth outside health facility",
    "Facility birth without skilled provider"
  ),
  
  result = c(
    nrow(analytic),
    
    sum(
      !is.na(
        analytic$facility_delivery
      )
    ),
    
    sum(
      !is.na(
        analytic$skilled_birth
      )
    ),
    
    invalid_facility_delivery,
    
    invalid_skilled_birth,
    
    skilled_birth_outside_facility,
    
    facility_birth_without_skilled_provider
  )
)

# ------------------------------------------------------------
# Create unweighted delivery-indicator distributions
# ------------------------------------------------------------

delivery_indicator_distribution <- dplyr::bind_rows(
  
  analytic |>
    dplyr::count(
      value = facility_delivery,
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      indicator = "Health facility delivery"
    ),
  
  analytic |>
    dplyr::count(
      value = skilled_birth,
      name = "unweighted_n"
    ) |>
    dplyr::mutate(
      indicator = "Skilled birth attendance"
    )
  
) |>
  dplyr::group_by(
    indicator
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  ) |>
  dplyr::ungroup() |>
  dplyr::select(
    indicator,
    value,
    unweighted_n,
    percent
  )

# ------------------------------------------------------------
# Create delivery-setting distribution
# ------------------------------------------------------------

delivery_setting_distribution <- analytic |>
  dplyr::count(
    delivery_setting,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  )

# ------------------------------------------------------------
# Save delivery QA outputs
# ------------------------------------------------------------

readr::write_csv(
  delivery_quality_summary,
  here::here(
    "outputs",
    "tables",
    "delivery_indicator_quality_summary.csv"
  )
)

readr::write_csv(
  delivery_indicator_distribution,
  here::here(
    "outputs",
    "tables",
    "delivery_indicator_unweighted_distribution.csv"
  )
)

readr::write_csv(
  delivery_setting_distribution,
  here::here(
    "outputs",
    "tables",
    "delivery_setting_unweighted_distribution.csv"
  )
)

# ------------------------------------------------------------
# Save updated private analytical dataset
# ------------------------------------------------------------

saveRDS(
  analytic,
  here::here(
    "data",
    "interim",
    "analytic_with_delivery.rds"
  )
)

# ------------------------------------------------------------
# Review delivery quality checks
# ------------------------------------------------------------

print(
  delivery_quality_summary,
  n = Inf
)

print(
  delivery_setting_distribution,
  n = Inf
)

message(
  "Delivery care indicators derived and validated successfully."
)
# ============================================================
# MATERNAL POSTNATAL CARE
# ============================================================

# ------------------------------------------------------------
# Confirm required maternal PNC variables
# ------------------------------------------------------------

maternal_pnc_required_variables <- c(
  "m62",
  "m63",
  "m64",
  "m66",
  "m67",
  "m68"
)

missing_maternal_pnc_variables <- setdiff(
  maternal_pnc_required_variables,
  names(analytic)
)

if (length(missing_maternal_pnc_variables) > 0) {
  stop(
    paste0(
      "Required maternal PNC variables are missing: ",
      paste(
        missing_maternal_pnc_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Identify qualifying PNC providers
#
# DHS PNC tabulation uses provider codes 11-29 for an
# eligible postnatal check. This should not be interpreted
# as equivalent to the narrower skilled-birth definition.
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    mother_before_discharge_provider_eligible =
      dplyr::case_when(
        m62 == 1 &
          dplyr::between(
            as.numeric(m64),
            11,
            29
          ) ~ 1L,
        
        TRUE ~ 0L
      ),
    
    mother_after_discharge_provider_eligible =
      dplyr::case_when(
        m66 == 1 &
          dplyr::between(
            as.numeric(m68),
            11,
            29
          ) ~ 1L,
        
        TRUE ~ 0L
      )
  )

# ------------------------------------------------------------
# Derive PNC within two days
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    mother_before_discharge_pnc_2days =
      dplyr::case_when(
        
        mother_before_discharge_provider_eligible == 1 &
          within_two_days(m63) == 1 ~ 1L,
        
        TRUE ~ 0L
      ),
    
    mother_after_discharge_pnc_2days =
      dplyr::case_when(
        
        mother_after_discharge_provider_eligible == 1 &
          within_two_days(m67) == 1 ~ 1L,
        
        TRUE ~ 0L
      ),
    
    mother_pnc_2days =
      dplyr::case_when(
        
        mother_before_discharge_pnc_2days == 1 |
          mother_after_discharge_pnc_2days == 1 ~ 1L,
        
        TRUE ~ 0L
      )
  )

# ------------------------------------------------------------
# Identify route through which qualifying early PNC occurred
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    mother_pnc_route =
      dplyr::case_when(
        
        mother_before_discharge_pnc_2days == 1 &
          mother_after_discharge_pnc_2days == 1 ~
          "Before and after discharge",
        
        mother_before_discharge_pnc_2days == 1 ~
          "Before discharge",
        
        mother_after_discharge_pnc_2days == 1 ~
          "After discharge or home delivery",
        
        TRUE ~
          "No qualifying PNC within 2 days"
      )
  )

# ------------------------------------------------------------
# Construct first qualifying PNC timing field
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    mother_first_pnc_time_code =
      dplyr::case_when(
        
        mother_before_discharge_provider_eligible == 1 ~
          as.numeric(m63),
        
        mother_after_discharge_provider_eligible == 1 ~
          as.numeric(m67),
        
        TRUE ~
          NA_real_
      )
  )

# ------------------------------------------------------------
# Categorise timing of first qualifying PNC check
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    mother_first_pnc_timing =
      dplyr::case_when(
        
        mother_before_discharge_provider_eligible == 0 &
          mother_after_discharge_provider_eligible == 0 ~
          "No qualifying PNC check",
        
        dplyr::between(
          mother_first_pnc_time_code,
          100,
          103
        ) ~
          "Less than 4 hours",
        
        dplyr::between(
          mother_first_pnc_time_code,
          104,
          123
        ) |
          mother_first_pnc_time_code == 200 ~
          "4-23 hours",
        
        dplyr::between(
          mother_first_pnc_time_code,
          124,
          171
        ) |
          dplyr::between(
            mother_first_pnc_time_code,
            201,
            202
          ) ~
          "1-2 days",
        
        dplyr::between(
          mother_first_pnc_time_code,
          172,
          197
        ) |
          dplyr::between(
            mother_first_pnc_time_code,
            203,
            206
          ) ~
          "3-6 days",
        
        dplyr::between(
          mother_first_pnc_time_code,
          207,
          241
        ) |
          dplyr::between(
            mother_first_pnc_time_code,
            300,
            305
          ) ~
          "7-41 days",
        
        dplyr::between(
          mother_first_pnc_time_code,
          242,
          299
        ) |
          dplyr::between(
            mother_first_pnc_time_code,
            306,
            899
          ) ~
          "More than 41 days",
        
        mother_first_pnc_time_code %in%
          c(
            998,
            999
          ) ~
          "Don't know or missing timing",
        
        TRUE ~
          "Unclassified timing code"
      )
  )

# ------------------------------------------------------------
# Quality checks
# ------------------------------------------------------------

invalid_mother_pnc <- sum(
  !analytic$mother_pnc_2days %in%
    c(
      0L,
      1L
    ),
  na.rm = TRUE
)

before_without_eligible_provider <- sum(
  analytic$mother_before_discharge_pnc_2days == 1 &
    analytic$mother_before_discharge_provider_eligible != 1,
  na.rm = TRUE
)

after_without_eligible_provider <- sum(
  analytic$mother_after_discharge_pnc_2days == 1 &
    analytic$mother_after_discharge_provider_eligible != 1,
  na.rm = TRUE
)

combined_without_component <- sum(
  analytic$mother_pnc_2days == 1 &
    analytic$mother_before_discharge_pnc_2days == 0 &
    analytic$mother_after_discharge_pnc_2days == 0,
  na.rm = TRUE
)

unclassified_maternal_pnc_timing <- sum(
  analytic$mother_first_pnc_timing ==
    "Unclassified timing code",
  na.rm = TRUE
)

if (invalid_mother_pnc > 0) {
  stop(
    "Invalid maternal PNC indicator values were detected."
  )
}

if (before_without_eligible_provider > 0) {
  stop(
    "Maternal PNC before discharge was identified without an eligible provider."
  )
}

if (after_without_eligible_provider > 0) {
  stop(
    "Maternal PNC after discharge was identified without an eligible provider."
  )
}

if (combined_without_component > 0) {
  stop(
    "Combined maternal PNC indicator is inconsistent with its component indicators."
  )
}

# ------------------------------------------------------------
# Create maternal PNC quality summary
# ------------------------------------------------------------

maternal_pnc_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Analytical cohort size",
    "Maternal PNC indicator non-missing",
    "PNC before discharge within 2 days",
    "PNC after discharge/home delivery within 2 days",
    "Maternal PNC within 2 days",
    "Invalid maternal PNC values",
    "Before-discharge PNC without eligible provider",
    "After-discharge PNC without eligible provider",
    "Combined PNC without component PNC",
    "Unclassified maternal PNC timing codes"
  ),
  
  result = c(
    nrow(analytic),
    
    sum(
      !is.na(
        analytic$mother_pnc_2days
      )
    ),
    
    sum(
      analytic$mother_before_discharge_pnc_2days == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$mother_after_discharge_pnc_2days == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$mother_pnc_2days == 1,
      na.rm = TRUE
    ),
    
    invalid_mother_pnc,
    
    before_without_eligible_provider,
    
    after_without_eligible_provider,
    
    combined_without_component,
    
    unclassified_maternal_pnc_timing
  )
)

# ------------------------------------------------------------
# Create maternal PNC distributions
# ------------------------------------------------------------

maternal_pnc_distribution <- analytic |>
  dplyr::count(
    mother_pnc_2days,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  )

maternal_pnc_timing_distribution <- analytic |>
  dplyr::count(
    mother_first_pnc_timing,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  )

maternal_pnc_route_distribution <- analytic |>
  dplyr::count(
    mother_pnc_route,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  )

# ------------------------------------------------------------
# Save maternal PNC QA outputs
# ------------------------------------------------------------

readr::write_csv(
  maternal_pnc_quality_summary,
  here::here(
    "outputs",
    "tables",
    "maternal_pnc_quality_summary.csv"
  )
)

readr::write_csv(
  maternal_pnc_distribution,
  here::here(
    "outputs",
    "tables",
    "maternal_pnc_unweighted_distribution.csv"
  )
)

readr::write_csv(
  maternal_pnc_timing_distribution,
  here::here(
    "outputs",
    "tables",
    "maternal_pnc_timing_distribution.csv"
  )
)

readr::write_csv(
  maternal_pnc_route_distribution,
  here::here(
    "outputs",
    "tables",
    "maternal_pnc_route_distribution.csv"
  )
)

# ------------------------------------------------------------
# Save updated private analytical dataset
# ------------------------------------------------------------

saveRDS(
  analytic,
  here::here(
    "data",
    "interim",
    "analytic_with_maternal_pnc.rds"
  )
)

# ------------------------------------------------------------
# Review maternal PNC checks
# ------------------------------------------------------------

print(
  maternal_pnc_quality_summary,
  n = Inf
)

print(
  maternal_pnc_timing_distribution,
  n = Inf
)

message(
  "Maternal postnatal care indicators derived and validated successfully."
)

# ============================================================
# NEWBORN POSTNATAL CARE
# ============================================================

# ------------------------------------------------------------
# Confirm required newborn PNC variables
# ------------------------------------------------------------

newborn_pnc_required_variables <- c(
  "m70",
  "m71",
  "m72",
  "m74",
  "m75",
  "m76"
)

missing_newborn_pnc_variables <- setdiff(
  newborn_pnc_required_variables,
  names(analytic)
)

if (length(missing_newborn_pnc_variables) > 0) {
  stop(
    paste0(
      "Required newborn PNC variables are missing: ",
      paste(
        missing_newborn_pnc_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Identify reported newborn health checks
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_before_discharge_check =
      dplyr::if_else(
        m74 == 1,
        1L,
        0L,
        missing = 0L
      ),
    
    newborn_after_discharge_check =
      dplyr::if_else(
        m70 == 1,
        1L,
        0L,
        missing = 0L
      ),
    
    newborn_any_reported_check =
      dplyr::if_else(
        newborn_before_discharge_check == 1 |
          newborn_after_discharge_check == 1,
        1L,
        0L
      )
  )

# ------------------------------------------------------------
# Identify eligible provider categories
#
# DHS PNC timing algorithms use provider codes 11-29
# when identifying a qualifying health check.
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_before_discharge_provider_eligible =
      dplyr::if_else(
        newborn_before_discharge_check == 1 &
          dplyr::between(
            as.numeric(m76),
            11,
            29
          ),
        1L,
        0L
      ),
    
    newborn_after_discharge_provider_eligible =
      dplyr::if_else(
        newborn_after_discharge_check == 1 &
          dplyr::between(
            as.numeric(m72),
            11,
            29
          ),
        1L,
        0L
      )
  )

# ------------------------------------------------------------
# Derive component checks occurring within two days
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_before_discharge_pnc_2days =
      dplyr::if_else(
        newborn_before_discharge_provider_eligible == 1 &
          within_two_days(m75) == 1,
        1L,
        0L
      ),
    
    newborn_after_discharge_pnc_2days =
      dplyr::if_else(
        newborn_after_discharge_provider_eligible == 1 &
          within_two_days(m71) == 1,
        1L,
        0L
      )
  )

# ------------------------------------------------------------
# Reproduce DHS newborn PNC timing logic
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_pnc_time_code =
      dplyr::case_when(
        
        newborn_any_reported_check == 0 ~
          0,
        
        dplyr::between(
          as.numeric(m76),
          11,
          29
        ) ~
          as.numeric(m75),
        
        newborn_any_reported_check == 1 ~
          999,
        
        TRUE ~
          0
      )
  )

# A reported pre-discharge check by a non-eligible provider
# does not qualify as PNC for this indicator.

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_pnc_time_code =
      dplyr::case_when(
        
        newborn_pnc_time_code < 1000 &
          as.numeric(m76) > 30 &
          as.numeric(m76) < 100 ~
          0,
        
        TRUE ~
          newborn_pnc_time_code
      )
  )

# If no eligible pre-discharge PNC was identified, evaluate
# an eligible check after discharge or after a home delivery.

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_pnc_time_code =
      dplyr::case_when(
        
        newborn_pnc_time_code == 999 &
          dplyr::between(
            as.numeric(m72),
            11,
            29
          ) ~
          as.numeric(m71),
        
        TRUE ~
          newborn_pnc_time_code
      )
  )

# A post-discharge check by a non-eligible provider is
# classified as no qualifying PNC for the indicator.

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_pnc_time_code =
      dplyr::case_when(
        
        as.numeric(m71) < 1000 &
          as.numeric(m72) > 30 &
          as.numeric(m72) < 100 ~
          0,
        
        TRUE ~
          newborn_pnc_time_code
      )
  )

# ------------------------------------------------------------
# Categorise newborn PNC timing
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_pnc_timing_code =
      dplyr::case_when(
        
        newborn_pnc_time_code == 0 |
          dplyr::between(
            newborn_pnc_time_code,
            207,
            297
          ) |
          dplyr::between(
            newborn_pnc_time_code,
            301,
            396
          ) ~
          0L,
        
        newborn_pnc_time_code == 100 ~
          1L,
        
        newborn_pnc_time_code %in%
          c(
            101,
            102,
            103
          ) ~
          2L,
        
        dplyr::between(
          newborn_pnc_time_code,
          104,
          123
        ) |
          newborn_pnc_time_code == 200 ~
          3L,
        
        dplyr::between(
          newborn_pnc_time_code,
          124,
          171
        ) |
          newborn_pnc_time_code %in%
          c(
            201,
            202
          ) ~
          4L,
        
        dplyr::between(
          newborn_pnc_time_code,
          172,
          197
        ) |
          newborn_pnc_time_code %in%
          c(
            203,
            204,
            205,
            206
          ) ~
          5L,
        
        newborn_pnc_time_code %in%
          c(
            198,
            199,
            298,
            299,
            398,
            399,
            998,
            999
          ) ~
          9L,
        
        TRUE ~
          NA_integer_
      ),
    
    newborn_pnc_timing =
      dplyr::case_when(
        
        newborn_pnc_timing_code == 0 ~
          "No check or 7+ days",
        
        newborn_pnc_timing_code == 1 ~
          "Less than 1 hour",
        
        newborn_pnc_timing_code == 2 ~
          "1-3 hours",
        
        newborn_pnc_timing_code == 3 ~
          "4-23 hours",
        
        newborn_pnc_timing_code == 4 ~
          "1-2 days",
        
        newborn_pnc_timing_code == 5 ~
          "3-6 days",
        
        newborn_pnc_timing_code == 9 ~
          "Don't know or missing timing",
        
        TRUE ~
          "Unclassified"
      )
  )

# ------------------------------------------------------------
# Derive primary newborn PNC indicator
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_pnc_2days =
      dplyr::case_when(
        
        newborn_pnc_timing_code %in%
          c(
            1L,
            2L,
            3L,
            4L
          ) ~
          1L,
        
        newborn_pnc_timing_code %in%
          c(
            0L,
            5L,
            9L
          ) ~
          0L,
        
        TRUE ~
          NA_integer_
      )
  )

# ------------------------------------------------------------
# Describe route of early newborn PNC
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    newborn_pnc_route =
      dplyr::case_when(
        
        newborn_before_discharge_pnc_2days == 1 &
          newborn_after_discharge_pnc_2days == 1 ~
          "Before and after discharge",
        
        newborn_before_discharge_pnc_2days == 1 ~
          "Before discharge",
        
        newborn_after_discharge_pnc_2days == 1 ~
          "After discharge or home delivery",
        
        newborn_pnc_2days == 0 ~
          "No qualifying PNC within 2 days",
        
        TRUE ~
          "Unclassified"
      )
  )

# ------------------------------------------------------------
# Validate newborn PNC indicators
# ------------------------------------------------------------

invalid_newborn_pnc <- sum(
  !is.na(analytic$newborn_pnc_2days) &
    !analytic$newborn_pnc_2days %in%
    c(
      0L,
      1L
    )
)

unclassified_newborn_timing <- sum(
  is.na(
    analytic$newborn_pnc_timing_code
  )
)

combined_without_component <- sum(
  analytic$newborn_pnc_2days == 1 &
    analytic$newborn_before_discharge_pnc_2days == 0 &
    analytic$newborn_after_discharge_pnc_2days == 0,
  na.rm = TRUE
)

if (invalid_newborn_pnc > 0) {
  stop(
    "Invalid newborn PNC indicator values were detected."
  )
}

if (unclassified_newborn_timing > 0) {
  stop(
    paste0(
      "Unclassified newborn PNC timing codes detected: ",
      unclassified_newborn_timing
    )
  )
}

if (combined_without_component > 0) {
  stop(
    "Newborn PNC within two days was identified without a qualifying component check."
  )
}

# ------------------------------------------------------------
# Create quality-assurance summary
# ------------------------------------------------------------

newborn_pnc_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Analytical cohort size",
    "Newborn PNC indicator non-missing",
    "Reported check before discharge",
    "Reported check after discharge/home delivery",
    "Qualifying PNC before discharge within 2 days",
    "Qualifying PNC after discharge/home delivery within 2 days",
    "Newborn PNC within 2 days",
    "Invalid newborn PNC values",
    "Unclassified newborn timing codes",
    "Combined PNC without qualifying component"
  ),
  
  result = c(
    nrow(analytic),
    
    sum(
      !is.na(
        analytic$newborn_pnc_2days
      )
    ),
    
    sum(
      analytic$newborn_before_discharge_check == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$newborn_after_discharge_check == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$newborn_before_discharge_pnc_2days == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$newborn_after_discharge_pnc_2days == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$newborn_pnc_2days == 1,
      na.rm = TRUE
    ),
    
    invalid_newborn_pnc,
    
    unclassified_newborn_timing,
    
    combined_without_component
  )
)

# ------------------------------------------------------------
# Create output distributions
# ------------------------------------------------------------

newborn_pnc_distribution <- analytic |>
  dplyr::count(
    newborn_pnc_2days,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  )

newborn_pnc_timing_distribution <- analytic |>
  dplyr::count(
    newborn_pnc_timing,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  )

newborn_pnc_route_distribution <- analytic |>
  dplyr::count(
    newborn_pnc_route,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  )

# ------------------------------------------------------------
# Save QA outputs
# ------------------------------------------------------------

readr::write_csv(
  newborn_pnc_quality_summary,
  here::here(
    "outputs",
    "tables",
    "newborn_pnc_quality_summary.csv"
  )
)

readr::write_csv(
  newborn_pnc_distribution,
  here::here(
    "outputs",
    "tables",
    "newborn_pnc_unweighted_distribution.csv"
  )
)

readr::write_csv(
  newborn_pnc_timing_distribution,
  here::here(
    "outputs",
    "tables",
    "newborn_pnc_timing_distribution.csv"
  )
)

readr::write_csv(
  newborn_pnc_route_distribution,
  here::here(
    "outputs",
    "tables",
    "newborn_pnc_route_distribution.csv"
  )
)

# ------------------------------------------------------------
# Save updated private analytical dataset
# ------------------------------------------------------------

saveRDS(
  analytic,
  here::here(
    "data",
    "interim",
    "analytic_with_newborn_pnc.rds"
  )
)

# ------------------------------------------------------------
# Review newborn PNC checks
# ------------------------------------------------------------

print(
  newborn_pnc_quality_summary,
  n = Inf
)

print(
  newborn_pnc_timing_distribution,
  n = Inf
)

print(
  newborn_pnc_route_distribution,
  n = Inf
)

message(
  "Newborn postnatal care indicators derived and validated successfully."
)

# ============================================================
# PAIRED MOTHER-NEWBORN POSTNATAL CARE
# ============================================================

# ------------------------------------------------------------
# Confirm component indicators
# ------------------------------------------------------------

paired_pnc_required_variables <- c(
  "mother_pnc_2days",
  "newborn_pnc_2days"
)

missing_paired_pnc_variables <- setdiff(
  paired_pnc_required_variables,
  names(analytic)
)

if (length(missing_paired_pnc_variables) > 0) {
  stop(
    paste0(
      "Required paired PNC variables are missing: ",
      paste(
        missing_paired_pnc_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Validate component indicators before pairing
# ------------------------------------------------------------

invalid_mother_component <- sum(
  !is.na(analytic$mother_pnc_2days) &
    !analytic$mother_pnc_2days %in% c(0L, 1L)
)

invalid_newborn_component <- sum(
  !is.na(analytic$newborn_pnc_2days) &
    !analytic$newborn_pnc_2days %in% c(0L, 1L)
)

if (invalid_mother_component > 0) {
  stop(
    "Invalid maternal PNC component values were detected."
  )
}

if (invalid_newborn_component > 0) {
  stop(
    "Invalid newborn PNC component values were detected."
  )
}

# ------------------------------------------------------------
# Derive paired PNC status
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    paired_pnc_status =
      dplyr::case_when(
        
        mother_pnc_2days == 1 &
          newborn_pnc_2days == 1 ~
          "Both mother and newborn",
        
        mother_pnc_2days == 1 &
          newborn_pnc_2days == 0 ~
          "Mother only",
        
        mother_pnc_2days == 0 &
          newborn_pnc_2days == 1 ~
          "Newborn only",
        
        mother_pnc_2days == 0 &
          newborn_pnc_2days == 0 ~
          "Neither",
        
        TRUE ~
          "Missing or indeterminate"
      )
  )

# ------------------------------------------------------------
# Derive binary paired PNC indicator
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    paired_pnc_2days =
      dplyr::case_when(
        
        mother_pnc_2days == 1 &
          newborn_pnc_2days == 1 ~
          1L,
        
        mother_pnc_2days %in% c(0L, 1L) &
          newborn_pnc_2days %in% c(0L, 1L) ~
          0L,
        
        TRUE ~
          NA_integer_
      )
  )

# ------------------------------------------------------------
# Derive postnatal-care gap indicators
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    mother_pnc_gap =
      dplyr::case_when(
        mother_pnc_2days == 0 ~ 1L,
        mother_pnc_2days == 1 ~ 0L,
        TRUE ~ NA_integer_
      ),
    
    newborn_pnc_gap =
      dplyr::case_when(
        newborn_pnc_2days == 0 ~ 1L,
        newborn_pnc_2days == 1 ~ 0L,
        TRUE ~ NA_integer_
      ),
    
    either_member_pnc_gap =
      dplyr::case_when(
        mother_pnc_2days == 0 |
          newborn_pnc_2days == 0 ~
          1L,
        
        mother_pnc_2days == 1 &
          newborn_pnc_2days == 1 ~
          0L,
        
        TRUE ~
          NA_integer_
      )
  )

# ------------------------------------------------------------
# Validate paired indicators
# ------------------------------------------------------------

invalid_paired_pnc <- sum(
  !is.na(analytic$paired_pnc_2days) &
    !analytic$paired_pnc_2days %in%
    c(
      0L,
      1L
    )
)

missing_paired_status <- sum(
  analytic$paired_pnc_status ==
    "Missing or indeterminate",
  na.rm = TRUE
)

both_status_mismatch <- sum(
  analytic$paired_pnc_status ==
    "Both mother and newborn" &
    analytic$paired_pnc_2days != 1,
  na.rm = TRUE
)

paired_binary_mismatch <- sum(
  analytic$paired_pnc_2days == 1 &
    (
      analytic$mother_pnc_2days != 1 |
        analytic$newborn_pnc_2days != 1
    ),
  na.rm = TRUE
)

if (invalid_paired_pnc > 0) {
  stop(
    "Invalid paired PNC indicator values were detected."
  )
}

if (both_status_mismatch > 0) {
  stop(
    "Paired PNC status is inconsistent with the binary paired indicator."
  )
}

if (paired_binary_mismatch > 0) {
  stop(
    "Paired PNC binary indicator is inconsistent with maternal or newborn PNC."
  )
}

# ------------------------------------------------------------
# Create paired PNC quality summary
# ------------------------------------------------------------

paired_pnc_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Analytical cohort size",
    "Paired PNC indicator non-missing",
    "Paired PNC within 2 days",
    "Mother PNC within 2 days",
    "Newborn PNC within 2 days",
    "Invalid paired PNC values",
    "Missing or indeterminate paired status",
    "Both-status mismatch",
    "Paired binary-component mismatch"
  ),
  
  result = c(
    nrow(analytic),
    
    sum(
      !is.na(
        analytic$paired_pnc_2days
      )
    ),
    
    sum(
      analytic$paired_pnc_2days == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$mother_pnc_2days == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$newborn_pnc_2days == 1,
      na.rm = TRUE
    ),
    
    invalid_paired_pnc,
    
    missing_paired_status,
    
    both_status_mismatch,
    
    paired_binary_mismatch
  )
)

# ------------------------------------------------------------
# Create paired-care distribution
# ------------------------------------------------------------

paired_pnc_distribution <- analytic |>
  dplyr::count(
    paired_pnc_status,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  ) |>
  dplyr::arrange(
    dplyr::desc(
      unweighted_n
    )
  )

# ------------------------------------------------------------
# Create binary paired-care distribution
# ------------------------------------------------------------

paired_pnc_binary_distribution <- analytic |>
  dplyr::count(
    paired_pnc_2days,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  )

# ------------------------------------------------------------
# Create mother-newborn PNC cross-tabulation
# ------------------------------------------------------------

mother_newborn_pnc_crosstab <- analytic |>
  dplyr::count(
    mother_pnc_2days,
    newborn_pnc_2days,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  )

# ------------------------------------------------------------
# Save paired PNC outputs
# ------------------------------------------------------------

readr::write_csv(
  paired_pnc_quality_summary,
  here::here(
    "outputs",
    "tables",
    "paired_pnc_quality_summary.csv"
  )
)

readr::write_csv(
  paired_pnc_distribution,
  here::here(
    "outputs",
    "tables",
    "paired_pnc_unweighted_distribution.csv"
  )
)

readr::write_csv(
  paired_pnc_binary_distribution,
  here::here(
    "outputs",
    "tables",
    "paired_pnc_binary_distribution.csv"
  )
)

readr::write_csv(
  mother_newborn_pnc_crosstab,
  here::here(
    "outputs",
    "tables",
    "mother_newborn_pnc_crosstab.csv"
  )
)

# ------------------------------------------------------------
# Save updated private analytical dataset
# ------------------------------------------------------------

saveRDS(
  analytic,
  here::here(
    "data",
    "interim",
    "analytic_with_paired_pnc.rds"
  )
)

# ------------------------------------------------------------
# Review paired PNC results
# ------------------------------------------------------------

print(
  paired_pnc_quality_summary,
  n = Inf
)

print(
  paired_pnc_distribution,
  n = Inf
)

print(
  mother_newborn_pnc_crosstab,
  n = Inf
)

message(
  "Paired mother-newborn postnatal care indicators derived and validated successfully."
)

# ============================================================
# MATERNAL CONTINUUM-OF-CARE PATHWAY
# ============================================================

# ------------------------------------------------------------
# Confirm required continuum indicators
# ------------------------------------------------------------

continuum_required_variables <- c(
  "anc_4plus",
  "anc_8plus",
  "skilled_birth",
  "facility_delivery",
  "mother_pnc_2days",
  "newborn_pnc_2days",
  "paired_pnc_2days"
)

missing_continuum_variables <- setdiff(
  continuum_required_variables,
  names(analytic)
)

if (length(missing_continuum_variables) > 0) {
  stop(
    paste0(
      "Required continuum indicators are missing: ",
      paste(
        missing_continuum_variables,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Define primary continuum
#
# Primary pathway:
# ANC 4+ -> skilled birth attendance ->
# paired mother-newborn PNC within 2 days
#
# ANC 8+ is retained as a secondary, more intensive
# antenatal-care specification.
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    continuum_anc4_skilledbirth =
      dplyr::case_when(
        
        anc_4plus == 1 &
          skilled_birth == 1 ~ 1L,
        
        anc_4plus %in% c(0L, 1L) &
          skilled_birth %in% c(0L, 1L) ~ 0L,
        
        TRUE ~ NA_integer_
      ),
    
    complete_continuum =
      dplyr::case_when(
        
        anc_4plus == 1 &
          skilled_birth == 1 &
          paired_pnc_2days == 1 ~ 1L,
        
        anc_4plus %in% c(0L, 1L) &
          skilled_birth %in% c(0L, 1L) &
          paired_pnc_2days %in% c(0L, 1L) ~ 0L,
        
        TRUE ~ NA_integer_
      )
  )

# ------------------------------------------------------------
# Create ANC 8+ sensitivity definition
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    complete_continuum_anc8 =
      dplyr::case_when(
        
        anc_8plus == 1 &
          skilled_birth == 1 &
          paired_pnc_2days == 1 ~ 1L,
        
        anc_8plus %in% c(0L, 1L) &
          skilled_birth %in% c(0L, 1L) &
          paired_pnc_2days %in% c(0L, 1L) ~ 0L,
        
        TRUE ~ NA_integer_
      )
  )

# ------------------------------------------------------------
# Create facility-based alternative definition
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    complete_continuum_facility =
      dplyr::case_when(
        
        anc_4plus == 1 &
          facility_delivery == 1 &
          paired_pnc_2days == 1 ~ 1L,
        
        anc_4plus %in% c(0L, 1L) &
          facility_delivery %in% c(0L, 1L) &
          paired_pnc_2days %in% c(0L, 1L) ~ 0L,
        
        TRUE ~ NA_integer_
      )
  )

# ------------------------------------------------------------
# Construct sequential continuum stage
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    continuum_stage =
      dplyr::case_when(
        
        is.na(anc_4plus) |
          is.na(skilled_birth) |
          is.na(paired_pnc_2days) ~
          "Missing or indeterminate",
        
        anc_4plus != 1 ~
          "Did not reach ANC 4+",
        
        anc_4plus == 1 &
          skilled_birth != 1 ~
          "ANC 4+ only",
        
        anc_4plus == 1 &
          skilled_birth == 1 &
          paired_pnc_2days != 1 ~
          "ANC 4+ and skilled birth only",
        
        anc_4plus == 1 &
          skilled_birth == 1 &
          paired_pnc_2days == 1 ~
          "Complete continuum",
        
        TRUE ~
          "Unclassified"
      )
  )

# ------------------------------------------------------------
# Construct continuum score
#
# 0 = none of the three primary continuum components
# 1 = one component
# 2 = two components
# 3 = all three components
# ------------------------------------------------------------

continuum_component_matrix <- analytic |>
  dplyr::select(
    anc_4plus,
    skilled_birth,
    paired_pnc_2days
  )

continuum_complete_cases <- stats::complete.cases(
  continuum_component_matrix
)

continuum_score_raw <- rowSums(
  continuum_component_matrix,
  na.rm = TRUE
)

analytic$continuum_score <- dplyr::if_else(
  continuum_complete_cases,
  as.integer(continuum_score_raw),
  NA_integer_
)

# ------------------------------------------------------------
# Create descriptive score labels
# ------------------------------------------------------------

analytic <- analytic |>
  dplyr::mutate(
    
    continuum_score_label =
      dplyr::case_when(
        
        continuum_score == 0 ~
          "0 of 3 components",
        
        continuum_score == 1 ~
          "1 of 3 components",
        
        continuum_score == 2 ~
          "2 of 3 components",
        
        continuum_score == 3 ~
          "3 of 3 components",
        
        TRUE ~
          "Missing"
      )
  )

# ------------------------------------------------------------
# Construct sequential flow counts
# ------------------------------------------------------------

continuum_flow <- tibble::tibble(
  
  stage = c(
    "Eligible recent live births",
    "Received ANC 4+",
    "ANC 4+ and skilled birth attendance",
    "ANC 4+, skilled birth and paired PNC within 2 days"
  ),
  
  unweighted_n = c(
    
    nrow(analytic),
    
    sum(
      analytic$anc_4plus == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$anc_4plus == 1 &
        analytic$skilled_birth == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$complete_continuum == 1,
      na.rm = TRUE
    )
  )
)

continuum_flow <- continuum_flow |>
  dplyr::mutate(
    
    percent_of_cohort =
      unweighted_n /
      dplyr::first(unweighted_n) *
      100,
    
    retained_from_previous_stage =
      dplyr::case_when(
        
        dplyr::row_number() == 1 ~
          100,
        
        TRUE ~
          unweighted_n /
          dplyr::lag(unweighted_n) *
          100
      ),
    
    drop_from_previous_stage =
      100 -
      retained_from_previous_stage
  )

# ------------------------------------------------------------
# Create pathway distribution
# ------------------------------------------------------------

continuum_pathway_distribution <- analytic |>
  dplyr::count(
    continuum_stage,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  ) |>
  dplyr::arrange(
    dplyr::desc(unweighted_n)
  )

# ------------------------------------------------------------
# Create continuum-score distribution
# ------------------------------------------------------------

continuum_score_distribution <- analytic |>
  dplyr::count(
    continuum_score,
    continuum_score_label,
    name = "unweighted_n"
  ) |>
  dplyr::mutate(
    
    percent =
      unweighted_n /
      sum(unweighted_n) *
      100
  ) |>
  dplyr::arrange(
    continuum_score
  )

# ------------------------------------------------------------
# Validate continuum indicators
# ------------------------------------------------------------

invalid_complete_continuum <- sum(
  !is.na(analytic$complete_continuum) &
    !analytic$complete_continuum %in%
    c(0L, 1L)
)

invalid_continuum_score <- sum(
  !is.na(analytic$continuum_score) &
    (
      analytic$continuum_score < 0 |
        analytic$continuum_score > 3
    )
)

complete_continuum_mismatch <- sum(
  analytic$complete_continuum == 1 &
    (
      analytic$anc_4plus != 1 |
        analytic$skilled_birth != 1 |
        analytic$paired_pnc_2days != 1
    ),
  na.rm = TRUE
)

score_three_mismatch <- sum(
  analytic$continuum_score == 3 &
    analytic$complete_continuum != 1,
  na.rm = TRUE
)

unclassified_continuum_stage <- sum(
  analytic$continuum_stage ==
    "Unclassified",
  na.rm = TRUE
)

if (invalid_complete_continuum > 0) {
  stop(
    "Invalid complete-continuum indicator values were detected."
  )
}

if (invalid_continuum_score > 0) {
  stop(
    "Continuum scores outside the expected 0-3 range were detected."
  )
}

if (complete_continuum_mismatch > 0) {
  stop(
    "Complete-continuum indicator is inconsistent with its component indicators."
  )
}

if (score_three_mismatch > 0) {
  stop(
    "Continuum score of 3 is inconsistent with the complete-continuum indicator."
  )
}

if (unclassified_continuum_stage > 0) {
  stop(
    "Unclassified continuum stages were detected."
  )
}

# ------------------------------------------------------------
# Create continuum quality-assurance summary
# ------------------------------------------------------------

continuum_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Analytical cohort size",
    "Complete continuum non-missing",
    "Complete ANC4-skilled birth-paired PNC continuum",
    "Complete ANC8-skilled birth-paired PNC continuum",
    "Complete ANC4-facility delivery-paired PNC continuum",
    "Invalid complete-continuum values",
    "Invalid continuum scores",
    "Complete-continuum component mismatches",
    "Continuum score-three mismatches",
    "Unclassified continuum stages"
  ),
  
  result = c(
    
    nrow(analytic),
    
    sum(
      !is.na(
        analytic$complete_continuum
      )
    ),
    
    sum(
      analytic$complete_continuum == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$complete_continuum_anc8 == 1,
      na.rm = TRUE
    ),
    
    sum(
      analytic$complete_continuum_facility == 1,
      na.rm = TRUE
    ),
    
    invalid_complete_continuum,
    
    invalid_continuum_score,
    
    complete_continuum_mismatch,
    
    score_three_mismatch,
    
    unclassified_continuum_stage
  )
)

# ------------------------------------------------------------
# Save continuum outputs
# ------------------------------------------------------------

readr::write_csv(
  continuum_flow,
  here::here(
    "outputs",
    "tables",
    "continuum_flow_unweighted.csv"
  )
)

readr::write_csv(
  continuum_pathway_distribution,
  here::here(
    "outputs",
    "tables",
    "continuum_pathway_distribution.csv"
  )
)

readr::write_csv(
  continuum_score_distribution,
  here::here(
    "outputs",
    "tables",
    "continuum_score_distribution.csv"
  )
)

readr::write_csv(
  continuum_quality_summary,
  here::here(
    "outputs",
    "tables",
    "continuum_quality_summary.csv"
  )
)

# ------------------------------------------------------------
# Save complete derived analytical dataset
# ------------------------------------------------------------

saveRDS(
  analytic,
  here::here(
    "data",
    "processed",
    "maternal_continuum_analytic.rds"
  )
)

# ------------------------------------------------------------
# Review continuum results
# ------------------------------------------------------------

print(
  continuum_quality_summary,
  n = Inf
)

print(
  continuum_flow,
  n = Inf
)

print(
  continuum_pathway_distribution,
  n = Inf
)

print(
  continuum_score_distribution,
  n = Inf
)

message(
  "Maternal continuum-of-care pathway derived and validated successfully."
)