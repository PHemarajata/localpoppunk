#!/bin/bash

echo "🧬 Testing PopPUNK Clustering Optimization"
echo "=========================================="

# Clean up previous runs
echo "Cleaning up previous runs..."
rm -rf work .nextflow* /home/peerah/contextual/results

echo ""
echo "Applied Clustering Fixes:"
echo "  ✅ MASH threshold: 0.02 → 0.005 (99.5% ANI, more stringent)"
echo "  ✅ Subsampling: 30% → 15% (more selective)"
echo "  ✅ PopPUNK search depth: 10 → 15 (deeper boundary search)"
echo "  ✅ PopPUNK mixture components: K=2 (better separation)"
echo "  ✅ Enhanced diagnostics and warnings"
echo ""

# Run the pipeline with clustering fixes
echo "Running pipeline with clustering optimization..."
echo "Expected: Multiple clusters instead of single cluster"
echo ""

# Start the pipeline
nextflow run poppunk_subsample_snp.nf -resume

echo ""
echo "Pipeline completed. Analyzing clustering results..."
echo "=================================================="

# Check if assignment completed successfully
if [ -f "/home/peerah/contextual/results/poppunk_full/full_assign.csv" ]; then
    echo "✅ SUCCESS: Assignment file created"
    
    # Analyze clustering results
    total_lines=$(wc -l < /home/peerah/contextual/results/poppunk_full/full_assign.csv)
    assigned_samples=$((total_lines - 1))
    unique_clusters=$(tail -n +2 /home/peerah/contextual/results/poppunk_full/full_assign.csv | cut -d',' -f2 | sort -u | wc -l)
    
    echo "   Total samples assigned: $assigned_samples"
    echo "   Number of unique clusters: $unique_clusters"
    echo ""
    
    # Check if clustering improved
    if [ "$unique_clusters" -eq 1 ]; then
        echo "❌ ISSUE PERSISTS: Still only 1 cluster found"
        echo "   Recommendations:"
        echo "   - Try even stricter MASH threshold (0.001)"
        echo "   - Reduce subsampling further (10%)"
        echo "   - Check if your data is actually very homogeneous"
        echo ""
        echo "   Single cluster may be correct if:"
        echo "   - All samples are from same strain/outbreak"
        echo "   - Data is from highly clonal population"
        echo "   - Samples are very closely related"
    elif [ "$unique_clusters" -lt 5 ]; then
        echo "⚠️  LIMITED IMPROVEMENT: $unique_clusters clusters found"
        echo "   This is better but may still need parameter tuning"
        echo "   Consider further reducing MASH threshold"
    else
        echo "🎉 EXCELLENT IMPROVEMENT: $unique_clusters clusters found!"
        echo "   Clustering optimization successful!"
    fi
    
    echo ""
    echo "Cluster size distribution:"
    tail -n +2 /home/peerah/contextual/results/poppunk_full/full_assign.csv | cut -d',' -f2 | sort | uniq -c | sort -nr | head -10
    
    # Calculate clustering statistics
    largest_cluster=$(tail -n +2 /home/peerah/contextual/results/poppunk_full/full_assign.csv | cut -d',' -f2 | sort | uniq -c | sort -nr | head -1 | awk '{print $1}')
    percentage_in_largest=$((largest_cluster * 100 / assigned_samples))
    
    echo ""
    echo "Clustering Quality Metrics:"
    echo "  - Largest cluster: $largest_cluster samples ($percentage_in_largest%)"
    echo "  - Average cluster size: $((assigned_samples / unique_clusters))"
    
    if [ "$percentage_in_largest" -gt 80 ]; then
        echo "  ⚠️  Warning: $percentage_in_largest% of samples in largest cluster"
        echo "     Consider stricter parameters for better separation"
    elif [ "$percentage_in_largest" -lt 50 ]; then
        echo "  ✅ Good cluster balance: largest cluster is $percentage_in_largest%"
    else
        echo "  ✅ Reasonable cluster balance: largest cluster is $percentage_in_largest%"
    fi
    
else
    echo "❌ FAILURE: Assignment file not created"
    echo "Check pipeline logs for errors"
fi

# Check for component analysis in logs
echo ""
echo "MASH Pre-clustering Analysis:"
echo "============================="
if find work -name ".command.log" -exec grep -l "Component sizes" {} \; 2>/dev/null | head -1 | xargs grep -A 5 "Component sizes" 2>/dev/null; then
    echo "✅ Component analysis found in logs"
else
    echo "⚠️  Component analysis not found - check BIN_SUBSAMPLE logs"
fi

# Summary
echo ""
echo "Clustering Fix Test Summary:"
echo "============================"
if [ "$unique_clusters" -gt 1 ]; then
    echo "✅ SUCCESS: Multiple clusters detected ($unique_clusters clusters)"
    echo "   The single cluster issue has been resolved!"
else
    echo "❌ ISSUE PERSISTS: Still finding single cluster"
    echo "   May need further parameter adjustment or data investigation"
fi

echo ""
echo "Next steps:"
if [ "$unique_clusters" -gt 5 ]; then
    echo "  🎯 Clustering looks good! Analyze biological meaning of clusters"
    echo "  📊 Consider phylogenetic analysis to validate cluster relationships"
elif [ "$unique_clusters" -gt 1 ]; then
    echo "  🔧 Fine-tune parameters for better resolution if needed"
    echo "  📋 Investigate if limited clusters reflect true population structure"
else
    echo "  🔍 Investigate data homogeneity - may be truly clonal population"
    echo "  ⚙️  Try even stricter parameters (mash_thresh = 0.001)"
fi

echo ""
echo "Clustering optimization test complete!"