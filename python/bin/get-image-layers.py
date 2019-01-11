#!/usr/bin/env python

import os
import sys

import skimage.io
import numpy as np

import synapseclient
import pandas

def get_unique_object_labels(img, timepoint, experiment, well):
    return pandas.DataFrame({"Experiment": experiment, "Well": well,
                             "TimePoint": timepoint,
                             "ObjectLabelsFound": np.unique(img)})

def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--synapseConfig", type=str, default="~/.synapseConfig")
    parser.add_argument("synapseid", type=str)
    
    args = parser.parse_args()

    syn = synapseclient.Synapse(configPath=args.synapseConfig)
    syn.login(silent=True)

    f = syn.get(args.synapseid)
    img_stack = skimage.io.imread(f.path)

    df = pandas.DataFrame()

    for x in range(img_stack.shape[0]):
        
        foo = get_unique_object_labels(img_stack[x], timepoint=x, experiment=f.Experiment[0], well=f.Well[0])
        
        df = pandas.concat([df, foo])

    df[["Experiment", "TimePoint", "ObjectLabelsFound"]].to_csv("/dev/stdout", index=False)

if __name__ == "__main__":
    main()

