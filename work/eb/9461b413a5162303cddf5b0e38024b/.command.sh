#!/bin/bash -ue
# Create a staged file list for all FASTA files
ls *.fasta > staged_all_files.list

echo "Assigning $(wc -l < staged_all_files.list) genomes to PopPUNK clusters..."
echo "First few files:"
head -5 staged_all_files.list

poppunk --use-model --ref-db poppunk_db \
    --r-files staged_all_files.list \
    --output poppunk_full \
    --threads 48

# Check for different possible output file locations for cluster assignments
if [ -f "poppunk_full/poppunk_full_clusters.csv" ]; then
    cp poppunk_full/poppunk_full_clusters.csv full_assign.csv
    echo "Found poppunk_full_clusters.csv in poppunk_full/"
elif [ -f "poppunk_full/cluster_assignments.csv" ]; then
    cp poppunk_full/cluster_assignments.csv full_assign.csv
    echo "Found cluster_assignments.csv in poppunk_full/"
elif ls poppunk_full/*_clusters.csv 1> /dev/null 2>&1; then
    cp poppunk_full/*_clusters.csv full_assign.csv
    echo "Found cluster file in poppunk_full/"
elif ls poppunk_full/*.csv 1> /dev/null 2>&1; then
    cp poppunk_full/*.csv full_assign.csv
    echo "Found CSV file in poppunk_full/"
else
    echo "Available files in poppunk_full/:"
    ls -la poppunk_full/ || echo "poppunk_full directory not found"
    echo "Available files in current directory:"
    ls -la *.csv || echo "No CSV files found"
    # Create a minimal output file so the pipeline doesn't fail
    echo "sample,cluster" > full_assign.csv
    echo "PopPUNK completed but cluster assignments file not found in expected location"
    exit 1
fi

echo "PopPUNK assignment completed successfully!"
