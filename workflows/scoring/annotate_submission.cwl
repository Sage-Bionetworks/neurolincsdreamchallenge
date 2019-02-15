#!/usr/bin/env cwl-runner
#
# Annotate an existing submission with a string value
# (variations can be written to pass long or float values)
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
  - id: annotation_values
    type: File
  - id: to_public
    type: boolean 
    default: true
  - id: force_change_annotation_acl
    type: boolean 
    default: true
  - id: synapseConfig
    type: File

arguments:
  - valueFrom: annotationSubmission.py
  - valueFrom: $(inputs.submissionId)
    prefix: -s
  - valueFrom: $(inputs.annotation_values)
    prefix: -v
  - valueFrom: $(inputs.to_public)
    prefix: -p
  - valueFrom: $(inputs.force_change_annotation_acl)
    prefix: -f
  - valueFrom: $(inputs.synapseConfig.path)
    prefix: -c

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: annotationSubmission.py
        entry: |
          #!/usr/bin/env python
          import synapseclient as sc
          import argparse
          import json
          from synapseclient.retry import _with_retry

          def read_args():
              parser = argparse.ArgumentParser()
              parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
              parser.add_argument("-v", "--annotation_values", required=True,
                                  help="JSON file of annotations with key:value pair")
              parser.add_argument("-p", "--to_public",
                                  help="Annotations are by default private "
                                       "except to queue administrator(s), "
                                       "so change them to be public",
                                       action='store_const', const = True,
                                       default='false')
              parser.add_argument("-f", "--force_change_annotation_acl",
                                  help="Ability to update annotations if the key "
                                       "has different ACLs, warning will occur if "
                                       "this parameter isn't specified and the same "
                                       "key has different ACLs",
                                       action='store_const', const = True,
                                       default='false')
              parser.add_argument("-c", "--synapse_config", required=True,
                                  help="credentials file")
              args = parser.parse_args()
              return(args)
          
          def update_single_submission_status(status, add_annotations,
                                              to_public=False,
                                              force_change_annotation_acl=False):
              """
              This will update a single submission's status
              :param:    Submission status: syn.getSubmissionStatus()
              :param:    Annotations that you want to add in dict or submission
                         status annotations format. If dict, all submissions will
                         be added as private submissions
              """
              existing_annotations = status.get("annotations", dict())
              private_annotations = {annotation['key']:annotation['value']
                                     for annotation_type in existing_annotations
                                     for annotation in existing_annotations[annotation_type]
                                     if (annotation_type not in ['scopeId','objectId']
                                         and annotation['isPrivate'] == True)}
              public_annotations = {annotation['key']:annotation['value']
                                    for annotation_type in existing_annotations
                                    for annotation in existing_annotations[annotation_type]
                                    if (annotation_type not in ['scopeId','objectId']
                                        and annotation['isPrivate'] == False)}
              if not sc.annotations.is_submission_status_annotations(add_annotations):
                  private_added_annotations = dict() if to_public else add_annotations
                  public_added_annotations = add_annotations if to_public else dict()
              else:
                  private_added_annotations = {annotation['key']:annotation['value']
                                               for annotation_type in add_annotations
                                               for annotation in add_annotations[annotation_type]
                                               if (annotation_type not in ['scopeId','objectId']
                                                   and annotation['isPrivate'] == True)}
                  public_added_annotations = {annotation['key']:annotation['value']
                                              for annotation_type in add_annotations
                                              for annotation in add_annotations[annotation_type]
                                              if (annotation_type not in ['scopeId','objectId']
                                                  and annotation['isPrivate'] == False)}
              # If you add a private annotation that appears in
              # the public annotation, it switches 
              if not sum([key in public_added_annotations for key in private_annotations]):
                  pass
              elif (sum([key in public_added_annotations for key in private_annotations]) > 0
                    and force_change_annotation_acl):
                  # Filter out the annotations that have changed ACL
                  private_annotations = {key:private_annotations[key]
                                         for key in private_annotations
                                         if key not in public_added_annotations}
              else:
                  raise ValueError("You are trying to change the ACL of these "
                                   "annotation key(s): {}.  Either change the "
                                   "annotation key or specify "
                                   "force_change_annotation_acl=True".format(
                                   ", ".join([key for key in private_annotations
                                              if key in public_added_annotations])))
              if not sum([key in private_added_annotations for key in public_annotations]):
                  pass
              elif (sum([key in private_added_annotations for key in public_annotations]) > 0
                    and force_change_annotation_acl):
                  public_annotations = {key:public_annotations[key]
                                        for key in public_annotations
                                        if key not in private_added_annotations}
              else:
                  raise ValueError("You are trying to change the ACL of these "
                                   "annotation key(s): {}.  Either change the "
                                   "annotation key or specify "
                                   "force_change_annotation_acl=True".format(
                                   ", ".join([key for key in public_annotations
                                              if key in private_added_annotations])))
              private_annotations.update(private_added_annotations)
              public_annotations.update(public_added_annotations)
              priv = sc.annotations.to_submission_status_annotations(
                      private_annotations, is_private=True)
              pub = sc.annotations.to_submission_status_annotations(
                      public_annotations, is_private=False)
              # Combined private and public annotations into one
              for annotation_type in ['stringAnnos', 'longAnnos', 'doubleAnnos']:
                  if (priv.get(annotation_type) is not None
                      and pub.get(annotation_type) is not None):
                      if pub.get(annotation_type) is not None:
                          priv[annotation_type].extend(pub[annotation_type])
                      else:
                          priv[annotation_type] = pub[annotation_type]
                  elif (priv.get(annotation_type) is None
                        and pub.get(annotation_type) is not None):
                      priv[annotation_type] = pub[annotation_type]
              status.annotations = priv
              return(status)

          def annotate_submission(syn, submissionid, annotation_values,
                                  to_public, force_change_annotation_acl):
              status = syn.getSubmissionStatus(submissionid)
              with open(annotation_values) as json_data:
                  annotation_json = json.load(json_data)
              status = update_single_submission_status(
                    status, annotation_json, to_public=to_public,
                    force_change_annotation_acl=force_change_annotation_acl)
              status = syn.store(status)

          def update_status(syn, submission_id, annotation_values):
              status = syn.getSubmissionStatus(submission_id)
              with open(annotation_values, 'r') as f:
                  annotations = json.load(f)
              for k, v in annotations:
                  if k == "prediction_file_status" and v != status["status"]:
                      status['status'] = v
                      syn.store(status)

          def main():
              args = read_args()
              syn = sc.Synapse(configPath=args.synapse_config)
              syn.login()
              update_status(syn, args.submissionid, args.annotation_values)
              _with_retry(lambda: annotate_submission(
                                syn, args.submissionid, args.annotation_values,
                                to_public=args.to_public,
                                force_change_annotation_acl=args.force_change_annotation_acl),
                          wait=3,
                          retries=10)
            
          if __name__ == '__main__':
              main()
     
outputs: []
