experience_tracer_input <- function(input_id,
                                    label,
                                    instruction = NULL,
                                    width = "100%",
                                    height = 240,
                                    duration_seconds = NA,
                                    y_min = 0,
                                    y_max = 100,
                                    samples = 101,
                                    min_points = 10,
                                    x_label = "Time",
                                    y_label = "Intensity",
                                    top_label = NULL,
                                    grid_cols = 10,
                                    grid_rows = 10) {
  if (is.null(width) || is.na(width) || width == "") width <- "100%"
  if (is.null(height) || is.na(height)) height <- 240
  if (is.null(instruction) || is.na(instruction)) instruction <- ""
  if (is.null(x_label) || is.na(x_label) || x_label == "") x_label <- "Time"
  if (is.null(y_label) || is.na(y_label) || y_label == "") y_label <- "Intensity"
  if (is.null(top_label) || is.na(top_label) || top_label == "") top_label <- label
  if (is.null(grid_cols) || is.na(grid_cols) || grid_cols < 2) grid_cols <- 10
  if (is.null(grid_rows) || is.na(grid_rows) || grid_rows < 2) grid_rows <- 10

  y_ticks <- seq(y_min, y_max, length.out = grid_rows + 1)
  if (!is.finite(duration_seconds) || is.na(duration_seconds) || duration_seconds <= 0) {
    x_max <- 10
  } else {
    x_max <- duration_seconds / 60
  }
  x_ticks <- seq(0, x_max, length.out = grid_cols + 1)

  div(
    class = "experience-tracer",
    style = paste0("width:", width, ";"),
    `data-input-id` = input_id,
    `data-duration` = duration_seconds,
    `data-y-min` = y_min,
    `data-y-max` = y_max,
    `data-samples` = samples,
    `data-min-points` = min_points,
    tags$div(class = "experience-tracer-label", label),
    if (instruction != "") tags$div(class = "experience-tracer-instruction", instruction),
    tags$div(
      class = "experience-tracer-canvas-wrap",
      style = paste0("height:", height, "px; --tracer-cols:", grid_cols, "; --tracer-rows:", grid_rows, ";"),
      tags$canvas(class = "experience-tracer-canvas"),
      tags$div(class = "experience-tracer-top-label", top_label),
      tags$div(
        class = "experience-tracer-ticks",
        tags$div(
          class = "experience-tracer-ticks-x",
          lapply(seq_along(x_ticks), function(i) {
            pct <- (i - 1) / grid_cols * 100
            val <- x_ticks[[i]]
            lab <- paste0(format(round(val, 1), trim = TRUE, nsmall = ifelse(val %% 1 == 0, 0, 1)), " min")
            tags$span(class = "tick-label tick-label-x", style = paste0("left:", pct, "%;"), lab)
          })
        ),
        tags$div(
          class = "experience-tracer-ticks-y",
          lapply(seq_along(y_ticks), function(i) {
            pct <- (i - 1) / grid_rows * 100
            val <- y_ticks[[i]]
            lab <- format(round(val, 0), trim = TRUE)
            tags$span(class = "tick-label tick-label-y", style = paste0("bottom:", pct, "%;"), lab)
          })
        )
      )
    ),
    tags$div(
      class = "experience-tracer-actions",
      tags$button(type = "button", class = "btn btn-default tracer-clear", "Clear"),
      tags$button(type = "button", class = "btn btn-default tracer-undo", "Undo"),
      tags$span(class = "experience-tracer-status", "No trace yet")
    )
  )
}

tracer_points_df <- function(payload) {
  if (is.null(payload) || length(payload) == 0) {
    return(data.frame(x_norm = numeric(0), y_norm = numeric(0), t = numeric(0)))
  }
  pts <- payload$points
  if (is.null(pts) || length(pts) == 0) {
    return(data.frame(x_norm = numeric(0), y_norm = numeric(0), t = numeric(0)))
  }

  df <- try(as.data.frame(pts), silent = TRUE)
  if (inherits(df, "try-error")) {
    df <- data.frame(
      x = vapply(pts, function(p) p$x, numeric(1)),
      y = vapply(pts, function(p) p$y, numeric(1)),
      t = vapply(pts, function(p) if (!is.null(p$t)) p$t else NA_real_, numeric(1))
    )
  }

  names(df) <- tolower(names(df))
  if (!("x" %in% names(df)) || !("y" %in% names(df))) {
    return(data.frame(x_norm = numeric(0), y_norm = numeric(0), t = numeric(0)))
  }

  df$x <- pmax(0, pmin(1, as.numeric(df$x)))
  df$y <- pmax(0, pmin(1, as.numeric(df$y)))
  if (!("t" %in% names(df))) df$t <- NA_real_
  df <- df[order(df$x), ]
  df <- df[!duplicated(df$x), ]
  data.frame(x_norm = df$x, y_norm = df$y, t = df$t)
}

tracer_resample <- function(payload,
                            n = 101,
                            y_min = 0,
                            y_max = 100) {
  df <- tracer_points_df(payload)
  if (nrow(df) < 2) {
    return(list(
      x_norm = seq(0, 1, length.out = n),
      y_norm = rep(NA_real_, n),
      y_value = rep(NA_real_, n)
    ))
  }

  x_out <- seq(0, 1, length.out = n)
  approx_res <- approx(df$x_norm, df$y_norm, xout = x_out, ties = "ordered", rule = 2)
  y_norm <- pmax(0, pmin(1, approx_res$y))
  y_value <- y_min + (y_max - y_min) * y_norm
  list(x_norm = approx_res$x, y_norm = y_norm, y_value = y_value)
}
