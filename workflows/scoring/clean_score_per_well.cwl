#!/usr/bin/env cwl-runner
#
# Put score per well in csv format
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3.6

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient

inputs:
  - id: score
    type: File

arguments:
  - valueFrom: clean_score_per_well.py
  - valueFrom: $(inputs.score.path)
    prefix: --score

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: clean_score_per_well.py
        entry: |
            #!/usr/bin/env python
            import pandas as pd
            import argparse
            import json
            
            def read_args():
                parser = argparse.ArgumentParser()
                parser.add_argument("--score", required=True)
                args = parser.parse_args()
                return(args)

            def clean_score(score):
                with open(score, "r") as f:
                    score_dic = json.load(f)
                clean_score = pd.DataFrame(score_dic["results"])
                return clean_score

            def main():
                args = read_args()
                score = clean_score(args.score)
                score.to_csv("results.csv", index = False)
            
            if __name__ == "__main__":
                main()
     
outputs:
  - id: clean_score
    type: File
    outputBinding:
      glob: results.csv
