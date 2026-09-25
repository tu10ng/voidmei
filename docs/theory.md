# 计算原理

本章记录 VoidMei 派生指标背后的数学。输入两路：8111 遥测（实时状态）与 FM 拆包（机型气动/结构/引擎数据），全部计算在本地完成。公式与实现一一对应（源码 `src/prog/Service.java`、`src/parser/Blkx.java`、`src/prog/util/`）。

## 大气模型（ISA）

所有高度相关的换算都基于国际标准大气：

$$
\frac{P}{P_0} = \left(1 - 0.0000225577 \, h\right)^{5.25588}
$$

$$
\rho = \frac{P_0 \cdot (P/P_0)}{R \cdot T(h)}, \qquad T(h) = T_0 - 0.0065 \, h
$$

其中 $h$ 为高度（m），海平面 $T_0$ = 15 °C、$P_0$ = 101325 Pa、$\rho_0$ = 1.225 kg/m³，气体常数 $R$ = 287.05 J/(kg·K)。

**表速与真空速换算**（动压等价定义）：

$$
TAS = IAS \times \sqrt{\rho_0 / \rho}, \qquad IAS = TAS \times \sqrt{\rho / \rho_0}
$$

**冲压效应等效高度**（活塞功率计算用）：高速飞行时进气口捕获动压，相当于把增压器"放"在更低的静压高度上工作：

$$
q = \tfrac{1}{2}\rho \, v_{TAS}^2 \times k_{ram}, \qquad h_{ram} = P^{-1}\!\left(P_{static} + q\right)
$$

$k_{ram}$ 为 FM 文件里的进气效率系数 `SpeedManifoldMultiplier`（典型 0.8–1.0），$P^{-1}$ 是气压比公式的反函数。

## 马赫数与速度临界比

战雷 state 接口给的 mach 只有小数点后两位，误差大——VoidMei **不用它**，而是从大气模型手动换算。

由动压定义推出"马赫 1 对应的表速"：以马赫数 $M$ 飞行时动压 $q = \tfrac{1}{2}\rho (\dots)$，按声速 $a = \sqrt{\gamma P / \rho}$ 化简后 $q_M = \tfrac{1}{2}\gamma P$（只与静压有关！），再按表速定义 $q = \tfrac{1}{2}\rho_0 v_{IAS}^2$ 反解，得：

$$
IAS_{M=1} = \sqrt{\gamma \, P_0 / \rho_0} \times \sqrt{P/P_0} = a_0 \sqrt{P/P_0} \approx 1225 \sqrt{P/P_0} \; \text{km/h}
$$

$$
M = \frac{IAS}{IAS_{M=1}}
$$

**速度临界比**（智能速度/语音超速告警的统一依据）——表速与马赫哪个更接近解体极限就取哪个：

$$
ratio = \max\!\left(\frac{IAS}{VNE}, \; \frac{M}{MNE}\right)
$$

