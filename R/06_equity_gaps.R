# ============================================================
# EQUITY GAP AND DISPARITY ANALYSIS
# 2024 NIGERIA DEMOGRAPHIC AND HEALTH SURVEY
# ============================================================

source(
  here::here(
    "R",
    "01_setup.R"
  )
)

# ------------------------------------------------------------
# Load survey-weighted equity estimates
# ------------------------------------------------------------

equity_file <- here::here(
  "outputs",
  "tables",
  "weighted_equity_estimates_public.csv"
)

if (!file.exists(equity_file)) {
  stop(
    paste0(
      "Weighted equity estimates not found at:\n",
      equity_file,
      "\nRun R/05_equity_analysis.R first."
    )
  )
}

equity <- readr::read_csv(
  equity_file,
  show_col_types = FALSE
)

message(
  "Weighted equity estimates loaded: ",
  format(
    nrow(equity),
    big.mark = ","
  ),
  " subgroup-indicator estimates."
)

# ------------------------------------------------------------
# Confirm required fields
# ------------------------------------------------------------

required_fields <- c(
  "equity_variable",
  "equity_dimension",
  "equity_category",
  "indicator_variable",
  "indicator",
  "unweighted_n",
  "public_weighted_percent",
  "public_ci_low",
  "public_ci_high",
  "reporting_status"
)

missing_fields <- setdiff(
  required_fields,
  names(equity)
)

if (length(missing_fields) > 0) {
  stop(
    paste0(
      "Required fields are missing: ",
      paste(
        missing_fields,
        collapse = ", "
      )
    )
  )
}

# ------------------------------------------------------------
# Keep estimates eligible for comparison
#
# Suppressed estimates are excluded from gap calculations.
# Caution estimates remain available but are flagged.
# ------------------------------------------------------------

equity_comparable <- equity |>
  dplyr::filter(
    reporting_status != "Suppress",
    !is.na(public_weighted_percent)
  )

if (nrow(equity_comparable) == 0) {
  stop(
    "No reportable equity estimates are available for comparison."
  )
}

# ------------------------------------------------------------
# Rank subgroups within each indicator and equity dimension
# ------------------------------------------------------------

equity_subgroup_ranking <- equity_comparable |>
  dplyr::group_by(
    equity_variable,
    equity_dimension,
    indicator_variable,
    indicator
  ) |>
  dplyr::mutate(
    
    highest_percent =
      max(
        public_weighted_percent,
        na.rm = TRUE
      ),
    
    lowest_percent =
      min(
        public_weighted_percent,
        na.rm = TRUE
      ),
    
    rank_high_to_low =
      dplyr::min_rank(
        dplyr::desc(
          public_weighted_percent
        )
      ),
    
    gap_to_best_pp =
      highest_percent -
      public_weighted_percent,
    
    gap_above_lowest_pp =
      public_weighted_percent -
      lowest_percent
  ) |>
  dplyr::ungroup()

# ------------------------------------------------------------
# Identify highest- and lowest-performing groups
# ------------------------------------------------------------

highest_groups <- equity_subgroup_ranking |>
  dplyr::group_by(
    equity_variable,
    equity_dimension,
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
    
    equity_variable,
    equity_dimension,
    indicator_variable,
    indicator,
    
    highest_group =
      equity_category,
    
    highest_percent =
      public_weighted_percent,
    
    highest_ci_low =
      public_ci_low,
    
    highest_ci_high =
      public_ci_high,
    
    highest_group_n =
      unweighted_n,
    
    highest_reporting_status =
      reporting_status
  )

lowest_groups <- equity_subgroup_ranking |>
  dplyr::group_by(
    equity_variable,
    equity_dimension,
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
    
    equity_variable,
    equity_dimension,
    indicator_variable,
    indicator,
    
    lowest_group =
      equity_category,
    
    lowest_percent =
      public_weighted_percent,
    
    lowest_ci_low =
      public_ci_low,
    
    lowest_ci_high =
      public_ci_high,
    
    lowest_group_n =
      unweighted_n,
    
    lowest_reporting_status =
      reporting_status
  )

# ------------------------------------------------------------
# Count usable groups within each comparison
# ------------------------------------------------------------

