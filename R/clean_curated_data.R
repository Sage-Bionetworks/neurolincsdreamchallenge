library(synapser)
library(tidyverse)

fetch_syn_table <- function(syn_id, cols = "*") {
  if (is.vector(cols)) {
    cols <- paste(cols, collapse = ",")
  }
  table <- synapser::synTableQuery(paste("select", cols, "from", syn_id))
  table_df <- table$asDataFrame()
  return(as_tibble(table_df))
}

get_curated_cell_data <- function() {
  curated_cell_data <- fetch_syn_table("syn11378063") %>% 
    select(-ROW_ID, -ROW_VERSION) %>% 
    mutate(Live_Cells = as.logical(Live_Cells),
           Lost_Tracking = as.logical(Lost_Tracking))
  return(curated_cell_data)
}

get_corrected_indices <- function() {
  corrected_abc <- fetch_syn_table("syn17087846")
  corrected_lincs <- fetch_syn_table("syn17096732")
  corrected_sod <- fetch_syn_table("syn17933845")
  corrected_indices <- bind_rows(corrected_abc, corrected_lincs, corrected_sod) %>%
    select(Experiment, ObjectTrackID, Well, TimePoint, Live_Cells, Lost_Tracking) %>% 
    mutate(Live_Cells = as.logical(Live_Cells),
           Lost_Tracking = as.logical(Lost_Tracking))
  return(corrected_indices)
}

get_potential_errors_corrected <- function() {
  potential_errors_corrected <- synGet("syn18134075")$path %>%
    read_csv() %>% 
    as_tibble() %>% 
    select(Experiment, ObjectTrackID, Well, TimePoint, Live_Cells, Lost_Tracking) %>% 
    mutate(ObjectTrackID = as.integer(ObjectTrackID),
           TimePoint = as.integer(TimePoint))
}

main <- function() {
  synLogin()
  curated_cell_data <- get_curated_cell_data()
  censored_wells <- fetch_syn_table("syn11709601") %>% 
    select(-ROW_ID, -ROW_VERSION)
  corrected_indices <- get_corrected_indices() 
  potential_errors_corrected <- get_potential_errors_corrected()
  curated_cell_data_updated <- anti_join(curated_cell_data, censored_wells) %>% 
    anti_join(corrected_indices, by = c("Experiment", "ObjectTrackID",
                                        "Well", "TimePoint")) %>% 
    anti_join(potential_errors_corrected, by = c("Experiment", "ObjectTrackID",
                                                 "Well", "TimePoint")) %>% 
    bind_rows(corrected_indices, potential_errors_corrected)
  bad_cells <- curated_cell_data_updated %>%
    group_by(Experiment, Well, ObjectTrackID) %>% 
    mutate(last_timepoint = max(TimePoint)) %>% 
    filter(TimePoint == last_timepoint, !Lost_Tracking, Live_Cells) %>%
    select(Experiment, Well, ObjectTrackID)
  curated_cell_data_clean <- curated_cell_data_updated %>%
    filter(!is.na(ObjectTrackID)) %>% 
    anti_join(bad_cells) %>% 
    arrange(Experiment, Well, ObjectTrackID, TimePoint) %>% 
    select(Experiment, Well, ObjectTrackID, TimePoint, dplyr::everything())
  write_tsv(curated_cell_data_clean, "curated_cell_data_clean.tsv")
}

main()