# PopPUNK Local Pipeline

A Nextflow pipeline for bacterial genome clustering using PopPUNK (Population Partitioning Using Nucleotide K-mers).

## Overview

This pipeline performs intelligent subsampling and clustering of bacterial genomes using:
- **MASH** for k-mer sketching and pre-clustering
- **PopPUNK 2.7.5** for detailed clustering and population structure analysis
- **Intelligent subsampling** to handle large datasets efficiently

## Pipeline Workflow

1. **VALIDATE_FASTA** - Validates input FASTA files
2. **MASH_SKETCH** - Creates k-mer sketches
3. **MASH_DIST** - Calculates pairwise distances
4. **BIN_SUBSAMPLE** - Intelligent subsampling (30% of each component)
5. **POPPUNK_MODEL** - Builds PopPUNK clustering model
6. **POPPUNK_ASSIGN** - Assigns all genomes to clusters
7. **SUMMARY_REPORT** - Generates comprehensive analysis report

## Quick Start

1. **Configure input/output paths** in `nextflow.config`:
   ```groovy
   params {
     input = '/path/to/your/fasta/files'
     resultsDir = '/path/to/results'
   }
   ```

2. **Run the pipeline**:
   ```bash
   nextflow run poppunk_subsample_snp.nf
   ```

3. **Test with segfault fixes**:
   ```bash
   ./test_segfault_fixes.sh
   ```

## Key Features

- ✅ **Segmentation fault fixes** - Resolved PopPUNK 2.7.5 stability issues
- ✅ **Intelligent subsampling** - Handles large datasets (450+ genomes)
- ✅ **Graceful fallbacks** - Progressive error recovery
- ✅ **Comprehensive validation** - Input file quality control
- ✅ **Docker containerization** - Reproducible execution

## Configuration

### Resource Settings
```groovy
params {
  threads = 16        // Optimized to prevent segfaults
  ram = '200 GB'      // Memory allocation
}
```

### PopPUNK Settings
```groovy
params {
  // MASH pre-clustering
  mash_k = 21
  mash_s = 1000
  mash_thresh = 0.02
  
  // PopPUNK stability fixes
  poppunk_stable = false  // Disabled to prevent segfaults
  poppunk_reciprocal = true
  poppunk_max_search = 10
}
```

## Troubleshooting

### Segmentation Faults
- **Fixed**: Thread count reduced from 48 to 16
- **Fixed**: Disabled `--stable core` option
- **Fixed**: Added graceful fallback strategies

### Large Datasets
- Uses intelligent subsampling (30% of each component)
- Minimum 25, maximum 200 representatives per cluster
- Progressive fallback to single-thread processing

## Output Files

- `full_assign.csv` - Cluster assignments for all genomes
- `pipeline_summary.txt` - Analysis summary and statistics
- `validation_report.txt` - Input file validation results

## Documentation

- `SEGFAULT_FIXES.md` - Detailed segmentation fault solutions
- `SEGFAULT_SOLUTION_SUMMARY.md` - Complete fix overview
- `IMPROVEMENTS.md` - Pipeline enhancement history
- Various fix documentation files for specific issues

## Requirements

- **Nextflow** 20.04+
- **Docker** or **Singularity**
- **8+ GB RAM** (200+ GB recommended for large datasets)
- **8+ CPUs** (16+ recommended)

## Citation

If you use this pipeline, please cite:
- **PopPUNK**: Lees et al. (2019) Genome Research
- **MASH**: Ondov et al. (2016) Genome Biology
- **Nextflow**: Di Tommaso et al. (2017) Nature Biotechnology

---

**Status**: ✅ Production ready with segmentation fault fixes applied
**Last Updated**: 2024-06-24
**Version**: 2.7.5 (PopPUNK) with stability patches