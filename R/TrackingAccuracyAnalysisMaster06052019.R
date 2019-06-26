###THIS CODE GENERATES COMBINED TRACKING READOUTS, COMBINED SURVIVAL OUTPUT, AND COMBINED FEATURES
###WRITTEN BY JEREMY LINSLEY JEREMY.LINSLEY@GLADSTONE.UCSF.EDU

################################################
#Import Dependencies and clear R environment####
################################################
library(ggplot2)
library(plyr)
library(dplyr)
library(splines)
library(survival)
library(reshape)
library(lattice)
library(stringr)
library(plotly)
library(tidyr)
library(Rtsne)
library(RColorBrewer)
library(synapser)

rm(list=ls())
synapser::synLogin()
################################################
#import most recent curation data###############
################################################

read_syn_csv <- function(synapse_id) {
    f <- synapser::synGet(synapse_id)
    df <- readr::read_csv(f$path)
    return(df)
}

trackingResults= read_syn_csv("syn18411380")

#Correct PP timepoint- already done in later verisons of cleaned data
#trackingResults$TimepointCor=ifelse(trackingResults$Experiment=="LINCS062016B", 1,0)
#trackingResults$TimePoint=(trackingResults$TimePoint)-(trackingResults$TimepointCor)

#Give unique identifiers
trackingResults$Plate_Object_Well_Time=paste(trackingResults$Experiment,trackingResults$ObjectLabelsFound,trackingResults$Well,trackingResults$TimePoint, sep="_")
trackingResults$Plate_Object_Well=paste(trackingResults$Experiment,trackingResults$ObjectLabelsFound,trackingResults$Well, sep="_")

#Filter out objects that come up after T0
trackingResults$sub=ifelse(trackingResults$TimePoint==0&is.na(trackingResults$ObjectLabelsFound), 0,1)
Tracks=subset(trackingResults, trackingResults$sub==1)
Tracks$Experiment=as.factor(Tracks$Experiment)
Tracks$Well=as.factor(Tracks$Well)

#Shorten and clean up tracks
TracksShort=Tracks[,c("ObjectLabelsFound","Plate_Object_Well","Plate_Object_Well_Time","Live_Cells","Mistracked","Out_of_Focus","Lost_Tracking")]
TracksShort$Live_Cells=as.logical(TracksShort$Live_Cells)
TracksShort$Mistracked=as.logical(TracksShort$Mistracked)
TracksShort$Out_of_Focus=as.logical(TracksShort$Out_of_Focus)
TracksShort$Lost_Tracking=as.logical(TracksShort$Lost_Tracking)

names(TracksShort)[names(TracksShort)=='ObjectLabelsFound'] <- 'Manual_Curation'
#names(TracksShort)[names(TracksShort)=='ObjectTrackID'] <- 'ObjectLabelsFound'

#List and eliminate duplicate tracks
ListDups=TracksShort[duplicated(TracksShort$Plate_Object_Well_Time),]

TracksShortened=TracksShort[!duplicated(TracksShort$Plate_Object_Well_Time), ]



TracksShortened$Plate_Object_Well_Time2=TracksShortened$Plate_Object_Well_Time
TracksShortened=separate(data=TracksShortened, col=Plate_Object_Well_Time2, into = c('Plate','Object','Well','Tracks_Time'), sep = "_")
TracksShortened$Tracks_Time=as.numeric(TracksShortened$Tracks_Time)

TracksShortened$Plate=NULL
TracksShortened$Object=NULL
TracksShortened$Well=NULL



######################################################################################
#ImportRefinedFeatures and add to curation for features+curation data###############
######################################################################################

refinedfeaturesABCS47iTDPSurvival= read_syn_csv("syn18879697")
refinedfeaturesABCS47iTDPSurvival$Experiment="AB-CS47iTDP-Survival"
refinedfeaturesABSOD1KW4WTC11= read_syn_csv("syn18879698")
refinedfeaturesABSOD1KW4WTC11$Experiment="AB-SOD1-KW4-WTC11-Survival"
refinedfeaturesAB7SOD1KW4WTC11Survivalexp3= read_syn_csv("syn18879696")
refinedfeaturesAB7SOD1KW4WTC11Survivalexp3$Experiment="AB7-SOD1-KW4-WTC11-Survival-exp3"
refinedfeaturesKSABiMNTDP43Survival= read_syn_csv("syn18879699")
refinedfeaturesKSABiMNTDP43Survival$Experiment="KS-AB-iMN-TDP43-Survival"
refinedfeaturesLINCS062016A= read_syn_csv("syn18914415")
refinedfeaturesLINCS062016A$Experiment="LINCS062016A"
refinedfeaturesLINCS062016B= read_syn_csv("syn18879700")
refinedfeaturesLINCS062016B$Experiment="LINCS062016B"
refinedfeaturesLINCS062016B$ElapsedHours=NULL
refinedfeaturesLINCS092016A= read_syn_csv("syn18914422")
refinedfeaturesLINCS092016A$Experiment="LINCS092016A"
refinedfeaturesLINCS092016B= read_syn_csv("syn18914424")
refinedfeaturesLINCS092016B$Experiment="LINCS092016B"

refinedfeaturesmerge=rbind(refinedfeaturesABCS47iTDPSurvival,
                           refinedfeaturesABSOD1KW4WTC11,
                           refinedfeaturesAB7SOD1KW4WTC11Survivalexp3,
                           refinedfeaturesKSABiMNTDP43Survival,
                           refinedfeaturesLINCS062016A,
                           refinedfeaturesLINCS062016B,
                           refinedfeaturesLINCS092016A,
                           refinedfeaturesLINCS092016B)


#Give unique identifiers
refinedfeaturesmerge$Plate_Object_Well_Time=paste(refinedfeaturesmerge$Experiment,refinedfeaturesmerge$ObjectLabelsFound,refinedfeaturesmerge$Sci_WellID,refinedfeaturesmerge$Timepoint, sep="_")
refinedfeaturesmerge$Plate_Object_Well=paste(refinedfeaturesmerge$Experiment,refinedfeaturesmerge$ObjectLabelsFound,refinedfeaturesmerge$Sci_WellID, sep="_")

#Remove duplicates
refinedfeaturesmerge=refinedfeaturesmerge[!duplicated(refinedfeaturesmerge$Plate_Object_Well_Time), ]


MergeFeaturesManualCuration=merge(refinedfeaturesmerge, TracksShortened, by="Plate_Object_Well_Time")


##Writeout Features and Curation
write.csv(MergeFeaturesManualCuration, "ManualCurationFeatures.csv") # syn18914552


######################################################################################
###ImportSurvivalFiles that use tracking as endpoint for survival###############
######################################################################################


#####Import survival and feature data

HRsurv1= read_syn_csv("syn18914439")
HRsurv1$MeasurementTag=NULL
HRsurv1$Experiment="AB-CS47iTDP-Survival"
HRsurv2= read_syn_csv("syn18914432")
HRsurv2$Experiment="AB-SOD1-KW4-WTC11-Survival"
HRsurv3= read_syn_csv("syn18914431")
HRsurv3$Experiment="AB7-SOD1-KW4-WTC11-Survival-exp3"
HRsurv4= read_syn_csv("syn18914433")
HRsurv4$Experiment="KS-AB-iMN-TDP43-Survival"
HRsurv5= read_syn_csv("syn18914434")
HRsurv5$Experiment="LINCS062016A"
HRsurv6= read_syn_csv("syn18914435")
HRsurv6$Experiment="LINCS062016B"
HRsurv7= read_syn_csv("syn18914437")
HRsurv7$Experiment="LINCS092016A"
HRsurv8= read_syn_csv("syn18914440")
HRsurv8$Experiment="LINCS062016B"