group_counts <- equity_subgroup_ranking |>
  dplyr::group_by(
    equity_variable,
    equity_dimension,
    indicator_variable,
    indicator
  ) |>
  dplyr::summarise(
    
    groups_compared =
      dplyr::n(),
    
    caution_groups =
      sum(
        reporting_status == "Caution"
      ),
    
    .groups = "drop"
  )

# ------------------------------------------------------------
# Build absolute and relative equity-gap summary
# ------------------------------------------------------------

equity_gap_summary <- highest_groups |>
  dplyr::left_join(
    lowest_groups,
    by = c(
      "equity_variable",
      "equity_dimension",
      "indicator_variable",
      "indicator"
    )
  ) |>
  dplyr::left_join(
    group_counts,
    by = c(
      "equity_variable",
      "equity_dimension",
      "indicator_variable",
      "indicator"
    )
  ) |>
  dplyr::mutate(
    
    absolute_gap_pp =
      highest_percent -
      lowest_percent,
    
    relative_ratio =
      dplyr::if_else(
        lowest_percent > 0,
        highest_percent /
          lowest_percent,
        NA_real_
      ),
    
    relative_shortfall_percent =
      dplyr::if_else(
        highest_percent > 0,
        (
          highest_percent -
            lowest_percent
        ) /
          highest_percent *
          100,
        NA_real_
      ),
    
    comparison_status =
      dplyr::case_when(
        
        groups_compared < 2 ~
          "Insufficient groups",
        
        highest_reporting_status ==
          "Caution" |
          lowest_reporting_status ==
          "Caution" ~
          "Caution",
        
        TRUE ~
          "Report"
      )
  )

# ------------------------------------------------------------
# Round analytical measures
# ------------------------------------------------------------

equity_gap_summary <- equity_gap_summary |>
  dplyr::mutate(
    
    dplyr::across(
      c(
        highest_percent,
        highest_ci_low,
        highest_ci_high,
        lowest_percent,
        lowest_ci_low,
        lowest_ci_high,
        absolute_gap_pp,
        relative_ratio,
        relative_shortfall_percent
      ),
      ~ round(
        .x,
        2
      )
    )
  )

equity_subgroup_ranking <- equity_subgroup_ranking |>
  dplyr::mutate(
    
    gap_to_best_pp =
      round(
        gap_to_best_pp,
        2
      ),
    
    gap_above_lowest_pp =
      round(
        gap_above_lowest_pp,
        2
      )
  )

# ------------------------------------------------------------
# Rank inequality dimensions by absolute gap
# ------------------------------------------------------------

equity_gap_ranking <- equity_gap_summary |>
  dplyr::filter(
    comparison_status !=
      "Insufficient groups"
  ) |>
  dplyr::group_by(
    indicator_variable,
    indicator
  ) |>
  dplyr::mutate(
    
    disparity_rank =
      dplyr::min_rank(
        dplyr::desc(
          absolute_gap_pp
        )
      )
  ) |>
  dplyr::ungroup() |>
  dplyr::arrange(
    indicator,
    disparity_rank
  )

# ------------------------------------------------------------
# Create focused complete-continuum disparity table
# ------------------------------------------------------------

complete_continuum_gaps <- equity_gap_ranking |>
  dplyr::filter(
    indicator_variable ==
      "complete_continuum"
  ) |>
  dplyr::arrange(
    dplyr::desc(
      absolute_gap_pp
    )
  )

# ------------------------------------------------------------
# Create lowest-performing groups table
# ------------------------------------------------------------

priority_groups <- equity_gap_summary |>
  dplyr::filter(
    comparison_status !=
      "Insufficient groups"
  ) |>
  dplyr::select(
    equity_dimension,
    indicator,
    lowest_group,
    lowest_percent,
    lowest_ci_low,
    lowest_ci_high,
    lowest_group_n,
    highest_group,
    highest_percent,
    absolute_gap_pp,
    relative_ratio,
    comparison_status
  ) |>
  dplyr::arrange(
    indicator,
    lowest_percent
  )

# ------------------------------------------------------------
# Validate gap calculations
# ------------------------------------------------------------

