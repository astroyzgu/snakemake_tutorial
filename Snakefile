# Snakefile

rule all: # 用来声明“整个 workflow 最终要产出什么”
    input:
        "output.txt"

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