HRsurvMerge=rbind(HRsurv1,HRsurv2,HRsurv3,HRsurv4,HRsurv5,HRsurv6,HRsurv7,HRsurv8)


HRsurvMerge$Plate_Object_Well_Time=paste(HRsurvMerge$Experiment,HRsurvMerge$ObjectLabelsFound,HRsurvMerge$Sci_WellID,HRsurvMerge$Timepoint, sep="_")
HRsurvMerge$Plate_Object_Well=paste(HRsurvMerge$Experiment,HRsurvMerge$ObjectLabelsFound,HRsurvMerge$Sci_WellID, sep="_")

HRsurvManual=subset(HRsurvMerge,HRsurvMerge$Curation_mode=="Manual")
colnames(HRsurvManual)[colnames(HRsurvManual)=='Timepoint']<-"Manual.Timepoint"
colnames(HRsurvManual)[colnames(HRsurvManual)=='Time']<-"Manual.Time"
HRsurvManual$Curation_mode=NULL

HRsurvYoungstrack=subset(HRsurvMerge, HRsurvMerge$Curation_mode=="Youngstrack")
HRsurvYoungstrack=HRsurvYoungstrack[,c("Timepoint","Plate_Object_Well")]
colnames(HRsurvYoungstrack)[colnames(HRsurvYoungstrack)=='Timepoint']<-"Youngstrack.Timepoint"

HRsurvProximity=subset(HRsurvMerge,HRsurvMerge$Curation_mode=="Proximity")
HRsurvProximity=HRsurvProximity[,c("Timepoint","Plate_Object_Well")]
colnames(HRsurvProximity)[colnames(HRsurvProximity)=='Timepoint']<-"Proximity.Timepoint"


HRsurvOverlap=subset(HRsurvMerge,HRsurvMerge$Curation_mode=="Galaxy")
HRsurvOverlap=HRsurvOverlap[!duplicated(HRsurvOverlap$Plate_Object_Well_Time), ]
HRsurvOverlap=HRsurvOverlap[,c("Timepoint","Plate_Object_Well")]
colnames(HRsurvOverlap)[colnames(HRsurvOverlap)=='Timepoint']<-"Overlap.Timepoint"


HRsurvMerge2=merge(HRsurvManual,HRsurvYoungstrack, by= "Plate_Object_Well")
HRsurvMerge3=merge(HRsurvMerge2,HRsurvProximity, by= "Plate_Object_Well")
HRsurvMerge4=merge(HRsurvMerge3,HRsurvOverlap, by= "Plate_Object_Well")

###writeout Combined Survival
write.csv(HRsurvMerge4, "CombinedSurvivalComparison.csv") # syn18914533

MergeFeaturesManualCurationT0=subset(MergeFeaturesManualCuration,MergeFeaturesManualCuration$Timepoint==0)
colnames(MergeFeaturesManualCurationT0)[colnames(MergeFeaturesManualCurationT0)=='Plate_Object_Well.x']<-"Plate_Object_Well"
MergeFeaturesManualCuration2=merge(MergeFeaturesManualCurationT0, HRsurvMerge4, by="Plate_Object_Well")

###writeout Survival and Features
write.csv(MergeFeaturesManualCuration2, "CombinedSurvivalandFeatures.csv") # syn18914524


######################################################################################
###Import and combine  tracking algorithm data with Curation data, then score##############
######################################################################################

######################################################################################
##############Import Young's tracking  ##############
######################################################################################


###Load and rename Young's Tracking Data in masterYoungsurv

surv1=  read_syn_csv("syn18914441")
surv1$Timepoint=surv1$TimePoint
surv1$TimePoint=NULL
surv1$Experiment=as.character(surv1$Experiment)
names(surv1)[names(surv1)=='Well'] <- 'Sci_WellID'
surv1=surv1[,c("Experiment","ObjectLabelsFound","ObjectTrackID","Sci_WellID","Timepoint")]



surv2= read_syn_csv("syn18914442")
names(surv2)[names(surv2)=='ObjectLabelsFound'] <- 'ObjectTrackID'
names(surv2)[names(surv2)=='ObjectLabelsFound_fromGalaxy'] <- 'ObjectLabelsFound'
surv2$MeasurementTag=NULL
surv2$Experiment=as.character(surv2$Experiment)
surv2$Sci_WellID=as.character(surv2$Sci_WellID)
surv2=surv2[,c("Experiment","ObjectLabelsFound","ObjectTrackID","Sci_WellID","Timepoint")]



surv3= read_syn_csv("syn18914443")
surv3$MeasurementTag=NULL
surv3$Experiment=as.character(surv3$Experiment)
surv3$Sci_WellID=as.character(surv3$Sci_WellID)
names(surv3)[names(surv3)=='ObjectLabelsFound'] <- 'ObjectTrackID'
names(surv3)[names(surv3)=='ObjectLabelsFound_fromGalaxy'] <- 'ObjectLabelsFound'
surv3=surv3[,c("Experiment","ObjectLabelsFound","ObjectTrackID","Sci_WellID","Timepoint")]


surv4= read_syn_csv("syn18914444")
surv4$MeasurementTag=NULL
surv4$Experiment=as.character(surv4$Experiment)
surv4$Sci_WellID=as.character(surv4$Sci_WellID)
names(surv4)[names(surv4)=='ObjectLabelsFound'] <- 'ObjectTrackID'
names(surv4)[names(surv4)=='ObjectLabelsFound_fromGalaxy'] <- 'ObjectLabelsFound'
surv4=surv4[,c("Experiment","ObjectLabelsFound","ObjectTrackID","Sci_WellID","Timepoint")]


surv5= read_syn_csv("syn18914445")
surv5$MeasurementTag=NULL
surv5$Experiment=as.character(surv5$Experiment)
surv5$Sci_WellID=as.character(surv5$Sci_WellID)
names(surv5)[names(surv5)=='ObjectLabelsFound'] <- 'ObjectTrackID'
names(surv5)[names(surv5)=='ObjectLabelsFound_fromGalaxy'] <- 'ObjectLabelsFound'
surv5=surv5[,c("Experiment","ObjectLabelsFound","ObjectTrackID","Sci_WellID","Timepoint")]


surv6= read_syn_csv("syn18914446")
surv6$MeasurementTag=NULL
surv6$Experiment=as.character(surv6$Experiment)
surv6$Sci_WellID=as.character(surv6$Sci_WellID)
names(surv6)[names(surv6)=='ObjectLabelsFound'] <- 'ObjectTrackID'
names(surv6)[names(surv6)=='ObjectLabelsFound_fromGalaxy'] <- 'ObjectLabelsFound'
surv6=surv6[,c("Experiment","ObjectLabelsFound","ObjectTrackID","Sci_WellID","Timepoint")]


