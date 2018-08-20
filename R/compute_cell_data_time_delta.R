# Add a distance column to cell data at syn11378063.
#
# To use: Rscript compute_cell_data_time_delta.R --outputPath curated_cell_data_with_distances.csv --outputSynapse syn15664274
# Omit either flag to omit its respective action.
# See Rscript compute_cell_data_time_delta.R --help

read_args <- function() {
  parser <- OptionParser()
  parser <- add_option(parser, "--outputPath",
                       type = "character",
                       help = "Where to write output to. By default,
                               no data will be written")
  parser <- add_option(parser, "--outputSynapse",
                       type = "character",
                       help = "Parent Synapse ID to output to. By default,
                               no output will be stored to Synapse.")
  parse_args(parser)
}

fetch_syn_table <- function(syn_id) {
  table <- synTableQuery(paste("select * from", syn_id))
  table_df <- table$asDataFrame() 
  return(table_df)
}

euclidean_distance_vectorized <- function(x1, y1, x2, y2) {
  distances <- purrr::pmap(list(x1, y1, x2, y2),
                           function(x1, y1, x2, y2) {
                             sqrt(sum((c(x1, y1) - c(x2, y2))^2))
                           })
  return(unlist(distances))
}

mutate_delta_time <- function(cell_data) {
  cell_data_mutated <- cell_data %>% 
    group_by(Experiment, ObjectTrackID, Well) %>%
    mutate(XCoordinate = as.double(XCoordinate), 
           YCoordinate = as.double(YCoordinate),
           previousXCoordinate = dplyr::lag(XCoordinate, order_by = TimePoint),
           previousYCoordinate = dplyr::lag(YCoordinate, order_by = TimePoint),
           distance = euclidean_distance_vectorized(previousXCoordinate,
                                         previousYCoordinate,
                                         XCoordinate,
                                         YCoordinate),
           distance = ifelse(is.na(ObjectTrackID), NA, distance)) %>% 
    select(-previousXCoordinate, -previousYCoordinate)
  return(cell_data_mutated)
}

main <- function() {
  library(optparse)
  args <- read_args()
  if(all(is.null(args$outputPath), is.null(args$outputSynapse))) {
    print("No --outputPath or --outputSynapse specified. Doing nothing.")
    return()
  }
  
  library(tidyverse)
  library(synapser)

  synLogin()
  cell_data <- fetch_syn_table("syn11378063")
  cell_data_mutated <- mutate_delta_time(cell_data)
  if(is.character(args$outputPath)) {
    write_csv(cell_data_mutated, args$outputPath)
  }
  if(is.character(args$outputSynapse)) {
    if(is.character(args$outputPath)) {
      f <- synapser::File(args$outputPath, parent = args$outputSynapse)
    } else {
      temp_path <- paste0(tempfile(), ".csv")
      write_csv(cell_data_mutated, temp_path)
      f <- synapser::File(temp_path, parent = args$outputSynapse)
    }
    synStore(f)
  }
}

main()