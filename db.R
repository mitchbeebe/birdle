library(RSQLite)
library(glue)
sqlitePath <- "my-db.sqlite"

initdb <- function() {
  db <- dbConnect(SQLite(), sqlitePath)
  
  dbExecute(db,
            "CREATE TABLE games (
                 id INTEGER PRIMARY KEY,
                 date TEXT,
                 user_id INTEGER,
                 history TEXT,
                 ui TEXT
              );")
  
  dbDisconnect(db)
}

get_games <- function() {
  db <- dbConnect(SQLite(), sqlitePath)
  
  res <- dbGetQuery(db, "select * from games")
  
  dbDisconnect(db)
  
  res
}

clear_table <- function() {
  db <- dbConnect(SQLite(), sqlitePath)
  
  dbExecute(db, "DELETE FROM games")
  
  dbDisconnect(db)
}

get_user_results <- function(date, user_id) {
  db <- dbConnect(SQLite(), sqlitePath)
  
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
  db <- dbConnect(SQLite(), sqlitePath)
  
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

# update_games <- function(uuid) {
#   dbExecute(db,
#             paste0("
#               UPDATE users 
#               SET games_played = games_played + 1 
#               WHERE uuid = ", uuid
#             )
#   )
# }
# 
# increase_streak <- function(uuid) {
#   dbExecute(db,
#             paste0("
#               UPDATE users 
#               SET streak = streak + 1 
#               WHERE uuid = ", uuid
#             )
#   )
# }
# 
# reset_streak <- function(uuid) {
#   dbExecute(db,
#             paste0("
#               UPDATE users 
#               SET streak = 0
#               WHERE uuid = ", uuid
#             )
#   )
# }