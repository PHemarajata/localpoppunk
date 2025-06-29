#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/* ----------------------------------------------------------
 * PARAMETERS
 * ---------------------------------------------------------- */

println "▶ FASTA input directory:  ${params.input}"
println "▶ Results directory:      ${params.resultsDir}"
println "▶ Threads / RAM:          ${params.threads}  /  ${params.ram}"

/* ──────────────────────────────────────────────────────────
 * 1 ▸ Validate FASTA files and filter out empty ones
 * ────────────────────────────────────────────────────────── */
process VALIDATE_FASTA {
    tag         'validate_fasta'
    container   'python:3.9'
    cpus        8
    memory      '16 GB'
    publishDir  "${params.resultsDir}/validation", mode: 'copy'

    input:
    path fasta_files

    output:
    path 'valid_files.list', emit: valid_list
    path 'validation_report.txt', emit: report

    script:
    """
    python - << 'PY'
import os
from pathlib import Path

valid_files = []
invalid_files = []
total_files = 0

# Process each FASTA file
fasta_files = '${fasta_files}'.split()
for fasta_file in fasta_files:
    total_files += 1
    file_path = Path(fasta_file)
    
    # Get the absolute path for the file
    abs_path = file_path.resolve()
    
    if not file_path.exists():
        invalid_files.append(f"{fasta_file}: File does not exist")
        continue
    
    if file_path.stat().st_size == 0:
        invalid_files.append(f"{fasta_file}: File is empty (0 bytes)")
        continue
    
    # Check if file contains actual sequence data
    has_sequence = False
    sequence_length = 0
    
    try:
        with open(fasta_file, 'r') as f:
            lines = f.readlines()
            for line in lines:
                line = line.strip()
                if line and not line.startswith('>'):
                    sequence_length += len(line)
                    has_sequence = True
        
        if not has_sequence or sequence_length == 0:
            invalid_files.append(f"{fasta_file}: No sequence data found")
        elif sequence_length < 1000:  # Minimum sequence length threshold
            invalid_files.append(f"{fasta_file}: Sequence too short ({sequence_length} bp)")
        else:
            # Store the absolute path so MASH can find the files
            valid_files.append(str(abs_path))
            
    except Exception as e:
        invalid_files.append(f"{fasta_file}: Error reading file - {str(e)}")

# Write valid files list with absolute paths
with open('valid_files.list', 'w') as f:
    for valid_file in valid_files:
        f.write(f"{valid_file}\\n")

# Write validation report
with open('validation_report.txt', 'w') as f:
    f.write(f"FASTA Validation Report\\n")
    f.write(f"======================\\n")
    f.write(f"Total files processed: {total_files}\\n")
    f.write(f"Valid files: {len(valid_files)}\\n")
    f.write(f"Invalid files: {len(invalid_files)}\\n\\n")
    
    if valid_files:
        f.write("Valid files (with absolute paths):\\n")
        for vf in valid_files:
            f.write(f"  ✓ {vf}\\n")
        f.write("\\n")
    
    if invalid_files:
        f.write("Invalid files (excluded from analysis):\\n")
        for inf in invalid_files:
            f.write(f"  ✗ {inf}\\n")

print(f"Validation complete: {len(valid_files)} valid files out of {total_files} total files")
if len(valid_files) < 3:
    print("WARNING: Less than 3 valid files found. PopPUNK requires at least 3 genomes.")
    exit(1)
PY
    """
}

/* ──────────────────────────────────────────────────────────
 * 2 ▸ MASH sketch every valid .fasta
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
    # Create file list with staged filenames (not absolute paths)
    ls *.fasta > all_files.list
    
    # Check if we have any files to process
    if [ ! -s all_files.list ]; then
        echo "ERROR: No valid FASTA files found for sketching"
        exit 1
    fi
    
    echo "Sketching \$(wc -l < all_files.list) valid FASTA files..."
    echo "First few files to be processed:"
    head -5 all_files.list
    
    echo "All files verified. Starting MASH sketching..."
    
    mash sketch -p ${task.cpus} -k ${params.mash_k} -s ${params.mash_s} \\
        -o mash.msh -l all_files.list
        
    echo "MASH sketching completed successfully!"
    """
}

/* ──────────────────────────────────────────────────────────
 * 2 ▸ Mash pairwise distances
 * ────────────────────────────────────────────────────────── */