surv7= read_syn_csv("syn18914447")
surv7$MeasurementTag=NULL
surv7$Experiment=as.character(surv7$Experiment)
surv7$Sci_WellID=as.character(surv7$Sci_WellID)
names(surv7)[names(surv7)=='ObjectLabelsFound'] <- 'ObjectTrackID'
names(surv7)[names(surv7)=='ObjectLabelsFound_galaxy'] <- 'ObjectLabelsFound'
surv7=surv7[,c("Experiment","ObjectLabelsFound","ObjectTrackID","Sci_WellID","Timepoint")]


surv8= read_syn_csv("syn18914448")
surv8$MeasurementTag=NULL
surv8$Timepoint.PP=NULL
surv8$Experiment=as.character(surv8$Experiment)
surv8$Sci_WellID=as.character(surv8$Sci_WellID)
names(surv8)[names(surv8)=='ObjectLabelsFound'] <- 'ObjectTrackID'
names(surv8)[names(surv8)=='ObjectLabelsFound-galaxy'] <- 'ObjectLabelsFound'
surv8=surv8[,c("Experiment","ObjectLabelsFound","ObjectTrackID","Sci_WellID","Timepoint")]


#Merge Young tracking data
masterYoungsurv=rbind(surv1,surv2,surv3,surv4,surv5,surv6,surv7,surv8)
###Combine Young's Tracking Data with Manual Curation into YoungTracksMerged


##Find tracks not attempted in scoring
masterYoungsurv$sub=ifelse(masterYoungsurv$Timepoint==0&is.na(masterYoungsurv$ObjectLabelsFound), 0,1)
masterYoungTracks=subset(masterYoungsurv, masterYoungsurv$sub==1)

#Rename experiments to match other data
masterYoungTracks$Experiment <- gsub('AB7-SOD1-KW4-WTC11-exp3', 'AB7-SOD1-KW4-WTC11-Survival-exp3', masterYoungTracks$Experiment)
masterYoungTracks$Experiment <- gsub('AB-CS47iTDP', 'AB-CS47iTDP-Survival', masterYoungTracks$Experiment)
masterYoungTracks$Experiment=as.factor(masterYoungTracks$Experiment)

#Make ID for merge
masterYoungTracks$Plate_Object_Well_Time=paste(masterYoungTracks$Experiment,masterYoungTracks$ObjectTrackID,masterYoungTracks$Sci_WellID,masterYoungTracks$Timepoint, sep="_")
masterYoungTracks$Plate_Object_Well=paste(masterYoungTracks$Experiment,masterYoungTracks$ObjectTrackID,masterYoungTracks$Sci_WellID, sep="_")
masterYoungTracksShort=masterYoungTracks[,c("ObjectTrackID","Plate_Object_Well","Plate_Object_Well_Time", "Timepoint")]
#names(masterYoungTracksShort)[names(masterYoungTracksShort)=='ObjectLabelsFound'] <- 'ObjectLabelsFound.Young'
names(masterYoungTracksShort)[names(masterYoungTracksShort)=='ObjectTrackID'] <- 'ObjectTrackID.Young'
names(masterYoungTracksShort)[names(masterYoungTracksShort)=='Plate_Object_Well'] <- 'Plate_Object_Well.Young'


###writeout Raw Young's Tracking Data
masterYoungTracksShortOutput=masterYoungTracksShort
masterYoungTracksShortOutput=masterYoungTracksShortOutput[,c("ObjectTrackID.Young","Plate_Object_Well_Time")]
masterYoungTracksShortOutput=separate(data=masterYoungTracksShortOutput, col ="Plate_Object_Well_Time", into = c('Experiment', 'Object', 'Well', 'Time'), sep = "_")
write.csv(masterYoungTracksShortOutput, "RawVeronoitrackingData.csv") # syn18914555




#Merge all Young's tracks for which Human Curation is available


YoungTracksMerged=merge(masterYoungTracksShort,TracksShortened, by="Plate_Object_Well_Time", all=TRUE)
YoungTracksMerged$Plate_Object_Well_Time2=YoungTracksMerged$Plate_Object_Well_Time
YoungTracksMerged=separate(data= YoungTracksMerged, col=Plate_Object_Well_Time2, into=c('Plate', 'Object', 'Well','Time'), sep = "_")
YoungTracksMerged$Manual_Plate_Object_Well=paste(YoungTracksMerged$Plate,YoungTracksMerged$Manual_Curation,YoungTracksMerged$Well, sep = "_")




###Subset for just LINCS09 data with GEDI signal
#YoungTracksMergedLINCSA=subset(YoungTracksMerged, YoungTracksMerged$Plate=="LINCS092016A")
#YoungTracksMergedLINCSB=subset(YoungTracksMerged, YoungTracksMerged$Plate=="LINCS092016B")
#YoungTracksMerged=rbind(YoungTracksMergedLINCSA,YoungTracksMergedLINCSB)

###Score Young's tracking

##subset objects that were tracked based on curator perogative (dead cells and debri at T0, non-neuronal cells, clumped cells)
##Live_Cells==FALSE indicates dead cells + cells that weren't tracked because of curator choice (often clumped cells, non-neuronal, etc.)
##Live_Cells==FALSE&Mistracked==TRUE & Timepoint==0 gives only cells that weren't tracked because of curator choice

YoungTracksMerged$HumanFilter=paste(YoungTracksMerged$Live_Cells,YoungTracksMerged$Mistracked,YoungTracksMerged$Tracks_Time, sep = "_")
YoungTracksMerged=subset(YoungTracksMerged, !(YoungTracksMerged$HumanFilter=="FALSE_TRUE_0"))


##Perfect track scoring Young's tracking
    ##Summarize Manual Curation
    ##Remove Tracked objects not in manual curation at T0 (Young not attempted)=> Manual_Curation= NA at T0
YoungTracksMerged2a=YoungTracksMerged
YoungTracksMerged2a$HumanFilter2=paste(YoungTracksMerged2a$Timepoint,YoungTracksMerged2a$Manual_Curation, sep = "_")
YoungTracksMerged2a=subset(YoungTracksMerged2a, !(YoungTracksMerged2a$HumanFilter2=="0_NA"))
#    YoungTracksMerged2a=subset(YoungTracksMerged,!((YoungTracksMerged$Timepoint==0)&(is.na(YoungTracksMerged$Manual_Curation))))
    #Find max timepoint for a track that matches Manual curation
    YoungTracksMerged2a <- YoungTracksMerged2a %>%
      group_by(Manual_Plate_Object_Well) %>%
      ##Use Manual Curation Timepoint
      summarise(maxManual=max(Tracks_Time))
    names(YoungTracksMerged2a)[names(YoungTracksMerged2a)=='Manual_Plate_Object_Well'] <- 'Plate_Object_Well'


