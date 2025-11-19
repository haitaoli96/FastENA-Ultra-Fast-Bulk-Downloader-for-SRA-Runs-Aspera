# 批量根据 SRA 登录号获取 ENA Aspera FASTQ 下载链接并自动批量下载（完整流程）

本项目提供两个核心脚本：

1. **get_aspera_links_realtime.sh**  
   根据 SRA 登录号实时获取 ENA 上 “FASTQ files: Aspera” 的下载链接，并生成 `output.tsv`。

2. **download_fastq_from_aspera.sh**  
   使用 Aspera `ascp` 工具，根据 `output.tsv` 自动批量下载所有 FASTQ 文件。

脚本适用于大规模 WGS/RNA-seq 项目，并且具有断点续传、下载加速功能。

---

# 📌 目录

- [1. 输入与输出说明](#1-输入与输出说明)
- [2. Step 1：准备 SRA 登录号列表](#2-step-1准备-sra-登录号列表)
- [3. Step 2：实时获取 ENA Aspera 下载链接](#3-step-2实时获取-ena-aspera-下载链接)
- [4. Step 3：安装 Aspera (ascp)](#4-step-3安装-aspera-ascp)
- [5. Step 4：批量下载 FASTQ 文件](#5-step-4批量下载-fastq-文件)
- [6. 项目目录结构](#6-项目目录结构)
- [7. 常见问题 FAQ](#7-常见问题-faq)

---

# 1. 输入与输出说明

## ✔ 输入文件：`sra_list.txt`

格式如下（每行一个 SRA 号，可以混合 SRR/ERR/DRR）：

```
SRR12345678
SRR23456789
ERR98765432
```

## ✔ 输出文件：`output.tsv`

脚本会自动生成：

```
run_accession   fastq_aspera
SRR12345678     era-fasp@fasp.sra.ebi.ac.uk:vol1/.../SRR12345678_1.fastq.gz;era-fasp@fasp.sra.ebi.ac.uk:vol1/.../SRR12345678_2.fastq.gz
SRR23456789     era-fasp@fasp.sra.ebi.ac.uk:vol1/.../SRR23456789_1.fastq.gz;era-fasp@fasp.sra.ebi.ac.uk:vol1/.../SRR23456789_2.fastq.gz
```

`fastq_aspera` 字段对应 ENA 网页上 “FASTQ files: Aspera (click to copy URL)” 的原始路径。

---

# 2. Step 1：准备 SRA 登录号列表

创建文件：

**sra_list.txt**
```
SRR12345678
SRR23456789
SRR55667788
```

---

# 3. Step 2：实时获取 ENA Aspera 下载链接

保存为：

**get_aspera_links_realtime.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 2 ]; then echo "Usage: $0 sra_list.txt output.tsv"; exit 1; fi
INPUT_LIST="$1"; OUTPUT_TSV="$2"
[ ! -f "$INPUT_LIST" ] && echo "Error: file not found." && exit 1
[ ! -f "$OUTPUT_TSV" ] && echo -e "run_accession\tfastq_aspera" > "$OUTPUT_TSV"
while read -r acc; do
    [[ -z "$acc" ]] && continue
    acc=$(echo "$acc" | tr -d '[:space:]')
    echo "Processing $acc ..."
    result=$(curl -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${acc}&result=read_run&fields=run_accession,fastq_aspera" | awk 'NR>1')
    [[ -z "$result" ]] && echo -e "${acc}\tNA" >> "$OUTPUT_TSV" || echo -e "$result" >> "$OUTPUT_TSV"
    sync
done < "$INPUT_LIST"
echo "Done."
```

---

# 4. Step 3：安装 Aspera (ascp)

```bash
wget https://download.asperasoft.com/download/sw/connect/3.11.1/aspera-connect_3.11.1-18_linux_x86_64.deb
sudo dpkg -i aspera-connect_3.11.1-18_linux_x86_64.deb
```

---

# 5. Step 4：批量下载 FASTQ 文件

保存为：

**download_fastq_from_aspera.sh**
```bash
#!/usr/bin/env bash
OUTPUT_TSV="output.tsv"
ASCP_BIN="$HOME/.aspera/connect/bin/ascp"
KEY="$HOME/.aspera/connect/etc/asperaweb_id_dsa.openssh"
DEST_DIR="fastq_downloads"
ASCP_OPTS="-QT -l 300M -P33001 -i $KEY"
mkdir -p "$DEST_DIR"
tail -n +2 "$OUTPUT_TSV" | while IFS=$'\t' read -r run accession; do
    echo "=== Processing $run ==="
    IFS=';' read -ra LINKS <<< "$accession"
    for LINK in "${LINKS[@]}"; do
        [[ -z "$LINK" || "$LINK" == "NA" ]] && continue
        echo "Downloading: $LINK"
        $ASCP_BIN $ASCP_OPTS "$LINK" "$DEST_DIR/" || echo "Failed: $LINK"
    done
done
```

---

# 6. 项目目录结构

```
project/
├── README.md
├── sra_list.txt
├── get_aspera_links_realtime.sh
├── download_fastq_from_aspera.sh
└── output.tsv
```

---

# 7. 常见问题 FAQ

- 某些 SRA 显示 NA → ENA 未同步 / 数据未公开  
- 下载慢 → 修改 `-l 1000M`  
- 支持断点续传  
