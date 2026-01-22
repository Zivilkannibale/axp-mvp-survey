# Questionnaire schema

Required columns:
- instrument_id
- instrument_version
- language
- item_id
- type
- label
- required (0/1)
- active (0/1)
- order (numeric)
- page
- section

Optional columns:
- options (semicolon-separated for radio/select)
- min/max (for numericInput)
- slider_min, slider_max, slider_value, slider_step, slider_pre, slider_post (for sliderInput)
- slider_left_label, slider_right_label (for sliderInput endpoint labels)
- slider_ticks (TRUE/FALSE to show tick marks)
- width, placeholder (for text inputs and select inputs)

Versioning:
- Keep instrument_id stable per instrument.
- Bump instrument_version on any item change.
- Definition hash is computed from the full CSV.
