#!/bin/bash -ue
echo "Running PopPUNK 2.7.x QC analysis..."

# Run QC with enhanced reporting
poppunk --qc-db --ref-db poppunk_db \
    --output qc_analysis \
    --threads 62

# Generate QC report
echo "PopPUNK 2.7.x QC Analysis Report" > qc_report.txt
echo "=================================" >> qc_report.txt
echo "Generated on: $(date)" >> qc_report.txt
echo "" >> qc_report.txt

# Copy QC outputs
if [ -d "qc_analysis" ]; then
    cp -r qc_analysis qc_plots
    echo "QC analysis completed successfully" >> qc_report.txt
    echo "QC plots and data available in qc_plots directory" >> qc_report.txt
else
    echo "QC analysis completed but no output directory found" >> qc_report.txt
fi

echo "PopPUNK QC completed!"
