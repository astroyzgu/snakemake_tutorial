# 遍历数据目录下的所有文件just_{expid}.txt文件， 
# 提取文件中exptype的值， 如果是arc，则执行arc流程，如果是flat，则执行flat流程，如果是science，则执行science流程
patterns=("b0" "r0" "z0" "b1" "r1" "z1" "b2" "r2" "z2" "b3" "r3" "z3")
#
# rule preproc 
#
for file in $(find data -name "*.txt" -type f); do
    night=$(echo "$file" | sed -n 's/.*\/\([^/]*\)\/[^/]*\/[^/]*$/\1/p')
    expid=$(echo "$file" | sed -n 's/.*\/\([^/]*\)\/[^/]*$/\1/p')
    echo 'file='$file
    echo 'night='$night
    echo 'expid='$expid

    for pattern in "${patterns[@]}"; do
        if grep -q "$pattern" "$file"; then
        mkdir -p redux/preproc/${night}/${expid}
        grep exptype  $file >  redux/preproc/${night}/${expid}/preproc_${pattern}_${expid}.txt
        grep $pattern $file >> redux/preproc/${night}/${expid}/preproc_${pattern}_${expid}.txt
        fi
    done
done
#
# rule psf 
#
for file in $(find redux/preproc -name "*.txt" -type f); do
    night=$(echo "$file" | sed -n 's/.*\/\([^/]*\)\/[^/]*\/[^/]*$/\1/p')
    expid=$(echo "$file" | sed -n 's/.*\/\([^/]*\)\/[^/]*$/\1/p')
    camera=$(echo "$file" | sed -n 's/.*\/preproc\/[^/]*\/[^/]*\/preproc_\(.*\)_'"$expid"'\.txt$/\1/p')
    echo 'file='$file
    echo 'night='$night
    echo 'expid='$expid
    echo 'camera='$camera
    if grep -q arc "$file"; then
        mkdir -p redux/exposures/${night}/${expid}
        grep $camera $file >  redux/exposures/${night}/${expid}/fit-psf-${camera}-${expid}.txt
    fi
done 

#
# rule nightpdf 
#
for file in $(find redux/exposures -name "fit-psf-*.txt" -type f); do
    night=$(echo "$file" | sed -n 's/.*\/\([^/]*\)\/[^/]*\/[^/]*$/\1/p')
    expid=$(echo "$file" | sed -n 's/.*\/\([^/]*\)\/[^/]*$/\1/p')
    camera=$(echo "$file" | sed -n 's/.*\/fit-psf-\(.*\)-'"$expid"'\.txt$/\1/p')
    echo "file=$file"
    echo "night=$night"
    echo "expid=$expid"
    echo "camera=$camera" 
done



