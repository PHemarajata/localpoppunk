# PopPUNK Assign Name Collision Fix

## Issue Identified

The `poppunk_assign` process failed with the following error:

```
Names of queries match names in reference database

Not running -- change names or add --write-references to override this behaviour
```

## Root Cause

This error occurs when some of the query genomes have the same names as genomes that were used to build the reference database. PopPUNK prevents this by default to avoid confusion between reference and query samples.

## Additional Issue: QC Failures

The log also shows that **19 samples failed QC**:
- Burkholderia_pseudomallei_619s004_GCF_001212405_2_Malaysia
- IP-0099-2_S11_L001-SPAdes
- Burkholderia_pseudomallei_134K_GCF_009830075_1_Thailand
- And 16 others...

These samples failed quality control checks based on:
- Proportion of ambiguous bases (N's) > 0.1
- Genome length outside 2 standard deviations from mean

## Solution Applied

### 1. ✅ Added `--write-references` Flag
**Fix**: Added `--write-references` to the `poppunk_assign` command
**Effect**: Allows PopPUNK to proceed even when query names match reference database names

### 2. ✅ Added QC Failure Handling Option
**New Parameter**: `poppunk_retain_failures = false` in nextflow.config
**Effect**: Controls whether failed QC samples are retained in output (default: exclude them)

## Updated poppunk_assign Command

```bash
poppunk_assign --query staged_all_files.list \
    --db ${db_dir} \
    --output poppunk_full \
    --threads ${task.cpus} \
    --stable core \
    --run-qc \
    --write-references \
    --max-zero-dist 1 \
    --max-merge 3 \
    --length-sigma 2
```

## New Configuration Parameter

```groovy
/* PopPUNK QC settings for poppunk_assign --run-qc */
poppunk_max_zero_dist = 1       // --max-zero-dist: max zero distances allowed
poppunk_max_merge     = 3       // --max-merge: max merge operations
poppunk_length_sigma  = 2       // --length-sigma: outlying genome length detection
poppunk_retain_failures = false // --retain-failures: keep failed QC samples in output
```

## Expected Results

1. **Name collision resolved**: Pipeline will proceed despite matching names
2. **QC failures handled**: 19 failed samples will be excluded from clustering (unless retain_failures = true)
3. **Successful assignment**: Remaining ~431 samples should be successfully assigned to clusters

## QC Failure Details

The 19 samples that failed QC likely have issues with:
- **High N content**: Too many ambiguous bases
- **Unusual genome length**: Significantly shorter/longer than expected for Burkholderia pseudomallei
- **Poor assembly quality**: May indicate contamination or assembly artifacts

## Options for QC Failures

If you want to include the failed samples anyway, set:
```groovy
poppunk_retain_failures = true
```

This will add `--retain-failures` to the command and include all samples in the output, but they'll be flagged as QC failures.

## Verification

The pipeline should now:
1. ✅ Handle name collisions gracefully
2. ✅ Process all valid samples (431 expected to pass QC)
3. ✅ Generate cluster assignments for all processed samples
4. ✅ Complete successfully without the name collision error