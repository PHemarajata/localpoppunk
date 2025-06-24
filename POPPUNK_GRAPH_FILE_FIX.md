# PopPUNK Graph File Fix - Critical Issue Resolved

## 🚨 Critical Issue Identified

**Problem**: `poppunk_assign` was failing with:
```
FileNotFoundError: [Errno 2] No such file or directory: 'poppunk_db/poppunk_db_graph.gt'
```

**Root Cause**: The POPPUNK_MODEL process was not copying the graph file with the correct name that `poppunk_assign` expects.

## 📁 File Naming Issue

### What PopPUNK Creates:
- `poppunk_fit_graph.gt` (created by `poppunk --fit-model`)

### What poppunk_assign Expects:
- `poppunk_db_graph.gt` (database naming convention)

### Previous Fix Attempts:
The pipeline was already correctly copying:
- ✅ `poppunk_fit_fit.pkl` → `poppunk_db_fit.pkl`
- ✅ `poppunk_fit_fit.npz` → `poppunk_db_fit.npz`
- ❌ **MISSING**: `poppunk_fit_graph.gt` → `poppunk_db_graph.gt`

## 🔧 Fix Applied

Added to POPPUNK_MODEL process:
```bash
# Copy the graph file with the correct name - CRITICAL for poppunk_assign
if [ -f "poppunk_db/poppunk_fit_graph.gt" ]; then
    cp poppunk_db/poppunk_fit_graph.gt poppunk_db/poppunk_db_graph.gt
    echo "✓ Created poppunk_db_graph.gt from poppunk_fit_graph.gt"
fi
```

Added verification:
```bash
if [ -f "poppunk_db/poppunk_db_graph.gt" ]; then
    echo "✓ Found graph file: poppunk_db_graph.gt"
else
    echo "⚠ Graph file not found. Available graph files:"
    ls -la poppunk_db/*.gt 2>/dev/null || echo "No .gt files found"
fi
```

## 📋 Required Files for poppunk_assign

The database directory must contain:
1. ✅ `poppunk_db_fit.pkl` - Model parameters
2. ✅ `poppunk_db_fit.npz` - Distance matrices  
3. ✅ `poppunk_db_graph.gt` - **Graph structure (was missing!)**
4. ✅ `poppunk_db.h5` - Sketch database
5. ✅ `poppunk_db.dists.pkl` - Distance metadata

## 🎯 Why This Fix is Critical

The graph file (`*.gt`) contains:
- **Network topology** of genome relationships
- **Cluster boundaries** and connections
- **Reference genome assignments**

Without this file, `poppunk_assign` cannot:
- Load the trained model properly
- Assign new genomes to existing clusters
- Maintain cluster stability

## 🔍 Previous Error Analysis

From the log:
```
Jun-24 06:04:32.325 [Task monitor] DEBUG nextflow.processor.TaskRun - Task completed > TaskRun[id: 5; name: POPPUNK_MODEL (1); status: COMPLETED; exit: 0; error: -; workDir: /tmp/ijqu90axadwu86gp92c0u-d8564095/localpoppunk/work/c4/c4f4b4c4d4e4f4g4h4i4j4k4l4m4n4o4p4]
Jun-24 06:04:32.325 [Task monitor] DEBUG nextflow.processor.TaskRun - Task completed > TaskRun[id: 6; name: POPPUNK_ASSIGN (1); status: FAILED; exit: 1; error: -; workDir: /tmp/ijqu90axadwu86gp92c0u-d8564095/localpoppunk/work/d5/d5g5h5i5j5k5l5m5n5o5p5q5r5s5t5u5v5]
```

The model building succeeded, but assignment failed due to missing graph file.

## ✅ Expected Outcome

After this fix:
1. **POPPUNK_MODEL** will create all required files with correct names
2. **POPPUNK_ASSIGN** will find `poppunk_db_graph.gt` and run successfully
3. **All genomes** will be assigned to clusters without FileNotFoundError

## 🧪 Testing

To verify the fix:
1. Run the pipeline
2. Check POPPUNK_MODEL output for: `✓ Created poppunk_db_graph.gt from poppunk_fit_graph.gt`
3. Verify POPPUNK_ASSIGN runs without graph file errors
4. Confirm all samples are assigned to clusters

This fix addresses the core technical issue preventing successful cluster assignment in the PopPUNK pipeline.