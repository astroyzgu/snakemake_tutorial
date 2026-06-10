#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${1:-data}"

if [[ ! -d "$DATA_DIR" ]]; then
    echo "Error: directory '$DATA_DIR' not found" >&2
    exit 1
fi

for night_dir in "$DATA_DIR"/*/; do
    [[ -d "$night_dir" ]] || continue
    night=$(basename "$night_dir")

    for exp_dir in "$night_dir"*/; do
        [[ -d "$exp_dir" ]] || continue
        expid=$(basename "$exp_dir")

        for file in "$exp_dir"*.txt; do
            [[ -f "$file" ]] || continue

            # Replace the line above with your processing, e.g.:
            # cat "$file"
            # snakemake --cores 1 "data/${night}/${expid}/just_${expid}.txt"
            if grep -q "arc" $file; then
                echo "night=$night expid=$expid exptype=arc     file=$file"
            elif grep -q "flat" $file; then
                echo "night=$night expid=$expid exptype=flat    file=$file"
            elif grep -q "science" $file; then
                echo "night=$night expid=$expid exptype=science file=$file"
            else
                echo "文件中不包含exptype"
            fi
        done
    done
done
