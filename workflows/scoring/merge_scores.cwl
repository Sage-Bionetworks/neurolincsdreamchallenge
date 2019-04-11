#!/usr/bin/env cwl-runner
#
# Example validate submission file
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
  - id: synapse_id
    type: string

arguments:
  - valueFrom: merge_scores.py
  - valueFrom: $(inputs.score.path)
    prefix: --score
  - valueFrom: $(inputs.synapse_id)
    prefix: --synapse-id

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: merge_scores.py
        entry: |
            #!/usr/bin/env python
            import argparse
            import json
            
            def read_args():
                parser = argparse.ArgumentParser()
                parser.add_argument("--score", required=True)
                parser.add_argument("--synapse-id", required=True)
                args = parser.parse_args()
                return(args)

            def merge_scores(score, synapse_id):
                with open(score, "r") as f:
                    score_dic = json.load(f)
                score_dic['results_per_well'] = synapse_id
                return score_dic

            def main():
                args = read_args()
                score = merge_scores(args.score, args.synapse_id)
                with open("results.json", "w") as o:
                  o.write(json.dumps(score))
            
            if __name__ == "__main__":
                main()
     
outputs:
  - id: merged_score
    type: File
    outputBinding:
      glob: results.json
