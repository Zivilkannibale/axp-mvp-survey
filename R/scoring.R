load_scales <- function(path = "docs/scales.csv") {
  readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
}

compute_scores <- function(responses_numeric_df, scales_df) {
  if (nrow(responses_numeric_df) == 0) return(data.frame())

  merged <- merge(scales_df, responses_numeric_df, by = "item_id")
  if (nrow(merged) == 0) return(data.frame())

  merged$score_value <- merged$value
  if ("reverse" %in% names(merged)) {
    max_val <- if ("max_value" %in% names(merged)) merged$max_value else NA
    merged$score_value <- ifelse(!is.na(merged$reverse) & merged$reverse == 1 & !is.na(max_val),
      max_val - merged$value,
      merged$value
    )
  }

  agg <- aggregate(score_value ~ scale_id, data = merged, FUN = mean)
  agg$created_at <- Sys.time()
  agg
}
