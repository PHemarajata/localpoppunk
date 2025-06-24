# PopPUNK Pipeline Improvements - Version 2.7.5

## Issues Fixed

### 1. ✅ Pandas Installation Error
- **Problem**: SUMMARY_REPORT process failed due to missing pandas
- **Solution**: Added `pip install --quiet pandas` before Python script execution

### 2. ✅ Updated to PopPUNK 2.7.5
- **Problem**: Using outdated PopPUNK 2.6.2
- **Solution**: Updated all PopPUNK containers to `staphb/poppunk:2.7.5`

### 3. ✅ Implemented PopPUNK 2.7.x New Features

#### Model Fitting Improvements:
- `--reciprocal-only`: Reciprocal-best-match search for better lineage fitting
- `--count-unique-distances`: Unique-distance counting for more accurate cluster boundaries
- `--max-search-depth 10`: Deeper search depth tuning

#### Assignment Improvements:
- `--stable`: Stable nomenclature to freeze cluster IDs
- Distance-matrix-free mode (automatic in 2.7.x)

### 4. ✅ More Generous Subsampling
- **Problem**: Only 45-90 samples selected for model building
- **Old**: 10% of each component, min 3, max 45
- **New**: 30% of each component, min 25, max 200
- **Result**: More representatives for better model training

### 5. ✅ Enhanced QC Analysis
- **New**: Added POPPUNK_QC process using 2.7.x QC features
- **Features**: Enhanced QC reporting and plots
- **Output**: QC reports and visualizations

### 6. ✅ Better Debugging and Monitoring
- Added detailed logging in assignment process
- Shows expected vs actual sample counts
- Displays cluster distribution in real-time
- Enhanced error checking and validation

## New Configuration Parameters

```groovy
/* PopPUNK 2.7.x specific settings */
poppunk_stable       = true     // Use --stable flag for consistent cluster IDs
poppunk_reciprocal   = true     // Use --reciprocal-only for better lineage fitting
poppunk_max_search   = 10       // --max-search-depth for deeper search
poppunk_count_unique = true     // --count-unique-distances for better accuracy
```

## Expected Results

### Before (PopPUNK 2.6.2):
- 45-90 samples assigned
- Single cluster (cluster 1)
- Limited model representatives
- Basic QC

### After (PopPUNK 2.7.5):
- **All 450 samples assigned**
- **Better cluster resolution** (multiple clusters expected)
- **More robust model** (25-200 representatives per component)
- **Enhanced QC analysis**
- **Stable cluster nomenclature**

## New Workflow Steps

1. **VALIDATE_FASTA** - Validate input files
2. **MASH_SKETCH** - Create k-mer sketches
3. **MASH_DIST** - Calculate pairwise distances
4. **BIN_SUBSAMPLE** - Intelligent subsampling (30% of each component)
5. **POPPUNK_MODEL** - Build model with 2.7.x features
6. **POPPUNK_ASSIGN** - Assign ALL genomes with stable nomenclature
7. **POPPUNK_QC** - ✨ NEW: QC analysis with 2.7.x features
8. **SUMMARY_REPORT** - Generate comprehensive report

## Key PopPUNK 2.7.x Benefits Applied

1. **More accurate cluster boundaries** - Especially for diverse/recombinant species
2. **RAM/time savings** - Distance-matrix-free assignment mode
3. **Stable nomenclature** - Cluster IDs don't shift when updating database
4. **Better visualization** - Enhanced plotting for large datasets
5. **Improved QC** - Better DBSCAN fits and QC reporting

## Testing

Run the improved pipeline:
```bash
cd localpoppunk
./test_improved_pipeline.sh
```

This will provide comprehensive analysis of the improvements and verify all 450 samples are processed correctly.