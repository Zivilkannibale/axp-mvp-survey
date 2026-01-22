plot_scores_radar <- function(scores_df, norms_df) {
  if (nrow(scores_df) == 0) return(NULL)

  merged <- merge(scores_df, norms_df[, c("scale_id", "mean")], by = "scale_id", all.x = TRUE)
  merged$mean[is.na(merged$mean)] <- merged$score_value[is.na(merged$mean)]

  max_val <- max(c(merged$score_value, merged$mean), na.rm = TRUE)
  min_val <- min(c(merged$score_value, merged$mean), na.rm = TRUE)

  chart <- data.frame(
    max = rep(max_val, nrow(merged)),
    min = rep(min_val, nrow(merged)),
    participant = merged$score_value,
    mean = merged$mean
  )

  chart <- t(chart)
  colnames(chart) <- merged$scale_id

  op <- par(mar = c(1, 1, 1, 1))
  on.exit(par(op), add = TRUE)

  fmsb::radarchart(
    chart,
    axistype = 1,
    pcol = c(NA, NA, "#2c7fb8", "#d95f0e"),
    plwd = 2,
    plty = 1,
    cglcol = "#cccccc",
    cglty = 1,
    cglwd = 0.8,
    axislabcol = "#333333",
    vlcex = 0.8
  )

  legend(
    "topright",
    legend = c("Participant", "Mean"),
    col = c("#2c7fb8", "#d95f0e"),
    lty = 1,
    lwd = 2,
    bty = "n"
  )
}
