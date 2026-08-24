# Changelog

All notable changes to this project will be documented in this file.

<!--
版本规范 (Keep a Changelog):
- 平时改动记入 [Unreleased] 段落
- 发版时把 [Unreleased] 改名为 [x.yyy] 并补日期, 然后: git tag vx.yyy && git push origin vx.yyy
- fmdata 更新版也占一个正常版本号 (如 1.591), 注明 "FM 数据更新至 WT x.y.z.w"
- 不要用四段号 (v1.590.1): checkUpdate() 的正则会截断成 1.590, 用户收不到更新提示
以下为历史归档段落 (未对应发版 tag)
-->

## [Unreleased]

## [1.584] - 2026-08-24

### Changed
- **构建脚本迁移 Python**: build.sh/release_notes.sh 重写为 build.py/release_notes.py（仅依赖 Python 3.8+ 标准库），消除 Windows 下 bash 环境差异问题（GOW 老工具集、PATH 缺 git\usr\bin、CRLF、非登录 shell），cmd 与 PowerShell 可直接执行
- **fmdata 自动探测游戏目录**: 注册表 > Steam 库 (libraryfolders.vdf，兼容多盘) > 常见路径，命中后缓存 `.wt_game_dir`，无需手动设置 WT_GAME_DIR
- **工程流程重构**: 统一构建入口 `python script/build.py`（compile/test/jar/exe/dist/fmdata/clean 子命令，Windows/Linux/CI 通用），删除 build.cmd/build.ps1/zip.sh 等漂移旧脚本
- **版本号自动化**: 版本号由 git tag 驱动、构建时注入，发版不再需要修改代码提交 commit
- **发版自动化**: push tag 触发 GitHub Actions 自动构建、打包并创建 Release
- **分发包瘦身**: FM 数据裁剪为程序实际使用的 flightmodels 子树，包体积 104MB → 56MB；剔除误打包的 records/config 等用户数据
- **单一来源**: 项目目录即完整工作区（repo-as-workspace），废弃 Downloads 分发目录
- **FM 数据更新**: FM 数据更新至 WT 2.57.1.103

### Removed
- **商用字体不再提供**: DIN Pro 400 为商业授权字体，不再进入 git 仓库与分发包（规避版权风险）；开源字体照常内置，需要 DIN Pro 的用户可自行放置于 `fonts/` 目录

### Fixed
- **真机 FM 测试套件修复**: `test spitfire`/`test tempest` 改从项目内 `data/` 读取 FM 数据（无 data 自动跳过）；修复测试入口未初始化语言字符串导致的 NPE；Tempest Mk.V 期望功率随当前游戏数据同步调整

## [Unreleased] - 2026-02-22

### Changed
- **颜色配置格式优化**: 文本框显示十六进制格式，失去焦点自动保存，存储仍用十进制保持兼容
- **滑块控件增强**: 新增 Spinner 数字输入框，布局 `[标签]...[滑块][输入框][单位]`，`:unit` 替代 `:format`
- **ui_layout.cfg**: 颜色默认值改用十六进制，WEP 默认值改为 true
- **姿态仪方向指示**: 北向用橙色，南向用白色

### Fixed
- **ConfigManager**: 修复空键配置项导致每次启动都显示变更通知的问题

## [Unreleased] - 2026-02-16

### Added
- **引擎控制面板新增动力量 (POWER) gauge**: 在 `EngineControlOverlay` 中新增独立的动力量显示条。
  - 新增 `GaugeType.POWER` 枚举值，显示当前推力/功率与发动机极限的比值
  - 配置项：`disableEngineInfoPower`（默认启用）
  - 标签：`动`（单字，保持与其他 gauge 视觉一致）
  - 最大值：100%
  - **行为变更**：
    - PITCH gauge 现仅显示螺旋桨桨距，喷气机上自动隐藏
    - POWER gauge 对所有机型可见（喷气机显示推力%，活塞机显示功率%）
    - 移除了原有 PITCH gauge 在喷气机上切换标签为"推"的逻辑

### Removed
- **`TelemetrySource.getThrustPercent()`**: 删除冗余方法，统一使用 `getPowerPercent()`（自动封顶至 100%）

