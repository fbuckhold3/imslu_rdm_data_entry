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
  result <- tryCatch({
    REDCapR::redcap_read_oneshot(
      redcap_uri = REDCAP_URL,
      token = REDCAP_TOKEN,
      forms = c("resident_data"),
      raw_or_label = label_mode,
      col_types = readr::cols(.default = readr::col_character())
    )
  }, error = function(e) {
    message("Error reading from REDCap: ", e$message)
    return(list(success = FALSE, data = NULL))
  })

  if (result$success) return(result$data)
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
  dashboardHeader(title = "REDCap Data Entry"),
  dashboardSidebar(
    useShinyjs(),
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
                  uiOutput("entry_form"),
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
      return(as.character(val))
    }

    type_choices <- c("Preliminary" = "1", "Categorical" = "2", "Dismissed" = "3")
    type_choices <- c("Select..." = "", type_choices)

    grad_choices <- c("2025" = "3", "2026" = "4", "2027" = "5", "2028" = "6", "2029" = "7")
    grad_choices <- c("Select..." = "", grad_choices)

    deg_choices <- c("US MD" = "1", "US DO" = "2", "US IMG" = "3", "IMG" = "4")
    deg_choices <- c("Select..." = "", deg_choices)

    tagList(
      textInput("last_name", "Last Name", value = safe_val("last_name")),
      textInput("first_name", "First Name", value = safe_val("first_name")),
      selectInput("type", "Type",
                  choices = type_choices,
                  selected = safe_val("type")),
      selectInput("grad_yr", "Graduation Year",
                  choices = grad_choices,
                  selected = safe_val("grad_yr")),
      textInput("email", "Email", value = safe_val("email")),
      textInput("phone", "Phone", value = safe_val("phone")),
      selectInput("deg", "Degree Type",
                  choices = deg_choices,
                  selected = safe_val("deg"))
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

    data_to_save <- data.frame(
      record_id = as.character(vals$selected_id),
      last_name = na_if_empty(input$last_name),
      first_name = na_if_empty(input$first_name),
      type = na_if_empty(input$type),
      grad_yr = na_if_empty(input$grad_yr),
      email = na_if_empty(input$email),
      phone = na_if_empty(input$phone),
      deg = na_if_empty(input$deg),
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
