# shiny.quetzio vendor notes

This project vendors a minimal subset of shiny.quetzio UI generation in `R/quetzio/`.

Changes applied:
- Added question type `sliderInput` with columns `slider_min`, `slider_max`, `slider_value`, `slider_step`, `slider_pre`, `slider_post`.
- UI uses `shiny::sliderInput()`.
- Required sliders are valid only if the user touches the slider (set `<id>__touched` to 1 via JS).

If a full fork is needed later, use this vendor implementation as the reference.