#########Filter out Live cells based on Manual Curation
  #  YoungTracksMerged= subset(YoungTracksMerged,YoungTracksMerged$Live_Cells==TRUE)

    ##Summarize Young Tracking
    YoungTracksMerged2b <- YoungTracksMerged %>%
      group_by(Plate_Object_Well.Young) %>%
      ##Use Tracking Timepoint
      summarise(maxYoung=max(Timepoint))
    names(YoungTracksMerged2b)[names(YoungTracksMerged2b)=='Plate_Object_Well.Young'] <- 'Plate_Object_Well'




    #merge summary max time points
    YoungTracksMerged4=merge(YoungTracksMerged, YoungTracksMerged2a, by="Plate_Object_Well")
    YoungTracksMerged4=merge(YoungTracksMerged4, YoungTracksMerged2b, by="Plate_Object_Well")

    ###Score tracks from T0
    YoungTracksMerged4=subset(YoungTracksMerged4,YoungTracksMerged4$Tracks_Time==0)

    ##Eliminate n's
    YoungTracksMerged4= subset(YoungTracksMerged4,!(is.na(YoungTracksMerged4$ObjectTrackID.Young)))

    #Scoring
    YoungTracksMerged4$PerfectTracksScore=ifelse(YoungTracksMerged4$maxManual==YoungTracksMerged4$maxYoung,1,0)
    YoungTracksMerged4$YoungUndertracked=ifelse(YoungTracksMerged4$maxManual>YoungTracksMerged4$maxYoung,1,0)
    YoungTracksMerged4$YoungOvertracked=ifelse(YoungTracksMerged4$maxManual<YoungTracksMerged4$maxYoung,1,0)

    #Summarize mean scoring
    YPn=sum(YoungTracksMerged4$PerfectTracksScore)
    YPd=length(YoungTracksMerged4$PerfectTracksScore)
    print("Young's perfect track score")
    YPs=((YPn/YPd)*100)
    print((YPn/YPd)*100)


#AAA=subset(YoungTracksMerged4,YoungTracksMerged4$YoungOvertracked==1)
#print(sum(AAA$YoungOvertracked))


        ##Score Per Track correct
        ##ie objects that match between Manual Curation and Tracking
        YoungTracksMerged$Timepoint=as.numeric(YoungTracksMerged$Timepoint)


        #Eliminate Objects in Young's tracking not in Manual Curation
        YoungTracksMerged=subset(YoungTracksMerged,!(is.na(YoungTracksMerged$Manual_Curation)))

        #Score
        YoungTracksMerged$Score=ifelse(YoungTracksMerged$Manual_Curation==YoungTracksMerged$ObjectTrackID.Young,1,0)
        YoungTracksMerged$Score=ifelse(is.na(YoungTracksMerged$ObjectTrackID.Young),0,YoungTracksMerged$Score)


        ###Subtract T0 from scoring as tracking was initiated with numbers from T0 and should match automatically
        YoungTracksMerged$Score=ifelse((YoungTracksMerged$Tracks_Time==0),NA,YoungTracksMerged$Score)
        YoungTracksMerged=subset(YoungTracksMerged,!(is.na(YoungTracksMerged$Score)))

        ###Time weighted scoring
        YoungTracksMerged$TimeScore=(YoungTracksMerged$Tracks_Time)*(YoungTracksMerged$Score)


        YTn=sum(YoungTracksMerged$Score)
        YTd=length(YoungTracksMerged$Score)
        print("Young's track score")
        YTs=((YTn/YTd)*100)
        print((YTn/YTd)*100)



###Merge and Summarize Stats
#Merge Perfect track and per track Stats
YoungTracksMerged$Plate_Object_Well_Time2=YoungTracksMerged$Plate_Object_Well_Time
YoungTracksMerged$Plate_Object_Well_Time2=gsub("-","",YoungTracksMerged$Plate_Object_Well_Time2)
YoungTracksMerged=separate(data=YoungTracksMerged, col=Plate_Object_Well_Time2, into=c('Plate', 'Object','Well','Time'), sep="_")
YoungTracksMerged$Plate_Well=paste(YoungTracksMerged$Plate,YoungTracksMerged$Well, sep="_")


YoungTracksMerged4$Plate_Object_Well_Time2=YoungTracksMerged4$Plate_Object_Well_Time
YoungTracksMerged4$Plate_Object_Well_Time2=gsub("-","",YoungTracksMerged4$Plate_Object_Well_Time2)
YoungTracksMerged4=separate(data=YoungTracksMerged4, col=Plate_Object_Well_Time2, into=c('Plate','Object', 'Well', 'Time'), sep="_")
YoungTracksMerged4$Plate_Well=paste(YoungTracksMerged4$Plate,YoungTracksMerged4$Well, sep="_")



##Summarize Stats
YoungTracksStats=summarise(group_by(YoungTracksMerged,Plate_Well),
             YoungPerWellTrackScore=mean(Score),
             YoungPerWellTrackN=length(Score)
             )


YoungTracksStats2=summarise(group_by(YoungTracksMerged4,Plate_Well),
                            YoungPerWellPerfectScore=mean(PerfectTracksScore),
                           YoungOverTrackTot=sum(YoungOvertracked),
                           YoungOverTrackAvg=mean(YoungOvertracked),
                           YoungUnderTrackTot=sum(YoungUndertracked),
                           YoungUnderTrackAvg=mean(YoungUndertracked),
                            YoungPerWellPerfectScoreN=length(PerfectTracksScore),
                            YoungPerWellPerfectScoreSum=sum(PerfectTracksScore)
)

##Merge Summary Stats
YoungTracksStats2=merge(YoungTracksStats, YoungTracksStats2, by = "Plate_Well")



######################################################################################
##################Import Overlap tracking##############
######################################################################################



####Load and rename Overlap tracking into
OLsurv1= read_syn_csv("syn18914368")

OLsurv2= read_syn_csv("syn18914371")

OLsurv3= read_syn_csv("syn18914375")

OLsurv4= read_syn_csv("syn18914369")

OLsurv5= read_syn_csv("syn18914378")
##Make PP adjustments
OLsurv5$PixelIntensityMaximum=as.integer(OLsurv5$PixelIntensityMaximum)
OLsurv5$PixelIntensityMinimum=as.integer(OLsurv5$PixelIntensityMinimum)
OLsurv5$PixelIntensity1Percentile=as.integer(OLsurv5$PixelIntensity1Percentile)
OLsurv5$MeasurementTag=as.factor(OLsurv5$MeasurementTag)
OLsurv5$Range.SD.FITC=NULL
OLsurv5$Range.FITC=NULL
  OLsurv5$Perim.BlobArea=NULL
  OLsurv5$ObjectLabelsFoundCurated=NULL
  OLsurv5$PixelIntensity90Percentile.RFP.DFTrCy5=NULL
  OLsurv5$Range.SD.RFP=NULL
  OLsurv5$Mean.SD.RFP=NULL
  OLsurv5$PixelIntensity5Percentile.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensityKurtosis.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensitySkewness.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensity95Percentile.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensity75Percentile.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensityMinimum.FITC.DFTrCy5=NULL
  OLsurv5$Perim.Circ=NULL
  OLsurv5$PixelIntensityMinimum.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensity95Percentile.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensity25Percentile.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensity50Percentile.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensityMaximum.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensityStdDev.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensity10Percentile.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensity1Percentile.FITC.DFTrCy5=NULL
  OLsurv5$PixelIntensity1Percentile.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensityStdDev.FITC.DFTrCy5=NULL
  OLsurv5$PixelIntensityMean.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensityInterquartileRange.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensityVariance.RFP.DFTrCy5=NULL
  OLsurv5$PixelIntensityMaximum.FITC.DFTrCy5=NULL
  OLsurv5$LiveDeadComment=NULL
  OLsurv5$Range.RFP=NULL
  OLsurv5$PixelIntensityMinimum.FITC.DFTrCy5=NULL
  OLsurv5$PixelIntensityMaximum=NA
  OLsurv5$PixelIntensityMinimum=NA
  OLsurv5$PixelIntensity1Percentile=NA
  OLsurv5$ MeasurementTag=NA

  names(OLsurv5)[names(OLsurv5)=='PixelIntensityMean.FITC.DFTrCy5'] <- 'PixelIntensityMean'
  names(OLsurv5)[names(OLsurv5)=='Mean.SD.FITC'] <- 'PixelIntensityStdDev'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensityInterquartileRange.FITC.DFTrCy5'] <- 'PixelIntensityInterquartileRange'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensity99Percentile.RFP.DFTrCy5'] <- 'PixelIntensity99Percentile'

  names(OLsurv5)[names(OLsurv5)=='PixelIntensity5Percentile.FITC.DFTrCy5'] <- 'PixelIntensity5Percentile'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensity10Percentile.FITC.DFTrCy5'] <- 'PixelIntensity10Percentile'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensity75Percentile.FITC.DFTrCy5'] <- 'PixelIntensity75Percentile'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensity95Percentile.FITC.DFTrCy5'] <- 'PixelIntensity95Percentile'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensity25Percentile.FITC.DFTrCy5'] <- 'PixelIntensity25Percentile'

  names(OLsurv5)[names(OLsurv5)=='PixelIntensity90Percentile.FITC.DFTrCy5'] <- 'PixelIntensity90Percentile'

  names(OLsurv5)[names(OLsurv5)=='PixelIntensityKurtosis.FITC.DFTrCy5'] <- 'PixelIntensityKurtosis'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensity50Percentile.FITC.DFTrCy5'] <- 'PixelIntensity50Percentile'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensity99Percentile.FITC.DFTrCy5'] <- 'PixelIntensity99Percentile'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensitySkewness.FITC.DFTrCy5'] <- 'PixelIntensitySkewness'
  names(OLsurv5)[names(OLsurv5)=='PixelIntensityVariance.FITC.DFTrCy5'] <- 'PixelIntensityVariance'

  names(OLsurv5)[names(OLsurv5)=='PixelIntensityVariance.FITC.DFTrCy5'] <- 'PixelIntensityVariance'

  OLsurv5$Radius=NA