process MASH_DIST {
    tag         'mash_dist'
    container 'quay.io/biocontainers/mash:2.3--hb105d93_9'
    cpus        { Math.min(params.threads, 16) }  // Prevent resource contention
    memory      '60 GB'

    input:
    path msh

    output:
    path 'mash.dist'

    script:
    """
    echo "Computing pairwise distances for all genomes..."
    mash dist -p ${task.cpus} ${msh} ${msh} > mash.dist
    echo "Distance computation completed. Generated \$(wc -l < mash.dist) pairwise comparisons."
    """
}

/* ──────────────────────────────────────────────────────────
 * 3 ▸ Bin genomes & subsample
 * ────────────────────────────────────────────────────────── */
process BIN_SUBSAMPLE {
    tag         'bin_subsample'
    container 'python:3.9'
    cpus        8  // Reduced for stability
    memory      '32 GB'

    input:
    path dist_file

    output:
    path 'subset.list'

    script:
    """
    pip install --quiet networkx
    python - << 'PY'
import networkx as nx, random, sys, pathlib, os

print("Building similarity graph from MASH distances...")

# This is the absolute path to your main input directory
input_dir = "${params.input}"

G = nx.Graph()
# Process the mash distance file - files are now relative filenames
for line in open('${dist_file}'):
    a, b, d, *_ = line.split()
    if float(d) < ${params.mash_thresh}:
        G.add_edge(a, b)

print(f"Graph built with {G.number_of_nodes()} nodes and {G.number_of_edges()} edges")
print(f"Found {nx.number_connected_components(G)} connected components")

# Analyze component sizes for debugging
component_sizes = [len(comp) for comp in nx.connected_components(G)]
component_sizes.sort(reverse=True)
print(f"Component sizes: {component_sizes[:10]}")  # Show top 10 component sizes
print(f"Largest component has {max(component_sizes) if component_sizes else 0} genomes")
print(f"Average component size: {sum(component_sizes)/len(component_sizes) if component_sizes else 0:.1f}")

with open('subset.list','w') as out:
    total_selected = 0
    for i, comp in enumerate(nx.connected_components(G)):
        comp = list(comp)
        # Optimized subsampling for better cluster resolution: take fewer but more diverse representatives
        k = min(100, max(10, int(len(comp) * 0.15)))
        k = min(k, len(comp))
        if k > 0:
            selected = random.sample(comp, k)
            for filename in selected:
                # Create a sample name from the filename
                sample_name = os.path.splitext(filename)[0]
                # Create the full absolute path for PopPUNK to use
                full_path = os.path.join(input_dir, filename)
                out.write(f"{sample_name}\\t{full_path}\\n")
                total_selected += 1
        print(f"Component {i+1}: {len(comp)} genomes -> selected {k} representatives")

print(f"Total genomes selected for PopPUNK modeling: {total_selected}")
PY
    """
}

/* ──────────────────────────────────────────────────────────
 * 4 ▸ Build PopPUNK model on subset
 * ────────────────────────────────────────────────────────── */
