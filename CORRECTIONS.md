# PopPUNK Pipeline Corrections - Fixed Parameter Issues

## ✅ Issues Fixed Based on User Feedback

### 1. **Fixed Invalid `--qc` Parameter**
- **Problem**: `poppunk --qc` doesn't exist
- **Solution**: Removed separate POPPUNK_QC process
- **Correct Approach**: Use `poppunk_assign --run-qc` instead

### 2. **Fixed `--stable` Parameter Usage**
- **Problem**: `--stable` was used with `poppunk --use-model` (invalid)
- **Solution**: Now using `poppunk_assign` with `--stable` (correct)
- **Benefit**: Stable cluster nomenclature that doesn't shift when updating database

### 3. **Implemented Proper QC with `poppunk_assign`**
- **Old (Wrong)**: Separate `poppunk --qc` process
- **New (Correct)**: `poppunk_assign --run-qc` with QC parameters:
  - `--max-zero-dist 1`: Maximum zero distances allowed
  - `--max-merge 3`: Maximum merge operations
  - `--length-sigma 2`: Outlying genome length detection

## 🔧 Updated PopPUNK Commands

### Model Building (Unchanged - Correct):
```bash
poppunk --create-db --r-files staged_files.list \
    --output poppunk_db --threads ${task.cpus}

poppunk --fit-model bgmm --ref-db poppunk_db \
    --output poppunk_fit --threads ${task.cpus} \
    --reciprocal-only \
    --count-unique-distances \
    --max-search-depth 10
```

### Assignment with QC (Fixed):
```bash
poppunk_assign --query staged_all_files.list \
    --db ${db_dir} \
    --output poppunk_full \
    --threads ${task.cpus} \
    --stable \
    --run-qc \
    --max-zero-dist 1 \
    --max-merge 3 \
    --length-sigma 2
```

## 📋 New Configuration Parameters

```groovy
/* PopPUNK 2.7.x specific settings */
poppunk_stable       = true     // Use --stable flag (poppunk_assign only)
poppunk_reciprocal   = true     // Use --reciprocal-only for better lineage fitting
poppunk_max_search   = 10       // --max-search-depth for deeper search
poppunk_count_unique = true     // --count-unique-distances for better accuracy

/* PopPUNK QC settings for poppunk_assign --run-qc */
poppunk_max_zero_dist = 1       // --max-zero-dist: max zero distances allowed
poppunk_max_merge     = 3       // --max-merge: max merge operations
poppunk_length_sigma  = 2       // --length-sigma: outlying genome length detection
```

## 🎯 Key Benefits of Corrections

1. **Proper QC Integration**: QC is now integrated into the assignment step using `poppunk_assign --run-qc`
2. **Stable Nomenclature**: Cluster IDs won't shift when updating the database
3. **Distance-Matrix-Free**: Uses PopPUNK 2.7.x efficient assignment mode
4. **Enhanced QC Criteria**: 
   - Outlying genome length detection
   - Zero distance filtering
   - Merge operation limits

## 🔍 QC Criteria Available in poppunk_assign --run-qc

- **Outlying genome length**: `--length-range` and/or `--length-sigma`
- **Too many 'N's**: `--prop-n` and/or `--upper-n`
- **Outlying distances**: `--max-pi-dist` and `--max-a-dist`
- **Too many zero distances**: `--max-zero-dist`

## 📊 Expected Improvements

1. **All samples processed**: Should now process all 450 samples (not just 90)
2. **Better QC**: Integrated QC filtering during assignment
3. **Stable clusters**: Consistent cluster IDs across runs
4. **Proper PopPUNK 2.7.x usage**: Using correct commands and parameters

Thank you for catching these critical parameter errors! The pipeline now uses the correct PopPUNK 2.7.x syntax and workflow.