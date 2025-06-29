# PopPUNK Assign Parameter Fixes

## Issues Fixed

### 1. ✅ Fixed `--stable` Parameter Syntax
**Problem**: The `--stable` flag was being used as a boolean (`--stable` or empty), but according to the official documentation, it requires a specific value.

**Official Syntax**: `--stable {core,accessory,False}`

**Changes Made**:
- **nextflow.config**: Changed `poppunk_stable = true` to `poppunk_stable = 'core'`
- **poppunk_subsample_snp.nf**: Changed `${params.poppunk_stable ? '--stable' : ''}` to `--stable ${params.poppunk_stable}`

### 2. ✅ Added Missing QC Parameters
**Problem**: The pipeline was using QC parameters in the `poppunk_assign` command that weren't defined in the config.

**Parameters Added to nextflow.config**:
```groovy
/* PopPUNK QC settings for poppunk_assign --run-qc */
poppunk_max_zero_dist = 1       // --max-zero-dist: max zero distances allowed
poppunk_max_merge     = 3       // --max-merge: max merge operations
poppunk_length_sigma  = 2       // --length-sigma: outlying genome length detection
```

## Current poppunk_assign Command

The corrected command now looks like:
```bash
poppunk_assign --query staged_all_files.list \
    --db ${db_dir} \
    --output poppunk_full \
    --threads ${task.cpus} \
    --stable core \
    --run-qc \
    --max-zero-dist 1 \
    --max-merge 3 \
    --length-sigma 2
```

## Parameter Validation Against Official Documentation

Based on the usage guide provided:
```
usage: poppunk_assign [-h] --db DB --query QUERY [--distances DISTANCES]
                      [--external-clustering EXTERNAL_CLUSTERING] --output
                      OUTPUT [--plot-fit PLOT_FIT] [--write-references]
                      [--update-db] [--overwrite] [--graph-weights]
                      [--save-partial-query-graph]
                      [--min-kmer-count MIN_KMER_COUNT] [--exact-count]
                      [--strand-preserved] [--run-qc] [--retain-failures]
                      [--max-a-dist MAX_A_DIST] [--max-pi-dist MAX_PI_DIST]
                      [--max-zero-dist MAX_ZERO_DIST] [--max-merge MAX_MERGE]
                      [--betweenness] [--type-isolate TYPE_ISOLATE]
                      [--length-sigma LENGTH_SIGMA]
                      [--length-range LENGTH_RANGE LENGTH_RANGE]
                      [--prop-n PROP_N] [--upper-n UPPER_N] [--serial]
                      [--stable {core,accessory,False}]
                      [--model-dir MODEL_DIR]
                      [--previous-clustering PREVIOUS_CLUSTERING] [--core]
                      [--accessory] [--use-full-network] [--threads THREADS]
                      [--gpu-sketch] [--gpu-dist] [--gpu-graph]
                      [--deviceid DEVICEID] [--version] [--citation]
```

### ✅ Parameters Currently Used (All Valid):
- `--query` ✅ (required)
- `--db` ✅ (required) 
- `--output` ✅ (required)
- `--threads` ✅ (optional)
- `--stable {core,accessory,False}` ✅ (optional, now correctly using 'core')
- `--run-qc` ✅ (optional)
- `--max-zero-dist` ✅ (optional, used with --run-qc)
- `--max-merge` ✅ (optional, used with --run-qc)
- `--length-sigma` ✅ (optional, used with --run-qc)

### 🔧 Additional QC Parameters Available (Not Currently Used):
If you need more stringent QC, you can add these to the config:
- `--max-a-dist`: Maximum accessory distance
- `--max-pi-dist`: Maximum core distance  
- `--length-range`: Acceptable genome length range
- `--prop-n`: Maximum proportion of N bases
- `--upper-n`: Maximum number of N bases
- `--retain-failures`: Keep failed QC samples in output

## Stable Nomenclature Options

The `--stable` parameter accepts three values:
- `'core'`: Stable nomenclature based on core genome distances
- `'accessory'`: Stable nomenclature based on accessory genome distances  
- `'False'`: No stable nomenclature (default PopPUNK behavior)

**Current Setting**: `'core'` (recommended for most bacterial analyses)

## Testing

The pipeline should now run without the `--stable` parameter error. The corrected parameters follow the official PopPUNK 2.7.x documentation exactly.