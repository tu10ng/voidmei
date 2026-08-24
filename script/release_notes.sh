#!/bin/bash
#
# CHANGELOG.md 单一来源 → 双输出:
#   1. GitHub Release body (markdown 原样)
#   2. 更新日志.txt (面向用户的中文纯文本, 随 zip 分发)
#
# 用法 (通常由 release.yml CI 调用, 也可本地预览):
#   script/release_notes.sh extract-md <version>   # 提取该版本段落 → stdout (Release body)
#   script/release_notes.sh append-txt <version>   # 按 更新日志.txt 现有格式插入该版本条目
#   script/release_notes.sh preview <version>      # 本地预览将生成的 txt 条目 (不写文件)
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

VER="${2:?用法: release_notes.sh extract-md|append-txt|preview <version>}"
SEP_LINE="_______________________________________"

# 从 CHANGELOG.md 提取 "## [version]" 到下一个 "## [" 之间的段落
# 注意 1: 必须用字符串全等 (==) 而非动态正则 —— 版本号含 [.] 时会被解释为字符类,
#   例如 [1.584-test] 中 "4-t" 构成 ASCII 范围, 会误匹配 "[Unreleased]" 等行
# 注意 2: 匹配前剥掉行尾 \r, 兼容 Windows 工作区 checkout 出的 CRLF 换行
extract_section() {
    awk -v hdr="## [$VER]" '
        { line = $0; sub(/\r$/, "", line) }
        line == hdr { flag = 1; next }
        line ~ /^## \[/ && flag { exit }
        flag && !started && /^[[:space:]]*$/ { next }   # 跳过段落开头空行
        flag { started = 1; print line }
    ' CHANGELOG.md
}

# markdown 段落 → 更新日志.txt 的纯文本条目:
# 保留所有列表行 (- 与缩进子项), 去掉 markdown 强调符号
to_txt_entries() {
    extract_section | grep -E '^[[:space:]]*-' | sed 's/\*\*//g'
}

case "${1:-}" in
    extract-md)
        section="$(extract_section)"
        [ -n "$section" ] || { echo "CHANGELOG.md 中未找到 [$VER] 段落" >&2; exit 1; }
        echo "# VoidMei v$VER"
        echo
        echo "$section"
        ;;
    preview | append-txt)
        entries="$(to_txt_entries)"
        [ -n "$entries" ] || { echo "CHANGELOG.md 中未找到 [$VER] 段落或其无列表条目" >&2; exit 1; }
        # 块结构对齐现有文件: 分隔线 / 版本行 / 条目行 / 空行 (与下一个分隔线隔开)
        block="$SEP_LINE
v$VER
$entries

"
        if [ "$1" = "preview" ]; then
            echo "$block"
            exit 0
        fi
        # 插入到 更新日志.txt 的第一个分隔线之前 (顶部 TODO 注释块之后, 最新版本在最上)
        # 该文件为 CRLF 换行 (Windows 面向用户文档), 新块也按 CRLF 写入保持一致
        mkdir -p build
        block="${block//$'\n'/$'\r\n'}"
        if [ ! -f 更新日志.txt ]; then
            printf '%s\n' "$block" > 更新日志.txt
        elif grep -qF "$SEP_LINE" 更新日志.txt; then
            # awk 在第一个分隔线行之前插入新块 (其余内容原样);
            # 输入剥 \r 后统一按 CRLF 重写 —— 避免 git-bash 的 gawk 文本模式
            # 剥掉全文件 \r 导致新旧内容换行混杂 (Linux 上则保持原样一致)
            awk -v block="$block" -v sep="$SEP_LINE" '
                {
                    line = $0
                    sub(/\r$/, "", line)
                    if (!done && line == sep) { printf "%s", block; done = 1 }
                    printf "%s\r\n", line
                }
            ' 更新日志.txt > build/更新日志.txt.new
            mv build/更新日志.txt.new 更新日志.txt
        else
            printf '%s\n%s\n' "$block" "$(cat 更新日志.txt)" > 更新日志.txt
        fi
        echo "更新日志.txt 已追加 v$VER 条目"
        ;;
    *)
        sed -n '3,10p' "$0"
        exit 1
        ;;
esac
