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
  - id: per_object
    type: boolean
    default: true
  - id: only_tracked
    type: boolean
    default: true
  - id: write_output_to_file
    type: string
    default: "results.json"

arguments:
  - valueFrom: $(inputs.inputfile.path)
    prefix: --tracking_file
  - valueFrom: $(inputs.gold_standard.path)
    prefix: --curated_data_table
  - valueFrom: $(inputs.per_object)
    prefix: --per_object
  - valueFrom: $(inputs.only_tracked)
    prefix: --only_tracked
  - valueFrom: $(inputs.write_output_to_file)
    prefix: --write_output_to_file

outputs:
  - id: score
    type: File
    outputBinding:
      glob: results.json
