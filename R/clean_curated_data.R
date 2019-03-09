library(synapser)
library(tidyverse)

fetch_syn_table <- function(syn_id, cols = "*") {
  if (is.vector(cols)) {
    cols <- paste(cols, collapse = ",")
  }
  table <- synTableQuery(paste("select", cols, "from", syn_id))
  table_df <- table$asDataFrame() %>%
    as_tibble()
  if (has_name(table_df, "ObjectTrackID")) {
    table_df <- table_df %>% mutate(ObjectTrackID = as.integer(ObjectTrackID))
  }
  if (has_name(table_df, "TimePoint")) {
    table_df <- table_df %>% mutate(TimePoint = as.integer(TimePoint))
  }
  if (has_name(table_df, "Live_Cells")) {
    table_df <- table_df %>% mutate(Live_Cells = as.logical(Live_Cells))
  }
  if (has_name(table_df, "Mistracked")) {
    table_df <- table_df %>% mutate(Mistracked = as.logical(Mistracked))
  }
  if (has_name(table_df, "Lost_Tracking")) {
    table_df <- table_df %>% mutate(Lost_Tracking = as.logical(Lost_Tracking))
  }
  if (has_name(table_df, "Out_of_Focus")) {
    table_df <- table_df %>% mutate(Out_of_Focus = as.logical(Out_of_Focus))
  }
  if (has_name(table_df, "XCoordinate")) {
    table_df <- table_df %>% mutate(XCoordinate = as.numeric(XCoordinate))
  }
  if (has_name(table_df, "YCoordinate")) {
    table_df <- table_df %>% mutate(YCoordinate = as.numeric(YCoordinate))
  }
  table_df <- table_df %>% select(-ROW_ID, -ROW_VERSION)
  return(as_tibble(table_df))
}

fetch_syn_csv <- function(syn_id) {
  f <- synGet(syn_id)
  df <- read_csv(f$path) %>%
    as_tibble()
  if (has_name(df, "ObjectTrackID")) {
    df <- df %>% mutate(ObjectTrackID = as.integer(ObjectTrackID))
  }
  if (has_name(df, "TimePoint")) {
    df <- df %>% mutate(TimePoint = as.integer(TimePoint))
  }
  if (has_name(df, "Live_Cells")) {
    df <- df %>% mutate(Live_Cells = as.logical(Live_Cells))
  }
  if (has_name(df, "Mistracked")) {
    df <- df %>% mutate(Mistracked = as.logical(Mistracked))
  }
  if (has_name(df, "Lost_Tracking")) {
    df <- df %>% mutate(Lost_Tracking = as.logical(Lost_Tracking))
  }
  if (has_name(df, "Out_of_Focus")) {
    df <- df %>% mutate(Out_of_Focus = as.logical(Out_of_Focus))
  }
  if (has_name(df, "XCoordinate")) {
    df <- df %>% mutate(XCoordinate = as.numeric(XCoordinate))
  }
  if (has_name(df, "YCoordinate")) {
    df <- df %>% mutate(YCoordinate = as.numeric(YCoordinate))
  }
  return(df)
}

get_corrected_indices <- function() {
  corrected_abc <- fetch_syn_table("syn17087846")
  corrected_lincs <- fetch_syn_table("syn17096732")
  corrected_sod <- fetch_syn_table("syn17933845")
  corrected_indices <- bind_rows(corrected_abc, corrected_lincs, corrected_sod) %>%
    #select(Experiment, ObjectTrackID, Well, TimePoint, Live_Cells, Lost_Tracking) %>%
    mutate(Live_Cells = as.logical(Live_Cells),
           Lost_Tracking = as.logical(Lost_Tracking))
  return(corrected_indices)
}

fill_in_missing_timepoints <- function(curated_cell_data) {
  timepoint_reference <- fetch_syn_table(
    "syn11817859", c("Experiment", "TimePointBegin", "TimePointEnd")) %>%
    select(Experiment, TimePointBegin, TimePointEnd)
  tidy_timepoint_reference <- timepoint_reference %>%
    purrr::pmap_dfr(function(Experiment, TimePointBegin, TimePointEnd) {
      tibble(
        Experiment = Experiment,
        TimePoint = TimePointBegin:TimePointEnd
      )
    })
  object_well_reference <- curated_cell_data %>%
    distinct(Experiment, Well, ObjectTrackID)
  complete_reference <- tidy_timepoint_reference %>%
    left_join(object_well_reference, by = "Experiment") %>%
    filter(!is.na(ObjectTrackID))
  curated_cell_data_full <- complete_reference %>%
    left_join(curated_cell_data) %>%
    arrange(Experiment, Well, ObjectTrackID, TimePoint) %>%
    mutate(Live_Cells = as.logical(Live_Cells),
           Lost_Tracking = as.logical(Lost_Tracking),
           TimePoint = ifelse(Experiment == "LINCS062016B",
                              TimePoint - 1, TimePoint)) %>%
    group_by(Experiment, Well, ObjectTrackID)
  return(curated_cell_data_full)
}

