#!/bin/bash

echo "Testing Improved PopPUNK 2.7.5 Pipeline"
echo "========================================"

# Clean up previous runs
echo "Cleaning up previous runs..."
rm -rf work .nextflow* /home/peerah/contextual/results

# Run the pipeline
echo "Running pipeline with PopPUNK 2.7.5 and new features..."
echo "Expected improvements:"
echo "  - PopPUNK 2.7.5 with new features"
echo "  - More generous subsampling (30% of each component)"
echo "  - All 450 genomes should be assigned"
echo "  - Better cluster resolution"
echo "  - Fixed pandas installation"
echo ""

nextflow run poppunk_subsample_snp.nf -resume

echo ""
echo "Pipeline completed. Analyzing results..."
echo "========================================"

# Check validation results
if [ -f "/home/peerah/contextual/results/validation/validation_report.txt" ]; then
    echo "✅ Validation report found"
    valid_count=$(grep "Valid files:" /home/peerah/contextual/results/validation/validation_report.txt | cut -d':' -f2 | tr -d ' ')
    echo "Valid files: $valid_count"
else
    echo "❌ Validation report not found"
fi

# Check assignment results
if [ -f "/home/peerah/contextual/results/poppunk_full/full_assign.csv" ]; then
    echo "✅ Full assignment file found"
    total_lines=$(wc -l < /home/peerah/contextual/results/poppunk_full/full_assign.csv)
    assigned_samples=$((total_lines - 1))
    echo "Total lines in full_assign.csv: $total_lines"
    echo "Samples assigned: $assigned_samples"
    
    echo ""
    echo "Cluster distribution:"
    tail -n +2 /home/peerah/contextual/results/poppunk_full/full_assign.csv | cut -d',' -f2 | sort | uniq -c | sort -nr
    
    echo ""
    echo "First 10 assignments:"
    head -10 /home/peerah/contextual/results/poppunk_full/full_assign.csv
    
    # Check if we got all samples
    if [ "$assigned_samples" -eq "$valid_count" ]; then
        echo "✅ SUCCESS: All valid samples were assigned!"
    else
        echo "⚠️  WARNING: Only $assigned_samples out of $valid_count samples were assigned"
    fi
else
    echo "❌ Full assignment file not found"
fi

# Check summary report
if [ -f "/home/peerah/contextual/results/summary/pipeline_summary.txt" ]; then
    echo "✅ Summary report found"
    echo ""
    echo "Summary Report:"
    echo "==============="
    cat /home/peerah/contextual/results/summary/pipeline_summary.txt
else
    echo "❌ Summary report not found"
fi

# Check for any errors in logs
echo ""
echo "Checking for errors in process logs..."
echo "====================================="
find work -name ".command.log" -exec grep -l "ERROR\|Error\|error" {} \; | while read logfile; do
    echo "Errors found in: $logfile"
    grep -A 3 -B 3 "ERROR\|Error\|error" "$logfile"
    echo "---"
done

echo ""
echo "Analysis complete!"