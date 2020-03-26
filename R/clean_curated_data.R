#!/usr/bin/env Rscript
# Produce a "clean" curated cell file with all potential timepoints
# present and correct values for Live_Cells and Lost_Tracking columns

library(synapser)
library(tidyverse)

SYNAPSE_PARENT <- "syn7837267"

#' Ensure that a dataframe has certain column data types
#'
#' @param df A data.frame with zero or more of columns ObjectTrackID,
#' TimePoint, Live_Cells, Mistracked, Lost_Tracking, Out_of_Focus,
#' XCoordinate, YCoordinate, ROW_ID, or ROW_VERSION
#' @return data.frame with correct data types
correct_types <- function(df) {
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
  if (has_name(df, c("ROW_ID", "ROW_VERSION"))) {
      df <- df %>% select(-ROW_ID, -ROW_VERSION)
  }
  return(as_tibble(df))
}

fetch_syn_table <- function(syn_id, cols = "*") {
  if (is.vector(cols)) {
    cols <- paste(cols, collapse = ",")
  }
  table <- synTableQuery(paste("select", cols, "from", syn_id))
  table_df <- table$asDataFrame() %>%
    as_tibble() %>%
    correct_types()
  return(table_df)
}

fetch_syn_csv <- function(syn_id) {
  f <- synGet(syn_id)
  df <- read_csv(f$path) %>%
    as_tibble() %>%
    correct_types()
  return(df)
}

get_corrected_indices <- function() {
  corrected_abc <- fetch_syn_table("syn17087846")
  corrected_lincs <- fetch_syn_table("syn17096732")
  corrected_sod <- fetch_syn_table("syn17933845")
  corrected_indices <- bind_rows(corrected_abc, corrected_lincs, corrected_sod) %>%
    filter(!is.na(Experiment), !is.na(Well), !is.na(ObjectTrackID), !is.na(TimePoint)) %>%
    mutate(Live_Cells = as.logical(Live_Cells),
           Lost_Tracking = as.logical(Lost_Tracking),
           XCoordinate = if_else(is.na(XCoordinate), Xcoordinate, XCoordinate),
           YCoordinate = if_else(is.na(YCoordinate), Ycoordinate, YCoordinate)) %>%
    select(-Xcoordinate, -Ycoordinate)
  return(corrected_indices)
}

#' Returns records which "should" exist in the curated data but do not.
#' A record "should" exist if:
#'
#' 1. It is a valid timepoint with respect to the Experiment
#' 2. There is a TimePoint in this track (Experiment/Well/ObjectTrackID combo)
#'    that is greater than the TimePoint of this missing record.
find_gaps <- function(curated_cell_data) {
  curated_cell_data <- curated_cell_data %>%
    filter(!is.na(ObjectTrackID))
  last_recorded_timepoints <- curated_cell_data %>%
    group_by(Experiment, Well, ObjectTrackID) %>%
    summarize(last_recorded_timepoint = max(TimePoint))
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
  gaps <- curated_cell_data %>%
    full_join(complete_reference,
              by=c("Experiment", "Well", "ObjectTrackID", "TimePoint")) %>%
    left_join(last_recorded_timepoints, by = c("Experiment", "Well", "ObjectTrackID")) %>%
    filter(TimePoint <= last_recorded_timepoint,
           is.na(ObjectLabelsFound)) %>%
    distinct(Experiment, Well, ObjectTrackID, TimePoint)
  return(gaps)
}

#' Insert all potential timepoints for each experiment
#'
#' @param curated_cell_data A data.frame containing records from
#' the original curated cell data file (syn11378063)
#' @param reference A Synapse table containing columns Experiment,
#' TimePointBegin, and TimePointEnd
#' @return data.frame with all possible timepoint values w.r.t. the experiment
fill_in_missing_timepoints <- function(curated_cell_data, reference="syn11817859") {
  timepoint_reference <- fetch_syn_table(
    reference, c("Experiment", "TimePointBegin", "TimePointEnd")) %>%
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
  curated_cell_data <- curated_cell_data %>%
    mutate(TimePoint = ifelse(Experiment == "LINCS062016B",
                              TimePoint - 1, TimePoint))
  curated_cell_data_full <- complete_reference %>%
    left_join(curated_cell_data) %>%
    arrange(Experiment, Well, ObjectTrackID, TimePoint) %>%
    mutate(Live_Cells = as.logical(Live_Cells),
           Lost_Tracking = as.logical(Lost_Tracking)) %>%
    group_by(Experiment, Well, ObjectTrackID)
  return(curated_cell_data_full)
}

