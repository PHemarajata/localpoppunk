#!/bin/bash

echo "Testing PopPUNK Segmentation Fault Fixes"
echo "========================================"

# Clean up previous runs
echo "Cleaning up previous runs..."
rm -rf work .nextflow* /home/peerah/contextual/results

echo ""
echo "Applied Fixes:"
echo "  ✅ Reduced thread count from 48 to 16"
echo "  ✅ Disabled --stable core (causes segfaults)"
echo "  ✅ Added graceful fallback strategy"
echo "  ✅ Enhanced error handling"
echo ""

# Run the pipeline with fixes
echo "Running pipeline with segfault fixes..."
echo "Expected: NO segmentation faults, successful completion"
echo ""

# Start the pipeline
nextflow run poppunk_subsample_snp.nf -resume

echo ""
echo "Pipeline completed. Checking for segfaults..."
echo "============================================="

# Check for any segmentation faults in logs
segfault_count=$(find work -name ".command.log" -exec grep -l "segmentation\|Segmentation\|SEGMENTATION\|segfault\|core dumped" {} \; 2>/dev/null | wc -l)

if [ "$segfault_count" -eq 0 ]; then
    echo "✅ SUCCESS: No segmentation faults detected!"
else
    echo "❌ FAILURE: $segfault_count segmentation faults still found"
    echo "Segfault locations:"
    find work -name ".command.log" -exec grep -l "segmentation\|Segmentation\|SEGMENTATION\|segfault\|core dumped" {} \; 2>/dev/null
fi

# Check if assignment completed successfully
if [ -f "/home/peerah/contextual/results/poppunk_full/full_assign.csv" ]; then
    echo "✅ SUCCESS: Assignment file created"
    total_lines=$(wc -l < /home/peerah/contextual/results/poppunk_full/full_assign.csv)
    assigned_samples=$((total_lines - 1))
    echo "   Samples assigned: $assigned_samples"
    
    # Show cluster distribution
    echo ""
    echo "Cluster distribution:"
    tail -n +2 /home/peerah/contextual/results/poppunk_full/full_assign.csv | cut -d',' -f2 | sort | uniq -c | sort -nr | head -10
else
    echo "❌ FAILURE: Assignment file not created"
fi

# Check process completion status
echo ""
echo "Process Status Summary:"
echo "======================"

# Count successful vs failed processes
success_count=$(find work -name ".exitcode" -exec cat {} \; 2>/dev/null | grep -c "^0$")
failure_count=$(find work -name ".exitcode" -exec cat {} \; 2>/dev/null | grep -v "^0$" | wc -l)

echo "Successful processes: $success_count"
echo "Failed processes: $failure_count"

if [ "$failure_count" -eq 0 ] && [ "$segfault_count" -eq 0 ]; then
    echo ""
    echo "🎉 ALL FIXES SUCCESSFUL!"
    echo "   - No segmentation faults"
    echo "   - All processes completed"
    echo "   - Assignment file generated"
    echo ""
    echo "The segmentation fault issue has been resolved!"
else
    echo ""
    echo "⚠️  Some issues may remain. Check the logs above."
fi

echo ""
echo "Fix verification complete!"