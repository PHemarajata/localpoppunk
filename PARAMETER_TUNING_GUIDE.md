# PopPUNK Parameter Tuning Guide

## 🎯 Quick Fix for Single Cluster Issue

If all samples are clustering together, try these parameter adjustments in order:

### Level 1: Moderate Adjustment (Applied)
```groovy
// nextflow.config
mash_thresh = 0.005     // Was 0.02 (99.5% ANI instead of 98%)
poppunk_max_search = 15 // Was 10 (deeper search)
poppunk_K = 2          // Mixture components for better separation
```

### Level 2: Strict Adjustment
```groovy
// nextflow.config  
mash_thresh = 0.001     // 99.9% ANI - very strict
poppunk_max_search = 20 // Even deeper search
poppunk_K = 3          // More mixture components
```

### Level 3: Very Strict Adjustment
```groovy
// nextflow.config
mash_thresh = 0.0005    // 99.95% ANI - extremely strict
poppunk_K = 4          // Maximum mixture components
```

## 📊 Parameter Effects Guide

### MASH Threshold (`mash_thresh`)
Controls pre-clustering stringency:

| Value | ANI % | Effect | Use Case |
|-------|-------|--------|----------|
| 0.05  | 95%   | Very permissive | Highly diverse species |
| 0.02  | 98%   | Permissive | Moderate diversity |
| 0.005 | 99.5% | Strict | Similar strains |
| 0.001 | 99.9% | Very strict | Outbreak investigation |

### PopPUNK K Parameter (`poppunk_K`)
Number of mixture components:

| K | Effect | Best For |
|---|--------|----------|
| 1 | Single cluster (avoid) | Clonal populations |
| 2 | Binary separation | Simple population structure |
| 3 | Moderate complexity | Typical bacterial species |
| 4 | High complexity | Highly structured populations |

### Search Depth (`poppunk_max_search`)
Model fitting thoroughness:

| Value | Effect | Trade-off |
|-------|--------|-----------|
| 5     | Fast, basic | May miss boundaries |
| 10    | Standard | Good balance |
| 15    | Thorough | Better boundaries, slower |
| 20    | Very thorough | Best quality, slowest |

## 🔧 Troubleshooting Scenarios

### Scenario 1: Still Single Cluster After Fix
**Symptoms**: All samples in cluster 1
**Solutions**:
1. Reduce `mash_thresh` to 0.001
2. Increase `poppunk_K` to 3-4
3. Check if data is truly homogeneous

### Scenario 2: Too Many Small Clusters
**Symptoms**: 50+ clusters, many singletons
**Solutions**:
1. Increase `mash_thresh` to 0.01
2. Reduce `poppunk_K` to 2
3. Increase subsampling percentage

### Scenario 3: Unbalanced Clusters
**Symptoms**: One huge cluster + many small ones
**Solutions**:
1. Adjust `mash_thresh` (try 0.003-0.008)
2. Modify subsampling strategy
3. Use `poppunk_K = 3`

### Scenario 4: Pipeline Fails/Crashes
**Symptoms**: Segfaults or memory errors
**Solutions**:
1. Reduce thread count further
2. Increase memory allocation
3. Use smaller subsampling percentages

## 🧬 Data-Specific Recommendations

### Outbreak Investigation (Very Similar Strains)
```groovy
mash_thresh = 0.0005    // Extremely strict
mash_k = 16            // Smaller k-mers for sensitivity
poppunk_K = 2          // Simple separation
```

### Species-Wide Analysis (Moderate Diversity)
```groovy
mash_thresh = 0.005     // Moderately strict
mash_k = 21            // Standard k-mers
poppunk_K = 3          // Moderate complexity
```

### Multi-Species Analysis (High Diversity)
```groovy
mash_thresh = 0.02      // More permissive
mash_k = 21            // Standard k-mers
poppunk_K = 4          // High complexity
```

## 📈 Validation Steps

### 1. Check MASH Pre-clustering
Look for this in logs:
```
Component sizes: [45, 32, 28, 15, ...]  # Good: multiple components
Component sizes: [450]                   # Bad: single large component
```

### 2. Validate PopPUNK Model
Check for:
- Model convergence messages
- No error messages about fitting
- Reasonable number of mixture components used

### 3. Analyze Final Clusters
Ideal characteristics:
- 5-50 clusters for typical datasets
- Largest cluster <80% of samples
- Reasonable biological interpretation

## 🎯 Quick Parameter Selection

### Conservative (Start Here)
```groovy
mash_thresh = 0.005
poppunk_K = 2
poppunk_max_search = 15
```

### Aggressive (If Conservative Fails)
```groovy
mash_thresh = 0.001
poppunk_K = 3
poppunk_max_search = 20
```

### Last Resort (Very Strict)
```groovy
mash_thresh = 0.0005
poppunk_K = 4
poppunk_max_search = 25
```

## 🔍 Diagnostic Commands

### Check Component Distribution
```bash
# Look for this in BIN_SUBSAMPLE logs
grep "Component sizes" work/*/command.log
```

### Analyze Cluster Balance
```bash
# Check cluster size distribution
tail -n +2 results/poppunk_full/full_assign.csv | cut -d',' -f2 | sort | uniq -c | sort -nr
```

### Validate Parameters
```bash
# Run the clustering test
./test_clustering_fix.sh
```

---

**Remember**: The goal is meaningful biological clusters, not just multiple clusters. Sometimes a single cluster is correct if your data represents a truly clonal population!