OLsurv5$Variance=NULL
OLsurv5$Convexity=NA
OLsurv5$Spread=NA

  OLsurv5=OLsurv5[,c( "ObjectCount" ,                     "ObjectLabelsFound"   ,             "MeasurementTag"     ,
 "BlobArea"    ,                     "BlobPerimeter"    ,                "Radius"    ,
"BlobCentroidX"     ,               "BlobCentroidY"   ,                 "BlobCircularity"      ,
 "Spread"          ,                 "Convexity"        ,                "PixelIntensityMaximum" ,
 "PixelIntensityMinimum"  ,         "PixelIntensityMean"      ,         "PixelIntensityVariance"  ,
 "PixelIntensityStdDev"    ,         "PixelIntensity1Percentile"  ,      "PixelIntensity5Percentile"  ,
 "PixelIntensity10Percentile"   ,    "PixelIntensity25Percentile"   ,    "PixelIntensity50Percentile" ,
 "PixelIntensity75Percentile"   ,    "PixelIntensity90Percentile" ,      "PixelIntensity95Percentile"  ,
"PixelIntensity99Percentile"   ,    "PixelIntensitySkewness"    ,       "PixelIntensityKurtosis"   ,
 "PixelIntensityInterquartileRange", "Sci_PlateID"         ,             "Sci_WellID"         ,
 "RowID"         ,                   "ColumnID"          ,               "Timepoint" )]




OLsurv6= read_syn_csv("syn18914381")
OLsurv6$ElapsedHours=NULL
OLsurv6$PixelIntensityTotal=NULL
OLsurv6$BlobCentroidX_RefIntWeighted=NULL
OLsurv6$BlobCentroidY_RefIntWeighted=NULL

OLsurv7= read_syn_csv("syn18914386")
OLsurv7$ElapsedHours=NULL
OLsurv7$PixelIntensityTotal=NULL
OLsurv7$BlobCentroidX_RefIntWeighted=NULL
OLsurv7$BlobCentroidY_RefIntWeighted=NULL

OLsurv8= read_syn_csv("syn18914389")
OLsurv8$ElapsedHours=NULL
OLsurv8$PixelIntensityTotal=NULL
OLsurv8$BlobCentroidX_RefIntWeighted=NULL
OLsurv8$BlobCentroidY_RefIntWeighted=NULL

##Merge overlap data
masterOLsurv=rbind(OLsurv1,OLsurv2,OLsurv3,OLsurv4,OLsurv5,OLsurv6,OLsurv7,OLsurv8)



##Score Overlap data
masterOLsurv$Sci_PlateID=as.factor(masterOLsurv$Sci_PlateID)
##Standardize Sci_Plate id name to experiment name
masterOLsurv$Sci_PlateID=gsub(".*_","",masterOLsurv$Sci_PlateID)

#Make ID for merge
masterOLsurv$Plate_Object_Well_Time=paste(masterOLsurv$Sci_PlateID,masterOLsurv$ObjectLabelsFound,masterOLsurv$Sci_WellID,masterOLsurv$Timepoint, sep="_")
masterOLsurv$Plate_Object_Well=paste(masterOLsurv$Sci_PlateID,masterOLsurv$ObjectLabelsFound,masterOLsurv$Sci_WellID, sep="_")




##Shorten OL tracking output
masterOLsurv2=masterOLsurv
names(masterOLsurv2)[names(masterOLsurv2)=='ObjectLabelsFound'] <- 'ObjectLabelsFound_OL'
masterOLsurvShort=masterOLsurv2[,c("ObjectLabelsFound_OL","Plate_Object_Well","Plate_Object_Well_Time")]
masterOLsurvShort=masterOLsurvShort[!duplicated(masterOLsurvShort$Plate_Object_Well_Time), ]

###writeout Raw Overlap Tracking data

masterOLsurvShortOutput=masterOLsurvShort
masterOLsurvShortOutput=masterOLsurv2[,c("ObjectLabelsFound_OL","Plate_Object_Well_Time")]
masterOLsurvShortOutput=separate(data=masterOLsurvShortOutput,col ="Plate_Object_Well_Time", into = c('Experiment','Object','Well','Time'), sep="_" )
write.csv(masterOLsurvShortOutput, "RawOverlapTrackingData.csv") # syn18914553


##Merge Overlap tracking and Manual Curation
masterOLsurvMerged=merge(masterOLsurvShort,TracksShortened, by="Plate_Object_Well_Time", all=TRUE)
masterOLsurvMerged$Plate_Object_Well_Time2=masterOLsurvMerged$Plate_Object_Well_Time
masterOLsurvMerged=separate(data= masterOLsurvMerged, col=Plate_Object_Well_Time2, into=c('Plate', 'Object','Well', 'Time'), sep = "_")
masterOLsurvMerged$Manual_Plate_Well_Object=paste(masterOLsurvMerged$Plate,masterOLsurvMerged$Manual_Curation,masterOLsurvMerged$Well, sep = "_")

##subset objects that were tracked.

##Subset for LINCS092016A and LINCS092016B that have GEDI info

