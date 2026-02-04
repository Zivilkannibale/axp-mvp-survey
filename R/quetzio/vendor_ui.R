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

    get_col <- function(name) {
      if (name %in% names(row)) row[[name]] else NA
    }

    mandatory <- FALSE
    if ("required" %in% names(row)) mandatory <- as.logical(row$required)
    if ("mandatory" %in% names(row)) mandatory <- as.logical(row$mandatory)

    item <- list(
      type = as.character(row$type),
      label = as.character(row$label),
      mandatory = mandatory,
      placeholder = quetzio_null_def(get_col("placeholder"), NULL),
      width = quetzio_null_def(get_col("width"), NULL),
      options = quetzio_null_def(get_col("options"), NULL),
      min = quetzio_null_def(get_col("min"), NA),
      max = quetzio_null_def(get_col("max"), NA)
    )

    # slider-specific fields
    item$slider_min <- quetzio_null_def(get_col("slider_min"), 0)
    item$slider_max <- quetzio_null_def(get_col("slider_max"), 100)
    item$slider_value <- quetzio_null_def(get_col("slider_value"), item$slider_min)
    item$slider_step <- quetzio_null_def(get_col("slider_step"), 1)
    item$slider_pre <- quetzio_null_def(get_col("slider_pre"), "")
    item$slider_post <- quetzio_null_def(get_col("slider_post"), "")
    item$slider_left_label <- quetzio_null_def(get_col("slider_left_label"), NA)
    item$slider_right_label <- quetzio_null_def(get_col("slider_right_label"), NA)
    item$slider_ticks <- quetzio_null_def(get_col("slider_ticks"), NA)

    # experience tracer fields
    item$tracer_duration_seconds <- quetzio_null_def(get_col("tracer_duration_seconds"), NA)
    item$tracer_y_min <- quetzio_null_def(get_col("tracer_y_min"), 0)
    item$tracer_y_max <- quetzio_null_def(get_col("tracer_y_max"), 100)
    item$tracer_samples <- quetzio_null_def(get_col("tracer_samples"), 101)
    item$tracer_height <- quetzio_null_def(get_col("tracer_height"), 240)
    item$tracer_min_points <- quetzio_null_def(get_col("tracer_min_points"), 10)
    item$tracer_instruction <- quetzio_null_def(get_col("tracer_instruction"), "")
    item$tracer_x_label <- quetzio_null_def(get_col("tracer_x_label"), "Time")
    item$tracer_y_label <- quetzio_null_def(get_col("tracer_y_label"), "Intensity")
    item$tracer_top_label <- quetzio_null_def(get_col("tracer_top_label"), item$label)
    item$tracer_grid_cols <- quetzio_null_def(get_col("tracer_grid_cols"), 10)
    item$tracer_grid_rows <- quetzio_null_def(get_col("tracer_grid_rows"), 10)

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

    question_ui <- switch(
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
        left_label <- if (!is.na(item$slider_left_label)) {
          item$slider_left_label
        } else {
          as.character(item$slider_min)
        }
        right_label <- if (!is.na(item$slider_right_label)) {
          item$slider_right_label
        } else {
          as.character(item$slider_max)
        }
        ticks_val <- if (!is.na(item$slider_ticks)) as.logical(item$slider_ticks) else FALSE
        width_val <- if (is.null(item$width) || is.na(item$width) || item$width == "") "100%" else item$width
        slider_value <- item$slider_value
        if (is.null(slider_value) || is.na(slider_value) || slider_value == "") {
          min_val <- as.numeric(item$slider_min)
          max_val <- as.numeric(item$slider_max)
          if (!is.na(min_val) && !is.na(max_val)) {
            midpoint <- (min_val + max_val) / 2
            step_val <- as.numeric(item$slider_step)
            if (!is.na(step_val) && step_val > 0) {
              midpoint <- min_val + round((midpoint - min_val) / step_val) * step_val
            }
            slider_value <- midpoint
          }
        }
        tagList(
          sliderInput(
            input_id,
            label,
            min = item$slider_min,
            max = item$slider_max,
            value = slider_value,
            step = item$slider_step,
            pre = item$slider_pre,
            post = item$slider_post,
            ticks = ticks_val,
            width = width_val
          ),
          tags$div(
            class = "slider-labels",
            tags$span(class = "slider-label-left", left_label),
            tags$span(class = "slider-label-right", right_label)
          ),
          tags$script(HTML(sprintf(
            "$(function(){ $('#%s').on('change input', function(){ Shiny.setInputValue('%s__touched', 1, {priority: 'event'}); if (window.__axpUpdateSliderNextState) { window.__axpUpdateSliderNextState(); } }); });",
            input_id, input_id
          ))),
          tags$script(HTML(sprintf(
            "$(function(){\n  var id = '%s';\n  var min = %s;\n  var max = %s;\n  var dragging = false;\n  function getClientX(e){\n    if (e.touches && e.touches.length) return e.touches[0].clientX;\n    return e.clientX;\n  }\n  function updateBar(){\n    var val = parseFloat($('#' + id).val());\n    if (isNaN(val)) { val = min; }\n    var pct = (val - min) / (max - min);\n    pct = Math.max(0, Math.min(1, pct));\n    var light = 65 - (pct * 25);\n    var color = 'hsl(266, 85%%,' + light + '%%)';\n    var $irs = $('#' + id).closest('.form-group').find('.irs--shiny');\n    $irs.find('.irs-bar, .irs-bar-edge').css('background', color);\n    $irs.find('.irs-handle, .irs-slider').css('border-color', color);\n  }\n  function markTouched(){\n    var $irs = $('#' + id).closest('.form-group').find('.irs--shiny');\n    $irs.removeClass('is-untouched').addClass('is-touched');\n  }\n  function markReady(){\n    var $input = $('#' + id);\n    var instance = $input.data('ionRangeSlider');\n    var $irs = $input.closest('.form-group').find('.irs--shiny');\n    if (!$irs.length) return false;\n    if (!instance) return false;\n    if ($irs.hasClass('is-ready')) return true;\n    if ($irs.data('readyPending')) return false;\n    $irs.data('readyPending', true);\n    var raf = window.requestAnimationFrame || function(cb){ return setTimeout(cb, 16); };\n    raf(function(){\n      raf(function(){\n        $irs.addClass('is-ready').addClass('is-untouched');\n        $irs.data('readyPending', false);\n      });\n    });\n    return true;\n  }\n  function waitForReady(tries){\n    if (markReady()) return;\n    if (tries <= 0) {\n      var $irs = $('#' + id).closest('.form-group').find('.irs--shiny');\n      if ($irs.length) $irs.addClass('is-ready');\n      return;\n    }\n    if (window.requestAnimationFrame) {\n      requestAnimationFrame(function(){ waitForReady(tries - 1); });\n    } else {\n      setTimeout(function(){ waitForReady(tries - 1); }, 16);\n    }\n  }\n  function computeValue(clientX){\n    var $input = $('#' + id);\n    var instance = $input.data('ionRangeSlider');\n    var $irs = $input.closest('.form-group').find('.irs--shiny');\n    var line = $irs.find('.irs-line')[0];\n    if (!instance || !line) return null;\n    var rect = line.getBoundingClientRect();\n    var pct = (clientX - rect.left) / rect.width;\n    pct = Math.max(0, Math.min(1, pct));\n    var minVal = instance.options.min;\n    var maxVal = instance.options.max;\n    var step = instance.options.step || 1;\n    var raw = minVal + pct * (maxVal - minVal);\n    var stepped = Math.round(raw / step) * step;\n    return Math.max(minVal, Math.min(maxVal, stepped));\n  }\n  function updateValue(val){\n    var $input = $('#' + id);\n    var instance = $input.data('ionRangeSlider');\n    if (!instance) return;\n    instance.update({ from: val });\n    $input.trigger('change');\n  }\n  function startDrag(e){\n    var $irs = $('#' + id).closest('.form-group').find('.irs--shiny');\n    if (!$irs.length) return;\n    var val = computeValue(getClientX(e));\n    if (val == null) return;\n    dragging = true;\n    updateValue(val);\n    if (e.preventDefault) e.preventDefault();\n  }\n  function moveDrag(e){\n    if (!dragging) return;\n    var val = computeValue(getClientX(e));\n    if (val == null) return;\n    updateValue(val);\n  }\n  function stopDrag(){ dragging = false; }\n  updateBar();\n  waitForReady(40);\n  $('#' + id).on('change input', function(){ markTouched(); updateBar(); });\n  var ns = '.axpSlider-' + id;\n  $(document)\n    .off('pointerdown' + ns + ' mousedown' + ns + ' touchstart' + ns)\n    .on('pointerdown' + ns + ' mousedown' + ns + ' touchstart' + ns, '.irs--shiny', function(ev){\n      var $irs = $(ev.currentTarget);\n      if (!$irs.closest('.form-group').find('#' + id).length) return;\n      startDrag(ev);\n    });\n  $(document)\n    .off('pointermove' + ns + ' mousemove' + ns + ' touchmove' + ns)\n    .on('pointermove' + ns + ' mousemove' + ns + ' touchmove' + ns, function(ev){ moveDrag(ev); });\n  $(document)\n    .off('pointerup' + ns + ' mouseup' + ns + ' touchend' + ns + ' touchcancel' + ns)\n    .on('pointerup' + ns + ' mouseup' + ns + ' touchend' + ns + ' touchcancel' + ns, function(){ stopDrag(); });\n});",
            input_id, item$slider_min, item$slider_max
          )))
        )
      },
      radioButtons = {
        choices <- quetzio_split_options(item$options)
        selected_val <- NULL
        if (input_id == "q1") selected_val <- character(0)
        radioButtons(input_id, label, choices = choices, selected = selected_val, width = item$width)
      },
      selectInput = {
        choices <- quetzio_split_options(item$options)
        selectize_flag <- input_id != "q0"
        if (!is.null(item$placeholder) && !is.na(item$placeholder) && item$placeholder != "") {
          choices <- c(setNames("", item$placeholder), choices)
          selectInput(
            input_id,
            label,
            choices = choices,
            selected = "",
            width = item$width,
            selectize = selectize_flag
          )
        } else {
          selectInput(
            input_id,
            label,
            choices = choices,
            width = item$width,
            selectize = selectize_flag
          )
        }
      },
      selectizeInput = {
        choices <- quetzio_split_options(item$options)
        if (!is.null(item$placeholder) && !is.na(item$placeholder) && item$placeholder != "") {
          choices <- c(setNames("", item$placeholder), choices)
          selectizeInput(input_id, label, choices = choices, selected = "", width = item$width)
        } else {
          selectizeInput(input_id, label, choices = choices, width = item$width)
        }
      },
      experience_tracer = {
        experience_tracer_input(
          input_id,
          label,
          instruction = item$tracer_instruction,
          width = item$width,
          height = item$tracer_height,
          duration_seconds = item$tracer_duration_seconds,
          y_min = item$tracer_y_min,
          y_max = item$tracer_y_max,
          samples = item$tracer_samples,
          min_points = item$tracer_min_points,
          x_label = item$tracer_x_label,
          y_label = item$tracer_y_label,
          top_label = item$tracer_top_label,
          grid_cols = item$tracer_grid_cols,
          grid_rows = item$tracer_grid_rows
        )
      },
      textInput(input_id, paste0(as.character(item$label), " (unsupported type: ", item$type, ")"))
    )

    ui_list[[idx]] <- tags$div(
      class = paste("quetzio-question", paste0("type-", item$type)),
      question_ui
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

