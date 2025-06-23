#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/* ----------------------------------------------------------
 * PARAMETERS
 * ---------------------------------------------------------- */

println "▶ FASTA input directory:  ${params.input}"
println "▶ Results directory:      ${params.resultsDir}"
println "▶ Threads / RAM:          ${params.threads}  /  ${params.ram}"

/* ──────────────────────────────────────────────────────────
 * 1 ▸ MASH sketch every .fasta
 * ────────────────────────────────────────────────────────── */
process MASH_SKETCH {
    tag         'mash_sketch'
    container 'quay.io/biocontainers/mash:2.3--hb105d93_9'
    cpus        { params.threads }
    memory      { params.ram }

    input:
    path fasta_files

    output:
    path 'mash.msh'      , emit: msh
    path 'all_files.list', emit: list

    script:
    """
    cat <<< '${fasta_files}' | tr ' ' '\\n' > all_files.list

    mash sketch -p ${task.cpus} -k ${params.mash_k} -s ${params.mash_s} \\
        -o mash.msh -l all_files.list
    """
}

/* ──────────────────────────────────────────────────────────
 * 2 ▸ Mash pairwise distances
 * ────────────────────────────────────────────────────────── */
process MASH_DIST {
    tag         'mash_dist'
    container 'quay.io/biocontainers/mash:2.3--hb105d93_9'
    cpus        4
    memory      '8 GB'

    input:
    path msh

    output:
    path 'mash.dist'

    script:
    """
    mash dist ${msh} ${msh} > mash.dist
    """
}

/* ──────────────────────────────────────────────────────────
 * 3 ▸ Bin genomes & subsample
 * ────────────────────────────────────────────────────────── */
process BIN_SUBSAMPLE {
    tag         'bin_subsample'
    container 'python:3.9'
    cpus        4
    memory      '16 GB'

    input:
    path dist_file

    output:
    path 'subset.list'

    script:
    """
    pip install --quiet networkx
    python - << 'PY'
import networkx as nx, random, sys, pathlib, os

# This is the absolute path to your main input directory
input_dir = "${params.input}"

G = nx.Graph()
# It's likely that mash.dist contains relative filenames
for line in open('${dist_file}'):
    a,b,d,*_ = line.split()
    if float(d) < ${params.mash_thresh}:
        G.add_edge(a,b)

with open('subset.list','w') as out:
    for comp in nx.connected_components(G):
        comp=list(comp)
        k=min(10, max(3, len(comp)//10))
        k=min(k, len(comp))
        if k > 0:
            for relative_path in random.sample(comp, k):
                # Create a sample name from the relative path
                sample_name = os.path.splitext(os.path.basename(relative_path))[0]
                # SOLUTION: Create the full, absolute path for PopPUNK to use
                full_path = os.path.join(input_dir, relative_path)
                out.write(f"{sample_name}\\t{full_path}\\n")
PY
    """
}

/* ──────────────────────────────────────────────────────────
 * 4 ▸ Build PopPUNK model on subset
 * ────────────────────────────────────────────────────────── */
process POPPUNK_MODEL {
    tag          'poppunk_model'
    container    'staphb/poppunk:2.6.2'
    cpus         { params.threads }
    memory       { params.ram }
    publishDir   "${params.resultsDir}/poppunk_model", mode: 'copy'

    input:
    path sub_list

    output:
    path 'poppunk_db', type: 'dir', emit: db
    path 'cluster_model.csv'     , emit: csv

    script:
    """
    poppunk --create-db --r-files ${sub_list} \\
        --output poppunk_db --threads ${task.cpus}

    poppunk --fit-model  --ref-db poppunk_db \\
        --output poppunk_fit --threads ${task.cpus}

    cp poppunk_fit/cluster_assignments.csv cluster_model.csv
    """
}

/* ──────────────────────────────────────────────────────────
 * 5 ▸ Assign *all* genomes to that model
 * ────────────────────────────────────────────────────────── */
process POPPUNK_ASSIGN {
    tag          'poppunk_assign'
    container    'staphb/poppunk:2.6.2'
    cpus         { params.threads }
    memory       { params.ram }
    publishDir   "${params.resultsDir}/poppunk_full", mode: 'copy'

    input:
    path db_dir
    path list_file

    output:
    path 'full_assign.csv'

    script:
    """
    poppunk --assign-query --ref-db ${db_dir} \\
        --qfiles ${list_file} \\
        --output poppunk_full \\
        --threads ${task.cpus}

    cp poppunk_full/cluster_assignments.csv full_assign.csv
    """
}

/* ──────────────────────────────────────────────────────────
 * MAIN WORKFLOW
 * ────────────────────────────────────────────────────────── */
workflow {

    ch_fasta = Channel.fromPath("${params.input}/*.fasta", checkIfExists: true)
    sketch_out = MASH_SKETCH(ch_fasta.collect())
    dist_ch    = MASH_DIST(sketch_out.msh)
    subset_ch  = BIN_SUBSAMPLE(dist_ch)
    model_out  = POPPUNK_MODEL(subset_ch)
    final_csv  = POPPUNK_ASSIGN(model_out.db, sketch_out.list)

    final_csv.view { p -> "✅ PopPUNK assignment written: ${p}" }
}