###Subset for just LINCS09 data with GEDI signal
#masterOLsurvMergedLINCSA=subset(masterOLsurvMerged, masterOLsurvMerged$Plate=="LINCS092016A")
#masterOLsurvMergedLINCSB=subset(masterOLsurvMerged, masterOLsurvMerged$Plate=="LINCS092016B")
#masterOLsurvMerged=rbind(masterOLsurvMergedLINCSA,masterOLsurvMergedLINCSB)


###Score Overlap tracking

##subset objects that were tracked based on curator perogative (dead cells and debri at T0, non-neuronal cells, clumped cells)
##Live_Cells==FALSE indicates dead cells + cells that weren't tracked because of curator choice (often clumped cells, non-neuronal, etc.)
##Live_Cells==FALSE&Mistracked==TRUE & Timepoint==0 gives only cells that weren't tracked because of curator choice

masterOLsurvMerged$HumanFilter=paste(masterOLsurvMerged$Live_Cells,masterOLsurvMerged$Mistracked,masterOLsurvMerged$Tracks_Time, sep = "_")
masterOLsurvMerged=subset(masterOLsurvMerged, !(masterOLsurvMerged$HumanFilter=="FALSE_TRUE_0"))





###Score Overlap against manual curation





##Perfect track scoring Overlap tracking
##Summarize Manual Curation
##Remove Tracked objects not in manual curation at T0 (Overlap not attempted)=> Manual_Curation= NA at T0
masterOLsurvMerged2a=masterOLsurvMerged
masterOLsurvMerged2a$HumanFilter2=paste(masterOLsurvMerged2a$Time,masterOLsurvMerged2a$Manual_Curation, sep = "_")
masterOLsurvMerged2a=subset(masterOLsurvMerged2a, !(masterOLsurvMerged2a$HumanFilter2=="0_NA"))

    masterOLsurvMerged2a <- masterOLsurvMerged2a %>%
      group_by(Manual_Plate_Well_Object) %>%
      summarise(maxManual=max(Tracks_Time))
    names(masterOLsurvMerged2a)[names(masterOLsurvMerged2a)=='Manual_Plate_Well_Object'] <- 'Plate_Object_Well'

    #########Filter out Live cells based on Manual Curation
#masterOLsurvMerged= subset(masterOLsurvMerged,masterOLsurvMerged$Live_Cells==TRUE)


    ##Summarize OL Tracking
    masterOLsurvMerged2b <- masterOLsurvMerged %>%
      group_by(Plate_Object_Well.x) %>%
      summarise(maxOL=max(Time))
    names(masterOLsurvMerged2b)[names(masterOLsurvMerged2b)=='Plate_Object_Well.x'] <- 'Plate_Object_Well'

    #merge summary max time points
    masterOLsurvMerged$Plate_Object_Well=paste(masterOLsurvMerged$Plate, masterOLsurvMerged$Object,masterOLsurvMerged$Well,  sep = "_")
    masterOLsurvMerged4=merge(masterOLsurvMerged, masterOLsurvMerged2a, by="Plate_Object_Well")
    masterOLsurvMerged4=merge(masterOLsurvMerged4, masterOLsurvMerged2b, by="Plate_Object_Well")

    ###Score tracks from T0
    masterOLsurvMerged4=subset(masterOLsurvMerged4,masterOLsurvMerged4$Tracks_Time==0)
    ##Eliminate n's
    masterOLsurvMerged4= subset(masterOLsurvMerged4,!(is.na(masterOLsurvMerged4$Plate_Object_Well.x)))


    #Scoring
    masterOLsurvMerged4$PerfectTracksScore=ifelse(masterOLsurvMerged4$maxManual==masterOLsurvMerged4$maxOL,1,0)
    masterOLsurvMerged4$OLUndertracked=ifelse(masterOLsurvMerged4$maxManual>masterOLsurvMerged4$maxOL,1,0)
    masterOLsurvMerged4$OLOvertracked=ifelse(masterOLsurvMerged4$maxManual<masterOLsurvMerged4$maxOL,1,0)


    #Summarize Mean Score
    OLPn=sum(masterOLsurvMerged4$PerfectTracksScore)
    OLPd=length(masterOLsurvMerged4$PerfectTracksScore)
    print("OL perfect track score")
    OLP=((OLPn/OLPd)*100)
    print((OLPn/OLPd)*100)





    ##Score Per Track correct
    ##ie objects that match between Manual Curation and Tracking
    masterOLsurvMerged$Time=as.numeric(masterOLsurvMerged$Time)

    #Eliminate Objects in OL's tracking not in Manual Curation
  masterOLsurvMerged=subset(masterOLsurvMerged,!(is.na(masterOLsurvMerged$Manual_Curation)))

  #Score
    masterOLsurvMerged$Score=ifelse(masterOLsurvMerged$Manual_Curation==masterOLsurvMerged$ObjectLabelsFound_OL,1,0)
    masterOLsurvMerged$Score=ifelse(is.na(masterOLsurvMerged$ObjectLabelsFound_OL),0,masterOLsurvMerged$Score)



    ###Subtract T0 from scoring as tracking was initiated with numbers from T0 and should match automatically
    masterOLsurvMerged$Score=ifelse((masterOLsurvMerged$Time==0),NA,masterOLsurvMerged$Score)
    masterOLsurvMerged=subset(masterOLsurvMerged,!(is.na(masterOLsurvMerged$Score)))

    ###Time weighted scoring
    masterOLsurvMerged$TimeScore=(masterOLsurvMerged$Time)*(masterOLsurvMerged$Score)



    OLTn=sum(masterOLsurvMerged$Score)
    OLTd=length(masterOLsurvMerged$Score)
    print("OL track score")
    OLTs=((OLTn/OLTd)*100)
    print((OLTn/OLTd)*100)


###Merge and summarize Overlap scoring stats
 masterOLsurvMerged$Plate_Object_Well_Time2=masterOLsurvMerged$Plate_Object_Well_Time
 masterOLsurvMerged$Plate_Object_Well_Time2=gsub("-","",masterOLsurvMerged$Plate_Object_Well_Time2)
 masterOLsurvMerged=separate(data=masterOLsurvMerged, col=Plate_Object_Well_Time2, into=c('Plate','Object', 'Well', 'Time'), sep="_")
 masterOLsurvMerged$Plate_Well=paste(masterOLsurvMerged$Plate,masterOLsurvMerged$Well, sep="_")


 masterOLsurvMerged4$Plate_Object_Well_Time2=masterOLsurvMerged4$Plate_Object_Well_Time
 masterOLsurvMerged4$Plate_Object_Well_Time2=gsub("-","",masterOLsurvMerged4$Plate_Object_Well_Time2)
 masterOLsurvMerged4=separate(data=masterOLsurvMerged4, col=Plate_Object_Well_Time2, into=c('Plate',  'Object','Well','Time'), sep="_")
 masterOLsurvMerged4$Plate_Well=paste(masterOLsurvMerged4$Plate,masterOLsurvMerged4$Well, sep="_")


###Writout


mergetestOLStats=summarise(group_by(masterOLsurvMerged,Plate_Well),
                           OLPerWellTrackScore=mean(Score),
                           OLPerWellN=length(Score)
)

mergetestOLStats2=summarise(group_by(masterOLsurvMerged4,Plate_Well),
                           OLPerWellPerfectScore=mean(PerfectTracksScore),
                           OLOverTrackTot=sum(OLOvertracked),
                           OLOverTrackAvg=mean(OLOvertracked),
                           OLUnderTrackTot=sum(OLUndertracked),
                           OLUnderTrackAvg=mean(OLUndertracked),
                           OLPerWellPerfectScoreN=length(PerfectTracksScore),
                           OLPerWellPerfectScoreSum=sum(PerfectTracksScore)
)


