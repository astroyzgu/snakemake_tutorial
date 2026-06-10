# Snakefile

# 方案：expid 作为目录，但需要知道 exptype
EXPINFO = {
    "00000001": "arc",
    "00000002": "flat", 
    "00000003": "sci"
}

rule all:
    input:
        [f"data/20240601/{expid}/just_{expid}.txt" 
         for expid in EXPINFO.keys()]

rule observation:
    output: "data/{night}/{expid}/just_{expid}.txt"
    params:
        # 动态获取 exptype
        exptype = lambda w: EXPINFO[w.expid],
        channels = ["b", "r", "z"],
        specids = [0, 3]
    run:
        night = wildcards.night      # "20240601"
        expid = wildcards.expid       # "00000001"
        exptype = params.exptype      # "arc"
        
        import os
        os.makedirs(os.path.dirname(output[0]), exist_ok=True)
        
        with open(output[0], "w") as f:
            f.write(f"night={night} expid={expid} exptype={exptype}\n")
            for sid in params.specids:
                for ch in params.channels:
                    f.write(f"{ch}{sid}\n")

rule step1:
    output: "step1_output.txt"
    params:
        content="step1"
    shell: "cat > {output} <<< '{params.content}'"

rule step2:
    output: "step2_output.txt"
    params:
        content="step2"
    shell: "cat > {output} <<< '{params.content}'"

rule combine:
    input:
        "step1_output.txt",
        "step2_output.txt"
    output: "output.txt"
    shell: "cat {input} > {output}"