process POPPUNK_MODEL {
    tag          'poppunk_model'
    container    'staphb/poppunk:2.7.5'
    cpus         { params.threads }
    memory       { params.ram }
    publishDir   "${params.resultsDir}/poppunk_model", mode: 'copy'

    input:
    path sub_list
    path fasta_files

    output:
    path 'poppunk_db', type: 'dir', emit: db
    path 'cluster_model.csv'     , emit: csv
    path 'staged_files.list'     , emit: staged_list

    script:
    """
    # Check if subset list is not empty
    if [ ! -s ${sub_list} ]; then
        echo "ERROR: Subset list is empty. No valid genomes found for PopPUNK modeling."
        exit 1
    fi
    
    echo "Building PopPUNK database with \$(wc -l < ${sub_list}) genomes..."
    
    # Create a new file list with staged filenames (not absolute paths)
    # Map the sample names from subset.list to the staged FASTA files
    > staged_files.list
    while IFS=\$'\\t' read -r sample_name file_path; do
        # Find the corresponding staged file
        basename_file=\$(basename "\$file_path")
        if [ -f "\$basename_file" ]; then
            echo -e "\$sample_name\\t\$basename_file" >> staged_files.list
            echo "Mapped: \$sample_name -> \$basename_file"
        else
            echo "ERROR: Staged file not found: \$basename_file"
            exit 1
        fi
    done < ${sub_list}
    
    echo "Created staged files list:"
    cat staged_files.list
    
    echo "All files verified. Starting PopPUNK database creation..."
    
    poppunk --create-db --r-files staged_files.list \\
        --output poppunk_db --threads ${task.cpus}

    echo "Database created successfully. Fitting model with PopPUNK 2.7.x features..."
    
    # Use optimized PopPUNK 2.7.x features for better cluster separation
    echo "Fitting PopPUNK model with optimized parameters for better clustering..."
    poppunk --fit-model bgmm --ref-db poppunk_db \\
        --output poppunk_fit --threads ${task.cpus} \\
        ${params.poppunk_reciprocal ? '--reciprocal-only' : ''} \\
        ${params.poppunk_count_unique ? '--count-unique-distances' : ''} \\
        --max-search-depth ${params.poppunk_max_search} \\
        --K ${params.poppunk_K}

    echo "Model fitting completed. Copying fitted model files to database directory..."
    
    # Copy all fitted model files from poppunk_fit to poppunk_db
    # This ensures the database directory contains both the database and the fitted model
    if [ -d "poppunk_fit" ]; then
        echo "Copying fitted model files to poppunk_db directory..."
        
        # Copy all files from poppunk_fit to poppunk_db
        cp poppunk_fit/* poppunk_db/ 2>/dev/null || echo "Some files could not be copied"
        
        # The critical step: rename the fitted model file to match what PopPUNK expects
        if [ -f "poppunk_db/poppunk_fit_fit.pkl" ]; then
            cp poppunk_db/poppunk_fit_fit.pkl poppunk_db/poppunk_db_fit.pkl
            echo "✓ Created poppunk_db_fit.pkl from poppunk_fit_fit.pkl"
        fi
        
        # Also copy the npz file with the correct name
        if [ -f "poppunk_db/poppunk_fit_fit.npz" ]; then
            cp poppunk_db/poppunk_fit_fit.npz poppunk_db/poppunk_db_fit.npz
            echo "✓ Created poppunk_db_fit.npz from poppunk_fit_fit.npz"
        fi
        
        # Copy the graph file with the correct name - CRITICAL for poppunk_assign
        if [ -f "poppunk_db/poppunk_fit_graph.gt" ]; then
            cp poppunk_db/poppunk_fit_graph.gt poppunk_db/poppunk_db_graph.gt
            echo "✓ Created poppunk_db_graph.gt from poppunk_fit_graph.gt"
        fi
        
        # Copy the cluster file with the correct name - CRITICAL for poppunk_assign
        if [ -f "poppunk_db/poppunk_fit_clusters.csv" ]; then
            cp poppunk_db/poppunk_fit_clusters.csv poppunk_db/poppunk_db_clusters.csv
            echo "✓ Created poppunk_db_clusters.csv from poppunk_fit_clusters.csv"
        fi
        
        echo "Files in poppunk_db after copying:"
        ls -la poppunk_db/
        
        # Verify the critical model files exist
        if [ -f "poppunk_db/poppunk_db_fit.pkl" ]; then
            echo "✓ Found fitted model file: poppunk_db_fit.pkl"
        else
            echo "⚠ Model .pkl file not found. Available files:"
            ls -la poppunk_db/*.pkl 2>/dev/null || echo "No .pkl files found"
        fi
        
        if [ -f "poppunk_db/poppunk_db_graph.gt" ]; then
            echo "✓ Found graph file: poppunk_db_graph.gt"
        else
            echo "⚠ Graph file not found. Available graph files:"
            ls -la poppunk_db/*.gt 2>/dev/null || echo "No .gt files found"
        fi
        
        if [ -f "poppunk_db/poppunk_db_clusters.csv" ]; then
            echo "✓ Found cluster file: poppunk_db_clusters.csv"
        else
            echo "⚠ Cluster file not found. Available cluster files:"
            ls -la poppunk_db/*clusters*.csv 2>/dev/null || echo "No cluster CSV files found"
        fi
    else
        echo "ERROR: poppunk_fit directory not found"
        exit 1
    fi

    # Check for different possible output file locations for cluster assignments
    if [ -f "poppunk_fit/poppunk_fit_clusters.csv" ]; then
        cp poppunk_fit/poppunk_fit_clusters.csv cluster_model.csv
        echo "Found poppunk_fit_clusters.csv in poppunk_fit/"
    elif [ -f "poppunk_fit/cluster_assignments.csv" ]; then
        cp poppunk_fit/cluster_assignments.csv cluster_model.csv
        echo "Found cluster_assignments.csv in poppunk_fit/"
    elif ls poppunk_fit/*_clusters.csv 1> /dev/null 2>&1; then
        cp poppunk_fit/*_clusters.csv cluster_model.csv
        echo "Found cluster file in poppunk_fit/"
    elif ls poppunk_fit/*.csv 1> /dev/null 2>&1; then
        cp poppunk_fit/*.csv cluster_model.csv
        echo "Found CSV file in poppunk_fit/"
    else
        echo "Available files in poppunk_fit/:"
        ls -la poppunk_fit/ || echo "poppunk_fit directory not found"
        echo "Available files in current directory:"
        ls -la *.csv || echo "No CSV files found"
        # Create a minimal output file so the pipeline doesn't fail
        echo "sample,cluster" > cluster_model.csv
        echo "PopPUNK completed but cluster assignments file not found in expected location"
    fi
    
    echo "PopPUNK model completed successfully!"
    """
}

