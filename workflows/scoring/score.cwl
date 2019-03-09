#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: tracking_summary_perfect_tracks.R

hints:
  DockerRequirement:
    dockerImageId: localneurolincsscoring

inputs:
  - id: inputfile
    type: File
  - id: gold_standard
    type: File

arguments:
  - valueFrom: $(inputs.inputfile.path)
    prefix: --tracking_file
  - valueFrom: $(inputs.gold_standard.path)
    prefix: --curated_data_table

outputs:
  - id: score
    type: stdout
