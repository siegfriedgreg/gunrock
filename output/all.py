#!/usr/bin/env python

import os

datasets = ['gh001',
            'gh002',
            'gh003',
            'gh004',
            'gh005',
            'gh006',
            'gh007',
            'gh008',
            'gh009',
            'gh010',
            'gh011',
            'gh012',
            'gh013',
            'gh014',
            'gh015'
            'gh016']

options = {
    "direction_optimizing_bfs" : "--src=0 --idempotence",
    "breadth_first_search" : "--src=0 --idempotence",
    "betweenness_centrality": "--src=0",
    "connected_component": "",
    "pagerank": "--undirected",
    "single_source_shortest_path": "--src=0 --undirected",
}


for binary in ["direction_optimizing_bfs", "breadth_first_search"]:
    for mark_pred in ["", "--mark-pred"]:
        for directed in ["", "--undirected"]:
            for dataset in datasets:
                os.system("../../gunrock/build/bin/%s market ../../maps/%s.mtx %s %s %s --iteration-num=10 --quiet --jsondir=." % (binary, dataset, options[binary], mark_pred, directed))

for binary in ["betweenness_centrality",
               "connected_component",
               "pagerank",
               "single_source_shortest_path"]:
    for dataset in datasets:
        os.system("../../gunrock/build/bin/%s market ../../maps/%s.mtx %s --iteration-num=10 --quiet --jsondir=." % (binary, dataset, options[binary]))
