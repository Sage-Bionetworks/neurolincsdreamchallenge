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
        valueFrom: "syn18345738"
      - id: synapseConfig
        source: "#synapseConfig"
    out:
      - id: gold_standard

  validation:
    run: validate.cwl
    in:
      - id: inputfile
        source: "#download_submission/filepath"
      - id: gold_standard
        source: "#download_goldstandard/gold_standard"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  validation_email:
    run: validate_email.cwl
    in:
      - id: submissionId
        source: "#submissionId"
      - id: synapseConfig
        source: "#synapseConfig"
      - id: status
        source: "#validation/status"
      - id: invalid_reasons
        source: "#validation/invalid_reasons"

    out: []

  annotate_validation_with_output:
    run: annotate_submission.cwl
    in:
      - id: submissionId
        source: "#submissionId"
      - id: annotation_values
        source: "#validation/results"
      - id: synapseConfig
        source: "#synapseConfig"
    out: []

  scoring:
    run: score.cwl
    in:
      - id: inputfile
        source: "#download_submission/filepath"
      - id: gold_standard
        source: "#download_goldstandard/gold_standard"
      - id: status 
        source: "#validation/status"
    out:
      - id: results
      
  score_email:
    run: score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#scoring/results"
    out: []

  annotate_submission_with_output:
    run: annotate_submission.cwl
    in:
      - id: submissionId
        source: "#submissionId"
      - id: annotation_values
        source: "#scoring/results"
      - id: synapseConfig
        source: "#synapseConfig"
    out: []
 
