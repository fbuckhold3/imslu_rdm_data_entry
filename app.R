library(shiny)
library(shinydashboard)
library(DT)
library(dplyr)
library(REDCapR)
library(shinyjs)
library(httr)

httr::set_config(httr::config(ssl_verifypeer = FALSE, ssl_verifyhost = FALSE))

REDCAP_URL <- Sys.getenv("REDCAP_URL")
REDCAP_TOKEN <- Sys.getenv("REDCAP_TOKEN")
APP_PASSWORD <- Sys.getenv("APP_PASSWORD", "changeme123")

get_data <- function(use_labels = TRUE) {
  label_mode <- if (use_labels) "label" else "raw"

  # Pull resident_data form
  result_resident <- tryCatch({
    REDCapR::redcap_read_oneshot(
      redcap_uri = REDCAP_URL,
      token = REDCAP_TOKEN,
      forms = c("resident_data"),
      raw_or_label = label_mode,
      col_types = readr::cols(.default = readr::col_character())
    )
  }, error = function(e) {
    message("Error reading resident_data from REDCap: ", e$message)
    return(list(success = FALSE, data = NULL))
  })

  # Pull s_e_step3 field from s_eval form
  result_step3 <- tryCatch({
    REDCapR::redcap_read_oneshot(
      redcap_uri = REDCAP_URL,
      token = REDCAP_TOKEN,
      fields = c("record_id", "s_e_step3"),
      raw_or_label = label_mode,
      col_types = readr::cols(.default = readr::col_character())
    )
  }, error = function(e) {
    message("Error reading s_e_step3 from REDCap: ", e$message)
    return(list(success = FALSE, data = NULL))
  })

  # Merge the data if both succeeded
  if (result_resident$success && result_step3$success) {
    # For s_e_step3, keep only the first occurrence per record_id to avoid duplicates
    step3_unique <- result_step3$data %>%
      distinct(record_id, .keep_all = TRUE)

    merged_data <- dplyr::left_join(
      result_resident$data,
      step3_unique,
      by = "record_id"
    )
    return(merged_data)
  } else if (result_resident$success) {
    # If step3 failed, just return resident data
    return(result_resident$data)
  }

  return(NULL)
}

save_data <- function(data_to_save) {
  result <- tryCatch({
    REDCapR::redcap_write_oneshot(
      ds = data_to_save,
      redcap_uri = REDCAP_URL,
      token = REDCAP_TOKEN
    )
  }, error = function(e) {
    message("Error writing to REDCap: ", e$message)
    return(list(success = FALSE))
  })

  return(result$success)
}

ui <- dashboardPage(
  dashboardHeader(title = "IMSLU Resident Data Management Entry", titleWidth = 450),
  dashboardSidebar(
    width = 450,
    useShinyjs(),
    div(style = "padding: 15px; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px; margin: 10px;",
        tags$strong(style = "color: #721c24;", "AUTHORIZED USE ONLY"),
        tags$p(style = "color: #721c24; font-size: 12px; margin-top: 5px;",
               "This system is for the exclusive use of administrators of the IMSLU Residency Program. ",
               "Unauthorized access or use is strictly forbidden and may result in disciplinary action and/or legal prosecution.")
    ),
    passwordInput("password", "Password"),
    actionButton("login_btn", "Login", class = "btn-primary"),
    hidden(
      div(id = "menu",
          hr(),
          selectInput("grad_filter", "Graduation Year:", choices = c("All" = "")),
          selectInput("type_filter", "Type:", choices = c("All" = "")),
          hr(),
          actionButton("refresh_btn", "Refresh", icon = icon("sync"))
      )
    )
  ),
  dashboardBody(
    useShinyjs(),
    hidden(
      div(id = "content",
          fluidRow(
            column(4,
              box(width = 12, title = "Select Resident", status = "primary",
                  textInput("name_search", "Search:", placeholder = "Name..."),
                  DTOutput("resident_table"),
                  hr(),
                  actionButton("prev_btn", "Previous", class = "btn-sm"),
                  actionButton("next_btn", "Next", class = "btn-sm")
              )
            ),
            column(8,
              box(width = 12, title = "Data Entry", status = "success",
                  uiOutput("resident_header"),
                  hr(),
                  div(style = "max-height: 600px; overflow-y: auto; padding-right: 10px;",
                      uiOutput("entry_form")
                  ),
                  hr(),
                  actionButton("save_btn", "Save", class = "btn-success", icon = icon("save")),
                  actionButton("save_next_btn", "Save & Next", class = "btn-primary"),
                  br(), br(),
                  uiOutput("save_message")
              )
            )
          )
      )
    )
  )
)