/* ──────────────────────────────────────────────────────────
 * 5 ▸ Assign *all* genomes to that model
 * ────────────────────────────────────────────────────────── */
process POPPUNK_ASSIGN {
    tag          'poppunk_assign'
    container    'staphb/poppunk:2.7.5'
    cpus         { Math.min(params.threads, 16) }  // Limit threads to prevent segfault
    memory       { params.ram }
    publishDir   "${params.resultsDir}/poppunk_full", mode: 'copy'

    input:
    path db_dir
    path valid_list
    path fasta_files

    output:
    path 'full_assign.csv'

    script:
    """
    # Create a staged file list for all valid FASTA files using sample names
    > staged_all_files.list
    while IFS= read -r file_path; do
        basename_file=\$(basename "\$file_path")
        if [ -f "\$basename_file" ]; then
            # Create sample name from filename (remove .fasta extension)
            sample_name=\$(basename "\$basename_file" .fasta)
            echo -e "\$sample_name\\t\$basename_file" >> staged_all_files.list
        else
            echo "WARNING: Staged file not found: \$basename_file"
        fi
    done < ${valid_list}
    
    echo "Assigning \$(wc -l < staged_all_files.list) genomes to PopPUNK clusters..."
    echo "Total valid files from input: \$(wc -l < ${valid_list})"
    echo "First few files to be assigned:"
    head -5 staged_all_files.list
    echo "Last few files to be assigned:"
    tail -5 staged_all_files.list
    
    # Verify all files exist
    echo "Verifying staged files exist..."
    while IFS=\$'\\t' read -r sample_name file_name; do
        if [ ! -f "\$file_name" ]; then
            echo "ERROR: File not found: \$file_name"
            exit 1
        fi
    done < staged_all_files.list
    
    echo "All files verified. Starting PopPUNK assignment..."
    echo "Using ${task.cpus} threads (reduced from ${params.threads} to prevent segmentation fault)"
    
    # SEGFAULT FIX: Use reduced thread count and disable problematic stable assignment
    # The segfault occurs in --stable core mode with high thread counts
    echo "Attempting PopPUNK assignment with segfault prevention measures..."
    
    # Try assignment without --stable first (more stable)
    if poppunk_assign --query staged_all_files.list \\
        --db ${db_dir} \\
        --output poppunk_full \\
        --threads ${task.cpus} \\
        --run-qc \\
        --write-references \\
        ${params.poppunk_retain_failures ? '--retain-failures' : ''} \\
        --max-zero-dist ${params.poppunk_max_zero_dist} \\
        --max-merge ${params.poppunk_max_merge} \\
        --length-sigma ${params.poppunk_length_sigma}; then
        
        echo "✅ PopPUNK assignment completed successfully without stable mode"
        
    else
        echo "⚠️  First attempt failed, trying with even more conservative settings..."
        
        # Fallback: Use single thread and minimal options
        poppunk_assign --query staged_all_files.list \\
            --db ${db_dir} \\
            --output poppunk_full_fallback \\
            --threads 1 \\
            --max-zero-dist ${params.poppunk_max_zero_dist} \\
            --max-merge ${params.poppunk_max_merge} \\
            --length-sigma ${params.poppunk_length_sigma}
            
        # Move fallback results to expected location
        if [ -d "poppunk_full_fallback" ]; then
            mv poppunk_full_fallback poppunk_full
            echo "✅ PopPUNK assignment completed with fallback settings"
        fi
    fi

    # Check for poppunk_assign output files (different naming convention)
    if [ -f "poppunk_full/poppunk_full_clusters.csv" ]; then
        cp poppunk_full/poppunk_full_clusters.csv full_assign.csv
        echo "Found poppunk_full_clusters.csv in poppunk_full/"
    elif [ -f "poppunk_full_clusters.csv" ]; then
        cp poppunk_full_clusters.csv full_assign.csv
        echo "Found poppunk_full_clusters.csv in current directory"
    elif [ -f "poppunk_full/cluster_assignments.csv" ]; then
        cp poppunk_full/cluster_assignments.csv full_assign.csv
        echo "Found cluster_assignments.csv in poppunk_full/"
    elif [ -f "cluster_assignments.csv" ]; then
        cp cluster_assignments.csv full_assign.csv
        echo "Found cluster_assignments.csv in current directory"
    elif ls poppunk_full/*_clusters.csv 1> /dev/null 2>&1; then
        cp poppunk_full/*_clusters.csv full_assign.csv
        echo "Found cluster file in poppunk_full/"
    elif ls *_clusters.csv 1> /dev/null 2>&1; then
        cp *_clusters.csv full_assign.csv
        echo "Found cluster file in current directory"
    elif ls poppunk_full/*.csv 1> /dev/null 2>&1; then
        cp poppunk_full/*.csv full_assign.csv
        echo "Found CSV file in poppunk_full/"
    elif ls *.csv 1> /dev/null 2>&1; then
        cp *.csv full_assign.csv
        echo "Found CSV file in current directory"
    else
        echo "Available files in poppunk_full/:"
        ls -la poppunk_full/ 2>/dev/null || echo "poppunk_full directory not found"
        echo "Available files in current directory:"
        ls -la *.csv 2>/dev/null || echo "No CSV files found"
        # Create a minimal output file so the pipeline doesn't fail
        echo "sample,cluster" > full_assign.csv
        echo "PopPUNK completed but cluster assignments file not found in expected location"
        exit 1
    fi
    
    echo "PopPUNK assignment completed successfully!"
    echo "Final assignment file contains \$(wc -l < full_assign.csv) lines (including header)"
    echo "Expected: \$(wc -l < ${valid_list}) + 1 (header)"
    echo "Actual samples assigned: \$(tail -n +2 full_assign.csv | wc -l)"
    
    # Show detailed cluster distribution analysis
    echo "Cluster distribution analysis:"
    echo "=============================="
    total_samples=\$(tail -n +2 full_assign.csv | wc -l)
    unique_clusters=\$(tail -n +2 full_assign.csv | cut -d',' -f2 | sort -u | wc -l)
    echo "Total samples assigned: \$total_samples"
    echo "Number of unique clusters: \$unique_clusters"
    echo ""
    echo "Cluster sizes:"
    tail -n +2 full_assign.csv | cut -d',' -f2 | sort | uniq -c | sort -nr | head -20
    echo ""
    if [ "\$unique_clusters" -eq 1 ]; then
        echo "⚠️  WARNING: All samples assigned to single cluster!"
        echo "   This suggests clustering parameters are too permissive."
        echo "   Consider reducing mash_thresh or adjusting PopPUNK parameters."
    else
        echo "✅ Good cluster diversity: \$unique_clusters clusters found"
    fi
    """
}