#' Fill in columns Live_Cells and Lost_Tracking
#'
#' @param curated_cell_data_all_timepoints The output from
#' \code{fill_in_missing_timepoints}
#' @return A "clean" curated cell data.frame
fill_in_missing_labels <- function(curated_cell_data_all_timepoints) {
  # Move Lost_Tracking = TRUE to next TimePoint
  # If Lost_Tracking = TRUE, subsequent Lost_Tracking values are true
  # If Lost_Tracking = TRUE, ObjectLabelsFound must be NA
  curated_cell_data_complete <- curated_cell_data_all_timepoints %>%
    mutate(first_lost_track = min(which(Lost_Tracking)) - 1,
           Correct_Lost_Tracking = ifelse(!Lost_Tracking, FALSE, NA)) %>%
    mutate(Correct_Lost_Tracking = ifelse(TimePoint > first_lost_track, TRUE, Correct_Lost_Tracking)) %>%
    mutate(Correct_Lost_Tracking = ifelse(TimePoint == first_lost_track, FALSE, Correct_Lost_Tracking)) %>%
    mutate(ObjectLabelsFound = ifelse(!is.na(Correct_Lost_Tracking),
                                      ifelse(Correct_Lost_Tracking, NA, ObjectLabelsFound),
                                      ObjectLabelsFound))
  # If Live_Cells is False, subsequent Live_Cells values are FALSE
  # In addition, if measurements stop unexpectedly, cell has died
  # If Lost_Tracking is TRUE, Live_Cells is NA
  curated_cell_data_complete <- curated_cell_data_complete %>%
    mutate(first_death = min(which(!Live_Cells)) - 1, # is Inf if Live_Cells is never FALSE
           last_measurement = min(which(is.na(Live_Cells) && is.na(Lost_Tracking))), # is Inf if measurements are complete
           Correct_Live_Cells = ifelse(TimePoint >= first_death, FALSE, Live_Cells)) %>%
    mutate(Correct_Live_Cells = ifelse(TimePoint > last_measurement, FALSE, Correct_Live_Cells)) %>%
    mutate(Correct_Live_Cells = ifelse(!is.na(Correct_Lost_Tracking),
                                       ifelse(Correct_Lost_Tracking, NA, Correct_Live_Cells),
                                       Correct_Live_Cells)) %>%
    mutate(Correct_Live_Cells = ifelse(is.na(Correct_Live_Cells),
                                       ifelse(is.na(Correct_Lost_Tracking), FALSE, Correct_Live_Cells),
                                       Correct_Live_Cells))
  # If Lost_Tracking = TRUE, we don't know Live_Cells value
  #curated_cell_data_complete <- curated_cell_data_complete %>%
  #  mutate(Correct_Live_Cells = ifelse(Correct_Lost_Tracking, NA, Live_Cells))
  #last_live_cell_value <- curated_cell_data_complete %>%
  #  summarise(last_live_cell_value = reduce(Correct_Live_Cells, `&&`))
  # Fill last recorded Live_Cell value to the end
  #curated_cell_data_complete <- curated_cell_data_complete %>%
  #  left_join(last_live_cell_value) %>%
  #  mutate(Correct_Live_Cells = ifelse(is.na(Correct_Live_Cells),
  #                                     last_live_cell_value,
  #                                     Correct_Live_Cells))
  # reassign correct values and remove helper columns
  curated_cell_data_complete <- curated_cell_data_complete %>%
    mutate(Live_Cells = Correct_Live_Cells, Lost_Tracking = Correct_Lost_Tracking) %>%
    select(-Correct_Live_Cells, -Correct_Lost_Tracking, -first_lost_track,
           -last_measurement, -first_death)
  return(curated_cell_data_complete)
}