$VNE$/$MNE$ 为 FM 的结构解体表速/马赫数，可变后掠翼机型按当前后掠角插值（见[后掠翼插值](#可变后掠翼插值)）。锁舵区同理：锁舵速度 ÷ 当前更临界的极限速度。

## 失速速度

由升力平衡 $L = W g = \tfrac{1}{2}\rho_0 v^2 S \, C_L$（表速定义在 $\rho_0$），在临界攻角取 $C_{L,max}$ 反解：

$$
v_{stall} = 3.6 \times \sqrt{\frac{2 \, W \, g}{1.225 \cdot \Sigma}}
$$

其中 $W$ = 空重 + **当前油量**（烧油后失速速度实时降低），$\Sigma$ 为翼身合计的升力面积因数：

$$
\Sigma = S_{wing} \cdot C_{L,crit}^{wing} + S_{fuse} \cdot C_{L,crit}^{fuse} \times \frac{\alpha_{crit}^{wing}}{\alpha_{crit}^{fuse}}
$$

机身升力贡献按翼/机身临界攻角之比折算。**襟翼按线性混合**（无襟翼 ↔ 满襟翼两构型按当前开度百分比插值）：

$$
\Sigma = (1 - f)\,\Sigma_{NoFlap} + f\,\Sigma_{FullFlap}, \qquad f = \text{襟翼开度}/100
$$

直升机无机翼失速概念，直接置零不计算。

## 智能襟翼极限开度

FM 里的 `FlapsDestructionIndSpeed` 是一张（襟翼开度比 → 吹飞表速）的二维表。VoidMei 反向使用：**按当前表速在表内线性插值，求当前速度下允许的最大襟翼开度**——这就是 MiniHUD 襟翼条上的极限开度线，精准到个位。

细节：放襟翼与收襟翼取不同的插值区间沿（放的过程用更保守的边界）；表尾固定补一个 `(125%, 0 km/h)` 锚点保证低速端闭合；无多点表的机型回退到单值/两点模板。

## 可变后掠翼插值

可变翼机型（F-14、Su-17/22 等）的 FM 为每个后掠档位存一套气动数据：解体表速 $VNE$、解体马赫 $MNE$、临界攻角。读取时按当前后掠角在档位间**线性插值**：

$$
X(\lambda) = X_i + \frac{\lambda - \lambda_i}{\lambda_{i+1} - \lambda_i}\left(X_{i+1} - X_i\right)
$$

临界攻角同时做**襟翼线性插值**（无襟翼 ↔ 满襟翼按开度百分比），两条插值叠加后供攻角告警与失速计算使用。

## 真实过载极限

FM 逆向出机翼临界气动载荷 $C_{wing}$ 后，按**当前重量**换算成过载极限：

$$
N_{pos} = 1.2 \times \left(\frac{2\,C_{wing}}{g\,W} - 1\right), \qquad N_{neg} = 1.2 \times \left(\frac{2\,C_{wing}^{neg}}{g\,W} + 1\right)
$$

系数 1.2 是补回战雷在"游戏内过载警告"之外预留的 20% 结构余量——所以[过载告警](features/voice.md)响才是真的接近断了，不响一定不会断。油量消耗使 $W$ 减小，极限随之实时升高。

## 引擎耐热时

FM 为活塞引擎存了一组温度档 `Load0..N`，每档含水温/油温阈值、可工作时间 `WorkTime` 与恢复时间 `RecoverTime`。VoidMei 对每个档位维护一个**剩余毫秒数**，随轮询周期（约 80 ms 一拍）演化：

- 当前水温/油温 **达到**该档阈值 → 剩余时间每拍递减
- 温度**回落**到该档以下 → 剩余时间按 $\tfrac{WorkTime}{RecoverTime}$ 比率逐拍恢复
- 水温与油温两套独立累计

$$
\text{耐热时} = \min_{\text{所有档位}} \text{剩余时间}
$$

所以它不是查表读数，而是对热史积分的仿真：搓几下油门跳跃温度区间会有偏差，稳定状态无误差。引擎关闭且温度降回无限档时全部恢复。

## 活塞功率模型

功率曲线计算移植自开源项目 wt-aircraft-performance-calculator（对战雷实际飞行模型 95% 以上机型精度 ±1%）。给定高度与速度，输出考虑以下因素的轴功率：

- **增压器临界高度**：临界高度以下维持额定进气压，以上功率随环境气压比例下降
- **扭矩曲线**：倒抛物线 $\tau(rpm) = -rpm^2 + 2b \cdot rpm$，峰值扭矩在 75% 最大转速——WEP 转速提升带来的功率比由此积分求出
- **增压器转速效应**：机械增压随转速提升的非线性增压增益 $\left(1 + \Delta\right)^{1+\omega^2}$
- **冲压效应**：按[等效高度](#大气模型isa)代入，高速时"免费增压"
- **多级增压选档**：每个增压档各自算出当前高度/速度下的功率，取最大者——这就是[增压器档位](features/algorithms.md#增压器不掉档)提示的最优档数据源（油门低于 100% 时不做档位判断）

引擎参数（各档临界高度、增压比、WEP 转速等）全部由 `FMPowerExtractor` 从 FM 文件提取，不硬编码。

## SEP（剩余功率）

首先由能量增量等于动能增量与重力势能增量得到：

$$
\Delta E = \Delta E_k + \Delta E_p
$$

$$
\Delta E_k = \frac{m(v_2^2 - v_1^2)}{2} \Rightarrow \frac{m(v_2 + v_1)(v_2 - v_1)}{2}
$$

$$
\Delta E_p = mg(h_2 - h_1)
$$

其中 $v_2, v_1$ 与 $h_2, h_1$ 分别表示两次时间间隔的速度与高度。

SEP 以 m/s 表示时，把能量增量全部转换成重力势能的高度增加量形式：

$$
SEP_{m/s} = \frac{\Delta E}{\Delta t \cdot mg} \Rightarrow \left(\frac{m(v_2 + v_1)(v_2 - v_1)}{2\Delta t} + \cfrac{mg(h_2 - h_1)}{\Delta t}\right) \bigg/ mg
$$

代入加速度 $a = (v_2 - v_1)/\Delta t$ 与爬升率表读数 $v_y = (h_2 - h_1)/\Delta t$，得到最终式：

$$
SEP_{m/s} = \frac{a(v_2 + v_1)}{2g} + v_y
$$

**稳定性处理**：两次间隔的速度差用 1 秒简单滑动平均计算，提升加速度与 SEP 的精确性与稳定性；针对只能用真空速计算加速度、精度不足的机型，将 IAS 变化率加入计算（v1.20 起），消除 SEP 显示不稳定的问题。

## 转弯加速度计算

转弯加速度 $a$ 等于法向过载矢量减去重力矢量。法向过载矢量等于法向过载 $N_y$ 绕 x 轴旋转横滚角 $\alpha$、绕 y 轴旋转俯仰角 $\beta$，即乘以两个旋转矩阵：

$$
a = \left[ \begin{matrix} 0 & 0 & N_y \end{matrix} \right]
\left[ \begin{matrix} 1 & 0 & 0 \\ 0 & \cos\alpha & -\sin\alpha \\ 0 & \sin\alpha & \cos\alpha \end{matrix} \right]
\left[ \begin{matrix} \cos\beta & 0 & \sin\beta \\ 0 & 1 & 0 \\ -\sin\beta & 0 & \cos\beta \end{matrix} \right] -
\left[ \begin{matrix} 0 & 0 & 1 \end{matrix} \right]
$$

$$
\Rightarrow a = \left[ \begin{matrix} -N_y\cos\alpha\sin\beta & N_y\sin\alpha & N_y\cos\alpha\cos\beta \end{matrix} \right]
$$

化简后求其大小得：

$$
|a| = g \sqrt{N_y^2 + 1 - 2N_y\cos\alpha\cos\beta}
$$

**注意**：

- 这种方式**不计入侧滑**产生的转弯加速度
- 在某些没有地平仪的机型上直接使用 $N_y$ 作为转弯加速度
- 转弯半径与转弯率由该加速度与空速实时反推，同样用滑动平均平滑

## 插值与平滑总表

全项目"哪些量来自插值、怎么插"的一览：

| 量 | 来源 | 方法 |
|----|------|------|
| 解体表速/马赫、临界攻角（可变翼） | FM 各后掠档 | 后掠角线性插值 |
| 临界攻角（襟翼） | FM 无襟翼/满襟翼两构型 | 开度百分比线性插值 |
| 失速速度（襟翼） | 同上两构型的升力面积因数 | 开度百分比线性混合 |
| 智能襟翼极限开度 | FM 襟翼吹飞速度表 | 表内按表速线性插值（收/放取不同沿） |
| SEP、转弯半径/率 | 遥测时序 | 1 秒滑动平均 |
| 耐热时 | FM 温度档 | 逐拍递减/按比率恢复的积分仿真 |

## 致谢

- 感谢大佬**隐居寒天**指出转弯过载、转弯率以及 SEP 计算中存在的问题
- 感谢大佬 **Zetta** 建议使用滑动平均处理数据计算误差和跳变
