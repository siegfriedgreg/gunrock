1) run "script_mods.sh", or at least note the order. helps when in the interact environment to install modules in the same order as compilation.
2) clone the github repository in your bridges folder.
3) from the gunrock folder, "mkdir build && cd build/"
4) run "cmake .."
5) run "make" (many warnings present, but still finishes.) running "make help" will also give a list of options.
6) you should have all of the algorithms in your build/bin/ folder. Algorithms are set to find my folders on bridges,
find the appropriate files from the main gunrock to use their directories, or edit for your own.
7) to run a graph from the build/bin directory, in an "interact --gpu" session, try: 
	"./bfs market ../../../maps/gh0**.mtx" where the ** is 1-16.


##################################################################################################################################################################################################################################################
#########################################################################################################################
#########################################################################################################################

SAMPLE RUN (gh012.mtx):

Loading Matrix-market coordinate-formatted graph ...
Reading from ../../../maps/gh012.mtx:
  Parsing MARKET COO format (12057441 nodes, 36164358 directed edges)... Done parsing (6s).
  Converting 12057441 vertices, 36164358 directed edges (unordered tuples) to CSR format...
Done converting (1s).

Degree Histogram (12057441 vertices, 36164358 edges):
    Degree   0: 0 (0.00%)
    Degree 2^0: 0 (0.00%)
    Degree 2^1: 12057441 (100.00%)

  Converting 12057441 vertices, 36164358 directed edges (unordered tuples) to CSR format...
Done converting (2s).
Using 1 GPU: [ 0 ].
Using traversal-mode TWC
__________________________
--------------------------
iteration 0 elapsed: 278.289080 ms, src = 0, #iteration = 4511
Computing reference value ...
CPU BFS finished in 1857.490112 msec. cpu_search_depth: 4511

Label Validity: 
CORRECT

First 40 labels of the GPU result:
[0:0 1:3 2:6 3:9 4:12 5:15 6:18 7:21 8:3189 9:137 10:141 11:3117 12:3082 13:123 14:127 15:3064 16:3063 17:113 18:117 19:171 20:172 21:167 22:168 23:349 24:87 25:83 26:60 27:64 28:73 29:77 30:57 31:61 32:43 33:46 34:187 35:188 36:193 37:194 38:3153 39:18 ]

	Memory Usage(B)	 #keys0,0	 #keys0,1
GPU_0	 1579155456	 78373368	 78373368
	 queue_sizing =	 6.500000 	 6.500000

 [BFS] finished.
 avg. elapsed: 278.2891 ms
 iterations: 4511
 min. elapsed: 278.2891 ms
 max. elapsed: 278.2891 ms
 rate: 129.9525 MiEdges/s
 src: 0
 nodes_visited: 12057441
 edges_visited: 36164358
 nodes queued: 12057441
 edges queued: 36164358
 load time: 28722.4212 ms
 preprocess time: 130.4500 ms
 postprocess time: 179.8768 ms
 total time: 31208.3521 ms



#########################################################################################################################
#########################################################################################################################
########################################################################################################################
