#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

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
  - valueFrom: $(inputs.gold_standard.path)
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
              args = parser.parse_args()
              return(args)

          def main():
              args = read_args()
              if args.status == "VALIDATED":
                  os.system("docker run --rm neurolincsscoring "
                            "--mount type=bind,source={},"
                            "target=/root/sub.csv,readonly "
                            "--mount type=bind,source={},"
                            "target=/root/goldstandard.csv,readonly"
                            "tracking_summary_perfect_tracks.R "
                            "--tracking_file /root/sub.csv "
                            "--curated_data_table /root/gold_standard.csv "
                            "--json".format(args.submissionfile, args.gold_standard))
                  result = {'prediction_file_status':"SCORED"}
              else:
                  result = {'prediction_file_status':args.status}
              with open(args.results, 'w') as o:
                  o.write(json.dumps(result))
     
          if __name__ == '__main__':
              main()

outputs:
  - id: score
    type: stdout
  - id: results 
    type: File
    outputBinding:
      glob: results.json
