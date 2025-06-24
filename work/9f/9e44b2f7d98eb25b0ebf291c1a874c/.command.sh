#!/bin/bash -ue
pip install --quiet networkx
    python - << 'PY'
import networkx as nx, random, sys, pathlib, os

print("Building similarity graph from MASH distances...")

# This is the absolute path to your main input directory
input_dir = "/home/peerah/contextual"

G = nx.Graph()
# Process the mash distance file - files are now relative filenames
for line in open('mash.dist'):
    a, b, d, *_ = line.split()
    if float(d) < 0.02:
        G.add_edge(a, b)

print(f"Graph built with {G.number_of_nodes()} nodes and {G.number_of_edges()} edges")
print(f"Found {nx.number_connected_components(G)} connected components")

with open('subset.list','w') as out:
    total_selected = 0
    for i, comp in enumerate(nx.connected_components(G)):
        comp = list(comp)
        # Very generous subsampling: take at least 30% of each component, minimum 25, maximum 200
        k = min(200, max(25, int(len(comp) * 0.3)))
        k = min(k, len(comp))
        if k > 0:
            selected = random.sample(comp, k)
            for filename in selected:
                # Create a sample name from the filename
                sample_name = os.path.splitext(filename)[0]
                # Create the full absolute path for PopPUNK to use
                full_path = os.path.join(input_dir, filename)
                out.write(f"{sample_name}\t{full_path}\n")
                total_selected += 1
        print(f"Component {i+1}: {len(comp)} genomes -> selected {k} representatives")

print(f"Total genomes selected for PopPUNK modeling: {total_selected}")
PY
