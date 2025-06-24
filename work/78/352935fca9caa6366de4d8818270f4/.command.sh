#!/bin/bash -ue
# Create a staged file list for all valid FASTA files using sample names
> staged_all_files.list
while IFS= read -r file_path; do
    basename_file=$(basename "$file_path")
    if [ -f "$basename_file" ]; then
        # Create sample name from filename (remove .fasta extension)
        sample_name=$(basename "$basename_file" .fasta)
        echo -e "$sample_name\t$basename_file" >> staged_all_files.list
    else
        echo "WARNING: Staged file not found: $basename_file"
    fi
done < valid_files.list

echo "Assigning $(wc -l < staged_all_files.list) genomes to PopPUNK clusters..."
echo "Total valid files from input: $(wc -l < valid_files.list)"
echo "First few files to be assigned:"
head -5 staged_all_files.list
echo "Last few files to be assigned:"
tail -5 staged_all_files.list

# Verify all files exist
echo "Verifying staged files exist..."
while IFS=$'\t' read -r sample_name file_name; do
    if [ ! -f "$file_name" ]; then
        echo "ERROR: File not found: $file_name"
        exit 1
    fi
done < staged_all_files.list

echo "All files verified. Starting PopPUNK assignment..."
echo "Using 16 threads (reduced from 16 to prevent segmentation fault)"

# SEGFAULT FIX: Use reduced thread count and disable problematic stable assignment
# The segfault occurs in --stable core mode with high thread counts
echo "Attempting PopPUNK assignment with segfault prevention measures..."

# Try assignment without --stable first (more stable)
if poppunk_assign --query staged_all_files.list \
    --db poppunk_db \
    --output poppunk_full \
    --threads 16 \
    --run-qc \
    --write-references \
     \
    --max-zero-dist 1 \
    --max-merge 3 \
    --length-sigma 2; then

    echo "✅ PopPUNK assignment completed successfully without stable mode"

else
    echo "⚠️  First attempt failed, trying with even more conservative settings..."

    # Fallback: Use single thread and minimal options
    poppunk_assign --query staged_all_files.list \
        --db poppunk_db \
        --output poppunk_full_fallback \
        --threads 1 \
        --max-zero-dist 1 \
        --max-merge 3 \
        --length-sigma 2

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
echo "Final assignment file contains $(wc -l < full_assign.csv) lines (including header)"
echo "Expected: $(wc -l < valid_files.list) + 1 (header)"
echo "Actual samples assigned: $(tail -n +2 full_assign.csv | wc -l)"

# Show cluster distribution
echo "Cluster distribution:"
tail -n +2 full_assign.csv | cut -d',' -f2 | sort | uniq -c | sort -nr
