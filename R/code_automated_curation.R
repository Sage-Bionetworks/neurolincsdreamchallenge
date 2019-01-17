library(tidyverse)
library(data.table)

setwd('C:/Users/jaslin.kalra/Desktop')

# import curated survival data and original cell data files
#cd is the survival file, sd is the cell data file
sd <- read.csv('cell_data-AB-CS47iTDP.csv')

cd <- read.csv('cell_data_AB-CS47iTDP-Survival_EtoH.csv')

#add new columns
sd[c("ObjectTrackID","Live_Cells","Mistracked","Out_of_Focus","Lost_Tracking")] <- NA

#select the measurement tag(RFP-DFTrCy5/FITC-DFTrCy5)
sd <- sd[which(sd$MeasurementTag == 'RFP-DFTrCy5'), ]

sd_wells <- unique(sd$Sci_WellID)

#look at this to see which well to skip
levels(sd_wells)

########change the length for the for-loop eg: 48/96 ########
curated_data <- data.frame()
for(n in 37:81){
  #to skip messy well/empty well
  if(n == 63) next
  if(n == 74| n == 75| n == 76)next

  sd_temp_row <- data.frame()
  cd_temp_row <- data.frame()
  
  sd_temp_row <- sd[sd$Sci_WellID == levels(sd_wells)[n], ]
  cd_temp_row <- cd[cd$Sci_WellID == levels(sd_wells)[n], ]
  notes <- tolower(cd_temp_row$Notes)
  
  x <- data.frame()
  
  for (i in 1:length(cd_temp_row$ObjectLabelsFound)){
    cd_temp_of <- cd_temp_row[cd_temp_row$ObjectLabelsFound == i, ]
    cd_temp_of <- cd_temp_of %>% replace(.=="", NA)
  
    sd_temp_of_total <- data.frame()
    
    #changing the conditions
    if ((as.character(cd_temp_of$Phenotype) == 'Dead') == TRUE){
     #Change the last 4 columns
     sd_temp_of <-  sd_temp_row[sd_temp_row$ObjectLabelsFound == i, ]
    
     sd_temp_of[(ncol(sd_temp_of)-3):ncol(sd_temp_of)][1,] <- c('FALSE', 'FALSE','FALSE','FALSE')
      sd_temp_of$ObjectTrackID[1] <- sd_temp_of[sd_temp_of$Timepoint == 0, ][1,]$ObjectLabelsFound
    
      x = rbind(x, sd_temp_of)
      
    }else if ((as.character(cd_temp_of$Phenotype) == 'x') == TRUE){
      sd_temp_of <-  sd_temp_row[sd_temp_row$ObjectLabelsFound == i, ]
    
      sd_temp_of[(ncol(sd_temp_of)-3):ncol(sd_temp_of)][1,] <- c('FALSE', 'TRUE','FALSE','FALSE')
      sd_temp_of$ObjectTrackID[1] <- sd_temp_of[sd_temp_of$Timepoint == 0, ][1,]$ObjectLabelsFound
      
      x = rbind(x, sd_temp_of)
    
    }else{
      corrected_time = cd_temp_of$Corrected
      time = paste('T', as.character(corrected_time),sep="")
      start_time = which(colnames(cd_temp_of) == 'T0')
      end_time = which(colnames(cd_temp_of)== time)
      temp_list = cd_temp_of[start_time:end_time]
      temp_list <- temp_list %>% replace(.== 'U', NA)
    
      #find the objectTrackID from the sd dataframe and combine them
      for (j in 1:length((temp_list))){
        sd_temp_of <- data.frame()
         temp_list[,j] <- as.numeric(as.character(temp_list[,j]))
          if (is.na(temp_list[,j]) == FALSE) {
             sd_temp_of <- sd_temp_row[sd_temp_row$ObjectLabelsFound == temp_list[,j], ]
             sd_temp_of <- sd_temp_of[(sd_temp_of$Timepoint == j-1),]
          }
          sd_temp_of_total <- rbind(sd_temp_of_total, sd_temp_of)
          sd_temp_of_total <- sd_temp_of_total[!duplicated(sd_temp_of_total), ]
      }
    
        #for double labeling:
        #sort it by blobarea and choose the first one appeared in the list (removing duplicated)
        double_label_rm = sd_temp_of_total[order(sd_temp_of_total[,'Timepoint'],-sd_temp_of_total[,'BlobArea']),]
        double_label_rm = double_label_rm[!duplicated(double_label_rm$Timepoint),]
        
        #For live cells
        for(j in 1:length(double_label_rm$ObjectTrackID)){
          double_label_rm$ObjectTrackID[j] <- double_label_rm[double_label_rm$Timepoint == 0, ][1,]$ObjectLabelsFound
          double_label_rm[(ncol(double_label_rm )-3):ncol(double_label_rm )][j,] <- c('TRUE', 'FALSE','FALSE','FALSE')
          }
        
        #for lost track
        for (j in 1:length(temp_list)){
          if(is.na(temp_list[,j]) == TRUE){
            lost_track_list = which(is.na(temp_list))-1
        
           for(j in 1:length(lost_track_list)){
              if ((lost_track_list[j] <= max(double_label_rm$Timepoint))) {
                lost_track = lost_track_list[j]
                if(nrow(double_label_rm[double_label_rm$Timepoint == lost_track-1,]) > 0){
                 double_label_rm[double_label_rm$Timepoint == lost_track-1,][(ncol(double_label_rm )-3):ncol(double_label_rm)] <- c('TRUE', 'FALSE','FALSE','TRUE')
                }
              }else{
                double_label_rm[double_label_rm$Timepoint == max(double_label_rm$Timepoint),][(ncol(double_label_rm )-3):ncol(double_label_rm)] <- c('TRUE', 'FALSE','FALSE','TRUE')
            }
           }
          }
        }
        
        #handle the stings from Notes
        out_of_focus =  grepl("\\out of frame at t|\\out of focus at t", notes[i])
        if (out_of_focus == TRUE) {
          out_of_focus_num = gsub("\\out of frame at t|\\out of focus at t", "", notes[i])
        }
        
        #for out of focus
        if (out_of_focus == TRUE){
          double_label_rm[double_label_rm$Timepoint == max(double_label_rm$Timepoint),][(ncol(double_label_rm )-3):ncol(double_label_rm)] <- c('TRUE', 'FALSE','TRUE','FALSE')
        }
        
        x <- rbind(x, double_label_rm)
    }
  }
  curated_data = rbind(curated_data, x)
}

