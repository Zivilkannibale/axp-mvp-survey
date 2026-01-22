# Vendored, simplified UI generator based on shiny.quetzio

quetzio_label_mandatory <- function(label) {
  tagList(
    label,
    span("*", class = "mandatory_star")
  )
}

quetzio_null_def <- function(x, default) {
  if (is.null(x) || is.na(x)) default else x
}

quetzio_split_options <- function(x) {
  if (is.null(x) || is.na(x) || x == "") return(character(0))
  parts <- unlist(strsplit(x, ";|\n"))
  trimws(parts)
}

quetzio_df_to_items <- function(df) {
  items <- list()

  for (i in seq_len(nrow(df))) {
    row <- df[i, ]
    input_id <- as.character(row$item_id)

    mandatory <- FALSE
    if ("required" %in% names(row)) mandatory <- as.logical(row$required)
    if ("mandatory" %in% names(row)) mandatory <- as.logical(row$mandatory)

    item <- list(
      type = as.character(row$type),
      label = as.character(row$label),
      mandatory = mandatory,
      placeholder = quetzio_null_def(row$placeholder, NULL),
      width = quetzio_null_def(row$width, NULL),
      options = quetzio_null_def(row$options, NULL),
      min = quetzio_null_def(row$min, NA),
      max = quetzio_null_def(row$max, NA)
    )

    # slider-specific fields
    item$slider_min <- quetzio_null_def(row$slider_min, 0)
    item$slider_max <- quetzio_null_def(row$slider_max, 100)
    item$slider_value <- quetzio_null_def(row$slider_value, item$slider_min)
    item$slider_step <- quetzio_null_def(row$slider_step, 1)
    item$slider_pre <- quetzio_null_def(row$slider_pre, "")
    item$slider_post <- quetzio_null_def(row$slider_post, "")

    items[[input_id]] <- item
  }

  items
}

quetzio_generate_ui <- function(items) {
  ui_list <- list()
  idx <- 0

  for (input_id in names(items)) {
    idx <- idx + 1
    item <- items[[input_id]]
    label <- if (isTRUE(item$mandatory)) quetzio_label_mandatory(item$label) else item$label

    ui_list[[idx]] <- switch(
      item$type,
      textInput = {
        textInput(input_id, label, placeholder = quetzio_null_def(item$placeholder, ""), width = item$width)
      },
      textarea = {
        textAreaInput(input_id, label, placeholder = quetzio_null_def(item$placeholder, ""), width = item$width)
      },
      numericInput = {
        numericInput(
          input_id,
          label,
          value = NA,
          min = quetzio_null_def(item$min, NA),
          max = quetzio_null_def(item$max, NA),
          width = item$width
        )
      },
      sliderInput = {
        tagList(
          sliderInput(
            input_id,
            label,
            min = item$slider_min,
            max = item$slider_max,
            value = item$slider_value,
            step = item$slider_step,
            pre = item$slider_pre,
            post = item$slider_post
          ),
          tags$script(HTML(sprintf(
            "$(function(){ $('#%s').on('change input', function(){ Shiny.setInputValue('%s__touched', 1, {priority: 'event'}); }); });",
            input_id, input_id
          )))
        )
      },
      radioButtons = {
        choices <- quetzio_split_options(item$options)
        radioButtons(input_id, label, choices = choices, width = item$width)
      },
      selectInput = {
        choices <- quetzio_split_options(item$options)
        selectInput(input_id, label, choices = choices, width = item$width)
      },
      selectizeInput = {
        choices <- quetzio_split_options(item$options)
        selectizeInput(input_id, label, choices = choices, width = item$width)
      },
      textInput(input_id, paste0(as.character(item$label), " (unsupported type: ", item$type, ")"))
    )
  }

  tagList(ui_list)
}

questionnaire_ui_vendor <- function(df) {
  df <- df[df$active == 1, ]
  df <- df[order(df$order), ]
  items <- quetzio_df_to_items(df)
  quetzio_generate_ui(items)
}
