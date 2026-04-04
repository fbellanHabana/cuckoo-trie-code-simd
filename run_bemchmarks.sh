#!/bin/bash
# =============================================================================
# Cuckoo Trie SIMD Benchmark Script
# Usage: ./run_benchmarks.sh <label>
#   label: "baseline" or "simd" — used to name output files
#
# Run twice:
#   1. On original code:  ./run_benchmarks.sh baseline
#   2. On SIMD code:      ./run_benchmarks.sh simd
#
# Results saved to: results_<label>/
# =============================================================================

LABEL=${1:-"run"}
RUNS=7                          # number of times to repeat each benchmark
THREADS=(1 2 4 8 12 16 24)     # thread counts for multi-threaded benchmarks
DATASET="rand-8"                # primary dataset
OUTDIR="results_${LABEL}"

# Single-threaded benchmarks to run
ST_BENCHMARKS=(
    "pos-lookup"
    "insert"
    "ycsb-b"
    "ycsb-c"
    "ycsb-f"
    "range-read"
)

# Multi-threaded benchmarks (use --threads flag)
MT_BENCHMARKS=(
    "mt-pos-lookup"
    "mt-ycsb-b"
    "mt-ycsb-c"
)

# ---- Sanity checks ----
if [ ! -f "./benchmark" ]; then
    echo "ERROR: ./benchmark not found. Run this script from the repo directory."
    exit 1
fi

mkdir -p "$OUTDIR"
SUMMARY="$OUTDIR/summary.txt"
> "$SUMMARY"

echo "=============================================="
echo " Cuckoo Trie Benchmark: $LABEL"
echo " Date:    $(date)"
echo " Runs:    $RUNS per benchmark"
echo " Dataset: $DATASET"
echo " Output:  $OUTDIR/"
echo "=============================================="
echo ""

# ---- Helper: run a benchmark N times, save raw + extract avg ----
run_bench() {
    local name=$1       # benchmark name
    local extra=$2      # extra flags e.g. "--threads 8"
    local outfile=$3    # output file path

    echo -n "  Running $name $extra ... "
    > "$outfile"

    for i in $(seq 1 $RUNS); do
        ./benchmark "$name" $extra "$DATASET" 2>/dev/null >> "$outfile"
    done

    # Extract ns/op values and compute average
    local values=$(grep -oP '\d+(?=ns/op)' "$outfile")
    local count=$(echo "$values" | wc -l)
    local sum=0
    for v in $values; do sum=$((sum + v)); done
    local avg=$((sum / count))

    # Extract Mops/s values and compute average
    local mops_vals=$(grep -oP '[\d.]+(?=Mops/s)' "$outfile" | head -$RUNS)
    local mops_sum=0
    local mops_count=0
    for v in $mops_vals; do
        mops_sum=$(echo "$mops_sum + $v" | bc)
        mops_count=$((mops_count + 1))
    done
    local mops_avg=$(echo "scale=2; $mops_sum / $mops_count" | bc)

    echo "avg ${avg} ns/op  (${mops_avg} Mops/s)"
    echo "$name $extra | avg_ns=${avg} | avg_mops=${mops_avg}" >> "$SUMMARY"
}

# ---- Single-threaded benchmarks ----
echo ">>> Single-threaded benchmarks"
echo "----------------------------------------------"
for bench in "${ST_BENCHMARKS[@]}"; do
    outfile="$OUTDIR/${bench//-/_}_st.txt"
    run_bench "$bench" "" "$outfile"
done
echo ""

# ---- Multi-threaded benchmarks ----
echo ">>> Multi-threaded benchmarks"
echo "----------------------------------------------"
for bench in "${MT_BENCHMARKS[@]}"; do
    for t in "${THREADS[@]}"; do
        outfile="$OUTDIR/${bench//-/_}_t${t}.txt"
        run_bench "$bench" "--threads $t" "$outfile"
    done
    echo ""
done

# ---- Done ----
echo "=============================================="
echo " DONE. Results in: $OUTDIR/"
echo " Summary:"
echo "=============================================="
cat "$SUMMARY"