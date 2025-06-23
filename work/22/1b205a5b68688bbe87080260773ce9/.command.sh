#!/bin/bash -ue
# Create a staged file list for all FASTA files
ls *.fasta > staged_all_files.list

echo "Assigning $(wc -l < staged_all_files.list) genomes to PopPUNK clusters..."
echo "First few files:"
head -5 staged_all_files.list

poppunk --use-model --ref-db poppunk_db \
    --qfiles staged_all_files.list \
    --output poppunk_full \
    --threads 48

cp poppunk_full/cluster_assignments.csv full_assign.csv

echo "PopPUNK assignment completed successfully!"
