library(shiny)
library(tidyverse)
library(shinyalert)
library(pluralize)
library(glue)
library(shinyjs)
library(lubridate)
library(emoji)
library(scales)

source("./db.R")
birds <- read_csv("birds.csv")

# Define UI for application that draws a histogram
ui <- navbarPage(
  id = "tabs",
  windowTitle = "Birdle",
  title = HTML(paste(icon("dove", "fa-light"), "Birdle")),
  theme = bslib::bs_theme(bootswatch = "default"),
  collapsible = TRUE,
  header = tags$head(
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
        #keep_alive {
          visibility: hidden;
        }
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
      td:first-child {
        font-weight: bold
      }
    "))
  ),
  footer = useShinyjs(),
  tabPanel("Play", icon = icon("play", "fa-light"),
           textOutput("keep_alive"),
           fluidRow(
             column(width = 12, align = "center",
                    htmlOutput("bird_img", inline = TRUE),
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
           div(align = "center", plotOutput("distribution", width = "300px", height = "200px")),
           hr(),
           div(align = "center", tableOutput("stats"))
  ),
  tabPanel("Info", 
           id = "info", 
           icon = icon("info"),
           column(4, offset = 4,
                  HTML("
            <br>
            <p>
             Hi, my name is Mitch. I'm the creator of Birdle. 
             I'm neither a birder nor web developer.
             I jokingly threw the name 'Birdle' out there to a friend that is an avid birder and also very 
             into all -dle games (<a href='https://www.nytimes.com/games/wordle/index.html' target=_blank>Wordle</a>, 
             <a href='https://worldle.teuteuf.fr/' target=_blank>Worldle</a>, 
             <a href='https://www.flagle.io/' target=_blank>Flagle</a>, 
             <a href='https://globle-game.com/' target=_blank>Globle</a>, to name a few).
             He proceeded to ask me about development progress daily until I caved and hacked this together.
            </p>
            <br>
            <a href='https://www.buymeacoffee.com/mitchbeebe' target=_blank>https://www.buymeacoffee.com/mitchbeebe</a>")
           ))
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {
  
  # Create presets 
  num_guesses <- 0
  history <- list()
  ui <- tagList()
  
  bird_answer <- reactive({
    set.seed(today(tzone = "EST") %>% as.integer())
    bird_answer <- birds %>% slice_sample(n = 1)
    bird_answer
  })
  
  output$bird_img <- renderUI({ 
    img(class = "bird-img", 
        src = bird_answer()$img_src,
        alt = "Today's bird",
        width = "200px")
  })
  
  observe({ if(input$tabs == "Info") help_alert() })
  
  stats_df <- eventReactive(input$load | input$submit, { 
    get_games() %>%
      filter(user_id == input$user_id) %>%
      mutate(results = map(history, ~ .x %>% charToRaw() %>% unserialize()),
             guesses = map_int(results, length),
             final = map2(results, guesses, ~ .x[.y][[1]]),
             win = coalesce(map_lgl(final, ~ all(. == rep("correct", 4))), FALSE))
  })
  
  output$stats <- renderTable({
    
    today_stats <- stats_df() %>% 
      filter(date == today(tzone = "EST"))
    
    streaks <- stats_df() %>% 
      filter(win) %>% 
      mutate(con = cumsum(c(1, diff(as.Date(date))) > 1)) %>% 
      group_by(con) %>% 
      mutate(streak = sum(win))
    
    current_streak <- 
      if(today_stats$guesses == 6 & !today_stats$win) {
        0
      } else if(today_stats$guesses < 6 & !today_stats$win) {
        streaks %>% 
          filter(date == today(tzone = "EST") - 1) %>% 
          pluck("streak", .default = 0) %>% 
          as.numeric()
      } else if(today_stats$win) {
        streaks %>% 
          filter(date == today(tzone = "EST")) %>% 
          pluck("streak", .default = 1) %>% 
          as.numeric()
      }
    
    tibble(
      `Games Played` = nrow(stats_df()),
      `Games Won` = sum(stats_df()$win),
      `Win Percentage` = mean(stats_df()$win) %>% percent(),
      `Best Streak` = streaks %>% pluck("streak") %>% max(., current_streak),
      `Current Streak` = current_streak
    ) %>% 
      t()
  }, rownames = T, colnames = F)
  
  output$distribution <- renderPlot({
    stats_df() %>% 
      mutate(guesses = factor(guesses, levels = 1:6)) %>% 
      filter(win) %>% 
      count(guesses) %>%
      ggplot(aes(x = n, y = guesses)) + 
      geom_col() +
      geom_text(aes(label = n),
                color = "white", 
                fontface = "bold",
                size = 6,
                hjust = 1.5) +
      scale_y_discrete(limits = 6:1 %>% as.character()) +
      theme_minimal() +
      theme(axis.text.x = element_blank(),
            axis.text = element_text(face = "bold", size = 18),
            title = element_text(face = "bold", size = 16, color = "grey20")) +
      labs(title = "Guess Distribution", x = NULL, y = NULL)
  })
  
  # Do on page load
  observeEvent(input$load, {
    # Get the user_id from the cookies
    req(input$user_id)
    
    # Fetch user results and store as current values
    res <- get_user_results(as.character(today(tzone = "EST")), input$user_id)
    try({
      unserialized_history <- res$history %>% charToRaw() %>% unserialize()
      if(!is.na(unserialized_history)) history <<- unserialized_history
      num_guesses <<- length(history)
      if(!is.na(res$ui)) ui <<- tagAppendChild(ui, HTML(res$ui))
    })
    
    if(nrow(stats_df()) == 1 & is.na(stats_df()$results)) help_alert()
    
    # Render output
    output$results <- renderUI({
      ui
    })
    
    # Show popup again
    if(is_winner(history) | length(history) == 6) alert(history, bird_answer())
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
    
    result <- check_bird(input$guess, bird_answer())
    
    history <<- append(history, result$correctness)
    
    ui <<- tagAppendChild(ui, result$divs)
    
    update_user_results(today(tzone = "EST"), input$user_id, history, ui)
    
    output$results <- renderUI({
      ui
    })
    
    alert(history, bird_answer())
  })
  
  onclick("a")
  
  output$keep_alive <- renderText({
    req(input$alive_count)
    input$alive_count
  })
}

check_bird <- function(guess, bird_answer) {
  
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

alert <- function(history, bird_answer) {
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

help_alert <- function() {
  shinyalert(
    title = "Welcome to Birdle!",
    text = HTML("You get six guesses to identify the bird of the day.
        If you guess incorrectly, but your guess shares the order, family, or genus 
        (<a href=\"https://en.wikipedia.org/wiki/Taxonomic_rank\" target=_blank>taxonomic rank</a>) 
        with the species of the day, the tiles below will turn green. Good luck!"),
    size = "xs", 
    closeOnEsc = TRUE,
    closeOnClickOutside = TRUE,
    html = TRUE,
    type = "",
    showConfirmButton = FALSE,
    showCancelButton = FALSE,
    timer = 0,
    imageUrl = "https://upload.wikimedia.org/wikipedia/en/d/d8/Windows_11_Clippy_paperclip_emoji.png",
    animation = TRUE
  )
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
  
  glue("Birdle #{birdle_num} {n}/6\n{rounds}\nhttps://www.play-birdle.com")
}


# Run the application 
shinyApp(ui = ui, server = server)
