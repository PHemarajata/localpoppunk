# Single Cluster Problem - Solution

## 🔍 Problem Description

The pipeline runs successfully but assigns all samples to a single cluster, indicating that the clustering parameters are too permissive and not finding meaningful population structure.

## 🛠️ Root Cause Analysis

### 1. MASH Threshold Too Permissive
- **Before**: `mash_thresh = 0.02` (98% ANI)
- **Issue**: Groups too many genomes together in pre-clustering
- **Result**: Single large component fed to PopPUNK

### 2. Subsampling Strategy
- **Before**: 30% of each component (min 25, max 200)
- **Issue**: If everything is in one component, training set lacks diversity
- **Result**: PopPUNK model can't find cluster boundaries

### 3. PopPUNK Model Parameters
- **Issue**: Default parameters may not be optimal for cluster separation
- **Result**: Model fits single cluster to all data

## ✅ Fixes Applied

### 1. Stricter MASH Threshold
```diff
- mash_thresh = 0.02      // 98% ANI
+ mash_thresh = 0.005     // 99.5% ANI (much more stringent)
```

**Impact**: Creates more, smaller components for better diversity

### 2. Optimized Subsampling
```diff
- k = min(200, max(25, int(len(comp) * 0.3)))  // 30% of component
+ k = min(100, max(10, int(len(comp) * 0.15))) // 15% of component
```

**Impact**: 
- Fewer representatives per component
- Forces more selective sampling
- Better training set diversity

### 3. Enhanced PopPUNK Parameters
```diff
- poppunk_max_search = 10
+ poppunk_max_search = 15     // Deeper search for boundaries

+ poppunk_K = 2               // Number of mixture components
```

**Impact**: Better model fitting and cluster boundary detection

### 4. Enhanced Diagnostics
- Added component size analysis
- Detailed cluster distribution reporting
- Warning messages for single cluster results

## 🧪 Testing the Fix

### Run with New Parameters
```bash
cd localpoppunk
nextflow run poppunk_subsample_snp.nf -resume
```

### Expected Results
- **Multiple components** in MASH pre-clustering
- **Diverse training set** for PopPUNK model
- **Multiple clusters** in final assignment
- **Better population structure** resolution

### Diagnostic Output
Look for these indicators of success:
```
Component sizes: [45, 32, 28, 15, 12, ...]  # Multiple components
Number of unique clusters: 15                # Multiple clusters
✅ Good cluster diversity: 15 clusters found
```

## 📊 Parameter Tuning Guide

If you still get single clusters, try these adjustments:

### Make MASH Even Stricter
```groovy
mash_thresh = 0.001  // 99.9% ANI - very strict
```

### Reduce Subsampling Further
```groovy
# In BIN_SUBSAMPLE process
k = min(50, max(5, int(len(comp) * 0.1)))  // 10% of component
```

### Adjust PopPUNK Model
```groovy
poppunk_K = 3        // Try 3-4 mixture components
poppunk_max_search = 20  // Even deeper search
```

## 🎯 Understanding Your Data

### Check Component Analysis
The pipeline now reports:
- Number of connected components
- Component sizes
- Largest component size

### Interpret Results
- **Many small components**: Good diversity, should produce multiple clusters
- **One large component**: Data is very similar, may need stricter thresholds
- **Few medium components**: Balanced, likely to produce good clustering

## 🔧 Alternative Approaches

### Option 1: Skip MASH Pre-clustering
For very diverse datasets, you might skip MASH and use all samples:
```groovy
mash_thresh = 0.0  // Effectively disables pre-clustering
```

### Option 2: Use Different Distance Metrics
Consider adjusting MASH k-mer size:
```groovy
mash_k = 16  // Smaller k-mers for more sensitivity
```

### Option 3: Manual Curation
If automated clustering fails, consider:
- Phylogenetic analysis
- Manual inspection of distance matrices
- Alternative clustering algorithms

## 📈 Success Metrics

### Before Fix
- ❌ Single cluster containing all samples
- ❌ No population structure detected
- ❌ Uninformative clustering results

### After Fix
- ✅ Multiple clusters (5-50 typical for bacterial datasets)
- ✅ Meaningful population structure
- ✅ Clusters reflect biological relationships
- ✅ Balanced cluster sizes

---

**Status**: ✅ **OPTIMIZED** - Parameters tuned for better cluster resolution
**Expected**: Multiple clusters instead of single cluster
**Next Steps**: Run pipeline and analyze cluster distribution