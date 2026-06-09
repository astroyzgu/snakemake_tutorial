## snakemake quickstart 

### 任务原型

```bash
cat > step1_output.txt <<< "step1"
cat > step2_output.txt <<< "step2"
cat step1_output.txt step2_output.txt >> output.txt
```
### snakemake实现

###### 软件安装

``` bash 
pip install httpx[socks]
pip install snakesee snakemake-logger-plugin-snakesee snakemake-logger-plugin-snkmt snakemake-logger-plugin-flowo
```
###### 快速开始

``` bash 
# Run specific rule
snakemake --cores 1 step1
# Or run all rules (if in Snakefile)
snakemake --cores 1
```

###### 流程可视化 

``` bash 
# 生成具体的任务依赖图 (DAG) --- 具体的任务实例（jobs）， 非常细节
snakemake --dag | dot -Tpng > docs/dag.png

# 生成简化的规则依赖图 (Rulegraph) --- 规则之间的数据流， 比较简洁
snakemake --rulegraph | dot -Tpdf > docs/rulegraph.pdf
```