fill_in_missing_labels <- function(curated_cell_data_all_timepoints) {
  last_seen_alive <- curated_cell_data_all_timepoints %>%
    summarise(last_seen_alive = max(which(Live_Cells)) - 1)
  # Move Lost_Tracking = TRUE to next TimePoint
  curated_cell_data_complete <- curated_cell_data_all_timepoints %>%
    left_join(last_seen_alive) %>%
    mutate(previous_live_cells = lag(Live_Cells),
           previous_lost_tracking = lag(Lost_Tracking),
           Correct_Lost_Tracking = ifelse(!Lost_Tracking, FALSE, NA)) %>%
    mutate(Correct_Lost_Tracking = ifelse(!is.na(previous_lost_tracking),
                                          ifelse(previous_lost_tracking,
                                                 TRUE, Correct_Lost_Tracking),
                                          Correct_Lost_Tracking)) %>%
    mutate(Correct_Lost_Tracking = ifelse(!is.na(Lost_Tracking),
                                          ifelse(Lost_Tracking, FALSE, Correct_Lost_Tracking),
                                          Correct_Lost_Tracking))
  # If last Lost_Tracking = TRUE, rest are true
  # If last Lost_Tracking = FALSE, cell died or we are at end of measurement
  curated_cell_data_complete <- curated_cell_data_complete %>%
    tidyr::fill(., Correct_Lost_Tracking)
  # If Lost_Tracking = TRUE, we don't know Live_Cells value
  # Otherwise, if measurements stop unexpectedly, cell has died
  curated_cell_data_complete <- curated_cell_data_complete %>%
    mutate(Correct_Live_Cells = ifelse(is.na(Live_Cells),
                                       ifelse(!is.na(previous_lost_tracking),
                                              ifelse(previous_lost_tracking, NA, FALSE),
                                              Live_Cells),
                                       Live_Cells))
  last_live_cell_value <- curated_cell_data_complete %>%
    summarise(last_live_cell_value = reduce(Correct_Live_Cells, `&&`))
  # Fill last recorded Live_Cell value to the end
  curated_cell_data_complete <- curated_cell_data_complete %>%
    left_join(last_live_cell_value) %>%
    mutate(Correct_Live_Cells = ifelse(is.na(Correct_Live_Cells),
                                       last_live_cell_value,
                                       Correct_Live_Cells))
  # reassign correct values and remove helper columns
  curated_cell_data_complete <- curated_cell_data_complete %>%
    mutate(Live_Cells = Correct_Live_Cells, Lost_Tracking = Correct_Lost_Tracking) %>%
    select(-Correct_Live_Cells, -Correct_Lost_Tracking, -last_seen_alive,
           -last_live_cell_value, -previous_live_cells, -previous_lost_tracking)
  return(curated_cell_data_complete)
}

main <- function() {
  synLogin()
  curated_cell_data <- fetch_syn_table("syn11378063")
  censored_wells <- fetch_syn_table("syn11709601") %>%
    select(Experiment, Well)
  gaps <- fetch_syn_table("syn18384770") %>%
    select(Experiment, Well, ObjectTrackID)
  corrected_indices <- get_corrected_indices()
  potential_errors_corrected <- fetch_syn_csv("syn18134075")
  zombie_cells_corrected <- fetch_syn_csv("syn18160422")
  lost_tracking_corrected <- fetch_syn_csv("syn18174013")
  curated_cell_data_updated <- anti_join(curated_cell_data, censored_wells) %>%
    anti_join(gaps) %>%
    anti_join(corrected_indices, by = c("Experiment", "ObjectTrackID",
                                        "Well", "TimePoint")) %>%
    anti_join(potential_errors_corrected, by = c("Experiment", "ObjectTrackID",
                                                 "Well", "TimePoint")) %>%
    anti_join(zombie_cells_corrected, by = c("Experiment", "ObjectTrackID",
                                                 "Well", "TimePoint")) %>%
    anti_join(lost_tracking_corrected, by = c("Experiment", "ObjectTrackID",
                                                 "Well", "TimePoint")) %>%
    bind_rows(corrected_indices, potential_errors_corrected,
              zombie_cells_corrected, lost_tracking_corrected)
  curated_cell_data_all_timepoints <- fill_in_missing_timepoints(curated_cell_data_updated)
  curated_cell_data_complete <- fill_in_missing_labels(curated_cell_data_all_timepoints) %>%
    select(Experiment, Well, ObjectTrackID, TimePoint,
            Live_Cells, Lost_Tracking, dplyr::everything())
  write_csv(curated_cell_data_complete, "clean_curated_cell_data.csv")
}

main()