drop_specific_rows <- function(curated_cell_data) {
  # These rows had their index corrected
  #to_drop <- curated_cell_data %>%
  #  filter(Experiment == "LINCS062016A", Well == "D4",
  #         ObjectLabelsFound == 113, ObjectTrackID == 33)
  #curated_cell_data <- curated_cell_data %>%
  #  anti_join(to_drop, by = c("Experiment", "Well", "ObjectLabelsFound", "ObjectTrackID"))
  #return(curated_cell_data)

  # This comes from issue 19 https://github.com/Sage-Bionetworks/neurolincsdreamchallenge/issues/19
  to_drop <- curated_cell_data %>%
    filter(Experiment == "AB-SOD1-KW4-WTC11-Survival", Well == "B1", ObjectTrackID == 6) %>%
    select(Experiment, Well, ObjectTrackID)
  # from https://github.com/Sage-Bionetworks/neurolincsdreamchallenge/issues/5#issuecomment-583085143
  #to_drop_2 <-  curated_cell_data %>%
  #  filter(Experiment == "AB-CS47iTDP-Survival", Well == "D11", ObjectTrackID == 21)
  #curated_cell_data_corrected <- curated_cell_data %>%
  #  anti_join(to_drop) %>%
  #  anti_join(to_drop_2)
  return(curated_cell_data_corrected)
}

#' Mark gaps as Lost_Tracking = TRUE
#'
#' Since the original protocol is to set the TimePoint before the tracking
#' was lost to Lost_Tracking = TRUE we will mark the previous TimePoint
#' as the gap and all Lost_Tracking values leading up to this first TRUE
#' value as FALSE (Since once tracking is lost it cannot be found again).
mark_gaps_as_lost_tracking <- function(curated_cell_data, gaps) {
  gaps <- gaps %>%
    mutate(gap_timepoint = TimePoint) %>%
    select(Experiment, Well, ObjectTrackID, gap_timepoint)
  curated_cell_data <- curated_cell_data %>%
    left_join(gaps, by = c("Experiment", "Well", "ObjectTrackID")) %>%
    group_by(Experiment, Well, ObjectTrackID) %>%
    mutate(gap_timepoint = median(gap_timepoint, na.rm = TRUE)) %>% # there is only one gap per track
    ungroup() %>%
    mutate(Lost_Tracking = ifelse(!is.na(gap_timepoint), # this track has a gap
                                  ifelse(TimePoint < gap_timepoint, FALSE, TRUE),
                                  Lost_Tracking),
           Live_Cells = ifelse(Lost_Tracking, NA, Live_Cells),
           ObjectLabelsFound = ifelse(Lost_Tracking, NA, ObjectLabelsFound)) %>%
    select(-gap_timepoint)
  return(curated_cell_data)
}

#' Ensure the curated data satisfies all the rules as listed here:
#' https://github.com/Sage-Bionetworks/neurolincsdreamchallenge/issues/17
validate_curated_cell_data <- function(curated_cell_data) {
  problem <- "All Experiment/Well/ObjectTrackID/TimePoint must be unique"
  problem_tracks <- curated_cell_data %>%
    count(Experiment, Well, ObjectTrackID, TimePoint) %>%
    filter(n > 1)
  if (nrow(problem_tracks)) {
    print(problem)
    return(problem_tracks)
  }
  problem <- "All TimePoints must be present for that respective Experiment"
  timepoint_reference <- fetch_syn_table(
    "syn11817859", c("Experiment", "TimePointBegin", "TimePointEnd")) %>%
    select(Experiment, TimePointBegin, TimePointEnd)
  problem_tracks <- purrr::pmap_dfr(timepoint_reference, function(Experiment_, TimePointBegin, TimePointEnd) {
    curated_cell_data %>%
      filter(Experiment == Experiment_) %>%
      group_by(Experiment, Well, ObjectTrackID) %>%
      summarize(n = n(), n_correct = TimePointEnd - TimePointBegin + 1) %>%
      filter(n != n_correct)
  })
  if (nrow(problem_tracks)) {
    print(problem)
    return(problem_tracks)
  }
  problem <- "If Live_Cells = FALSE, all following Live_Cells must also be FALSE"
  problem_tracks <- curated_cell_data %>%
    group_by(Experiment, Well, ObjectTrackID) %>%
    mutate(last_seen_alive = max(which(Live_Cells)) - 1) %>%
    filter(TimePoint < last_seen_alive, !Live_Cells) %>%
    distinct(Experiment, Well, ObjectTrackID)
  if (nrow(problem_tracks)) {
    print(problem)
    return(problem_tracks)
  }
  problem <- "If Lost_Tracking = TRUE, the rest must be TRUE"
  problem_tracks <- curated_cell_data %>%
    group_by(Experiment, Well, ObjectTrackID) %>%
    mutate(first_lost_track = min(which(Lost_Tracking))) %>%
    filter(TimePoint > first_lost_track, !Lost_Tracking) %>%
    distinct(Experiment, Well, ObjectTrackID)
  if (nrow(problem_tracks)) {
    print(problem)
    return(problem_tracks)
  }
  problem <- "If Lost_Tracking = TRUE, then ObjectLabelsFound must be NA"
  problem_tracks <- curated_cell_data %>%
    filter(Lost_Tracking, !is.na(ObjectLabelsFound)) %>%
    distinct(Experiment, Well, ObjectTrackID)
  if (nrow(problem_tracks)) {
    print(problem)
    return(problem_tracks)
  }
  problem <- "If Lost_Tracking = TRUE, then Live_Cells must be NA"
  problem_tracks <- curated_cell_data %>%
    filter(Lost_Tracking, !is.na(Live_Cells)) %>%
    distinct(Experiment, Well, ObjectTrackID)
  if (nrow(problem_tracks)) {
    print(problem)
    return(problem_tracks)
  }
}

