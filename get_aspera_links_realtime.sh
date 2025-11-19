#!/usr/bin/env bash
# 实时写入结果的 SRA → Aspera fastq 链接获取脚本
# 用法：
#   bash get_aspera_links_realtime.sh sra_list.txt output.tsv

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 sra_list.txt output.tsv" >&2
    exit 1
fi

INPUT_LIST="$1"
OUTPUT_TSV="$2"

if [ ! -f "$INPUT_LIST" ]; then
    echo "Error: file '$INPUT_LIST' not found." >&2
    exit 1
fi

# 如果输出文件不存在，写入表头；存在则追加
if [ ! -f "$OUTPUT_TSV" ]; then
    echo -e "run_accession\tfastq_aspera" > "$OUTPUT_TSV"
fi

# 一行一行读取并实时处理
while read -r acc; do
    # 跳过空行
    [[ -z "$acc" ]] && continue

    acc=$(echo "$acc" | tr -d '[:space:]')

    echo "Processing $acc ..."

    # 查询 ENA API (立即获取并写入文件)
    result=$(curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${acc}&result=read_run&fields=run_accession,fastq_aspera" \
        | awk 'NR>1')

    if [[ -z "$result" ]]; then
        echo -e "${acc}\tNA" >> "$OUTPUT_TSV"
        echo "  >> No result, written NA"
    else
        echo -e "$result" >> "$OUTPUT_TSV"
        echo "  >> Written OK"
    fi

    # 立即刷新写盘 (确保实时写入)
    sync

done < "$INPUT_LIST"

echo "All done. Output written to: $OUTPUT_TSV"