mergetestOLStats=merge(mergetestOLStats, mergetestOLStats2, by = "Plate_Well")

mergetestOLStats2=mergetestOLStats[!grepl("ABSOD1KW4WTC11Survival_E5", mergetestOLStats$Plate_Well),]
mergetestOLStats2=mergetestOLStats2[!grepl("ABSOD1KW4WTC11Survival_H6", mergetestOLStats$Plate_Well),]
mergetestOLStats2=mergetestOLStats2[!grepl("ABSOD1KW4WTC11Survival_H9", mergetestOLStats$Plate_Well),]




######################################################################################
####################Load Proximity tracking##############
######################################################################################


##Import Proximity tracking data

Prsurv1= read_syn_csv("syn18914391")

Prsurv1$ElapsedHours=NULL
Prsurv1$PixelIntensityTotal=NULL
Prsurv1$BlobCentroidX_RefIntWeighted=NULL
Prsurv1$BlobCentroidY_RefIntWeighted=NULL


Prsurv2= read_syn_csv("syn18914393")
Prsurv2$ElapsedHours=NULL
Prsurv2$PixelIntensityTotal=NULL
Prsurv2$BlobCentroidX_RefIntWeighted=NULL
Prsurv2$BlobCentroidY_RefIntWeighted=NULL



Prsurv3= read_syn_csv("syn18914390")
Prsurv3$ElapsedHours=NULL
Prsurv3$PixelIntensityTotal=NULL
Prsurv3$BlobCentroidX_RefIntWeighted=NULL
Prsurv3$BlobCentroidY_RefIntWeighted=NULL


Prsurv4= read_syn_csv("syn18914394")

Prsurv5= read_syn_csv("syn18914395")

Prsurv6= read_syn_csv("syn18914396")

Prsurv7= read_syn_csv("syn18914397")
Prsurv7$ElapsedHours=NULL
Prsurv7$PixelIntensityTotal=NULL
Prsurv7$BlobCentroidX_RefIntWeighted=NULL
Prsurv7$BlobCentroidY_RefIntWeighted=NULL

Prsurv8= read_syn_csv("syn18914399")
Prsurv8$ElapsedHours=NULL
Prsurv8$PixelIntensityTotal=NULL
Prsurv8$BlobCentroidX_RefIntWeighted=NULL
Prsurv8$BlobCentroidY_RefIntWeighted=NULL



masterPrsurv=rbind(Prsurv1,Prsurv2,Prsurv3,Prsurv4,Prsurv5,Prsurv6,Prsurv7,Prsurv8)




#Fix Sci_PlateID to experiment
masterPrsurv$Sci_PlateID=gsub(".*_","",masterPrsurv$Sci_PlateID)

#Give Unique identifier
masterPrsurv$Plate_Object_Well_Time=paste(masterPrsurv$Sci_PlateID,masterPrsurv$ObjectLabelsFound,masterPrsurv$Sci_WellID,masterPrsurv$Timepoint, sep="_")
masterPrsurv$Plate_Object_Well=paste(masterPrsurv$Sci_PlateID,masterPrsurv$ObjectLabelsFound,masterPrsurv$Sci_WellID, sep="_")



masterPrsurv2=masterPrsurv
#[!(masterPrsurv$Plate_Object_Well_Time %in%  masterPrsurvT0dif$Plate_Object_Well_Time),]

#make proximity tracking name unique
names(masterPrsurv2)[names(masterPrsurv2)=='ObjectLabelsFound'] <- 'ObjectLabelsFound_Pr'

##shorten proximity tracking ouput
masterPrsurvShort=masterPrsurv2[,c("ObjectLabelsFound_Pr","Plate_Object_Well_Time","Plate_Object_Well")]

##remove duplicates
masterPrsurvShort=masterPrsurvShort[!duplicated(masterPrsurvShort$Plate_Object_Well_Time), ]
masterPrsurvShortOutput=masterPrsurvShort
masterPrsurvShortOutput=separate(data=masterPrsurvShortOutput, col ="Plate_Object_Well_Time", into = c('Experiment', 'Object', 'Well', 'Time'), sep = "_")


###writeout Raw Combined Overlap Tracking
write.csv(masterPrsurvShortOutput, "RawProximityTrackingData.csv") # syn18914554



#Merge all Young's tracks for which Human Curation is available
masterPrsurvMerged=merge(masterPrsurvShort,TracksShortened, by="Plate_Object_Well_Time", all=TRUE)



masterPrsurvMerged$Plate_Object_Well_Time2=masterPrsurvMerged$Plate_Object_Well_Time
masterPrsurvMerged=separate(data= masterPrsurvMerged, col=Plate_Object_Well_Time2, into=c('Plate', 'Object','Well', 'Time'), sep = "_")
masterPrsurvMerged$Manual_Plate_Well_Object=paste(masterPrsurvMerged$Plate,masterPrsurvMerged$Manual_Curation,masterPrsurvMerged$Well, sep = "_")


###Subset for just LINCS09 data with GEDI signal
##masterPrsurvMergedLINCSA=subset(masterPrsurvMerged, masterPrsurvMerged$Plate=="LINCS092016A")
#masterPrsurvMergedLINCSB=subset(masterPrsurvMerged, masterPrsurvMerged$Plate=="LINCS092016B")
#masterPrsurvMerged=rbind(masterPrsurvMergedLINCSA,masterPrsurvMergedLINCSB)



##Score Proximity tracking data
##subset objects that were tracked based on curator perogative (dead cells and debri at T0, non-neuronal cells, clumped cells)
##Live_Cells==FALSE indicates dead cells + cells that weren't tracked because of curator choice (often clumped cells, non-neuronal, etc.)
##Live_Cells==FALSE&Mistracked==TRUE & Timepoint==0 gives only cells that weren't tracked because of curator choice

masterPrsurvMerged$HumanFilter=paste(masterPrsurvMerged$Live_Cells,masterPrsurvMerged$Mistracked,masterPrsurvMerged$Tracks_Time, sep = "_")
masterPrsurvMerged=subset(masterPrsurvMerged, !(masterPrsurvMerged$HumanFilter=="FALSE_TRUE_0"))


##Perfect track scoring Proximity tracking
##Summarize Manual Curation

##Remove Tracked objects not in manual curation at T0 (Young not attempted)=> Manual_Curation= NA at T0

masterPrsurvMerged2a= masterPrsurvMerged
masterPrsurvMerged2a$HumanFilter2=paste(masterPrsurvMerged2a$Time,masterPrsurvMerged2a$Manual_Curation, sep = "_")
masterPrsurvMerged2a=subset(masterPrsurvMerged2a, !(masterPrsurvMerged2a$HumanFilter2=="0_NA"))

#Find max timepoint for a track that matches Manual curation
    masterPrsurvMerged2a <- masterPrsurvMerged2a %>%
      group_by(Manual_Plate_Well_Object) %>%
      ##Use Manual Curation Timepoint
      summarise(maxManual=max(Tracks_Time))
    names(masterPrsurvMerged2a)[names(masterPrsurvMerged2a)=='Manual_Plate_Well_Object'] <- 'Plate_Object_Well'

    #########Filter out Live cells based on Manual Curation
