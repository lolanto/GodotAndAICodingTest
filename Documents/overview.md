# Documents — 索引文档

本目录包含 **GravityRush** 项目的所有设计与实现文档，分为两个子目录：

| 目录 | 用途 |
| --- | --- |
| [`GameDesign/`](GameDesign/) | 游戏设计文档（GDD） |
| [`ImplementDesign/`](ImplementDesign/) | 代码实现设计文档 |

---

## GameDesign — 游戏设计文档

| 文件 | 章节 | 内容简述 |
| ---- | ---- | -------- |
| [GameDesignDocument_CoreMechanics.md](GameDesign/GameDesignDocument_CoreMechanics.md) | 核心玩法策划案 | 重力 × 时间双核机制设计总览，是阅读各章节 GDD 的入口 |
| [GDD_01_Overview.md](GameDesign/GDD_01_Overview.md) | 第1章：游戏概述 | 世界观（The Box）、核心循环、设计愿景、操控哲学 |
| [GDD_02_GravitySystem.md](GameDesign/GDD_02_GravitySystem.md) | 第2章：重力系统 | 重力方向切换、强度调节、能量消耗规则 |
| [GDD_03_TimeSystem.md](GameDesign/GDD_03_TimeSystem.md) | 第3章：时间系统 | 时间回溯机制、时间流速控制、能量管理 |
| [GDD_04_Synergy.md](GameDesign/GDD_04_Synergy.md) | 第4章：重力 × 时间联动 | 两种能力的协同规则、空间-时间谜题设计范式 |
| [GDD_05_WorldStructure.md](GameDesign/GDD_05_WorldStructure.md) | 第5章：世界结构 | 区域图（Zone Graph）、关卡布局与通路设计 |
| [GDD_06_Numerics.md](GameDesign/GDD_06_Numerics.md) | 第6章：数值框架 | 能量系统基准值、升级曲线、平衡性参考数据 |

---

## ImplementDesign — 代码实现设计文档

> 当前目录为空，待后续代码设计文档陆续补充。

每份实现设计文档均应包含：

- 功能说明（Markdown）
- 架构 / 流程图（PlantUML 格式）
