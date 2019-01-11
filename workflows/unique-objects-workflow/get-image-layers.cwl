#!/usr/bin/env cwl-runner
#
#  This sample workflow gets sprints for a rally
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: ['get-image-layers.py']

inputs:
  synapseConfig:
    type: File?
    inputBinding:
      position: 1
      prefix: --synapseConfig
  synapseid:
    type: string
    inputBinding:
      position: 2


outputs:
  - id: stdout
    type: stdout

stdout: $(inputs.synapseid).txt

