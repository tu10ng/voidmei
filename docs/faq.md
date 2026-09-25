# 常见问题

## OBS 无法捕捉 VoidMei 窗口？

VoidMei 基于 Java 的**逐像素透明窗口机制**实现，OBS"窗口捕捉"的两种采集方法——BitBlt 与 WGC——均无法获取这类窗口的内容。改用**显示器捕捉**（或带游戏源的全屏采集）即可。

## 提示 JVM NOT FOUND？

安装 JRE 8：<https://www.java.com/zh-CN/download/>，或使用 [Eclipse Temurin 8](https://adoptium.net/temurin/releases/?version=8)。

## 如何导入他人的配置？升级新版怎么保留配置？

全部设置都在程序目录下的 `ui_layout.user.cfg` 里，务必通过「全局设置 → 导入配置」导入，切勿直接复制替换文件；升级在原目录解压覆盖即可自动保留。详见[安装 → 升级与配置迁移](install.md#升级与配置迁移)。

## 游戏画面卡顿？

游戏以 **DX12 模式**运行时（Intel Arc 核显只允许 DX12，部分 A 卡同样），悬浮窗与游戏渲染冲突会导致画面卡顿，详见 [#54](https://github.com/matrixsukhoi/voidmei/issues/54)（同类工具也有此问题）。目前最有效的解法是**在游戏内锁帧（如 60fps），注意不要开垂直同步**；仍无改善时依次尝试：

1. 开关「全局设置」的「软件渲染模式」
2. 将游戏改为全屏窗口模式
3. 开关显卡驱动的「GPU 硬件加速计划」
4. 切换独显直连 / 混合模式

## 程序界面帧数低、不达预期？

游戏帧数大大超出屏幕刷新率、开垂直同步也限不住时，可能是 Win11 调度导致的游戏帧数 bug。用显卡驱动限制最大帧数（如 Nvidia 控制面板 → 管理 3D 设置 → 最大帧速率 = 屏幕刷新率）；独显直连/混合模式也可能触发，遇到请切换至另一种模式。

## VoidMei 自身 CPU 占用偏高？

增大「高级设置 → 数据帧延时（毫秒）」，并启用「高级设置 → 简化字体描边」。

## Win7 上能用吗？

可以，但必须开启 AERO 主题（不要切换到"Basic"或"经典"主题）：Java 的窗体透明调用系统 AERO 透明接口，关闭 AERO 时透明悬浮窗会影响所有游戏的性能。建议升级 Win10+。

## 支持 Linux 吗？

不支持原生 Linux。可在 Wine 下运行：`winecfg` 兼容性设为 win10，安装 Windows 版 JRE 8 后执行 `wine java -jar VoidMei.jar`。悬浮窗依赖的窗口透明与置顶特性在不同桌面环境下表现不一，请自行尝试。

## 分析记录的文件用 Excel 打开是乱码？

导出的 csv 为 UTF-8 编码，Excel 打开乱码请以 UTF-8 编码导入，或使用 WPS 等其他软件。

## 读取 8111 端口违反用户协议吗？

读取 8111 端口本身不违反用户协议，但 FM 拆包/逆向工程是可能违反 EULA 1.2 与 3.2 条款的行为，附带数据库可自行删除，详见[首页](index.md)的风险提示。

---

其他问题请到 [GitHub Issues](https://github.com/matrixsukhoi/voidmei/issues) 反馈。
