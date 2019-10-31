#!/usr/bin/env cwl-runner
#
# Put a json-formatted score into tabular format
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v1.9.2

inputs:
  - id: score
    type: File
  - id: output_path
    type: string

arguments:
  - valueFrom: clean_score_per_blank.py
  - valueFrom: $(inputs.score.path)
    prefix: --score
  - valueFrom: $(inputs.output_path)
    prefix: --output-path

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: clean_score_per_blank.py
        entry: |
            #!/usr/bin/env python3
            import pandas as pd
            import argparse
            import json
            
            def read_args():
                parser = argparse.ArgumentParser()
                parser.add_argument("--score", required=True)
                parser.add_argument("--output-path", required=True)
                args = parser.parse_args()
                return(args)

            def clean_score(score):
                with open(score, "r") as f:
                    score_dic = json.load(f)
                if score_dic['status'] == "SCORED":
                    clean_score = pd.DataFrame(score_dic["results"])
                else:
                    clean_score = pd.DataFrame()
                return clean_score

            def main():
                args = read_args()
                score = clean_score(args.score)
                score.to_csv(args.output_path, index = False)
            
            if __name__ == "__main__":
                main()
     
outputs:
  - id: clean_score
    type: File
    outputBinding:
      glob: $(inputs.output_path)
