#!/usr/bin/env cwl-runner
#

cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3.6

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient

inputs:
  - id: synapseConfig
    type: File
  - id: synapseId
    type: string

arguments:
  - valueFrom: download_synapse_file.py
  - valueFrom: $(inputs.synapseId)
    prefix: -s
  - valueFrom: $(inputs.synapseConfig.path)
    prefix: -c

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: download_synapse_file.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import os

          def read_args():
              parser = argparse.ArgumentParser()
              parser.add_argument("-s", "--synapseid", required=True, help="Submission Id")
              parser.add_argument("-c", "--synapse_config", required=True, help="Credentials file")
              args = parser.parse_args()
              return(args)
          
          def main():
              args = read_args()
              syn = synapseclient.Synapse(configPath=args.synapse_config)
              syn.login()
              f = syn.get(args.synapseid, downloadLocation=".")
              os.rename(f.path, "goldstandard.csv")

          if __name__ == '__main__':
              main()
     
outputs:
  - id: gold_standard
    type: File
    outputBinding:
      glob: goldstandard.csv
