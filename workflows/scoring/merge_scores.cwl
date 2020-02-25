#!/usr/bin/env cwl-runner
#
# Example validate submission file
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
  - id: synapse_id_per_well
    type: string
  - id: synapse_id_per_object
    type: string

arguments:
  - valueFrom: merge_scores.py
  - valueFrom: $(inputs.score.path)
    prefix: --score
  - valueFrom: $(inputs.synapse_id_per_well)
    prefix: --synapse-id-per-well
  - valueFrom: $(inputs.synapse_id_per_object)
    prefix: --synapse-id-per-object

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: merge_scores.py
        entry: |
            #!/usr/bin/env python3
            import argparse
            import json
            
            def read_args():
                parser = argparse.ArgumentParser()
                parser.add_argument("--score", required=True)
                parser.add_argument("--synapse-id-per-well", required=True)
                parser.add_argument("--synapse-id-per-object", required=True)
                args = parser.parse_args()
                return(args)

            def merge_scores(score, synapse_id_per_well, synapse_id_per_object):
                with open(score, "r") as f:
                    score_dic = json.load(f)
                score_dic["results_per_well"] = synapse_id_per_well
                score_dic["results_per_object"] = synapse_id_per_object
                return score_dic

            def main():
                args = read_args()
                print(args.synapse_id_per_object)
                print(args.synapse_id_per_well)
                score = merge_scores(args.score, args.synapse_id_per_well,
                                     args.synapse_id_per_object)
                with open("results.json", "w") as o:
                  o.write(json.dumps(score))
            
            if __name__ == "__main__":
                main()
     
outputs:
  - id: merged_score
    type: File
    outputBinding:
      glob: results.json
