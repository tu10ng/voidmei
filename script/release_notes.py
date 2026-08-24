#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""CHANGELOG.md 单一来源 -> 双输出:

  1. GitHub Release body (markdown 原样)
  2. 更新日志.txt (面向用户的中文纯文本, CRLF 行尾, 随 zip 分发)

用法 (通常由 release.yml CI 调用, 也可本地预览):
  python script/release_notes.py extract-md <version>   提取该版本段落 -> stdout (Release body)
  python script/release_notes.py append-txt <version>   按 更新日志.txt 现有格式插入该版本条目
  python script/release_notes.py preview <version>      本地预览将生成的 txt 条目 (不写文件)
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEP_LINE = "_______________________________________"


def log_err(msg):
    print("[error] " + msg, file=sys.stderr)


def extract_section(ver):
    """提取 "## [version]" 到下一个 "## [" 之间的段落 (跳过段首空行)。

    匹配用字符串全等并剥行尾 \\r —— 兼容 CRLF 工作区, 且避免把版本号
    当正则解释 (如 [1.584-test] 的 "4-t" 是 ASCII 范围, 会误匹配 [Unreleased])。
    """
    try:
        text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    except FileNotFoundError:
        return []
    hdr = "## [%s]" % ver
    out, flag, started = [], False, False
    for raw in text.splitlines():
        line = raw.rstrip("\r")
        if not flag:
            if line == hdr:
                flag = True
            continue
        if line.startswith("## ["):
            break
        if not started and not line.strip():
            continue  # 跳过段落开头空行
        started = True
        out.append(line)
    return out


def to_txt_entries(section):
    """markdown 段落 -> 更新日志.txt 纯文本条目: 保留列表行, 去掉 markdown 强调符号。"""
    return [re.sub(r"\*\*", "", ln) for ln in section if ln.lstrip().startswith("-")]


def build_block(ver, entries):
    """块结构对齐现有文件: 分隔线 / 版本行 / 条目行 / 空行 (与下一个分隔线隔开)。"""
    return [SEP_LINE, "v%s" % ver] + entries + [""]


def cmd_extract_md(ver):
    section = extract_section(ver)
    if not section:
        log_err("CHANGELOG.md 中未找到 [%s] 段落" % ver)
        return 1
    print("# VoidMei v%s" % ver)
    print()
    print("\n".join(section))
    return 0


def read_lines_keep(path):
    """读文本并返回已剥 \\r 的行列表 (文件可能是 CRLF 或 LF)。"""
    with open(path, encoding="utf-8", newline="") as f:
        return [ln.rstrip("\r") for ln in f.read().split("\n")]


def cmd_append_txt(ver, dry=False):
    entries = to_txt_entries(extract_section(ver))
    if not entries:
        log_err("CHANGELOG.md 中未找到 [%s] 段落或其无列表条目" % ver)
        return 1
    block = build_block(ver, entries)

    if dry:
        print("\n".join(block))
        return 0

    # 插入到 更新日志.txt 的第一个分隔线之前 (顶部 TODO 注释块之后, 最新版本在最上);
    # 输出统一按 CRLF 重写 —— 该文件为 Windows 面向用户文档
    path = ROOT / "更新日志.txt"
    if not path.exists():
        path.write_bytes(("\r\n".join(block) + "\r\n").encode("utf-8"))
    else:
        lines = read_lines_keep(path)
        out, done = [], False
        for ln in lines:
            if not done and ln == SEP_LINE:
                out.extend(block)
                done = True
            out.append(ln)
        if not done:  # 无分隔线 (异常格式): 整块前置
            out = block + [""] + lines
        path.write_bytes(("\r\n".join(out) + "\r\n").encode("utf-8"))
    print("更新日志.txt 已追加 v%s 条目" % ver)
    return 0


def main():
    args = sys.argv[1:]
    if len(args) != 2 or args[0] not in ("extract-md", "append-txt", "preview"):
        print(__doc__)
        sys.exit(1)
    cmd, ver = args
    if cmd == "extract-md":
        sys.exit(cmd_extract_md(ver))
    else:
        sys.exit(cmd_append_txt(ver, dry=(cmd == "preview")))


if __name__ == "__main__":
    main()
