#!/usr/bin/env cwl-runner
#
# Example score emails to participants
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v1.9.2

inputs:
  - id: submissionid
    type: int
  - id: synapse_config
    type: File
  - id: score
    type: File

arguments:
  - valueFrom: score_email.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.score.path)
    prefix: --score

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: score_email.py
        entry: |
          #!/usr/bin/env python3
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
              args = parser.parse_args()
              return(args)

          def send_email(syn, submission_id, scoring_results):
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
                               "below are your results:\n\n",
                               "\n".join([i + " : " + 
                                          str(scoring_results["results"][i])
                                          for i in scoring_results["results"]]),
                               "\n\nYour results per well can be found here: ",
                               "https://synapse.org/#!Synapse:{}".format(
                                 scoring_results["results_per_well"]),
                               "\nYour results per object can be found here: ",
                               "https://synapse.org/#!Synapse:{}".format(
                                 scoring_results["results_per_object"]),
                               "\n\nSincerely,\nNeurolincs Administrator"]
              syn.sendMessage(
                userIds=[user_id],
                messageSubject=subject,
                messageBody="".join(message),
                contentType="text/html")

          def main():
              args = read_args()
              with open (args.score, "r") as f:
                  score = json.load(f)
              syn = synapseclient.Synapse(configPath=args.synapse_config)
              syn.login()
              send_email(syn, args.submissionid, score)

          if __name__ == '__main__':
              main()

outputs: []
