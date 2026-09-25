"""mkdocs hook: 构建前把 image/ 顶层图片复制进 docs/assets/img/。

站点与 README 共用仓库 image/ 这一份图片 (单一来源, 改一处两边生效)。
- 只复制顶层 *.png (MiniHUD 分解图/总览截图/托盘图标), 不含 gunsight/ 瞄具贴图 (~53MB)
- 已存在且同大小的目标跳过: mkdocs serve 每次热重建都会跑本 hook,
  无条件重写会触发 watch 循环重建
"""
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent           # 仓库根
SRC = ROOT / "image"
DST = ROOT / "docs" / "assets" / "img"
IGNORE = {"facebook.gif", "test.png", "watermark.png"}  # 非文档素材

def on_pre_build(config):
    DST.mkdir(parents=True, exist_ok=True)
    for src in sorted(SRC.glob("*.png")):
        if src.name in IGNORE:
            continue
        dst = DST / src.name
        if not dst.exists() or dst.stat().st_size != src.stat().st_size:
            shutil.copy2(src, dst)
