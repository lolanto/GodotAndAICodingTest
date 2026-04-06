## ADDED Requirements

### Requirement: SkillTestLab 场景提供封闭测试环境

系统 SHALL 在 `Game/Scenes/SkillTestLab.tscn` 创建技能测试场景，包含四面封闭边界（4 个 `StaticBody2D` + `CollisionShape2D`），确保玩家在任意重力方向下不会飞出场景。场景 SHALL 包含若干不同高度的静态平台（`StaticBody2D`）、Player 实例（置于场景中心初始位置）、静态可交互物体（至少 1 个木箱，继承 `RigidBody2D`，参与时间回溯）、HUD CanvasLayer 和调试面板。

#### Scenario: 所有重力方向下玩家不飞出

- **WHEN** `GravityManager.direction` 被设置为 `Vector2.UP`、`Vector2.DOWN`、`Vector2.LEFT`、`Vector2.RIGHT` 的任一方向
- **THEN** 玩家 SHALL 在有限时间内被边界挡住，不离开场景可视区域

#### Scenario: 场景启动后系统全部就绪

- **WHEN** SkillTestLab.tscn 被加载并运行
- **THEN** GravityManager、TimeManager、Player 节点 SHALL 全部完成初始化，无断言错误或脚本报错

---

### Requirement: HUD 实时显示核心系统状态

HUD `CanvasLayer` SHALL 包含以下显示元素，每帧更新：
- GE 条：当前值 / 上限（数值 + 进度条）
- CE 条：当前值 / 上限（数值 + 进度条）
- 时间流速：`×{time_scale}` 格式，保留 1 位小数
- 当前重力向量：显示 `GravityManager.direction` 和 `GravityManager.magnitude`，如 `↓ ×1.0`
- 回溯状态指示：回溯进行中时显示醒目提示（如画面泛蓝色滤镜或文字标记）

#### Scenario: HUD 反映 time_scale 变化

- **WHEN** `TimeManager.time_scale` 变为 0.5（慢动作）
- **THEN** HUD 时间流速显示 SHALL 更新为 `×0.5`，在下一渲染帧可见

#### Scenario: 回溯进行中时 HUD 显示回溯指示

- **WHEN** `TimeManager.is_rewinding == true`
- **THEN** HUD SHALL 显示回溯状态标识（蓝色滤镜或文字），玩家可直观感知正处于回溯状态

---

### Requirement: 调试面板显示内部数值

场景 SHALL 包含一个 `Label` 或 `VBoxContainer` 调试面板，显示以下开发期调试信息（每帧更新）：
- GE 精确数值与上限
- CE 精确数值与上限
- `time_scale` 精确值
- 当前重力向量（`direction` 和 `magnitude` 各自精确值）
- `is_rewinding` 状态
- `in_rewind_free_zone` 状态
- Ring Buffer 有效帧数（`_valid_frame_count`）

#### Scenario: 调试面板可在编辑器中关闭

- **WHEN** 发布正式版本或需要截图时
- **THEN** 调试面板节点 SHALL 可通过在编辑器中设置 `visible = false` 隐藏，不影响其他游戏功能

---

### Requirement: 测试场景满足 P0 最小可测试集

SkillTestLab.tscn SHALL 满足以下 P0 前置条件，使所有核心技能可在此场景中触发并验证：
- GravityManager 运行，玩家能感知重力方向/强度变化
- TimeManager 运行，慢动作/加速/回溯可触发（受 CE 约束）
- Player 有基础移动（MovementComponent + GravityReceiverComponent）
- 玩家可通过输入触发重力技能（至少方向切换 + LGF 放置）
- 玩家可通过输入触发时间技能（至少回溯 + 慢动作）
- 场景内含至少 1 个参与回溯的静态可交互物体

#### Scenario: 回溯验证——木箱位置还原

- **WHEN** 玩家将木箱推动后触发时间回溯
- **THEN** 回溯结束后木箱 `global_position` SHALL 恢复为回溯目标时刻快照中记录的位置

#### Scenario: 全局重力切换可立即感知

- **WHEN** 玩家按下全局重力切换输入（方向翻转）
- **THEN** `GravityManager.direction` 瞬间改变，玩家在下一物理帧起开始向新方向"坠落"