server <- function(input, output, session) {

  vals <- reactiveValues(
    data_display = NULL,
    data_edit = NULL,
    filtered = NULL,
    selected_id = NULL,
    selected_index = NULL
  )

  observeEvent(input$login_btn, {
    req(input$password)
    if (input$password == APP_PASSWORD) {
      show("menu")
      show("content")

      showNotification("Loading data...", type = "message")
      vals$data_display <- get_data(use_labels = TRUE)
      vals$data_edit <- get_data(use_labels = FALSE)

      if (!is.null(vals$data_display) && nrow(vals$data_display) > 0) {
        grad_years <- sort(unique(vals$data_display$grad_yr), decreasing = TRUE)
        grad_years <- grad_years[!is.na(grad_years)]
        updateSelectInput(session, "grad_filter", choices = c("All" = "", grad_years))

        types <- unique(vals$data_display$type)
        types <- types[!is.na(types)]
        updateSelectInput(session, "type_filter", choices = c("All" = "", types))

        showNotification("Loaded successfully!", type = "message")
      } else {
        showNotification("No data loaded or data is empty", type = "warning")
      }
    } else {
      showNotification("Invalid password", type = "error")
    }
  })

  observeEvent(input$refresh_btn, {
    vals$data_display <- get_data(use_labels = TRUE)
    vals$data_edit <- get_data(use_labels = FALSE)
    showNotification("Refreshed", type = "message")
  })

  get_filtered <- reactive({
    req(vals$data_display)
    data <- vals$data_display

    # Remove duplicate records - keep only unique record_ids
    data <- data %>% distinct(record_id, .keep_all = TRUE)

    if (!is.null(input$grad_filter) && nchar(input$grad_filter) > 0) {
      data <- data %>% filter(grad_yr == input$grad_filter)
    }

    if (!is.null(input$type_filter) && nchar(input$type_filter) > 0) {
      data <- data %>% filter(type == input$type_filter)
    }

    if (!is.null(input$name_search) && nchar(input$name_search) > 0) {
      search_term <- input$name_search
      data <- data %>% filter(
        grepl(search_term, last_name, ignore.case = TRUE) |
        grepl(search_term, first_name, ignore.case = TRUE)
      )
    }

    if (nrow(data) > 0) {
      vals$filtered <- data$record_id
    } else {
      vals$filtered <- character(0)
    }

    cols <- c("record_id", "last_name", "first_name", "type", "grad_yr", "email")
    data %>% select(any_of(cols))
  })

  output$resident_table <- renderDT({
    datatable(
      get_filtered(),
      selection = "single",
      options = list(pageLength = 8, dom = 't', scrollY = "300px"),
      rownames = FALSE
    )
  })

  observeEvent(input$resident_table_rows_selected, {
    req(vals$filtered)
    idx <- input$resident_table_rows_selected
    if (length(idx) > 0 && idx <= length(vals$filtered)) {
      vals$selected_id <- vals$filtered[idx]
      vals$selected_index <- idx
    }
  })

  observeEvent(input$prev_btn, {
    req(vals$selected_index, vals$filtered)
    if (vals$selected_index > 1) {
      new_idx <- vals$selected_index - 1
      vals$selected_id <- vals$filtered[new_idx]
      vals$selected_index <- new_idx
      dataTableProxy("resident_table") %>% selectRows(new_idx)
    }
  })

  observeEvent(input$next_btn, {
    req(vals$selected_index, vals$filtered)
    if (vals$selected_index < length(vals$filtered)) {
      new_idx <- vals$selected_index + 1
      vals$selected_id <- vals$filtered[new_idx]
      vals$selected_index <- new_idx
      dataTableProxy("resident_table") %>% selectRows(new_idx)
    }
  })

  output$resident_header <- renderUI({
    req(vals$selected_id, vals$data_display)
    resident <- vals$data_display %>% filter(record_id == vals$selected_id)
    req(nrow(resident) > 0)

    res <- resident[1, ]
    fname <- if (!is.null(res$first_name) && !is.na(res$first_name)) res$first_name else ""
    lname <- if (!is.null(res$last_name) && !is.na(res$last_name)) res$last_name else ""
    rtype <- if (!is.null(res$type) && !is.na(res$type)) res$type else ""
    gyear <- if (!is.null(res$grad_yr) && !is.na(res$grad_yr)) res$grad_yr else ""

    h4(paste(fname, lname, "-", rtype, "-", gyear))
  })

  output$entry_form <- renderUI({
    req(vals$selected_id, vals$data_edit)

    resident <- vals$data_edit %>% filter(record_id == vals$selected_id)
    req(nrow(resident) > 0)

    res <- resident[1, ]

    safe_val <- function(col_name) {
      val <- res[[col_name]]
      if (is.null(val) || length(val) == 0 || is.na(val)) {
        return("")
      }
      # Trim whitespace and convert to character
      val_clean <- trimws(as.character(val))
      # Debug output for grad_yr
      if (col_name == "grad_yr" && nchar(val_clean) > 0) {
        message("DEBUG: grad_yr raw value = '", val_clean, "'")
      }
      return(val_clean)
    }

    # Define choice lists
    type_choices <- c("Preliminary" = "1", "Categorical" = "2", "Dismissed" = "3")
    type_choices <- c("Select..." = "", type_choices)

    # All graduation years from data dictionary (codes 1-36 = years 2000-2035)
    grad_choices <- c(
      "2000" = "14", "2001" = "15", "2002" = "16", "2003" = "17", "2004" = "18", "2005" = "19",
      "2006" = "20", "2007" = "21", "2008" = "22", "2009" = "23", "2010" = "24", "2011" = "25",
      "2012" = "26", "2013" = "27", "2014" = "28", "2015" = "29", "2016" = "30", "2017" = "31",
      "2018" = "32", "2019" = "33", "2020" = "34", "2021" = "35", "2022" = "36",
      "2023" = "1", "2024" = "2", "2025" = "3", "2026" = "4", "2027" = "5", "2028" = "6",
      "2029" = "7", "2030" = "8", "2031" = "9", "2032" = "10", "2033" = "11", "2034" = "12",
      "2035" = "13"
    )
    grad_choices <- c("Select..." = "", grad_choices)

    deg_choices <- c("US MD" = "1", "US DO" = "2", "US IMG" = "3", "IMG" = "4")
    deg_choices <- c("Select..." = "", deg_choices)

    gender_choices <- c("Male" = "1", "Female" = "2", "Non-binary" = "3")
    gender_choices <- c("Select..." = "", gender_choices)

    yesno_choices <- c("Select..." = "", "No" = "0", "Yes" = "1")

    coach_choices <- c("Shieh" = "1", "Pollard" = "3", "Kunnath" = "4", "Mar" = "5", "Purdy" = "6",
                       "Kamel" = "7", "Freedle" = "8", "Cumming" = "9", "Reid" = "10", "Can" = "11",
                       "Walentik" = "13", "Ferguson" = "14", "Wheeler" = "18", "Buckhold" = "16",
                       "Morreale" = "19", "Bastin" = "20", "Robin" = "21", "Fernelius" = "22",
                       "Kent" = "23", "Karches" = "24")
    coach_choices <- c("Select..." = "", coach_choices)

    track_choices <- c("Primary Care" = "1", "Hospitalist" = "2", "PROMOTE" = "3")
    track_choices <- c("Select..." = "", track_choices)

    spec_choices <- c("Allergy" = "1", "Cardiology" = "2", "Endocrinology" = "3", "Gastroenterology" = "4",
                      "Geriatrics" = "5", "Hematology/Oncology" = "6", "Hospitalist" = "7",
                      "Infectious Disease" = "8", "Nephrology" = "9", "Pulmonary / CC" = "10",
                      "Rheumatology" = "11", "Addiction Medicine" = "12", "Palliative Care" = "13",
                      "Primary Care" = "14", "Sleep Medicine" = "15", "Other" = "16")
    spec_choices <- c("Select..." = "", spec_choices)

    tagList(
      h5(strong("Basic Information")),
      textInput("name", "Name (from evaluation instrument)", value = safe_val("name")),
      textInput("last_name", "Last Name", value = safe_val("last_name")),
      textInput("first_name", "First Name", value = safe_val("first_name")),
      selectInput("type", "Resident Type", choices = type_choices, selected = safe_val("type")),
      selectInput("grad_yr", "Graduation Year", choices = grad_choices, selected = safe_val("grad_yr")),
      textInput("dob", "Date of Birth (MM/DD/YYYY)", value = safe_val("dob")),
      selectInput("gender", "Gender", choices = gender_choices, selected = safe_val("gender")),

      # Race/Ethnicity checkboxes
      div(
        strong("Race / Ethnicity (check all that apply)"),
        checkboxInput("race_ethn___1", "American Indian or Alaska Native",
                      value = safe_val("race_ethn___1") == "1"),
        checkboxInput("race_ethn___2", "Asian",
                      value = safe_val("race_ethn___2") == "1"),
        checkboxInput("race_ethn___3", "Black or African American",
                      value = safe_val("race_ethn___3") == "1"),
        checkboxInput("race_ethn___4", "Hispanic, Latino, or of Spanish Origin",
                      value = safe_val("race_ethn___4") == "1"),
        checkboxInput("race_ethn___5", "Native Hawaiian or Other Pacific Islander",
                      value = safe_val("race_ethn___5") == "1"),
        checkboxInput("race_ethn___6", "White",
                      value = safe_val("race_ethn___6") == "1"),
        checkboxInput("race_ethn___7", "Other / Unknown",
                      value = safe_val("race_ethn___7") == "1")
      ),

      selectInput("deg", "Degree Type", choices = deg_choices, selected = safe_val("deg")),

      # Show phone and email only for non-archived residents
      if (is.null(res$res_archive) || is.na(res$res_archive) || res$res_archive != "1") {
        tagList(
          textInput("phone", "Phone", value = safe_val("phone")),
          textInput("email", "Email", value = safe_val("email"))
        )
      },

      hr(),
      h5(strong("USMLE Scores")),
      selectInput("usmle_step1_failure", "USMLE Step 1 Failure", choices = yesno_choices, selected = safe_val("usmle_step1_failure")),
      selectInput("usmle_step2_failure", "USMLE Step 2 Failure", choices = yesno_choices, selected = safe_val("usmle_step2_failure")),
      textInput("usmle_step2_score", "USMLE Step 2 Score", value = safe_val("usmle_step2_score")),

      # Show message if s_e_step3 is Yes (check for both raw "1" and labeled "Yes")
      if (!is.null(res$s_e_step3) && !is.na(res$s_e_step3) &&
          (res$s_e_step3 == "1" || res$s_e_step3 == "Yes")) {
        div(class = "alert alert-info", style = "margin: 10px 0;",
            icon("info-circle"),
            strong(" Resident indicated that they completed Step 3"))
      },

      selectInput("step3", "USMLE and/or COMLEX Step 3 Passed?", choices = yesno_choices, selected = safe_val("step3")),
      selectInput("usmle_step3_failure", "USMLE Step 3 Failure", choices = yesno_choices, selected = safe_val("usmle_step3_failure")),
      textInput("usmle_step3_score", "USMLE Step 3 Score", value = safe_val("usmle_step3_score")),

      hr(),
      h5(strong("COMLEX Scores")),
      selectInput("comlex_step1_failure", "COMLEX Step 1 Failure", choices = yesno_choices, selected = safe_val("comlex_step1_failure")),
      selectInput("comlex_step2_failure", "COMLEX Step 2 Failure", choices = yesno_choices, selected = safe_val("comlex_step2_failure")),
      textInput("comlex_step2_score", "COMLEX Step 2 Score", value = safe_val("comlex_step2_score")),
      selectInput("comlex_step3_failure", "COMLEX Step 3 Failure", choices = yesno_choices, selected = safe_val("comlex_step3_failure")),
      textInput("comlex_step3_score", "COMLEX Step 3 Score", value = safe_val("comlex_step3_score")),

      hr(),
      h5(strong("Board & Licensing")),
      selectInput("abim_first_year", "Took ABIM year of graduation?", choices = yesno_choices, selected = safe_val("abim_first_year")),
      selectInput("abim_pass", "1st time ABIM Pass?", choices = yesno_choices, selected = safe_val("abim_pass")),
      textInput("npi", "NPI", value = safe_val("npi")),
      textInput("mo_lic", "MO License ##", value = safe_val("mo_lic")),

      # Conditionally show Coaching & Review section (hide for archived residents)
      if (is.null(res$res_archive) || is.na(res$res_archive) || res$res_archive != "1") {
        tagList(
          hr(),
          h5(strong("Coaching & Review")),
          selectInput("coach", "Resident Coach", choices = coach_choices, selected = safe_val("coach")),
          textInput("coach_email", "Coach Email", value = safe_val("coach_email")),
          textInput("second_rev", "Second Reviewer", value = safe_val("second_rev")),
          textInput("sec_email", "Second Email", value = safe_val("sec_email")),
          textInput("access_code", "Access Code", value = safe_val("access_code"))
        )
      },

      hr(),
      h5(strong("Background & Training")),
      selectInput("hs_mo", "High School in Missouri?", choices = yesno_choices, selected = safe_val("hs_mo")),
      selectInput("college_mo", "College in Missouri?", choices = yesno_choices, selected = safe_val("college_mo")),
      selectInput("med_mo", "Medical School in Missouri?", choices = yesno_choices, selected = safe_val("med_mo")),
      selectInput("track", "Part of a Track?", choices = track_choices, selected = safe_val("track")),
      selectInput("slusom", "SLUSOM Alumni?", choices = yesno_choices, selected = safe_val("slusom")),

      hr(),
      h5(strong("Alumni & Career")),
      selectInput("res_archive", "Archived?", choices = yesno_choices, selected = safe_val("res_archive")),
      textInput("res_alumni_position", "Current Position", value = safe_val("res_alumni_position")),
      selectInput("res_alumni_academic", "Academic Medicine", choices = yesno_choices, selected = safe_val("res_alumni_academic")),
      selectInput("ssm", "SSM?", choices = yesno_choices, selected = safe_val("ssm")),
      selectInput("mo_prac", "Practice in MO?", choices = yesno_choices, selected = safe_val("mo_prac")),
      selectInput("rural", "Practice in Rural Setting", choices = yesno_choices, selected = safe_val("rural")),
      selectInput("und_urban", "Practice in Underserved Urban Setting?", choices = yesno_choices, selected = safe_val("und_urban")),
      selectInput("grad_spec", "Specialty", choices = spec_choices, selected = safe_val("grad_spec")),
      selectInput("chief", "Chief Resident?", choices = yesno_choices, selected = safe_val("chief")),
      selectInput("im_practice", "Practicing in IM?", choices = yesno_choices, selected = safe_val("im_practice")),
      textInput("grad_email", "Graduate Email", value = safe_val("grad_email")),
      textInput("grad_phone", "Graduate Phone", value = safe_val("grad_phone"))
    )
  })

  do_save <- function() {
    req(vals$selected_id)

    na_if_empty <- function(x) {
      if (is.null(x) || length(x) == 0 || nchar(as.character(x)) == 0) {
        return(NA_character_)
      }
      return(as.character(x))
    }

    # Helper function to safely get input value (returns NA if input doesn't exist)
    safe_input <- function(input_name) {
      if (!is.null(input[[input_name]])) {
        return(na_if_empty(input[[input_name]]))
      }
      return(NA_character_)
    }

    data_to_save <- data.frame(
      record_id = as.character(vals$selected_id),
      name = na_if_empty(input$name),
      last_name = na_if_empty(input$last_name),
      first_name = na_if_empty(input$first_name),
      type = na_if_empty(input$type),
      grad_yr = na_if_empty(input$grad_yr),
      dob = na_if_empty(input$dob),
      gender = na_if_empty(input$gender),
      race_ethn___1 = if (!is.null(input$race_ethn___1) && input$race_ethn___1) "1" else "0",
      race_ethn___2 = if (!is.null(input$race_ethn___2) && input$race_ethn___2) "1" else "0",
      race_ethn___3 = if (!is.null(input$race_ethn___3) && input$race_ethn___3) "1" else "0",
      race_ethn___4 = if (!is.null(input$race_ethn___4) && input$race_ethn___4) "1" else "0",
      race_ethn___5 = if (!is.null(input$race_ethn___5) && input$race_ethn___5) "1" else "0",
      race_ethn___6 = if (!is.null(input$race_ethn___6) && input$race_ethn___6) "1" else "0",
      race_ethn___7 = if (!is.null(input$race_ethn___7) && input$race_ethn___7) "1" else "0",
      phone = safe_input("phone"),
      email = safe_input("email"),
      deg = na_if_empty(input$deg),
      usmle_step1_failure = na_if_empty(input$usmle_step1_failure),
      usmle_step2_failure = na_if_empty(input$usmle_step2_failure),
      usmle_step2_score = na_if_empty(input$usmle_step2_score),
      step3 = na_if_empty(input$step3),
      usmle_step3_failure = na_if_empty(input$usmle_step3_failure),
      usmle_step3_score = na_if_empty(input$usmle_step3_score),
      comlex_step1_failure = na_if_empty(input$comlex_step1_failure),
      comlex_step2_failure = na_if_empty(input$comlex_step2_failure),
      comlex_step2_score = na_if_empty(input$comlex_step2_score),
      comlex_step3_failure = na_if_empty(input$comlex_step3_failure),
      comlex_step3_score = na_if_empty(input$comlex_step3_score),
      abim_first_year = na_if_empty(input$abim_first_year),
      abim_pass = na_if_empty(input$abim_pass),
      npi = na_if_empty(input$npi),
      mo_lic = na_if_empty(input$mo_lic),
      coach = safe_input("coach"),
      coach_email = safe_input("coach_email"),
      second_rev = safe_input("second_rev"),
      sec_email = safe_input("sec_email"),
      access_code = safe_input("access_code"),
      hs_mo = na_if_empty(input$hs_mo),
      college_mo = na_if_empty(input$college_mo),
      med_mo = na_if_empty(input$med_mo),
      track = na_if_empty(input$track),
      slusom = na_if_empty(input$slusom),
      res_archive = na_if_empty(input$res_archive),
      res_alumni_position = na_if_empty(input$res_alumni_position),
      res_alumni_academic = na_if_empty(input$res_alumni_academic),
      ssm = na_if_empty(input$ssm),
      mo_prac = na_if_empty(input$mo_prac),
      rural = na_if_empty(input$rural),
      und_urban = na_if_empty(input$und_urban),
      grad_spec = na_if_empty(input$grad_spec),
      chief = na_if_empty(input$chief),
      im_practice = na_if_empty(input$im_practice),
      grad_email = na_if_empty(input$grad_email),
      grad_phone = na_if_empty(input$grad_phone),
      stringsAsFactors = FALSE
    )

    success <- save_data(data_to_save)

    if (success) {
      vals$data_display <- get_data(use_labels = TRUE)
      vals$data_edit <- get_data(use_labels = FALSE)
      output$save_message <- renderUI({
        div(class = "alert alert-success", "Saved successfully!")
      })
      return(TRUE)
    } else {
      output$save_message <- renderUI({
        div(class = "alert alert-danger", "Error saving")
      })
      return(FALSE)
    }
  }

  observeEvent(input$save_btn, {
    showNotification("Saving...", type = "message")
    if (do_save()) {
      showNotification("Saved!", type = "message")
    } else {
      showNotification("Save failed!", type = "error")
    }
  })

  observeEvent(input$save_next_btn, {
    showNotification("Saving...", type = "message")
    if (do_save()) {
      showNotification("Saved! Moving to next...", type = "message")
      Sys.sleep(0.3)
      if (vals$selected_index < length(vals$filtered)) {
        new_idx <- vals$selected_index + 1
        vals$selected_id <- vals$filtered[new_idx]
        vals$selected_index <- new_idx
        dataTableProxy("resident_table") %>% selectRows(new_idx)
      }
    }
  })
}

shinyApp(ui, server)
