#!/usr/bin/env cwl-runner
#
# Sample workflow
# Inputs:
#   submissionId: ID of the Synapse submission to process
#   adminUploadSynId: ID of a folder accessible only to the submission queue administrator
#   submitterUploadSynId: ID of a folder accessible to the submitter
#   workflowSynapseId:  ID of the Synapse entity containing a reference to the workflow file(s)
#   synapseConfig: ~/.synapseConfig file that has your Synapse credentials
#
cwlVersion: v1.0
class: Workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  - id: submissionId
    type: int
  - id: adminUploadSynId
    type: string
  - id: submitterUploadSynId
    type: string
  - id: workflowSynapseId
    type: string
  - id: synapseConfig
    type: File

# there are no output at the workflow engine level.  Everything is uploaded to Synapse
outputs: []

steps:
  download_submission:
    run: download_submission_file.cwl
    in:
      - id: submissionId
        source: "#submissionId"
      - id: synapseConfig
        source: "#synapseConfig"
    out:
      - id: filepath
      - id: entity
      
  download_goldstandard:
    run: download_from_synapse.cwl
    in:
      - id: synapseId
        valueFrom: "syn18411380" #"syn18345738"
      - id: synapseConfig
        source: "#synapseConfig"
    out:
      - id: gold_standard

  scoring:
    run: score.cwl
    in: 
      - id: inputfile
        source: "#download_submission/filepath"
      - id: gold_standard
        source: "#download_goldstandard/gold_standard"
    out:
      - id: score

  scoring_per_well:
    run: score_per_well.cwl
    in: 
      - id: inputfile
        source: "#download_submission/filepath"
      - id: gold_standard
        source: "#download_goldstandard/gold_standard"
    out:
      - id: score

  clean_score_per_well:
    run: clean_score_per_well.cwl
    in:
      - id: score
        source: "#scoring_per_well/score"
    out:
      - id: clean_score
      
  store_score:
    run: store_to_synapse.cwl
    in:
      - id: score
        source: "#scoring_per_well/score"
      - id: clean_score
        source: "#clean_score_per_well/clean_score"
      - id: parent
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: results
      - id: id

  merge_scores:
    run: merge_scores.cwl
    in:
      - id: score
        source: "#scoring/score"
      - id: synapse_id
        source: "#store_score/id"
    out:
      - id: merged_score
      
  score_email:
    run: score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: score
        source: "#merge_scores/merged_score"
    out: []

  annotate_submission_with_output:
    run: annotate_submission.cwl
    in:
      - id: submissionId
        source: "#submissionId"
      - id: annotation_values
        source: "#merge_scores/merged_score"
      - id: synapseConfig
        source: "#synapseConfig"
    out: []
 