#merging and get the final dataframe
new_data <- left_join(sd, curated_data ,by = c("ObjectCount", "ObjectLabelsFound", "MeasurementTag", "BlobArea", "BlobPerimeter", "Radius", "BlobCentroidX", "BlobCentroidY", "BlobCircularity", "Spread", "Convexity", "PixelIntensityMaximum", "PixelIntensityMinimum", "PixelIntensityMean", "PixelIntensityVariance", "PixelIntensityStdDev", "PixelIntensity1Percentile", "PixelIntensity5Percentile", "PixelIntensity10Percentile", "PixelIntensity25Percentile", "PixelIntensity50Percentile", "PixelIntensity75Percentile", "PixelIntensity90Percentile", "PixelIntensity95Percentile", "PixelIntensity99Percentile", "PixelIntensitySkewness", "PixelIntensityKurtosis", "PixelIntensityInterquartileRange", "Sci_PlateID", "Sci_WellID", "RowID", "ColumnID", "Timepoint")) 
new_data <- new_data[-c(34:38)]
#rename the cols
setnames(new_data, old=c("ObjectTrackID.y","Live_Cells.y", "Mistracked.y","Out_of_Focus.y","Lost_Tracking.y"),
                  new = c("ObjectTrackID", "Live_Cells","Mistracked","Out_of_Focus","Lost_Tracking"))

new_data[is.na(new_data)] <- ""

write.csv(new_data, 'automated_cell_AB-CS47iTDP-Survival(D-G)-for.csv')
