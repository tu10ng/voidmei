#!/bin/bash
#
# VoidMei 统一构建脚本 —— 唯一构建入口
#
# Windows 开发者: 在 git-bash (或 WSL) 中执行; Linux/macOS 直接执行。
# CI (GitHub Actions, ubuntu-latest) 复用本脚本, 保证"本地能跑 = CI 能跑"。
#
# 用法:
#   ./script/build.sh compile            # 编译 src/ → bin/
#   ./script/build.sh test [suite]       # 编译并运行单元测试 (suite: atmosphere|piston|spitfire|tempest|visibility|voicepack|all)
#   ./script/build.sh jar                # 打 VoidMei.jar (版本号注入 MANIFEST)
#   ./script/build.sh exe                # launch4j 打 VoidMei.exe (版本号注入 EXE 资源)
#   ./script/build.sh dist               # jar+exe 后组装完整分发包 → dist/VoidMei_v*.zip
#   ./script/build.sh fmdata             # 从 War Thunder 客户端解包并裁剪 FM 数据 (游戏版本更新后执行)
#   ./script/build.sh clean              # 清理 bin/ build/ dist/
#
# 环境变量:
#   VOIDMEI_VERSION    版本号 (CI 从 git tag 注入, 如 1.590; 缺省 dev)
#   VOIDMEI_FMDATA_ZIP dist 使用的现成裁剪版 data zip (CI 从 data prerelease 下载; 缺省用项目内 ./data)
#   VOIDMEI_LAUNCH4J   launch4j 可执行文件或 launch4j.jar 的路径 (缺省从 PATH 及常见位置查找)
#   WT_GAME_DIR        fmdata 子命令: War Thunder 游戏安装目录
#   VOIDMEI_WT_EXT_CLI fmdata 子命令: wt_ext_cli 可执行文件路径 (缺省自动探测)
#

set -euo pipefail

# ---------- 全局配置 ----------
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# 版本号: 由构建环境注入 (CI 从 git tag 提取), 本地缺省 dev
VERSION="${VOIDMEI_VERSION:-dev}"

# 颜色输出 (不支持颜色的终端下 t decorative 字符无害)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[build]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn ]${NC} $*" >&2; }
err()  { echo -e "${RED}[error]${NC} $*" >&2; }

mkdir -p bin build dist

# ---------- compile: 编译 ----------
cmd_compile() {
    log "编译 src/ → bin/ ..."
    rm -rf bin
    mkdir -p bin
    find src -name "*.java" > build/sources.txt
    javac -encoding UTF-8 -d bin -classpath 'dep/*' @build/sources.txt
    log "编译完成"
}

# 编译检查: bin 不存在时自动先编译 (供 test/jar 复用)
ensure_compiled() {
    if [ ! -d bin/prog ]; then
        cmd_compile
    fi
}

