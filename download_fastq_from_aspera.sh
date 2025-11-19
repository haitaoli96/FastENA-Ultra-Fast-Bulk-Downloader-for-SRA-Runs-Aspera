#!/usr/bin/env bash
# 使用 conda 安装的 Aspera CLI + 密钥，从 output.tsv 批量下载 FASTQ
# 仅依赖：output.tsv，格式为 run_accession<TAB>fastq_aspera

set -euo pipefail

OUTPUT_TSV="output.tsv"
DEST_DIR="fastq_downloads"

# 你的 ascp 和 key 路径（根据你刚才给出的命令写死的）
ASCP_BIN="/home/liht/miniconda3/bin/ascp"
KEY="/home/liht/miniconda3/etc/asperaweb_id_dsa.openssh"

if [ ! -x "$ASCP_BIN" ]; then
    echo "ERROR: 找不到 ascp: $ASCP_BIN" >&2
    exit 1
fi

if [ ! -f "$KEY" ]; then
    echo "ERROR: 找不到 Aspera 密钥: $KEY" >&2
    exit 1
fi

ASCP_OPTS="-QT -l 300M -P33001 -i $KEY"

if [ ! -f "$OUTPUT_TSV" ]; then
    echo "ERROR: 找不到 $OUTPUT_TSV" >&2
    exit 1
fi

mkdir -p "$DEST_DIR"

echo "Using ascp : $ASCP_BIN"
echo "Key       : $KEY"
echo "Output TSV: $OUTPUT_TSV"
echo "Dest dir  : $DEST_DIR"
echo

# 跳过表头，从第 2 行开始
tail -n +2 "$OUTPUT_TSV" | while IFS=$'\t' read -r run links_raw; do
    # 跳过空行
    if [[ -z "${run:-}" ]]; then
        continue
    fi
    # 兼容你文件里可能存在的 'acc' 之类的头
    if [[ "$run" == "acc" || "$run" == "run_accession" ]]; then
        echo "Skip header-like line: $run"
        continue
    fi

    echo "=== Processing $run ==="

    if [[ -z "${links_raw:-}" || "$links_raw" == "NA" || "$links_raw" == "na" ]]; then
        echo "  >> No valid link, skip."
        echo
        continue
    fi

    # 自动修补用户名：fasp.sra.ebi.ac.uk -> era-fasp@fasp.sra.ebi.ac.uk
    links_fixed="${links_raw//fasp.sra.ebi.ac.uk:/era-fasp@fasp.sra.ebi.ac.uk:}"

    # 按分号拆成 R1/R2 多个链接
    IFS=';' read -ra LINKS <<< "$links_fixed"
    for L in "${LINKS[@]}"; do
        if [[ -z "$L" || "$L" == "NA" ]]; then
            echo "  >> Skip empty/NA link."
            continue
        fi

        echo "  Downloading: $L"
        "$ASCP_BIN" $ASCP_OPTS "$L" "$DEST_DIR/" || echo "  >> FAILED: $L"
    done

    echo
done

echo "All done. Files saved in: $DEST_DIR"
