#!/bin/bash -ue
# Check if subset list is not empty
if [ ! -s subset.list ]; then
    echo "ERROR: Subset list is empty. No valid genomes found for PopPUNK modeling."
    exit 1
fi

echo "Building PopPUNK database with $(wc -l < subset.list) genomes..."

# Create a new file list with staged filenames (not absolute paths)
# Map the sample names from subset.list to the staged FASTA files
> staged_files.list
while IFS=$'\t' read -r sample_name file_path; do
    # Find the corresponding staged file
    basename_file=$(basename "$file_path")
    if [ -f "$basename_file" ]; then
        echo -e "$sample_name\t$basename_file" >> staged_files.list
        echo "Mapped: $sample_name -> $basename_file"
    else
        echo "ERROR: Staged file not found: $basename_file"
        exit 1
    fi
done < subset.list

echo "Created staged files list:"
cat staged_files.list

echo "All files verified. Starting PopPUNK database creation..."

poppunk --create-db --r-files staged_files.list \
    --output poppunk_db --threads 48

echo "Database created successfully. Fitting model..."

poppunk --fit-model  --ref-db poppunk_db \
    --output poppunk_fit --threads 48

cp poppunk_fit/cluster_assignments.csv cluster_model.csv

echo "PopPUNK model completed successfully!"