main <- function() {
  synLogin()
  curated_cell_data <- fetch_syn_table("syn11378063") %>%
    filter(!is.na(ObjectTrackID)) # If there is no  ground-truth, there is nothing we can do
  censored_wells <- fetch_syn_table("syn11709601") %>%
    select(Experiment, Well)
  gaps <- fetch_syn_table("syn18384770") %>%
    select(Experiment, Well, ObjectTrackID, TimePoint) %>%
    arrange(Experiment, Well, ObjectTrackID, TimePoint) %>%
    distinct(Experiment, Well, ObjectTrackID, .keep_all = TRUE) # only keep the earliest gap
  # We need to remove this specific track because it contains a gap (TimePoint 21)
  corrected_indices <- get_corrected_indices()
  potential_errors_corrected <- fetch_syn_csv("syn18134075")
  zombie_cells_corrected <- fetch_syn_csv("syn18160422")
  lost_tracking_corrected <- fetch_syn_csv("syn18174013")
  uneven_tracks_corrected <- fetch_syn_csv("syn21568415")
  issue_19_corrected <- fetch_syn_csv("syn21574264")
  all_corrected_tracks <- bind_rows(uneven_tracks_corrected, corrected_indices,
                                    potential_errors_corrected, zombie_cells_corrected,
                                    lost_tracking_corrected, issue_19_corrected) %>%
    distinct(Experiment, Well, ObjectTrackID, TimePoint, .keep_all = TRUE)
  curated_cell_data_updated <- anti_join(curated_cell_data, censored_wells) %>%
    anti_join(corrected_indices, by = c("Experiment", "ObjectTrackID", "Well", "TimePoint")) %>%
    anti_join(potential_errors_corrected, by = c("Experiment", "ObjectTrackID", "Well")) %>%
    anti_join(zombie_cells_corrected, by = c("Experiment", "ObjectTrackID", "Well")) %>%
    anti_join(lost_tracking_corrected, by = c("Experiment", "ObjectTrackID", "Well")) %>%
    anti_join(uneven_tracks_corrected, by = c("Experiment", "ObjectTrackID", "Well", "TimePoint")) %>%
    anti_join(issue_19_corrected, by = c("Experiment", "ObjectTrackID", "Well", "TimePoint")) %>%
    bind_rows(all_corrected_tracks) %>%
    drop_specific_rows() %>%
    #rev() %>%
    #distinct(Experiment, Well, ObjectTrackID, TimePoint, .keep_all = T) %>%
    arrange(Experiment, Well, ObjectTrackID, TimePoint)
  curated_cell_data_all_timepoints <- fill_in_missing_timepoints(curated_cell_data_updated)
  # TODO: we still have TimePoints before the gap being marked as Lost_Tracking = NA. Is this right?
  curated_cell_data_complete <- fill_in_missing_labels(curated_cell_data_all_timepoints) %>%
    mark_gaps_as_lost_tracking(gaps) %>%
    select(Experiment, Well, ObjectTrackID, TimePoint,
            Live_Cells, Lost_Tracking, dplyr::everything())
  problem_tracks <- validate_curated_cell_data(curated_cell_data_complete)
  if (!is.null(problem_tracks)) {
    return(problem_tracks)
  } else {
    fname <- "curated_cell_data.csv"
    write_csv(curated_cell_data_complete, fname)
    f <- synapser::File(fname, parent = SYNAPSE_PARENT)
    synStore(f)
    unlink(fname)
  }
}

main()
