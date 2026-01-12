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
  result <- REDCapR::redcap_read_oneshot(
    redcap_uri = REDCAP_URL,
    token = REDCAP_TOKEN,
    forms = c("resident_data"),
    raw_or_label = label_mode,
    col_types = readr::cols(.default = readr::col_character())
  )
  if (result$success) return(result$data)
  return(NULL)
}

save_data <- function(data_to_save) {
  result <- REDCapR::redcap_write_oneshot(
    ds = data_to_save,
    redcap_uri = REDCAP_URL,
    token = REDCAP_TOKEN
  )
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
    if (input$password == APP_PASSWORD) {
      show("menu")
      show("content")
      
      showNotification("Loading data...", type = "message")
      vals$data_display <- get_data(use_labels = TRUE)
      vals$data_edit <- get_data(use_labels = FALSE)
      
      if (!is.null(vals$data_display)) {
        grad_years <- sort(unique(vals$data_display$grad_yr), decreasing = TRUE)
        updateSelectInput(session, "grad_filter", choices = c("All" = "", grad_years))
        
        types <- unique(vals$data_display$type)
        updateSelectInput(session, "type_filter", choices = c("All" = "", types))
        
        showNotification("Loaded successfully!", type = "message")
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
    
    if (!is.null(input$grad_filter) && input$grad_filter != "") {
      data <- data %>% filter(grad_yr == input$grad_filter)
    }
    
    if (!is.null(input$type_filter) && input$type_filter != "") {
      data <- data %>% filter(type == input$type_filter)
    }
    
    if (!is.null(input$name_search) && input$name_search != "") {
      data <- data %>% filter(
        grepl(input$name_search, last_name, ignore.case = TRUE) |
        grepl(input$name_search, first_name, ignore.case = TRUE)
      )
    }
    
    vals$filtered <- data$record_id
    
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
    vals$selected_id <- vals$filtered[idx]
    vals$selected_index <- idx
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
    resident <- resident[1, ]
    h4(paste(resident$first_name, resident$last_name, "-", resident$type, "-", resident$grad_yr))
  })
  
  output$entry_form <- renderUI({
    req(vals$selected_id, vals$data_edit)

    resident <- vals$data_edit %>% filter(record_id == vals$selected_id)
    req(nrow(resident) > 0)
    resident <- resident[1, ]

    tagList(
      textInput("last_name", "Last Name", value = ifelse(is.na(resident$last_name), "", resident$last_name)),
      textInput("first_name", "First Name", value = ifelse(is.na(resident$first_name), "", resident$first_name)),
      selectInput("type", "Type",
                  choices = c("" = "", "Preliminary" = "1", "Categorical" = "2", "Dismissed" = "3"),
                  selected = ifelse(is.na(resident$type), "", resident$type)),
      selectInput("grad_yr", "Graduation Year",
                  choices = c("" = "", "2025" = "3", "2026" = "4", "2027" = "5", "2028" = "6", "2029" = "7"),
                  selected = ifelse(is.na(resident$grad_yr), "", resident$grad_yr)),
      textInput("email", "Email", value = ifelse(is.na(resident$email), "", resident$email)),
      textInput("phone", "Phone", value = ifelse(is.na(resident$phone), "", resident$phone)),
      selectInput("deg", "Degree Type",
                  choices = c("" = "", "US MD" = "1", "US DO" = "2", "US IMG" = "3", "IMG" = "4"),
                  selected = ifelse(is.na(resident$deg), "", resident$deg))
    )
  })
  
  do_save <- function() {
    req(vals$selected_id)

    # Helper function to convert empty strings to NA
    na_if_empty <- function(x) {
      if (is.null(x) || length(x) == 0 || x == "") return(NA_character_)
      return(x)
    }

    data_to_save <- data.frame(
      record_id = vals$selected_id,
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
