# 安装

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10 及以上（Win7 需保持 AERO 主题，见 [FAQ](faq.md#win7-上能用吗)） |
| 运行环境 | JRE 8（exe 已强制 Java 8，缺失时提示下载地址） |
| 游戏设置 | **全屏窗口（无边框）或窗口模式**；独占全屏下悬浮窗不可见 |

!!! tip "游戏内开关"

    匹配模式即开即用；试飞与自定义模式需在难度选择中打开「允许使用网页界面」等开关。

## 方式一：GitHub Releases（推荐）

1. 从 [Releases](https://github.com/matrixsukhoi/voidmei/releases/latest) 下载最新版 zip
2. 解压到任意目录（**不要放在游戏目录或云盘同步目录**）
3. 运行 `VoidMei.exe`

## 方式二：Scoop（Windows 命令行）

```powershell
# 安装 scoop (已装可跳过)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# 设置代理(如果网络无问题可以直接跳过)
scoop config proxy [ip:port]
# 安装git(如果已安装可跳过)
scoop install git

# 添加 bucket 并安装 (感谢 @Lutra-Fs 维护)
scoop bucket add Lutra-Fs_scoop-bucket https://github.com/Lutra-Fs/scoop-bucket
scoop install Lutra-Fs_scoop-bucket/voidmei

# 升级
scoop update voidmei
```

## 升级与配置迁移

全部设置（面板开关、位置、字体、颜色、告警阈值等）都保存在程序目录下的 `ui_layout.user.cfg` 一个文件里。

- **原目录解压覆盖**：自动保留并合并设置，补齐新增选项，无需其他操作
- **换新目录**：用「全局设置 → 导入配置」导入自己原先的 `ui_layout.user.cfg`
- **使用他人配置**：向对方索要该文件后同样走「导入配置」，**切勿直接复制替换文件**——导入会自动备份（`.bak`）并与当前版本模板合并，直接替换在版本不一致时会缺失新功能

!!! warning "从 v1.580 及更早版本升级"

    旧设置文件（`config/config.properties`）与新配置系统不兼容、无法迁移。升级后请在设置界面重新调整（所有选项都有说明与实时预览），或直接导入他人分享的 `ui_layout.user.cfg`。

详细机制见[个性化定制 → 配置文件](features/customize.md#配置文件)。

## EULA 风险提示

读取 8111 端口本身不违反用户协议，但**拆包/逆向工程是可能违反战争雷霆 EULA 1.2 与 3.2 条款的行为**。程序附带的离线拆包数据库 `./data/aces` 由网络途径获得，若担心风险可自行删除该数据库（程序其余功能不受影响）。

此外，v1.586 起程序支持 [FM 数据在线自动更新](features/fmdata.md#在线自动更新)，如不希望程序联网可关闭设置中的「自动更新FM数据」。
