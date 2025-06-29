#!/bin/bash

echo "🧹 Cleaning up PopPUNK repository for efficient download..."
echo "=================================================="

# Remove Nextflow execution artifacts
echo "Removing Nextflow execution files..."
rm -rf work/
rm -rf .nextflow/
rm -f .nextflow.log*

# Remove HTML reports and timelines
echo "Removing HTML reports and timelines..."
rm -f report-*.html
rm -f timeline-*.html
rm -f dag-*.html
rm -f trace-*.txt

# Remove temporary and log files
echo "Removing temporary files..."
rm -f *.tmp
rm -f *.temp
rm -f *.log
rm -f core.*

# Remove results directory if it exists (user-specific)
if [ -d "results/" ]; then
    echo "Removing results directory..."
    rm -rf results/
fi

# Clean up git repository
echo "Optimizing git repository..."
git gc --aggressive --prune=now 2>/dev/null || echo "Git cleanup skipped (not a git repo or no git)"

# Show final size
echo ""
echo "✅ Cleanup complete!"
echo "Repository size after cleanup:"
du -sh .

echo ""
echo "Files remaining:"
ls -la

echo ""
echo "🎉 Repository is now optimized for efficient download!"
echo "   - Removed execution artifacts"
echo "   - Removed HTML reports"
echo "   - Optimized git history"
echo "   - Added .gitignore for future runs"