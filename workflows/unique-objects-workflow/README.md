# Unique Objects in NeuroLINCS images

This is a workflow to get unique `ObjectLabelsFound` from NeuroLINCS image masks. It uses the Python package [`neurolincsdreamchallenge`](https://github.com/Sage-Bionetworks/neurolincsdreamchallenge/blob/master/python/).

It is also an example of how to structure a CWL workflow to consume IDs from Synapse and run them in parallel using Toil.

This uses the [scatter](https://www.commonwl.org/user_guide/23-scatter-workflow/) feature of CWL. This puts the burden of identifying the tasks to run outside of the CWL definition.

## Requirements

See [requirements.txt](requirements.txt) for full listing.

- Python 2.7 (due to Toil)
- Toil
- CWL
- Synapse Python client

## Installation

1.. Clone this repository.
1. `pip install -r workflows/requirements.txt`
1. `pip install git+https://www.github.com/Sage-Bionetworks/neurolincsdreamchallenge.git#egg=neurolincsdreamchallenge&subdirectory=python`

## Usage

This specific workflow uses Synapse IDs obtained from a [Synapse File View](syn11688505) and uses the `Experiment` and `Well` columns to limit, as these are required by the [Python script](https://github.com/Sage-Bionetworks/neurolincsdreamchallenge/blob/master/python/bin/get-image-layers.py) that processes them.

1. Get a list of Synapse IDs to process. They will need to be added to a JSON-formatted file. This is one way to get the IDs in a way that can be copy-pasted into a JSON file:
    ``` shell
    synapse query 'select id from syn11688505 where Experiment is not NULL and Well is not NULL' | cut -f 4 | python -c "import pandas; df = pandas.read_csv('/dev/stdin', delimiter='\t')['id'].to_json('/dev/stdout', orient='records')"
    ```
1. Update the [`core-workflow-job.json`](core-workflow-job.json) template by replacing the `message_array` with your list of IDs and providing the path to your `.synapseConfig` file. The file will look like this:

    ``` json
    {
        "synapseConfig": {
            "class": "File",
            "path": "/home/yourhomedirectory/.synapseConfig"},
        "message_array": ["syn123", "syn456"]
    }

    ```
1. Run the workflow using `cwltoil`:

    ``` shell
    cwltoil core-workflow.cwl core-workflow-job.json
    ```
