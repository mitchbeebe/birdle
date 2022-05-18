library(tidyverse)
library(rvest)


birds <- read_html("https://www.allaboutbirds.org/guide/browse/taxonomy/#")

order_container <- birds %>% html_elements(".order-container")

order_family_species <-
  order_container %>% 
  map(. %>% html_elements(".order-name,.family-name,.species-card"))

species <-
  order_family_species %>% 
  map_dfr(
    ~ tibble(
      order = .x %>% html_element("h2") %>% html_text() %>% str_to_title(),
      family = .x %>% html_element("h3") %>% html_text() %>% str_remove("—.*"),
      genus_species = .x %>% html_element("p") %>% html_text(),
      genus = str_extract(genus_species, "^\\w+"),
      name = .x %>% html_element("h4") %>% html_text(),
      src = .x %>% html_element("img") %>% html_attr("src"),
      pre_src = .x %>% html_element("img") %>% html_attr("pre-src"),
      img_src = paste0(str_replace(src, "NA", NA_character_),
                       str_replace(pre_src, "NA", NA_character_)),
      url = paste0("https://www.allaboutbirds.org",
                   .x %>% html_element("a") %>% html_attr("href"))
    ) %>% 
      fill(order, family, .direction = "down") %>% 
      filter(!is.na(name)) %>% 
      select(-c(src, pre_src))
  )

species %>% write_csv("./birds.csv")