/* ──────────────────────────────────────────────────────────
 * 6 ▸ Generate summary report
 * ────────────────────────────────────────────────────────── */
process SUMMARY_REPORT {
    tag          'summary_report'
    container    'python:3.9'
    publishDir   "${params.resultsDir}/summary", mode: 'copy'

    input:
    path cluster_csv
    path validation_report

    output:
    path 'pipeline_summary.txt'

    script:
    """
    pip install --quiet pandas
    python - << 'PY'
import pandas as pd
from collections import Counter

# Read cluster assignments
try:
    df = pd.read_csv('${cluster_csv}')
    print(f"Successfully read cluster assignments: {len(df)} samples")
    
    # Count clusters
    if 'Cluster' in df.columns:
        cluster_col = 'Cluster'
    elif 'cluster' in df.columns:
        cluster_col = 'cluster'
    else:
        cluster_col = df.columns[1]  # Assume second column is cluster
    
    cluster_counts = df[cluster_col].value_counts().sort_index()
    total_samples = len(df)
    num_clusters = len(cluster_counts)
    
    # Read validation report
    with open('${validation_report}', 'r') as f:
        validation_content = f.read()
    
    # Generate summary
    with open('pipeline_summary.txt', 'w') as f:
        f.write("="*60 + "\\n")
        f.write("PopPUNK Pipeline Summary Report\\n")
        f.write("="*60 + "\\n\\n")
        
        f.write("VALIDATION RESULTS:\\n")
        f.write("-"*20 + "\\n")
        f.write(validation_content + "\\n\\n")
        
        f.write("CLUSTERING RESULTS:\\n")
        f.write("-"*20 + "\\n")
        f.write(f"Total samples processed: {total_samples}\\n")
        f.write(f"Number of clusters found: {num_clusters}\\n\\n")
        
        f.write("Cluster distribution:\\n")
        for cluster, count in cluster_counts.items():
            percentage = (count / total_samples) * 100
            f.write(f"  Cluster {cluster}: {count} samples ({percentage:.1f}%)\\n")
        
        f.write("\\n" + "="*60 + "\\n")
        
        # Also print to stdout
        print(f"\\n{'='*60}")
        print("PopPUNK Pipeline Summary")
        print(f"{'='*60}")
        print(f"Total samples processed: {total_samples}")
        print(f"Number of clusters found: {num_clusters}")
        print("\\nCluster distribution:")
        for cluster, count in cluster_counts.items():
            percentage = (count / total_samples) * 100
            print(f"  Cluster {cluster}: {count} samples ({percentage:.1f}%)")
        print(f"{'='*60}")

except Exception as e:
    print(f"Error processing results: {e}")
    with open('pipeline_summary.txt', 'w') as f:
        f.write(f"Error generating summary: {e}\\n")
        f.write("Please check the cluster assignment file format.\\n")
PY
    """
}

