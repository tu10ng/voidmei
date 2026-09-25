# VoidMei 使用手册

**VoidMei** 是一个开源的战争雷霆（War Thunder）实时飞行数据 HUD：以半透明悬浮窗呈现飞行状态、引擎参数与 FM 拆包数据，配合语音告警，帮助玩家快速掌握能量与机体状态。

![总览](assets/img/screenshot.png)

[:material-download: 前往安装](install.md){ .md-button .md-button--primary } [:material-rocket-launch: 快速上手](quickstart.md){ .md-button }

## 核心特性

所有指标都基于 FM 拆包数据实时计算，而非简单的仪表读数转发：

- **[MiniHUD](features/minihud.md)** —— 一块 HUD 看全空战关键信息：攻角、能量、耐热、航向全在一处
- **[精准控速](features/algorithms.md#精准控速)** —— 失速、解体、锁舵三条线实时画在速度条上，失速线随油量与襟翼开度变化
- **[直观控襟翼](features/algorithms.md#直观控襟翼)** —— 当前速度下襟翼最多能放多少，个位精度，贴线飞不吹飞
- **[精准控温](features/algorithms.md#精准控温)** —— 引擎还能烧多少秒，精确到个位的倒计时
- **[增压器不掉档](features/algorithms.md#增压器不掉档)** —— 现在几档功率最高实时算，手操增压器不用背高度表
- **[看穿功率余量](features/algorithms.md#看穿功率余量)** —— 引擎发挥了几成，一个数字说清
- **[摸透盘旋能力](features/algorithms.md#摸透盘旋能力)** —— 真实的飞行轨迹曲率半径，任意机动有效
- **[放心拉杆](features/algorithms.md#放心拉杆)** —— 真实断翼过载实时计算，告警不响一定不会断
- **[FM 拆包](features/fmdata.md)** —— 飞行中随时呼出飞行模型数据，机型之间随便比
- **[语音告警](features/voice.md)** —— 二十余种条件触发，wav 随便换、随便删
- **[所见即所得](features/customize.md#所见即所得)** —— 每个开关改完立刻看到效果，不用进游戏试

## 工作原理

- 通过 HTTP GET 读取 `127.0.0.1:8111` 的飞行状态与飞行仪表数据
- 解析离线拆包的气动模型文件（FM blkx），在本地计算派生指标
- 渲染为可自由摆放的桌面半透明悬浮窗

!!! warning "拆包数据风险提示"

    读取 8111 端口本身不违反用户协议，但**拆包/逆向工程是可能违反战争雷霆 EULA 1.2 与 3.2 条款的行为**。程序附带的离线拆包数据库 `./data/aces` 由网络途径获得，若担心风险可自行删除该数据库（程序其余功能不受影响）。

## 支持与联系

- 问题与建议：[GitHub Issues](https://github.com/matrixsukhoi/voidmei/issues)
- B 站：[隐居寒天](https://space.bilibili.com/14606916)
- 邮箱：<seclusionalagar@outlook.com>

VoidMei 遵循 [GPL-3.0](https://github.com/matrixsukhoi/voidmei/blob/master/LICENSE) 协议开源，源码与新版发布于 [GitHub](https://github.com/matrixsukhoi/voidmei)。