#masterPrsurvMerged= subset(masterPrsurvMerged,masterPrsurvMerged$Live_Cells==TRUE)

    ##Summarize Young Tracking
    masterPrsurvMerged2b <- masterPrsurvMerged %>%
      group_by(Plate_Object_Well.x) %>%
      ##Using tracking Timepoint
      summarise(maxPr=max(Time))
      names(masterPrsurvMerged2b)[names(masterPrsurvMerged2b)=='Plate_Object_Well.x'] <- 'Plate_Object_Well'


      #merge summary max time points
      masterPrsurvMerged$Plate_Object_Well=paste(masterPrsurvMerged$Plate,  masterPrsurvMerged$Object,masterPrsurvMerged$Well, sep = "_")
    masterPrsurvMerged4=merge(masterPrsurvMerged, masterPrsurvMerged2a, by="Plate_Object_Well")
    masterPrsurvMerged4=merge(masterPrsurvMerged4, masterPrsurvMerged2b, by="Plate_Object_Well")

    ###Score tracks from T0
    masterPrsurvMerged4=subset(masterPrsurvMerged4,masterPrsurvMerged4$Tracks_Time==0)

    ##Eliminate n's
    masterPrsurvMerged4= subset(masterPrsurvMerged4,!(is.na(masterPrsurvMerged4$Plate_Object_Well.x)))

    #Scoring
    masterPrsurvMerged4$PerfectTracksScore=ifelse(masterPrsurvMerged4$maxManual==masterPrsurvMerged4$maxPr,1,0)
    masterPrsurvMerged4$PrUndertracked=ifelse(masterPrsurvMerged4$maxManual>masterPrsurvMerged4$maxPr,1,0)
    masterPrsurvMerged4$PrOvertracked=ifelse(masterPrsurvMerged4$maxManual<masterPrsurvMerged4$maxPr,1,0)

    #Summarize mean scoring
    PrPn=sum(masterPrsurvMerged4$PerfectTracksScore)
    PrPd=length(masterPrsurvMerged4$PerfectTracksScore)
    print("Pr perfect track score")
    PrPs=((PrPn/PrPd)*100)
    print((PrPn/PrPd)*100)



 ##Score Per Track correct
 ##ie objects that match between Manual Curation and Tracking
    masterPrsurvMerged$Time=as.numeric(masterPrsurvMerged$Time)

    #Eliminate Objects in Young's tracking not in Manual Curation
    masterPrsurvMerged=subset(masterPrsurvMerged,!(is.na(masterPrsurvMerged$Manual_Curation)))


    #Score
    masterPrsurvMerged$Score=ifelse(masterPrsurvMerged$Manual_Curation==masterPrsurvMerged$ObjectLabelsFound_Pr,1,0)
    masterPrsurvMerged$Score=ifelse(is.na(masterPrsurvMerged$ObjectLabelsFound_Pr),0,masterPrsurvMerged$Score)




    ###Subtract T0 from scoring as tracking was initiated with numbers from T0 and should match automatically
    masterPrsurvMerged$Score=ifelse((masterPrsurvMerged$Time==0),NA,masterPrsurvMerged$Score)
    masterPrsurvMerged=subset(masterPrsurvMerged,!(is.na(masterPrsurvMerged$Score)))

    ###Time weighted scoring
    masterPrsurvMerged$TimeScore=(masterPrsurvMerged$Time)*(masterPrsurvMerged$Score)



    PrTn=sum(masterPrsurvMerged$Score)
    PrTd=length(masterPrsurvMerged$Score)
    print("Pr track score")
    PrTs=((PrTn/PrTd)*100)
    print((PrTn/PrTd)*100)



    masterPrsurvMerged$Score=ifelse(masterPrsurvMerged$Manual_Curation==masterPrsurvMerged$ObjectLabelsFound_Pr,1,0)
    masterPrsurvMerged=subset(masterPrsurvMerged,(!(is.na(masterPrsurvMerged$Manual_Curation))))

    masterPrsurvMerged$Score=ifelse(is.na(masterPrsurvMerged$ObjectLabelsFound_Pr),0,masterPrsurvMerged$Score)



##Merge and summarize stats for proximity tracking data
masterPrsurvMerged$Plate_Object_Well_Time2=masterPrsurvMerged$Plate_Object_Well_Time
masterPrsurvMerged$Plate_Object_Well_Time2=gsub("-","",masterPrsurvMerged$Plate_Object_Well_Time2)
masterPrsurvMerged=separate(data=masterPrsurvMerged, col=Plate_Object_Well_Time2, into=c('Plate',  'Object','Well','Time'), sep="_")
masterPrsurvMerged$Plate_Well=paste(masterPrsurvMerged$Plate,masterPrsurvMerged$Well, sep="_")


masterPrsurvMerged4$Plate_Object_Well_Time2=masterPrsurvMerged4$Plate_Object_Well_Time
masterPrsurvMerged4$Plate_Object_Well_Time2=gsub("-","",masterPrsurvMerged4$Plate_Object_Well_Time2)
masterPrsurvMerged4=separate(data=masterPrsurvMerged4, col=Plate_Object_Well_Time2, into=c('Plate',  'Object','Well','Time'), sep="_")
masterPrsurvMerged4$Plate_Well=paste(masterPrsurvMerged4$Plate,masterPrsurvMerged4$Well, sep="_")




mergetestPrStats=summarise(group_by(masterPrsurvMerged,Plate_Well),
                           PrPerWellTrackScore=mean(Score),
                           PrPerWellTrackN=length(Score)
)




mergetestPrStats2=summarise(group_by(masterPrsurvMerged4,Plate_Well),
                            PrPerWellPerfectScore=mean(PerfectTracksScore),
                            PrOverTrackTot=sum(PrOvertracked),
                            PrOverTrackAvg=mean(PrOvertracked),
                            PrUnderTrackTot=sum(PrUndertracked),
                            PrUnderTrackAvg=mean(PrUndertracked),
                            PrPerWellPerfectScoreN=length(PerfectTracksScore),
                            PrPerWellPerfectScoreSum=sum(PerfectTracksScore)
)



mergetestPrStats=merge(mergetestPrStats, mergetestPrStats2, by = "Plate_Well")




mergetestPrStats2=mergetestPrStats[!grepl("ABSOD1KW4WTC11Survival_E5", mergetestPrStats$Plate_Well),]
mergetestPrStats2=mergetestPrStats2[!grepl("ABSOD1KW4WTC11Survival_H6", mergetestPrStats$Plate_Well),]
mergetestPrStats2=mergetestPrStats2[!grepl("ABSOD1KW4WTC11Survival_H9", mergetestPrStats$Plate_Well),]


######################################################################################
####################Combine and writeout all tracking stats ##############
######################################################################################


###Combine Stats

ALLPERWELLTRACKING=merge(mergetestOLStats2, mergetestPrStats2, by="Plate_Well")
ALLPERWELLTRACKING=merge(ALLPERWELLTRACKING,YoungTracksStats2,by="Plate_Well")

ALLPERWELLTRACKING=separate(data=ALLPERWELLTRACKING,col=Plate_Well,into=c('Plate','Well'), sep="_")


write.csv(ALLPERWELLTRACKING, "ALLPERWELLTRACKINGDataDEATHFILTER.csv") # syn18914491

