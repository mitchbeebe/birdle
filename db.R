library(DBI)
library(RPostgres)
library(httr)
library(glue)

db_uri <- Sys.getenv('DATABASE_URL')
parts <- parse_url(db_uri)

conn <- function() {
  dbConnect(
    RPostgres::Postgres(),
    host = parts$hostname,
    port = parts$port,
    user = parts$user,
    password = parts$password,
    dbname = parts$path
  )
}

create_games <- function() {
  db <- conn()
  
  dbExecute(db, "
    CREATE TABLE games (
      date DATE
      , user_id BIGINT
      , history VARCHAR
      , ui VARCHAR
    )")
}

get_games <- function() {
  db <- conn()
  
  res <- dbGetQuery(db, "select * from games")
  
  dbDisconnect(db)
  
  res
}

get_user_results <- function(date, user_id) {
  db <- conn()
  
  res <- dbGetQuery(db, glue("select * from games where date = '{date}' and user_id = {user_id}"))
  
  if(nrow(res) == 0) {
    dbAppendTable(db, 
                  "games", 
                  tibble(
                    date = date,
                    user_id = user_id, 
                    history = rawToChar(serialize(NA, connection = NULL, ascii = TRUE)),
                    ui = NA
                  )
    )
    dbDisconnect(db)
    return(NA)
    # return(get_user_results(date, user_id))
  } else {
    dbDisconnect(db)
    return(res)
  }
}

update_user_results <- function(date, user_id, history, ui) {
  db <- conn()
  
  clean_ui <- gsub("'", "''", ui)
  clean_history <- history %>% serialize(NULL, ascii=TRUE) %>% rawToChar()
  
  dbExecute(db,
            glue("
                UPDATE games
                SET history = '{clean_history}', ui = '{clean_ui}'
                WHERE date = '{date}' and user_id = {user_id}
                 ")
  )
  
  dbDisconnect(db)
}