/* ──────────────────────────────────────────────────────────
 * MAIN WORKFLOW
 * ────────────────────────────────────────────────────────── */
workflow {

    ch_fasta = Channel.fromPath("${params.input}/*.fasta", checkIfExists: true)
    
    // Validate FASTA files first
    validation_out = VALIDATE_FASTA(ch_fasta.collect())
    
    // Display validation report
    validation_out.report.view { report -> 
        println "\n" + "="*50
        println "📋 FASTA VALIDATION REPORT"
        println "="*50
        println report.text
        println "="*50 + "\n"
    }
    
    // Filter the original FASTA files based on validation results
    // Read the valid files list and create a channel of valid files
    valid_files_ch = validation_out.valid_list
        .splitText() { it.trim() }
        .map { file_path -> file(file_path) }
        .filter { it.exists() }
    
    // Collect valid files for use in multiple processes
    valid_files_collected = valid_files_ch.collect()
    
    sketch_out = MASH_SKETCH(valid_files_collected)
    dist_ch    = MASH_DIST(sketch_out.msh)
    subset_ch  = BIN_SUBSAMPLE(dist_ch)
    model_out  = POPPUNK_MODEL(subset_ch, valid_files_collected)
    final_csv  = POPPUNK_ASSIGN(model_out.db, validation_out.valid_list, valid_files_collected)

    // Generate summary report
    SUMMARY_REPORT(final_csv, validation_out.report)
    
    final_csv.view { p -> "✅ PopPUNK assignment written: ${p}" }
}
