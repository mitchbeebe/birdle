library(shiny)
library(tidyverse)
library(shinyalert)
library(pluralize)
library(glue)
library(shinyjs)
library(lubridate)

source("./db.R")
birds <- read_csv("birds.csv")
set.seed(today(tzone = "EST") %>% as.integer())
bird_answer <- birds %>% slice_sample(n = 1)

# Define UI for application that draws a histogram
ui <- navbarPage(
    windowTitle = "Birdle",
    title = HTML(paste(icon("dove", "fa-light"), "Birdle")),
    theme = bslib::bs_theme(bootswatch = "default"),
    collapsible = TRUE,
    header = tags$head(
        tags$link(rel="shortcut icon", href=icon("dove", "fa-light")),
        tags$script(src = "script.js"),
        tags$script(
            src = paste0(
                "https://cdn.jsdelivr.net/npm/js-cookie@rc/",
                "dist/js.cookie.min.js"
            )
        ),
        tags$script(
            src = paste0(
                "https://cdn.jsdelivr.net/gh/StephanWagner/",
                "jBox@v1.2.0/dist/jBox.all.min.js"
            )
        ),
        tags$link(
            rel = "stylesheet",
            href = paste0(
                "https://cdn.jsdelivr.net/gh/StephanWagner/",
                "jBox@v1.2.0/dist/jBox.all.min.css"
            )
        ),
        tags$script(HTML("
    window.addEventListener('DOMContentLoaded', (event) => {
      const navLinks = document.querySelectorAll('.nav-item');
      const menuToggle = document.getElementsByClassName('navbar-collapse')[0];
      const bsCollapse = new bootstrap.Collapse(menuToggle, {
        toggle: false
      });
      navLinks.forEach((l) => {
          l.addEventListener('click', () => { bsCollapse.toggle() })
      });
    });")),
        tags$style(HTML("
  .selectize-control.single .selectize-input:after{
      display:none;
  }
    .form-group {
     margin-bottom: 0rem;
    }
    .bird-img {
      border-radius: 25px;
    }
    .bird {
        display: flex;
        align-content: flex-end;
        flex-direction: row;
        flex-wrap: nowrap;
        justify-content: center;
        align-items: center;
        gap: 5px;
    }
    .grid-container {
          display: grid;
          grid-template-columns: 1fr 1fr 1fr 1fr;
    }
      .guesses {
          margin: 5px;
      }
      .guesses .label {
        display: inline-block;
        font-size: 10px;
        color: grey;
        height: 15px;
        width: 70px;
        border-radius: 3px;
        text-align: center;
      }
      .guesses .bird {
          margin: 5px;
      }
      .guesses .bird > .taxonomy {
          display: flex;
          align-items: center; /* Vertical center alignment */
          justify-content: center; /* Horizontal center alignment */
          width: 70px;
          height: 50px;
          font-size: 9px;
          color: white;
          text-align: center;
          vertical-align: middle;
          border-radius: 3px;
          user-select: none;
          font-family: 'Clear Sans', 'Helvetica Neue', Arial, sans-serif;
          overflow-wrap: break-word; 
      }
      .guesses .bird > .correct {
          background-color: #6a5;
      }
      .guesses .bird > .incorrect {
          background-color: #888;
      }
    "))
    ),
    footer = useShinyjs(),
    tabPanel("Game", icon = icon("dove", "fa-light"),
             fluidRow(
                 column(width = 12, align = "center",
                        img(class = "bird-img", src = bird_answer$img_src, width = "200px"),
                        br(),
                        br(),
                        fluidRow( style = "justify-content: center;",
                                  selectizeInput("guess", 
                                                 width = "235px",
                                                 label = NULL, 
                                                 selected = NULL,
                                                 options = list(
                                                     placeholder = 'Guess',
                                                     onInitialize = I('function() { this.setValue(""); }'),
                                                     openOnFocus = FALSE),
                                                 choices = birds$name, 
                                                 multiple = FALSE),
                                  actionButton("submit", "Submit", style="margin-left:3px;height:calc(1.5em + 0.75rem + 2px);")
                        ),
                        div(class = "guesses",
                            div(class = "labels",
                                c("Order", "Family", "Genus", "Common Name") %>% 
                                    map(~ div(class = "taxonomy label", .x))),
                            uiOutput("results")
                        )
                 )
             )
    ),
    tabPanel("Stats", icon = icon("chart-bar", lib = "font-awesome"),
             h1("Coming soon"),
             plotOutput("stats")),
    tabPanel("About", icon = icon("info"),
             HTML("<p>
             Hi, my name is Mitch. I'm the creator of Birdle. I'm neither a birder or web developer.
             I jokingly threw the name 'Birdle' out there to a friend that is an avid birder and also very 
             into all -dle games (<a href='https://www.nytimes.com/games/wordle/index.html' target=_blank>Wordle</a>, 
             <a href='https://worldle.teuteuf.fr/' target=_blank>Worldle</a>, 
             <a href='https://www.flagle.io/' target=_blank>Flagle</a>, 
             <a href='https://globle-game.com/' target=_blank>Globle</a>, to name a few).
             He proceeded to ask me about development progress daily until I caved and hacked this together.</p>")
    )
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {
    
    # Create presets 
    num_guesses <- 0
    history <- list()
    ui <- tagList()
    
    # Do on page load
    observeEvent(input$load, {
        # Get the user_id from the cookies
        req(input$cookies$user_id)
        
        # Fetch user results and store as current values
        res <- get_user_results(as.character(today(tzone = "EST")), input$cookies$user_id)
        try({
            unserialized_history <- res$history %>% charToRaw() %>% unserialize()
            if(!is.na(unserialized_history)) history <<- unserialized_history
            num_guesses <<- length(history)
            if(!is.na(res$ui)) ui <<- tagAppendChild(ui, HTML(res$ui))
        })
        
        # Render output
        output$results <- renderUI({
            ui
        })
        
        output$stats <- renderPlot({
            ggplot(mtcars, aes(wt, mpg)) + geom_point()
        })
        
        # Show popup again
        if(is_winner(history) | length(history) == 6) alert(history)
    }, once = TRUE)
    
    # Do on guess submission
    observeEvent(input$submit, {
        jbox_alert <- function(msg) {
            runjs(paste0("
      new jBox('Notice', {
      content: '",msg,"'
      position: {
        x: 'center',
        y: 'center'
      }
    });"))
        }
        
        validate(
            need(input$guess %in% birds$name, 'Please guess a valid bird!'),
            need(num_guesses < 6, "You've run out of guesses!"),
            need(!is_winner(history), "Already won!")
        )
        
        # Clear search field  
        updateSelectizeInput(session, 
                             'guess', 
                             selected = NULL, 
                             options = list(
                                 placeholder = 'Guess',
                                 onInitialize = I('function() { this.setValue(""); }')))
        
        num_guesses <<- num_guesses + 1
        
        result <- check_bird(input$guess)
        
        history <<- append(history, result$correctness)
        
        ui <<- tagAppendChild(ui, result$divs)
        
        update_user_results(today(tzone = "EST"), input$cookies$user_id, history, ui)
        
        output$results <- renderUI({
            ui
        })
        
        alert(history)
    })
}

check_bird <- function(guess) {
    
    fields <- c("order", "family", "genus", "name")
    
    guess_taxonomy <-
        birds %>% 
        filter(name == guess) %>% 
        select(fields) %>% 
        as.character()
    
    answer_taxonomy <- 
        bird_answer %>% 
        select(fields) %>% 
        as.character()
    
    correct <- guess_taxonomy == answer_taxonomy
    out_str <- if_else(correct, "correct", "incorrect")
    
    list(
        correctness = list(out_str),
        winner = all(out_str == "correct"),
        divs = format_result(guess_taxonomy, out_str)
    )
}

format_result <- function(labels, result) {
    tibble(labels, result) %>% 
        pmap(~ div(..1, class = paste("taxonomy", ..2))) %>% 
        tagList() %>% 
        div(class="bird", .)
}

is_winner <- function(history) {
    guesses <- length(history)
    if(guesses > 0) {
        all(history[[guesses]] == rep("correct", 4))
    } else {
        FALSE
    }
}

alert <- function(history) {
    winner <- is_winner(history)
    num_guesses <- length(history)
    
    if(winner) {
        shinyalert(
            title = "Congratulations!",
            text = glue("You got today's Birdle in {num_guesses} {pluralize('guess', num_guesses)} 🎉<hr>
                  Learn more about the <a href=\"{bird_answer$url}\" target=_blank>{bird_answer$name}</a>"),
            size = "xs", 
            closeOnEsc = TRUE,
            closeOnClickOutside = TRUE,
            html = TRUE,
            type = "success",
            showConfirmButton = TRUE,
            showCancelButton = FALSE,
            confirmButtonText = "Copy Results",
            confirmButtonCol = "#AEDEF4",
            callbackJS = glue("function(x) {{
        if(x !== false) {{
          navigator.clipboard.writeText(`{share_results(history, winner)}`);
          new jBox('Notice', {{
              content: 'Copied!',
              position: {{
                x: 'center',
                y: 'center'
              }}
            }});
          }}
        }}"),
            timer = 0,
            imageUrl = "",
            animation = TRUE
        )
    } else if(num_guesses > 5) {
        shinyalert(
            title = "Oh no!",
            html = TRUE,
            text = HTML(glue("Today's bird is the <a href=\"{bird_answer$url}\" target=_blank>{bird_answer$name}</a>. But don't fret, <a href='https://birdsarentreal.com/' target=_blank>birds aren't real</a> anyway.")),
            size = "xs", 
            closeOnEsc = TRUE,
            closeOnClickOutside = TRUE,
            type = "error",
            showConfirmButton = TRUE,
            showCancelButton = FALSE,
            confirmButtonText = "Copy Results",
            confirmButtonCol = "#AEDEF4",
            callbackJS = glue("function(x) {{
        if(x !== false) {{
          navigator.clipboard.writeText(`{share_results(history, winner)}`);
          new jBox('Notice', {{
              content: 'Copied!',
              position: {{
                x: 'center',
                y: 'center'
              }}
            }});
          }}
        }}"),
            timer = 0,
            imageUrl = "",
            animation = TRUE
        )
    }
}

share_results <- function(guess_history, winner) {
    birdle_num <- (today(tzone = "EST") - date("2022-03-21")) %>% as.numeric
    rounds <- 
        guess_history %>% 
        map_chr(
            ~ if_else(.x == "correct",
                      emoji::emojis %>% filter(name=="bird") %>% pluck("emoji"),
                      emoji::emojis %>% filter(name=="cross mark") %>% pluck("emoji")) %>%
                paste0(collapse = "")) %>% 
        paste0(collapse = "\n")
    
    n <- if_else(winner, as.character(length(guess_history)), 'X')
    
    glue("Birdle #{birdle_num} {n}/6\n{rounds}\nhttps://mitchbeebe.shinyapps.io/Birdle/", )
}


# Run the application 
shinyApp(ui = ui, server = server)