# ---------- test: 单元测试 ----------
cmd_test() {
    local suite="${1:-all}"
    ensure_compiled
    log "编译测试代码 test/ ..."
    javac -encoding UTF-8 -d bin -classpath bin test/*.java

    local TOTAL_PASSED=0 TOTAL_FAILED=0

    run_test() {
        local test_name="$1" class_name="$2"
        echo -e "${YELLOW}Running $test_name ...${NC}"
        if java -classpath bin "$class_name"; then
            echo -e "${GREEN}$test_name: PASSED${NC}"
            return 0
        else
            echo -e "${RED}$test_name: FAILED${NC}"
            return 1
        fi
    }

    # 需要 Datamine FM 文件的验证套件 (spitfire/tempest), 本地有数据才跑
    run_datamine_test() {
        local label="$1" class_name="$2" plane="$3"
        local DATAMINE_ROOT="${DATAMINE_ROOT:-$HOME/projects/War-Thunder-Datamine-260205}"
        local CENTRAL_PATH="$DATAMINE_ROOT/aces.vromfs.bin_u/gamedata/flightmodels/$plane.blkx"
        local FM_PATH="$DATAMINE_ROOT/aces.vromfs.bin_u/gamedata/flightmodels/fm/$plane.blkx"
        if [ ! -f "$CENTRAL_PATH" ] || [ ! -f "$FM_PATH" ]; then
            warn "跳过 $label: 未找到 Datamine FM 文件 (设置 DATAMINE_ROOT 指向解包目录可启用)"
            return 0
        fi
        if run_test "$label" "$class_name"; then
            ((TOTAL_PASSED++)) || true
        else
            ((TOTAL_FAILED++)) || true
        fi
    }

    record() {
        if run_test "$1" "$2"; then ((TOTAL_PASSED++)) || true; else ((TOTAL_FAILED++)) || true; fi
    }

    case "$suite" in
        atmosphere|atm)    record "AtmosphereModel Tests" "TestAtmosphereModel" ;;
        piston|power)      record "PistonPowerModel Tests" "TestPistonPowerModel" ;;
        spitfire|f24)      run_datamine_test "Spitfire F24 Tests" "TestSpitfireF24Power" "spitfire_f24" ;;
        tempest|mkv)       run_datamine_test "Tempest Mk V Tests" "TestTempestMk5Power" "tempest_mkv" ;;
        visibility|vis)    record "VisibilityExpressionEvaluator Tests" "TestVisibilityExpressionEvaluator" ;;
        voicepack|voice)   record "VoicePackConfig Tests" "TestVoicePackConfig" ;;
        all|*)
            record "AtmosphereModel Tests" "TestAtmosphereModel"
            record "PistonPowerModel Tests" "TestPistonPowerModel"
            record "VisibilityExpressionEvaluator Tests" "TestVisibilityExpressionEvaluator"
            record "VoicePackConfig Tests" "TestVoicePackConfig"
            ;;
    esac

    echo ""
    echo -e "Test suites passed: ${GREEN}$TOTAL_PASSED${NC}  failed: ${RED}$TOTAL_FAILED${NC}"
    [ "$TOTAL_FAILED" -eq 0 ] || { err "存在失败的测试!"; exit 1; }
    log "全部测试通过"
}

# ---------- jar: 打包 jar (版本号注入 MANIFEST) ----------
cmd_jar() {
    ensure_compiled
    # 生成带版本号的 MANIFEST 副本: Application.readVersion() 运行时从
    # Implementation-Version 读取版本号 (本地未打 jar 直接跑时回退 "dev")
    # 注意: MANIFEST 规范要求末尾换行, 追加前先确保
    cp MANIFEST.MF build/MANIFEST.gen
    [ -n "$(tail -c1 build/MANIFEST.gen)" ] && echo >> build/MANIFEST.gen
    echo "Implementation-Version: $VERSION" >> build/MANIFEST.gen
    jar cfm VoidMei.jar build/MANIFEST.gen -C bin .
    log "打包完成: VoidMei.jar (版本: $VERSION)"
}

# ---------- exe: launch4j 打包 ----------
# 查找 launch4j: 环境变量 → PATH → Windows 常见安装位置
find_launch4j() {
    local l4j="${VOIDMEI_LAUNCH4J:-}"
    if [ -n "$l4j" ] && [ -e "$l4j" ]; then
        echo "$l4j"; return 0
    fi
    if command -v launch4jc >/dev/null 2>&1; then
        command -v launch4jc; return 0
    fi
    local candidate
    for candidate in \
        "/c/Program Files (x86)/Launch4j/launch4jc.exe" \
        "/c/Program Files/Launch4j/launch4jc.exe" \
        "/usr/local/bin/launch4j" \
        "/opt/launch4j/launch4j"; do
        [ -e "$candidate" ] && { echo "$candidate"; return 0; }
    done
    return 1
}

cmd_exe() {
    [ -f VoidMei.jar ] || cmd_jar
    local l4j
    if ! l4j="$(find_launch4j)"; then
        warn "未找到 launch4j (可设置 VOIDMEI_LAUNCH4J 指向 launch4jc 或 launch4j.jar), 跳过 EXE 生成"
        warn "CI 环境会自动下载 launch4j Linux 发行包; 本地缺失仅影响 exe, 不影响 jar"
        return 0
    fi
    # EXE 版本资源: fileVersion 必须四段式 (1.590 → 1.590.0.0); dev 版用 0.0.0.0
    local v4
    if [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        v4="${VERSION}.0.0"
    else
        v4="0.0.0.0"
    fi
    # 由模板生成临时配置 (生成到 script/ 下, 保证 icon 等相对路径与原配置一致)
    sed -e "s/@VERSION@/$VERSION/g" -e "s/@VERSION4@/$v4/g" \
        script/voidmeil4j.xml > script/voidmeil4j.gen.xml
    case "$l4j" in
        *.jar) java -jar "$l4j" script/voidmeil4j.gen.xml ;;
        *)     "$l4j" script/voidmeil4j.gen.xml ;;
    esac
    log "EXE 打包完成: VoidMei.exe (版本: $VERSION)"
}

# ---------- dist: 组装完整分发包 ----------
# data 源解析: VOIDMEI_FMDATA_ZIP (CI, 优先) → 项目内 ./data (本地默认)
stage_data() {
    local stage_data_dir="$1/data"
    mkdir -p "$stage_data_dir"
    if [ -n "${VOIDMEI_FMDATA_ZIP:-}" ]; then
        # CI: 解包裁剪版 data zip (zip 顶层为 data/)
        [ -f "$VOIDMEI_FMDATA_ZIP" ] || { err "VOIDMEI_FMDATA_ZIP 不存在: $VOIDMEI_FMDATA_ZIP"; exit 1; }
        (cd "$stage_data_dir/.." && unzip -q -o "$VOIDMEI_FMDATA_ZIP")
        [ -d "$stage_data_dir/aces/gamedata/flightmodels" ] \
            || { err "data zip 内容异常: 缺少 data/aces/gamedata/flightmodels"; exit 1; }
    elif [ -d data/aces/gamedata/flightmodels ]; then
        # 本地: 从项目内 ./data 裁剪 (程序仅引用 version 文件与 flightmodels 子树)
        mkdir -p "$stage_data_dir/aces/gamedata"
        [ -f data/aces/version ] && cp data/aces/version "$stage_data_dir/aces/version"
        cp -r data/aces/gamedata/flightmodels "$stage_data_dir/aces/gamedata/flightmodels"
    else
        err "缺少 FM 数据: 请先运行 ./script/build.sh fmdata 生成项目内 data/, 或设置 VOIDMEI_FMDATA_ZIP"
        exit 1
    fi
}

cmd_dist() {
    cmd_jar
    cmd_exe

    # zip 命名: 正式版 VoidMei_v1.590.zip; 本地 dev 版带 commit hash 与日期
    local zipname
    if [ "$VERSION" = "dev" ]; then
        local hash date
        hash="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
        date="$(date +%Y%m%d)"
        zipname="VoidMei_dev_${hash}_${date}"
    else
        zipname="VoidMei_v${VERSION}"
    fi

    local stage="dist/stage/$zipname"
    rm -rf "$stage"
    mkdir -p "$stage"

    log "组装分发包: $zipname ..."
    # --- 程序本体 ---
    cp VoidMei.jar "$stage/"
    cp VoidMei.bat "$stage/"
    [ -f VoidMei.exe ] && cp VoidMei.exe "$stage/"
    # --- 依赖与资源 (白名单复制, 天然排除 records/ config/ ui_layout.user.cfg 等用户数据) ---
    cp -r dep "$stage/dep"
    cp -r fonts "$stage/fonts"
    cp -r image "$stage/image"
    cp -r voice "$stage/voice"
    mkdir -p "$stage/lang"
    cp lang/cur.properties "$stage/lang/"
    cp ui_layout.cfg "$stage/"
    cp 使用说明.txt 快速使用说明.txt 更新日志.txt "$stage/" 2>/dev/null || warn "缺少说明文档 txt"
    # --- FM 数据 (裁剪版) ---
    stage_data "$stage"

    # 提示: 本地 fonts/ 可能含未入库的商业字体 (CI 构建的包不含)
    [ -f "fonts/DIN Pro 400.otf" ] && \
        warn "本地 fonts/ 含 DIN Pro 400.otf (商业字体, 未入库), 本地打的包将携带该字体; 正式发布请使用 CI 产物"

    (cd dist/stage && zip -r -q "../$zipname.zip" "$zipname")
    rm -rf dist/stage
    (cd dist && sha256sum "$zipname.zip" > "$zipname.zip.sha256")
    log "分发包完成: dist/$zipname.zip ($(du -h "dist/$zipname.zip" | cut -f1))"
}

# ---------- fmdata: 解包并裁剪 FM 数据 ----------
cmd_fmdata() {
    local game_dir="${WT_GAME_DIR:-}"
    if [ -z "$game_dir" ]; then
        err "必须设置 WT_GAME_DIR 指向 War Thunder 游戏安装目录, 例:"
        err '  WT_GAME_DIR="C:/Program Files (x86)/Steam/steamapps/common/War Thunder" ./script/build.sh fmdata'
        exit 1
    fi

    # 定位 vromfs 包 (WT 客户端为 gzip 压缩格式 _gz)
    local vromfs=""
    local candidate
    for candidate in aces.vromfs.bin_gz aces.vromfs.bin; do
        [ -f "$game_dir/$candidate" ] && { vromfs="$game_dir/$candidate"; break; }
    done
    [ -n "$vromfs" ] || { err "在 $game_dir 下未找到 aces.vromfs.bin_gz / aces.vromfs.bin"; exit 1; }

    # 定位 wt_ext_cli 解包工具
    local wtcli="${VOIDMEI_WT_EXT_CLI:-}"
    if [ -z "$wtcli" ]; then
        for candidate in "$HOME"/Downloads/wt_ext_cli-*/wt_ext_cli.exe "$HOME"/Downloads/wt_ext_cli-*/wt_ext_cli; do
            [ -e "$candidate" ] && { wtcli="$candidate"; break; }
        done
    fi
    [ -n "$wtcli" ] && [ -e "$wtcli" ] || {
        err "未找到 wt_ext_cli (设置 VOIDMEI_WT_EXT_CLI 指向其可执行文件)"
        err "工具主页: https://github.com/Warthunder-Open-Source-Foundation/wt_ext_cli"
        exit 1
    }

    # 解包到临时目录 (纯文本 .blkx 输出)
    log "wt_ext_cli 解包 $vromfs ..."
    rm -rf build/fmdata_unpack
    "$wtcli" unpack_vromfs -o build/fmdata_unpack "$vromfs"

    local unpack_root="build/fmdata_unpack"
    [ -d "$unpack_root/gamedata/flightmodels" ] \
        || { err "解包结果异常: 缺少 gamedata/flightmodels (wt_ext_cli 版本可能滞后于游戏格式, 请检查其 releases)"; exit 1; }

    # 裁剪更新项目内 ./data —— 单一来源, 本地即刻可用
    log "裁剪并更新项目内 data/ (仅 version + flightmodels, 程序只读这两处) ..."
    rm -rf data/aces/gamedata/flightmodels
    mkdir -p data/aces/gamedata
    cp -r "$unpack_root/gamedata/flightmodels" data/aces/gamedata/flightmodels

    # 生成 version 文件 (供 Blkx.getVersion() 显示 FM 数据版本), 探测多个来源
    local wtver=""
    for candidate in "$game_dir/version.txt" "$game_dir/_warthunder/version.txt" "$unpack_root/version" "$unpack_root/config/version"; do
        if [ -f "$candidate" ]; then
            wtver="$(tr -d '\r\n' < "$candidate")"
            cp "$candidate" data/aces/version
            break
        fi
    done
    [ -n "$wtver" ] || warn "未找到游戏 version 文件, data/aces/version 未生成 (程序可容错运行)"

    # 统计并产出上传用的 data zip + manifest
    local blkx_count file_count total_bytes date
    blkx_count="$(find data/aces/gamedata/flightmodels -name "*.blkx" | wc -l)"
    file_count="$(find data -type f | wc -l)"
    total_bytes="$(du -sb data | cut -f1)"
    date="$(date +%Y%m%d)"

    local data_zip="dist/VoidMei_data_${wtver:-unknown}_${date}.zip"
    rm -f dist/VoidMei_data_*.zip
    (cd . && zip -r -q "$data_zip" data)
    local sha256
    sha256="$(sha256sum "$data_zip" | cut -d' ' -f1)"

    cat > dist/data_manifest.json <<EOF
{
  "wt_version": "${wtver:-unknown}",
  "date": "$date",
  "blkx_count": $blkx_count,
  "file_count": $file_count,
  "total_bytes": $total_bytes,
  "zip": "$(basename "$data_zip")",
  "sha256": "$sha256"
}
EOF

    rm -rf build/fmdata_unpack
    log "fmdata 更新完成: $data_zip ($(du -h "$data_zip" | cut -f1), $blkx_count 个 blkx)"
    log "上传到 data 存储 (供 CI 组包): gh release upload data \"$(basename "$data_zip")\" dist/data_manifest.json --clobber"
}

# ---------- clean ----------
cmd_clean() {
    rm -rf bin build dist
    log "已清理 bin/ build/ dist/"
}

# ---------- 入口 ----------
case "${1:-}" in
    compile) cmd_compile ;;
    test)    shift; cmd_test "$@" ;;
    jar)     cmd_jar ;;
    exe)     cmd_exe ;;
    dist)    cmd_dist ;;
    fmdata)  cmd_fmdata ;;
    clean)   cmd_clean ;;
    *)
        sed -n '3,20p' "$0"
        exit 1
        ;;
esac