## [Unreleased] - 2026-02-03

### Added
- **MiniHUD 速度条/油门条切换**: 在 MiniHUD 面板的"hud数据设置"分组中新增"油门条/速度条"开关 (`showSpeedBar`)。
  - 开启时 (默认): 显示速度条 (SpeedRatioBar)
  - 关闭时: 显示油门条 (ThrottleBar)
  - 油门条刻度改为左侧显示，与速度条位置一致
  - 支持 WYSIWYG 实时预览切换

## [Unreleased] - 2026-01-19

###- **Refactored Configuration System (Category 2)**:
  - Migrated remaining logic parameters from `config.properties` to `ui_layout.cfg`.
  - **Color Fix**: Removed legacy `checkColorDefault` logic that was interfering with color loading. Implemented `refreshGlobalColors()` to ensure `Application` state is actively updated from `ui_layout.cfg` immediately after load.
  - **Layout-First Configuration Logic**:
    - Upgraded `ConfigurationService.getConfig()` to prioritize reading from `ui_layout.cfg` over `config.properties` for ALL keys.
    - Upgraded `ConfigurationService.setConfig()` to enforce dual-write: updates both `ui_layout.cfg` (in-memory) and `config.properties`.
    - This establishes `ui_layout.cfg` as the **Single Source of Truth** for duplicated keys.
    - **Batch Removal**: Safely deleted duplicate boolean keys (`disableEngineInfoThrottle`, `enableStatusBar`, etc.) from `config.properties` as they are now reliably served from Layout.
    - **Fix**: Implemented correct `SWITCH_INV` inversion logic in `ConfigurationService` to ensure keys like `disableFlightInfoIAS` are interpreted correctly (Store=True vs App=False).
    - **Defaults**: Updated `ui_layout.cfg` defaults to enable MiniHUD elements (`displayCrosshair`, `drawHUDtext`) by default, preventing "empty overlay" issues on fresh Layout-First load.
    - **Stability**: Fixed NullPointerExceptions in `VoiceWarning.init` and `Controller.openpad` caused by Preview Mode execution where Service is not fully initialized.
    - **Cleanup**: Completed Batch 4 removal of legacy duplicate keys (including `crosshairScale`, `enableVoiceWarn`, etc.) from `config.properties`, ensuring `ui_layout.cfg` is the definitive configuration source.
    - **Fix**: Updated `ConfigurationService` to support reading/writing Master Switches (`flightInfoSwitch`, etc.) directly from `GroupConfig` visibility. This resolves the "No Overlay in Game Mode" issue caused by missing keys in `config.properties`.
    - **Correction Completed**: Restored incorrectly deleted system-level configurations (`enableLogging`, `AAEnable`, `attitudeIndicatorFreqMs`) and resource keys (`crosshairName`) to `config.properties` to ensure system stability.
    - **Fix**: Updated `ConfigurationService` to support unified color strings (e.g., "255, 255, 255, 255") from `ui_layout.cfg`. This ensures Layout color settings take precedence over legacy split keys (`fontNumR` etc.) in `config.properties`.
  - Implemented **Typed Value Model**: Configuration items in `ui_layout.cfg` are now parsed into strict Java types (Integer, Boolean) at load time, eliminating manual string parsing in renderers.
  - Removed legacy `visible` and `defaultValue` fields in favor of a unified, typed `value` field.
  - Exposed hidden logic settings (AoA Warning Ratios) as sliders in the Layout UI.
- **Logic Exposure**: Exposed `miniHUDaoaWarningRatio` and `miniHUDaoaBarWarningRatio` as sliders (0-100%) in `ui_layout.cfg`. Updated backend key logic to support legacy (0.0-1.0) and new percentage values automatically.
- **Config Persistence**: Refactored `ConfigLoader` and `RowRenderer`s to persist control values (Sliders, Combos) directly into `ui_layout.cfg`, enabling migration away from `config.properties`.
- **UI**: Standardized `FontSize` control across `FlightInfo`, `EngineControl`, and `MiniHUD` overlays using the new `ui_layout.cfg` structure.
