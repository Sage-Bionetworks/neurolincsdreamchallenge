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
  - id: inputfile
    type: File

arguments:
  - valueFrom: validate.py
  - valueFrom: $(inputs.inputfile)
    prefix: -s
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validate.py
        entry: |
            #!/usr/bin/env python
            import pandas as pd
            import argparse
            import json
            
            def read_args():
                parser = argparse.ArgumentParser()
                parser.add_argument("-s", "--submission-file",
                                    required=True, help="Submission File")
                parser.add_argument("-r", "--results",
                                    required=True, help="validation results")
                args = parser.parse_args()
                return(args)
            
            def validate_submission(path):
                invalid_reasons = []
                try:
                    sub = pd.read_csv(path, sep=None, engine="python")
                except:
                    invalid_reasons.append("Submission is not readable as a tabular format. "
                                           "Did you submit the correct file and is that "
                                           "file in .csv or .tsv format?")
                    return invalid_reasons
                mandatory_columns = ["Experiment", "ObjectLabelsFound", "ObjectTrackID",
                                     "Well", "TimePoint"]
                if not all([c in sub.columns for c in mandatory_columns]):
                    invalid_reasons.append("Submission does not have all the required "
                                           "columns. Verify that columns {} are "
                                           "present.".format(", ".join(mandatory_columns)))
                    return invalid_reasons
                largest_min_timepoint = sub.groupby(
                        ["Experiment", "Well", "ObjectTrackID"]).min().TimePoint.max()
                if largest_min_timepoint > 0:
                    invalid_reasons.append("The TimePoint of each tracked cell must "
                                           "start at 0.")
                return invalid_reasons

            def main():
                args = read_args()
                invalid_reasons = validate_submission(args.submission_file)
                if len(invalid_reasons):
                    result = {'prediction_file_errors':"\n".join(invalid_reasons),
                              'prediction_file_status':"INVALID"}
                else:
                    result = {'prediction_file_errors':"",
                              'prediction_file_status':"VALIDATED"}
                with open(args.results, 'w') as o:
                  o.write(json.dumps(result))
            
            if __name__ == "__main__":
                main()
     
outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   

  - id: status
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['prediction_file_status'])

  - id: invalid_reasons
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['prediction_file_errors'])
