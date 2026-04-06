# GravityRush — Agent 指引文档

## 游戏简介

**GravityRush** 是一款以**重力操控**与**时间回溯**为核心机制的解谜探索游戏。

整个游戏世界是一个密闭的巨型箱子（The Box），由数十个相互毗邻的区域（Zone）构成。玩家从箱子内部醒来，最终目标是找到并逃离这个箱子。

玩家通过主动切换重力方向（乃至强度）在箱子中穿行——将重力指向右侧，角色即向右"坠落"；反转重力，角色便落向天花板。时间回溯机制则为玩家提供容错与策略空间，允许修正操作、构建因果链。两种能力的深度耦合，形成独特的"空间-时间谜题"。

> 详细游戏设计请参阅 `Documents/GameDesign/` 目录下的各章节 GDD 文档；代码实现设计请参阅 `Documents/ImplementDesign/` 目录。

---

## 技术栈

- **引擎**：[Godot Engine](https://godotengine.org/)（GDScript为优先编程语言）

所有**游戏设计**文档存放于 `Documents/GameDesign/`；所有**代码实现设计**文档存放于 `Documents/ImplementDesign/`。每份文档都需提供说明文档以及 PlantUML 格式的图示。

---

## 目录结构

```text
GravityRush/
├── AGENTS.md                        # 本文件：Agent 行为指引
├── run.sh                           # 快捷启动脚本（macOS）
├── Documents/                       # 所有设计文档根目录
│   ├── GameDesign/                  # 游戏设计文档（GDD）
│   │   ├── GDD_01_Overview.md           # 游戏概述与核心循环
│   │   ├── GDD_02_GravitySystem.md      # 重力系统设计
│   │   ├── GDD_03_TimeSystem.md         # 时间系统设计
│   │   ├── GDD_04_Synergy.md            # 重力与时间的协同机制
│   │   ├── GDD_05_WorldStructure.md     # 世界结构与区域设计
│   │   ├── GDD_06_Numerics.md           # 数值设计
│   │   └── GameDesignDocument_CoreMechanics.md  # 核心机制总览
│   └── ImplementDesign/             # 代码实现设计文档
├── Game/                            # Godot 项目根目录
│   ├── project.godot                # Godot 项目配置文件
│   ├── Scripts/                     # 游戏脚本（GDScript）
│   │   └── Bootstrap.gd             # Autoload 单例：启动日志
│   ├── Scenes/                      # 场景文件
│   │   └── Main.tscn                # 主场景
│   └── Resources/                   # 游戏资源（美术、音效等）
└── Engine/                          # 引擎相关配置或插件
    └── Godot.app                    # Godot 引擎（macOS）
```

---

## Agent 行为准则

### 1. 先读文档，再动手

在进行任何**设计讨论**或**功能实现**之前，必须优先阅读 `Documents/GameDesign/` 目录下与当前任务相关的 GDD 文档，确保对设计意图有准确理解。

- 涉及重力机制 → 读 `Documents/GameDesign/GDD_02_GravitySystem.md`
- 涉及时间机制 → 读 `Documents/GameDesign/GDD_03_TimeSystem.md`
- 涉及两者协同 → 读 `Documents/GameDesign/GDD_04_Synergy.md`
- 涉及世界/区域结构 → 读 `Documents/GameDesign/GDD_05_WorldStructure.md`
- 涉及数值平衡 → 读 `Documents/GameDesign/GDD_06_Numerics.md`
- 不确定范围时 → 先读 `Documents/GameDesign/GDD_01_Overview.md` 和 `Documents/GameDesign/GameDesignDocument_CoreMechanics.md` 建立全局认知
- 涉及代码实现方案 → 读 `Documents/ImplementDesign/` 下对应的实现设计文档

> **路径约定**：所有 GDScript 脚本均应放置于 `Game/Scripts/`；所有场景文件均应放置于 `Game/Scenes/`；所有游戏资源均应放置于 `Game/Resources/`。

### 2. 发现设计冲突时，立即暂停并提醒用户

如果在实现过程中，发现**需求描述**与 **GDD 文档中的设计内容存在矛盾或不一致**，必须：

1. **立即停止实现**，不得擅自选边或做出假设。
2. **明确指出冲突点**：说明需求的具体内容 vs. GDD 中的对应描述。
3. **等待用户裁决**，由用户决定是修改需求、还是更新 GDD，然后再继续。

> ⚠️ 不允许在未获得用户确认的情况下，以"实现方便"为由绕过或忽略已有的设计文档。

### 3. 设计/实现发生变更，需要同步更新相关的说明文档

1. 在完成游戏设计/代码实现的修改后，应该立即启动文档一致性检查。若存在新增/修改的情况，应该立即提示用户
