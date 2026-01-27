plot_scores_radar <- function(scores_df,
                              peer_points_df = NULL,
                              max_val = 100,
                              min_val = 0,
                              scale_map = NULL,
                              label_width = 20,
                              label_radius = 1.14,
                              jitter_max = 0.03,
                              base_size = 10,
                              label_size = NULL) {
  if (is.null(scores_df) || nrow(scores_df) == 0) return(NULL)

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 is required for plot_scores_radar().")
  }

  canonical_labels <- c(
    "Experience of Unity",
    "Spiritual Experience",
    "Blissful State",
    "Insightfulness",
    "Disembodiment",
    "Impaired Control and Cognition",
    "Anxiety",
    "Complex Imagery",
    "Elementary Imagery",
    "Audio-Visual Synesthesia",
    "Changed Meaning of Percepts"
  )

  normalize_scale_ids <- function(df, scale_map) {
    if (is.null(df) || nrow(df) == 0) return(df)

    if (!is.null(scale_map)) {
      if (!is.character(scale_map) || is.null(names(scale_map))) {
        stop("scale_map must be a named character vector: names=source ids, values=canonical labels.")
      }
      df$scale_id <- ifelse(df$scale_id %in% names(scale_map),
                            scale_map[df$scale_id],
                            df$scale_id)
    }

    if (!all(df$scale_id %in% canonical_labels)) {
      missing_ids <- unique(df$scale_id[!df$scale_id %in% canonical_labels])
      stop(paste0(
        "Unrecognized scale_id(s): ",
        paste(missing_ids, collapse = ", "),
        ". Provide scale_map to map to canonical labels."
      ))
    }

    df$scale_id <- factor(df$scale_id, levels = canonical_labels, ordered = TRUE)
    df
  }

  scores_df <- normalize_scale_ids(scores_df, scale_map)
  if (length(unique(scores_df$scale_id)) != length(canonical_labels)) {
    stop("scores_df must contain exactly one row for each of the 11 canonical scales.")
  }

  if (!is.null(peer_points_df) && nrow(peer_points_df) > 0) {
    peer_points_df <- normalize_scale_ids(peer_points_df, scale_map)
  }

  clamp01 <- function(x) pmax(0, pmin(1, x))
  scale_to_unit <- function(x) clamp01((x - min_val) / (max_val - min_val))

  n_scales <- length(canonical_labels)
  angle_seq <- seq(0, 2 * pi, length.out = n_scales + 1)[-(n_scales + 1)]

  axis_df <- data.frame(
    scale_id = factor(canonical_labels, levels = canonical_labels, ordered = TRUE),
    angle = angle_seq
  )

  polar_to_xy <- function(r, angle) {
    theta <- pi / 2 - angle
    data.frame(
      x = r * cos(theta),
      y = r * sin(theta),
      theta = theta
    )
  }

  wrap_two_lines <- function(x, width = 20) {
    vapply(x, function(s) {
      parts <- strwrap(s, width = width)
      if (length(parts) > 2) {
        parts <- c(parts[1], paste(parts[2:length(parts)], collapse = " "))
      }
      paste(parts[1:min(2, length(parts))], collapse = "\n")
    }, character(1))
  }

  stable_hash_offset <- function(keys, max_offset = 0.06) {
    primes <- c(3, 5, 7, 11, 13, 17, 19, 23)
    sums <- vapply(keys, function(k) {
      ints <- utf8ToInt(k)
      w <- primes[(seq_along(ints) - 1) %% length(primes) + 1]
      sum(ints * w)
    }, numeric(1))
    frac <- (sums %% 10000) / 10000
    (frac - 0.5) * 2 * max_offset
  }

  scores_df <- scores_df[order(scores_df$scale_id), ]
  scores_df$angle <- axis_df$angle[match(scores_df$scale_id, axis_df$scale_id)]
  scores_df$r <- scale_to_unit(scores_df$score_value)
  scores_xy <- polar_to_xy(scores_df$r, scores_df$angle)
  scores_df$x <- scores_xy$x
  scores_df$y <- scores_xy$y

  if (!is.null(peer_points_df) && nrow(peer_points_df) > 0) {
    peer_points_df$angle <- axis_df$angle[match(peer_points_df$scale_id, axis_df$scale_id)]
    peer_points_df$r <- scale_to_unit(peer_points_df$value)

    if ("peer_id" %in% names(peer_points_df)) {
      keys <- paste(peer_points_df$peer_id, peer_points_df$scale_id, sep = "|")
    } else {
      keys <- paste(peer_points_df$scale_id, seq_len(nrow(peer_points_df)), sep = "|")
    }

    peer_points_df$jitter <- stable_hash_offset(keys, max_offset = jitter_max)
    peer_points_df$r_j <- clamp01(peer_points_df$r + peer_points_df$jitter)

    peer_xy <- polar_to_xy(peer_points_df$r_j, peer_points_df$angle)
    peer_points_df$x <- peer_xy$x
    peer_points_df$y <- peer_xy$y
  }

  grid_levels <- seq(0.2, 1, by = 0.2)
  ring_df <- do.call(rbind, lapply(grid_levels, function(r) {
    xy <- polar_to_xy(rep(r, n_scales), angle_seq)
    ring <- data.frame(ring = r, x = xy$x, y = xy$y)
    rbind(ring, ring[1, ])
  }))

  spoke_df <- do.call(rbind, lapply(seq_len(n_scales), function(i) {
    xy <- polar_to_xy(1, angle_seq[i])
    data.frame(xend = xy$x, yend = xy$y)
  }))

  label_xy <- polar_to_xy(rep(label_radius, n_scales), angle_seq)
  label_df <- data.frame(
    scale_id = canonical_labels,
    x = label_xy$x,
    y = label_xy$y,
    theta = label_xy$theta
  )
  label_df$label <- wrap_two_lines(label_df$scale_id, width = label_width)
  label_df$hjust <- ifelse(cos(label_df$theta) > 0.3, 0,
                           ifelse(cos(label_df$theta) < -0.3, 1, 0.5))
  label_df$vjust <- ifelse(sin(label_df$theta) > 0.3, 0,
                           ifelse(sin(label_df$theta) < -0.3, 1, 0.5))

  grid_color <- "#d0d6e4"
  text_color <- "#3f4250"
  purple <- "#6b3df0"
  grey <- "#7b7f8c"

  limit <- label_radius + 0.15
  if (is.null(label_size)) {
    label_size <- base_size * 0.33
  }

  p <- ggplot2::ggplot() +
    ggplot2::geom_path(
      data = ring_df,
      ggplot2::aes(x = x, y = y, group = ring),
      color = grid_color,
      linewidth = 0.5
    ) +
    ggplot2::geom_segment(
      data = spoke_df,
      ggplot2::aes(x = 0, y = 0, xend = xend, yend = yend),
      color = grid_color,
      linewidth = 0.5
    )

  if (!is.null(peer_points_df) && nrow(peer_points_df) > 0) {
    p <- p +
      ggplot2::geom_point(
        data = peer_points_df,
        ggplot2::aes(x = x, y = y, color = "Everybody else"),
        size = 1.2,
        alpha = 0.35
      )
  }

  scores_closed <- rbind(scores_df, scores_df[1, ])

  p <- p +
    ggplot2::geom_polygon(
      data = scores_closed,
      ggplot2::aes(x = x, y = y, group = 1),
      fill = ggplot2::alpha(purple, 0.22),
      color = purple,
      linewidth = 1.1,
      linejoin = "round"
    ) +
    ggplot2::geom_path(
      data = scores_closed,
      ggplot2::aes(x = x, y = y, group = 1),
      color = purple,
      linewidth = 1.1,
      linejoin = "round"
    ) +
    ggplot2::geom_point(
      data = scores_df,
      ggplot2::aes(x = x, y = y, color = "Your results"),
      size = 2.2
    ) +
    ggplot2::geom_text(
      data = label_df,
      ggplot2::aes(x = x, y = y, label = label, hjust = hjust, vjust = vjust),
      color = text_color,
      size = label_size,
      fontface = "bold",
      lineheight = 0.95
    ) +
    ggplot2::scale_color_manual(
      values = c("Your results" = purple, "Everybody else" = grey),
      breaks = c("Your results", "Everybody else")
    ) +
    ggplot2::coord_equal(xlim = c(-limit, limit), ylim = c(-limit, limit), clip = "off") +
    ggplot2::guides(
      color = ggplot2::guide_legend(
        title = NULL,
        override.aes = list(size = 3, alpha = c(1, 0.35))
      )
    ) +
    ggplot2::theme_void() +
    ggplot2::theme(
      legend.position = "bottom",
      legend.box = "horizontal",
      legend.text = ggplot2::element_text(color = text_color, size = base_size),
      plot.margin = ggplot2::margin(10, 15, 30, 15)
    )

  p
}
