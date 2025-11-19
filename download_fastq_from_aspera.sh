#!/usr/bin/env bash
# 批量从 output.tsv 下载 fastq 文件 (Aspera)

OUTPUT_TSV="output.tsv"
ASCP_BIN="$HOME/.aspera/connect/bin/ascp"
KEY="$HOME/.aspera/connect/etc/asperaweb_id_dsa.openssh"
DEST_DIR="fastq_downloads"

# 下载参数（推荐）
ASCP_OPTS="-QT -l 300M -P33001 -i $KEY"

mkdir -p "$DEST_DIR"

# 跳过表头，从第 2 行开始
tail -n +2 "$OUTPUT_TSV" | while IFS=$'\t' read -r run accession; do
    echo
    echo "=== Processing $run ==="

    # 分割两个 URL
    IFS=';' read -ra LINKS <<< "$accession"

    # 遍历每个 fastq 链接
    for LINK in "${LINKS[@]}"; do
        if [[ -z "$LINK" || "$LINK" == "NA" ]]; then
            echo "No valid link for $run"
            continue
        fi

        echo "Downloading: $LINK"
        $ASCP_BIN $ASCP_OPTS "$LINK" "$DEST_DIR/" || echo "Failed: $LINK"
    done
done
