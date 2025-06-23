#!/bin/bash -ue
# Check if subset list is not empty
if [ ! -s subset.list ]; then
    echo "ERROR: Subset list is empty. No valid genomes found for PopPUNK modeling."
    exit 1
fi

echo "Building PopPUNK database with $(wc -l < subset.list) genomes..."
cat subset.list

# Verify all files in the subset list exist and are readable
while IFS=$'\t' read -r sample_name file_path; do
    if [ ! -f "$file_path" ]; then
        echo "ERROR: File not found: $file_path"
        exit 1
    fi
    if [ ! -s "$file_path" ]; then
        echo "ERROR: File is empty: $file_path"
        exit 1
    fi
done < subset.list

echo "All files verified. Starting PopPUNK database creation..."

poppunk --create-db --r-files subset.list \
    --output poppunk_db --threads 48

echo "Database created successfully. Fitting model..."

poppunk --fit-model  --ref-db poppunk_db \
    --output poppunk_fit --threads 48

cp poppunk_fit/cluster_assignments.csv cluster_model.csv

echo "PopPUNK model completed successfully!"
