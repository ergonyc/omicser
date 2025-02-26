#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    shinyjs::useShinyjs(),
    waiter::useWaiter(),
    # golem::activate_js(), #already loaded in your golem by `bundle_resources()`

    # Your application UI logic
    fluidPage(
      titlePanel(
        fluidRow(
          column(width=5,
            h1("NDCN omicser"),
            h5("Browse and play for creative hypothesis generation")
          ),
          column(width=7, align = 'right', #offset=4,
            img(src = "www/logo.svg")
            )
        )
      ), # end titlePanel
      sidebarLayout(
        div(
          id = "cond_sidebar",
          sidebarPanel(
            width = 3,
            conditionalPanel(
              ' input.top_tab === "welcome" || input.top_tab === "help" ', #
              mod_side_info_ui("side_info_ui_1")
            ),
            conditionalPanel(
              ' input.top_tab === "playground" || input.top_tab === "table" || input.top_tab === "ingest" ',
              mod_side_selector_ui("side_selector_ui_1")
            )
          ) # sidebarpanel
        ), # div
        mainPanel(
          width = 9,
          tabsetPanel(
            type = "tabs", # pills look good
            id = "top_tab",
            tabPanel(
              title = "Welcome", value = "welcome",
              mod_welcome_ui(id = "welcome_ui_1")
            ),
            # ingest tab
            tabPanel(
              title = "Ingest", value = "ingest",
              mod_ingestor_ui(id = "ingestor_ui_1")
            ),
            # playground tab
            tabPanel(
              title = "Playground", value = "playground",
              mod_playground_ui(id = "playground_ui_1")
            ),

            # table tab
            tabPanel(
              title = "Data Table", value = "table",
              # DT::dataTableOutput("my_datatable_0")
              mod_tables_tab_ui("tables_tab_ui_1")

            ),

            tabPanel(
              title = "Help", value = "help",
              mod_help_ui("help_ui_1")
            )

          ) # tabsetpanel
        ) # mainpanel
      ), # end sidebarlayout
      # actionButton("alert", "xxx"),
      tags$footer(tags$div(
        class = "footer", checked = NA, HTML('
              <head>
              <style>
              .footer a:link {color: #008b42; background-color: transparent; text-decoration: none}
              .footer a:visited {color: #008b42; background-color: transparent; text-decoration: none}
              .footer a:hover {color: #008b42; background-color: transparent; text-decoration: underline;}
              .footer a:active {color: red; background-color: transparent; text-decoration: underline;}
              .footer div {padding: 0px 0px 10px; color: grey;}
              position:fixed;
              bottom:0;
              width:100%;
              height:50px;   /* Height of the footer */
              /*padding: 10px;*/
              </style>
              </head>

              <body>
              <hr>
              <div>
              <a href="https://chanzuckerberg.com/ndcn/" target="_blank">CZI NDCN</a>

              Shiny App credits: NDCN, DTI, Andy Henrie <a href="https://github.com/ndcn/omicser" target="_blank">ndcn/omicser@github</a>

              </div>
              </body>
              '),
        align = "left"
      ))
    ) # end fluidpage
  ) # end taglist
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www", app_sys("app/www")
  )

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "omicser"
    )
    # Add here other external resources
    # for example, you can add shinyalert::useShinyalert()
  )
}
