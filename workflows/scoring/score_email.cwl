#!/usr/bin/env cwl-runner
#
# Example score emails to participants
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3.6

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient

inputs:
  - id: submissionid
    type: int
  - id: synapse_config
    type: File
  - id: results
    type: File

arguments:
  - valueFrom: score_email.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.results)
    prefix: -r


requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: score_email.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import json
          import os

          def read_args():
              parser = argparse.ArgumentParser()
              parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
              parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
              parser.add_argument("-r","--results", required=True, help="Resulting scores")
              args = parser.parse_args()
              return(args)

          def send_email(syn, submission_id, annotations):
              sub = syn.getSubmission(submission_id)
              user_id = sub.userId
              evaluation = syn.getEvaluation(sub.evaluationId)
              with open(annotations) as json_data:
                annots = json.load(json_data)
              subject = "Submission to {} has been evaluated!".format(evaluation.name)
              message = ["Hello {},\n\n".format(syn.getUserProfile(user_id)['userName']),
                           "Your submission ({}) has been evaluated, ",
                           "below are your results:\n\n".format(sub.name),
                           "\n".join([i + " : " + str(annots[i]) for i in annots]),
                           "\n\nSincerely,\nNeurolincs Administrator"]
              syn.sendMessage(
                userIds=[user_id],
                messageSubject=subject,
                messageBody="".join(message),
                contentType="text/html")

          def main():
              args = read_args()
              syn = synapseclient.Synapse(configPath=args.synapse_config)
              syn.login()
              send_email(syn, args.submissionid, args.results)

          if __name__ == '__main__':
              main()

outputs: []
