#!/usr/bin/env cwl-runner
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
  - id: clean_score
    type: File
  - id: parent
    type: string
  - id: synapse_config
    type: File

arguments:
  - valueFrom: store_to_synapse.py
  - valueFrom: $(inputs.score.path)
    prefix: --score
  - valueFrom: $(inputs.clean_score.path)
    prefix: --clean-score
  - valueFrom: $(inputs.parent)
    prefix: --parent
  - valueFrom: $(inputs.synapse_config.path)
    prefix: --synapse-config

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: store_to_synapse.py
        entry: |
            #!/usr/bin/env python
            import synapseclient
            import pandas as pd
            import argparse
            import json
            
            def read_args():
                parser = argparse.ArgumentParser()
                parser.add_argument("--score",
                                    required=True)
                parser.add_argument("--clean-score",
                                    required=True, help="File to upload.")
                parser.add_argument("--parent",
                                    required=True, help="Parent Synapse ID.")
                parser.add_argument("--synapse-config",
                                    required=True, help="Synapse config file.")
                args = parser.parse_args()
                return(args)

            def store(syn, path, clean_score, parent):
                with open(path, "r") as f:
                    score = json.load(f)
                if score["status"] == "SCORED":
                    f = synapseclient.File(clean_score, parent)
                    f = syn.store(f)
                    result = {'results': f['id'],
                              'status': "SCORED",
                              'invalid_reasons': "null"}
                else:
                    result = {"results": "null",
                              "status": score["status"],
                              "invalid_reasons": status["invalid_reasons"]}
                return(result)
            
            def main():
                args = read_args()
                syn = synapseclient.Synapse(configPath=args.synapse_config)
                syn.login()
                result = store(syn, args.score, args.clean_score, args.parent)
                with open("results.json", "w") as o:
                    o.write(json.dumps(result))
            
            if __name__ == "__main__":
                main()
     
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json
  - id: id
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['results'])
