#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3.6

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient

inputs:
  - id: inputfile
    type: File
  - id: gold_standard
    type: File
  - id: status
    type: string

arguments:
  - valueFrom: score.py
  - valueFrom: $(inputs.inputfile.path)
    prefix: -f
  - valueFrom: $(inputs.gold_standard)
    prefix: --gold-standard
  - valueFrom: $(inputs.status)
    prefix: -s
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: score.py
        entry: |
          #!/usr/bin/env python
          import argparse
          import os
          import json

          def read_args():
              parser = argparse.ArgumentParser()
              parser.add_argument("-f", "--submissionfile", required=True, help="Submission File")
              parser.add_argument("--gold-standard", required=True, help = "Gold standard file")
              parser.add_argument("-s", "--status", required=True, help="Submission status")
              parser.add_argument("-r", "--results", required=True, help="Scoring results")
              return(args)

          def main():
              args = parser.parse_args()
              if args.status == "VALIDATED":
                  os.system("docker run sagebionetworks/neurolincsscoring "
                            "--tracking_file {}, --curated_data_table {} ",
                            "--json".format(args.submissionfile, args.gold_standard)
                  prediction_file_status = "SCORED"
                  result = {'prediction_file_status':prediction_file_status}
              else:
                  result = {'prediction_file_status':args.status}
              with open(args.results, 'w') as o:
                  o.write(json.dumps(result))
     
outputs:
  - id: score
    type: stdout
  - id: results 
    type: File
    outputBinding:
      glob: results.json
