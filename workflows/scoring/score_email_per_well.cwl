#!/usr/bin/env cwl-runner

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
  - id: score
    type: File
  - id: synapse_id
    type: string

arguments:
  - valueFrom: score_email.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.score.path)
    prefix: --score
  - valueFrom: $(inputs.synapse_id)
    prefix: --results-per-well

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
              parser.add_argument("-s", "--submissionid",
                                  required=True, help="Submission ID")
              parser.add_argument("-c", "--synapse_config",
                                  required=True, help="credentials file")
              parser.add_argument("--score", required=True, help="Resulting scores")
              parser.add_argument("--results-per-well", required=True,
                                  help="Synapse ID of resulting scores")
              args = parser.parse_args()
              return(args)

          def send_email(syn, submission_id, scoring_results, results_per_well):
              sub = syn.getSubmission(submission_id)
              user_id = sub.userId
              evaluation = syn.getEvaluation(sub.evaluationId)
              if scoring_results["status"] == "INVALID":
                  subject = "Submission to {} invalid".format(evaluation.name)
                  if isinstance(scoring_results["invalid_reasons"], list): 
                      invalid_reasons = "\n".join(scoring_results["invalid_reasons"])
                  else:
                      invalid_reasons = scoring_results["invalid_reasons"]
                  message = ["Hello {},\n\n".format(
                                  syn.getUserProfile(user_id)['userName']),
                             "Your submission ({}) is invalid. ".format(sub.name), 
                             "below are the invalid reasons:\n\n",
                             invalid_reasons,
                             "\n\nSincerely,\nNeurolincs Challenge Administrator"]
              else:
                  subject = "Submission to {} has been evaluated!".format(evaluation.name)
                  message = ["Hello {},\n\n".format(syn.getUserProfile(user_id)['userName']),
                               "Your submission ({}) has been evaluated, ".format(sub.name),
                               "You can access your results at:\n\n",
                               "https://synapse.org/#!Synapse:{}".format(results_per_well),
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
              with open(args.score, "r") as f:
                  scoring_results = json.load(f)
              send_email(syn, args.submissionid,
                         scoring_results, args.results_per_well)

          if __name__ == '__main__':
              main()

outputs: []