negative_absolute_gaps <- sum(
  equity_gap_summary$absolute_gap_pp < 0,
  na.rm = TRUE
)

relative_ratio_below_one <- sum(
  equity_gap_summary$relative_ratio < 1,
  na.rm = TRUE
)

invalid_shortfall <- sum(
  equity_gap_summary$relative_shortfall_percent < 0 |
    equity_gap_summary$relative_shortfall_percent > 100,
  na.rm = TRUE
)

if (negative_absolute_gaps > 0) {
  stop(
    "Negative absolute equity gaps were detected."
  )
}

if (relative_ratio_below_one > 0) {
  stop(
    "Equity ratios below 1 were detected."
  )
}

if (invalid_shortfall > 0) {
  stop(
    "Invalid relative-shortfall values were detected."
  )
}

# ------------------------------------------------------------
# Create QA summary
# ------------------------------------------------------------

equity_gap_quality_summary <- tibble::tibble(
  
  quality_check = c(
    "Subgroup estimates available for ranking",
    "Equity gap comparisons created",
    "Negative absolute gaps",
    "Relative ratios below one",
    "Invalid relative shortfalls",
    "Comparisons flagged for caution",
    "Comparisons with insufficient groups"
  ),
  
  result = c(
    
    nrow(
      equity_subgroup_ranking
    ),
    
    nrow(
      equity_gap_summary
    ),
    
    negative_absolute_gaps,
    
    relative_ratio_below_one,
    
    invalid_shortfall,
    
    sum(
      equity_gap_summary$comparison_status ==
        "Caution"
    ),
    
    sum(
      equity_gap_summary$comparison_status ==
        "Insufficient groups"
    )
  )
)

# ------------------------------------------------------------
# Save analytical outputs
# ------------------------------------------------------------

readr::write_csv(
  equity_gap_summary,
  here::here(
    "outputs",
    "tables",
    "equity_gap_summary.csv"
  )
)

readr::write_csv(
  equity_gap_ranking,
  here::here(
    "outputs",
    "tables",
    "equity_gap_ranking.csv"
  )
)

readr::write_csv(
  equity_subgroup_ranking,
  here::here(
    "outputs",
    "tables",
    "equity_subgroup_ranking.csv"
  )
)

readr::write_csv(
  complete_continuum_gaps,
  here::here(
    "outputs",
    "tables",
    "complete_continuum_equity_gaps.csv"
  )
)

readr::write_csv(
  priority_groups,
  here::here(
    "outputs",
    "tables",
    "equity_priority_groups.csv"
  )
)

readr::write_csv(
  equity_gap_quality_summary,
  here::here(
    "outputs",
    "tables",
    "equity_gap_quality_summary.csv"
  )
)

# ------------------------------------------------------------
# Save Power BI-ready equity gap datasets
# ------------------------------------------------------------

powerbi_equity_gaps <- equity_gap_ranking |>
  dplyr::select(
    equity_dimension,
    indicator,
    highest_group,
    highest_percent,
    lowest_group,
    lowest_percent,
    absolute_gap_pp,
    relative_ratio,
    relative_shortfall_percent,
    disparity_rank,
    comparison_status
  )

readr::write_csv(
  powerbi_equity_gaps,
  here::here(
    "data",
    "powerbi",
    "equity_gap_summary.csv"
  )
)

powerbi_subgroup_ranking <- equity_subgroup_ranking |>
  dplyr::select(
    equity_dimension,
    equity_category,
    indicator,
    unweighted_n,
    public_weighted_percent,
    rank_high_to_low,
    gap_to_best_pp,
    reporting_status
  )

readr::write_csv(
  powerbi_subgroup_ranking,
  here::here(
    "data",
    "powerbi",
    "equity_subgroup_ranking.csv"
  )
)

# ------------------------------------------------------------
# Review QA
# ------------------------------------------------------------

print(
  equity_gap_quality_summary,
  n = Inf
)

# ------------------------------------------------------------
# Review complete-continuum disparities
# ------------------------------------------------------------

print(
  complete_continuum_gaps,
  n = Inf,
  width = Inf
)

message(
  "Equity gaps quantified and ranked successfully."
)