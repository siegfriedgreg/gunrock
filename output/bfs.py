#!/usr/bin/env python

import os

for binary in ["direction_optimizing_bfs", "breadth_first_search"]:
    for mark_pred in ["", "--mark-pred"]:
        for directed in ["", "--undirected"]:
            for dataset in ['gh001',
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
                            'gh015',
                            'gh016']:
                os.system("../../gunrock/build/bin/%s market ../../maps/%s.mtx --src=0 %s %s --idempotence --iteration-num=10 --quiet --jsondir=." % (binary, dataset, mark_pred, directed))
