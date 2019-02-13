#!/usr/bin/env cwl-runner
#
# Download a submitted file from Synapse and return the downloaded file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3.6

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient

inputs:
  - id: submissionId
    type: int
  - id: synapseConfig
    type: File

arguments:
  - valueFrom: download_submission_file.py
  - valueFrom: $(inputs.submissionId)
    prefix: --submission-id
  - valueFrom: results.json
    prefix: --results
  - valueFrom: $(inputs.synapseConfig.path)
    prefix: --synapse-config

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: download_submission_file.py
        entry: |
            #!/usr/bin/env python
            import synapseclient
            import argparse
            import json
            import os


            def read_args():
                parser = argparse.ArgumentParser()
                parser.add_argument("--submission-id", required=True, help="Submission ID")
                parser.add_argument("--submission-cache", default = ".",
                                    help = "Where to store submissions")
                parser.add_argument("--results", required=True, help="Path to write results")
                parser.add_argument("--synapse-config", required=True, help="Credentials file")
                args = parser.parse_args()
                return(args)


            def main():
                args = read_args()
                syn = synapseclient.Synapse(configPath=args.synapse_config)
                syn.login()
                sub = syn.getSubmission(args.submission_id,
                                        downloadLocation=args.submission_cache)
                os.rename(sub.filePath, "submission-"+args.submission_id)
                result = {'entityId': sub.entity.id,
                          'entityVersion': sub.entity.versionNumber}
                with open(args.results, 'w') as f:
                    f.write(json.dumps(result))


            if __name__ == "__main__":
                main()
     
outputs:
  - id: filepath
    type: File
    outputBinding:
      glob: $("submission-"+inputs.submissionId)
  - id: entity
    type:
      type: record
      fields:
      - name: id
        type: string
        outputBinding:
          glob: results.json
          loadContents: true
          outputEval: $(JSON.parse(self[0].contents)['entityId'])
      - name: version
        type: int
        outputBinding:
          glob: results.json
          loadContents: true
          outputEval: $(JSON.parse(self[0].contents)['entityVersion'])
