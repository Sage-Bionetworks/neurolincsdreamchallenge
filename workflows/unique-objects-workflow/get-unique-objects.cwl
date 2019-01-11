#!/usr/bin/env cwl-runner
#
#  Get unique objects from a NeuroLINCS image mask file in Synapse.
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: ['get-unique-objects.py']

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

