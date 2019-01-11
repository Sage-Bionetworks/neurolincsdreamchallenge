#!/usr/bin/env cwl-runner
#
#  This sample workflow gets sprints for a rally
#
cwlVersion: v1.0
class: Workflow

requirements:
  ScatterFeatureRequirement: {}

inputs:
  message_array: string[] 
  synapseConfig:
    type: File

steps:
  get-image-layers:
    run: get-image-layers.cwl
    scatter: synapseid
    in:
      synapseid: message_array
      synapseConfig:
        source: "#synapseConfig"
    out: [stdout]

outputs:
  workflow-output:
    type:
      type: array
      items: File
    outputSource: get-image-layers/stdout

