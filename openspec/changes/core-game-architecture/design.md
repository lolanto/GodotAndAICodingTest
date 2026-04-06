# Design: core-game-architecture

> 对应 Proposal: `core-game-architecture`
> 状态：**所有开放问题已确认（Q1-Q7 ✅）**，可推进实现阶段

---

## 1. 整体架构概览

### 1.1 架构模式

采用 **Entity-Component（EC）** 模式，以 Godot 的**子节点**作为 Component 的天然载体：

- **Entity**：场景中有语义的主体节点（Player、Enemy、Mechanism 等），通常是 `CharacterBody2D` 或 `Node2D`
- **Component**：挂在 Entity 下的子节点，各自封装单一职责，可独立测试

```
Player (CharacterBody2D)            ← Entity
├── MovementComponent (Node)        ← 速度/位置物理步
├── GravityReceiverComponent (Node) ← 感知并缓存当前受力向量
├── PlayerInputComponent (Node)     ← 输入映射，产生 InputEvent
├── GravitySkillComponent (Node)    ← 切换全局重力 & 管理 LGF 列表
├── TimeSkillComponent (Node)       ← 触发回溯/慢动作/加速/LCF
└── HealthComponent (Node)          ← 血量（参与回溯）
```

### 1.2 Autoload 清单

| 单例 | 职责 | 文件路径 |
|------|------|----------|
| `Bootstrap` | 启动日志（已有） | `Scripts/Bootstrap.gd` |
| `GravityManager` | 全局重力状态机 + GE 资源（**RewindableSystem**） | `Scripts/Autoloads/GravityManager.gd` |
| `TimeManager` | 时间流速 + CE 资源 + 帧快照调度 | `Scripts/Autoloads/TimeManager.gd` |
| `ZoneManager` | 区域子场景的加载/卸载调度 | `Scripts/Autoloads/ZoneManager.gd` |

> Autoload 是全局唯一入口，Component 通过 Autoload 名称直接访问（Godot 自动注入到场景树根）。

### 1.3 IRewindable 参与者分类

TimeManager 管理所有实现了 `IRewindable` 协议的注册者，分为两类：

| 类型 | 定义 | 典型示例 |
|------|------|----------|
| **RewindableComponent** | 挂载在场景树中的子节点 Component | `MovementComponent`, `GravitySkillComponent` |
| **RewindableSystem** | 实现快照接口的 Autoload 单例 | `GravityManager` |

两类注册者对 TimeManager 完全透明——统一通过 `capture_snapshot` / `apply_snapshot` 接口调度，TimeManager 无需感知注册者的具体类型。

```gdscript
# IRewindable 协议（GDScript 约定，非强制接口）
# rewind_id 是协议的一等公民字段，非可选调试附属
var rewind_id: String          # 全局唯一，命名规范：sys/<name>, player/<name>, zone_<id>/<name>

func capture_snapshot() -> Dictionary: pass
func apply_snapshot(snapshot: Dictionary) -> void: pass
```

---

## 2. 主循环设计

每个物理帧（`_physics_process`）的执行顺序：

```
_physics_process(delta)
│
├─ 1. TimeManager.pre_tick(delta)
│      ├─ 计算 effective_delta = delta × time_scale
│      └─ 如果 is_rewinding:
│           从 Ring Buffer 取出上一帧快照
│           分发给所有注册 Component（apply_snapshot）
│           return（跳过后续所有步骤）
│
├─ 2. GravityManager.tick(effective_delta)
│      ├─ 应用联动效果：
│      │    引力时间膨胀 → 修正 TimeManager.time_scale
│      │    零重力时间失锚 → 若 CE 当前无消耗，触发 3× CE 回复加成
│      ├─ 维持所有活跃 LGF，扣除 GE
│      └─ 若当前无 GE 消耗（无活跃 LGF），回复 GE（自然回复速率）
│           ↑ 消耗与恢复互斥：同一帧内只执行其一
│
├─ 3. 各 Entity 的 Component physics_step(effective_delta)
│      ├─ MovementComponent: 查询 GravityManager → 计算速度 → move_and_slide
│      ├─ 敌人 AI Component: 更新行为
│      └─ Mechanism Component: 检测触发条件、执行机关逻辑
│
└─ 4. TimeManager.post_tick()
       遍历所有注册 Component → capture_snapshot()
       将本帧快照压入 Ring Buffer
```

**关键约定**：
- `effective_delta` 由 TimeManager 计算并分发，所有 Component 只使用 `effective_delta`，不直接使用 `delta`
- 联动修正（引力时间膨胀）在步骤 2 中写入 `TimeManager.time_scale`，供下一帧步骤 1 使用（单帧延迟，可接受）

---

## 3. 核心系统设计

### 3.1 GravityManager

**职责**：
- 持有全局重力状态：`direction: Vector2`（瞬时切换），`magnitude: float`（插值过渡，0×~3×）
- 管理 GE 资源（上限 100，自然回复 8/秒）
- 持有 LGF 注册表（`_lgf_registry: Array[LGFNode]`），供重力计算使用
- 提供接口：`get_gravity_at(pos: Vector2) -> Vector2`（遍历注册表，后置优先叠加）
- 提供接口：`register_lgf(node: LGFNode)`、`unregister_lgf(node: LGFNode)`
- 发射信号：`gravity_direction_changed`、`magnitude_changed`

**重力过渡行为**（来自 GDD §2.1.1、§2.3）：

| 属性 | 过渡方式 | 原理 |
|------|----------|------|
| `direction` | **瞬间切换** | 方向值即时生效；物体靠原有速度惯性自然过渡（MovementComponent 保留速度分量） |
| `magnitude` | **0.2s 线性插值** | 避免强度突变导致穿模；`magnitude` 是当前物理生效值，始终向 `_target_magnitude` 插值靠拢 |

```gdscript
# GravityManager 强度相关字段
var magnitude: float          # 当前物理生效值（插值中间值，物理层使用此值）
var _target_magnitude: float  # 玩家设定的目标强度
var _mag_interp_t: float      # 插值进度 0.0 ~ 1.0

# tick() 中的强度插值
const MAG_INTERP_DURATION := 0.2   # 秒
func _update_magnitude(effective_delta: float) -> void:
    if magnitude != _target_magnitude:
        _mag_interp_t = min(_mag_interp_t + effective_delta / MAG_INTERP_DURATION, 1.0)
        magnitude = lerp(magnitude, _target_magnitude, _mag_interp_t)
        if _mag_interp_t >= 1.0:
            magnitude = _target_magnitude   # 消除浮点误差
```

**GE 消耗规则**（来自 GDD §6）：
- 全局方向切换：单次扣费（待定具体值）+ 1.5 秒冷却
- LGF 维持：持续扣费 / 秒 / 个
- LGF 放置/移除：0.3 秒冷却 / 个

**GE 消耗与恢复互斥**：每帧只执行其一，代码如下：

```gdscript
# GravityManager.tick()
func tick(effective_delta: float) -> void:
    # ... 联动效果、LGF 维持 ...
    var ge_drain: float = 0.0
    for lgf in _lgf_registry:
        if lgf.active and lgf.source == "player_skill":
            ge_drain += LGF_DRAIN_PER_SEC   # 待定具体值

    if ge_drain > 0.0:
        ge = max(ge - ge_drain * effective_delta, 0.0)
    else:
        ge = min(ge + GE_RECOVERY_RATE * effective_delta, ge_max)
```

**✅ Q7 — LGF 的归属方（已确认）**

> **决策**：LGF 作为独立节点类型 `LGFNode`（`Area2D`），自行向 GravityManager 注册/注销。LGF 存在两种来源，架构统一处理：

**两种来源对比**：

| 属性 | 场景机制 LGF | 玩家技能 LGF |
|------|------------|------------|
| 放置方 | 关卡设计师（静态场景节点） | 玩家运行时释放 |
| 节点存在方式 | 始终在场景树中 | 预分配对象池（**6 个槽位**，含升级后上限），始终在场景树中 |
| active 变化来源 | 关卡机关触发（开关、计时器等） | 玩家技能释放 / 到期 / 手动移除 |
| 数量上限 | 无限制 | 默认解锁 3 个，升级后最多 6 个（由 CD + 存续时间约束） |
| 参与时间回溯 | ✅（active 状态会变化，需还原） | ✅ |

**LGFNode 结构**：

```gdscript
# LGFNode (Area2D) — RewindableComponent
var direction: Vector2
var magnitude: float
var blend_factor: float        # 0 = 完全覆盖全局重力
var source: String             # "scene" | "player_skill"
var active: bool               # 是否当前生效（参与快照，随回溯还原）
var unlocked: bool             # 槽位是否已解锁（持久状态，不参与快照，不随回溯还原）
var remaining_time: float      # 剩余时长；scene 类型填 -1.0（外部控制）
var placement_order: int       # 全局单调递增，决定后置优先级；scene 类型固定为 0

func _ready():
    GravityManager.register_lgf(self)

func _exit_tree():
    GravityManager.unregister_lgf(self)

func capture_snapshot() -> Dictionary:
    # unlocked 不纳入快照：它是存档层的持久数据，不受时间回溯影响
    return {
        "active":          active,
        "direction":       direction,
        "magnitude":       magnitude,
        "blend_factor":    blend_factor,
        "remaining_time":  remaining_time,
        "placement_order": placement_order   # 回溯后恢复优先级排序
    }

func apply_snapshot(s: Dictionary) -> void:
    active          = s["active"]
    direction       = s["direction"]
    magnitude       = s["magnitude"]
    blend_factor    = s["blend_factor"]
    remaining_time  = s["remaining_time"]
    placement_order = s["placement_order"]
    # unlocked 不在快照中，保持当前持久值不变
```

**`get_gravity_at()` 优先级规则**（后置优先）：

```gdscript
# GravityManager
func get_gravity_at(pos: Vector2) -> Vector2:
    var hits = _lgf_registry.filter(func(n): return n.active and n.overlaps_point(pos))
    if hits.is_empty():
        return direction * magnitude
    # placement_order 越大 = 越晚放置 = 优先级越高
    hits.sort_custom(func(a, b): return a.placement_order > b.placement_order)
    var top = hits[0]
    return lerp(top.direction * top.magnitude, direction * magnitude, top.blend_factor)
```

**玩家技能 LGF 预分配对象池**（由 GravitySkillComponent 管理）：

> **✅ 升级方案确认（方案 A）**：预分配全部 6 个槽位（GDD 上限），游戏初始 Slot0~2 解锁，Slot3~5 锁定。升级时只翻转 `unlocked` flag，不增删节点，彻底规避 Q5。

```
Player
└── GravitySkillComponent
      ├── LGFNode_Slot0  (source="player_skill", unlocked=true,  active=false)  ← 初始可用
      ├── LGFNode_Slot1  (source="player_skill", unlocked=true,  active=false)
      ├── LGFNode_Slot2  (source="player_skill", unlocked=true,  active=false)
      ├── LGFNode_Slot3  (source="player_skill", unlocked=false, active=false)  ← 升级后解锁
      ├── LGFNode_Slot4  (source="player_skill", unlocked=false, active=false)
      └── LGFNode_Slot5  (source="player_skill", unlocked=false, active=false)
```

- "放置 LGF" = 从 `unlocked=true && active=false` 的槽位中取一个，赋予 `placement_order`，配置参数后激活
- "移除 LGF" = 将槽位设为 `active=false`（归还池；`unlocked` 不变）
- "升级 LGF 上限" = 在 Rest Station 中将下一个 `unlocked=false` 的槽位设为 `unlocked=true`
- 6 个槽位始终在场景树中 → 始终注册于 TimeManager → **彻底规避 Q5（动态存在性问题）**
- `unlocked=false` 的槽位虽注册于 TimeManager，但 `active` 恒为 `false`，对 `get_gravity_at()` 和游戏逻辑无影响

**边界情况：回溯周期内槽位被回收复用**

若回溯时间窗口内某槽先到期再被新 LGF 复用（始终保持 3 个激活），帧快照仍正确处理：

```
Ring Buffer 关键帧示意：
  T=2.9s : Slot0={active=true,  LGF-A params, order=1}
  T=3.0s : Slot0={active=false, ...}
  T=3.1s : Slot0={active=true,  LGF-D params, order=4}  ← 同一槽，不同LGF

回溯时 Slot0 状态序列（反向）：
  LGF-D(active) → inactive → LGF-A(active)
```

`placement_order` 随快照一起还原，确保 `get_gravity_at()` 的后置优先顺序在回溯后完全准确。

**GravitySkillComponent 快照内容**：

```gdscript
func capture_snapshot() -> Dictionary:
    # unlocked_count 不纳入快照：升级是持久进度，不随回溯还原
    return {
        "active_count":         active_count,
        "next_placement_order": _next_order  # 回溯后新放置的LGF可正确延续计数
    }
```

---

**✅ Q1 — GravityManager 的快照归属（已确认）**

> **决策**：采用路线 A。GravityManager 作为 **RewindableSystem** 实现 `IRewindable` 协议，在 `_ready()` 中向 TimeManager 注册。

**快照内容**：

```gdscript
# GravityManager.capture_snapshot()
return {
    "direction":           direction,
    "magnitude":           magnitude,           # 当前物理生效值（含插值进度）
    "target_magnitude":    _target_magnitude,   # 插值目标值
    "mag_interp_t":        _mag_interp_t,       # 插值进度（回溯后从完全一致的状态继续）
    "ge":                  ge,
    "zero_g_timer":        _zero_g_timer,
    "zero_g_bonus_active": _zero_g_bonus_active
}
```

> **GE 回溯决策**：GE 随重力状态一同被回溯。若玩家切换重力（消耗 GE）后回溯，重力方向已还原，GE 若不还原则产生"状态回退但资源永久扣除"的体验矛盾。

**零重力计时器设计**：

```gdscript
# GravityManager 新增字段
var _zero_g_timer: float = 0.0        # 零重力累积游戏时间（必须纳入快照，否则回溯后计时泄漏）
var _zero_g_bonus_active: bool = false # 供 TimeManager._tick_ce() 直接读取

func tick(effective_delta: float) -> void:
    # ...联动效果、LGF 维持、GE 消耗/回复...
    if magnitude == 0.0:
        _zero_g_timer += effective_delta
        _zero_g_bonus_active = (_zero_g_timer >= 3.0)
    else:
        _zero_g_timer = 0.0
        _zero_g_bonus_active = false

func apply_snapshot(s: Dictionary) -> void:
    direction            = s["direction"]
    magnitude            = s["magnitude"]
    _target_magnitude    = s["target_magnitude"]
    _mag_interp_t        = s["mag_interp_t"]
    ge                   = s["ge"]
    _zero_g_timer        = s["zero_g_timer"]
    _zero_g_bonus_active = s["zero_g_bonus_active"]
```

> **计时维度**：使用 `effective_delta`（游戏时间），与所有其他游戏逻辑保持一致。慢动作下零重力计时同步放慢，符合预期。

> **与 CE 恢复互斥的联动**：`_zero_g_bonus_active` 在 `TimeManager._tick_ce()` 的**恢复分支**（`ce_drain == 0`）中读取，因此玩家在零重力下使用任意时间技能（time_scale=2.0 / 慢动作 / 回溯 / LCF）时，CE 走消耗分支，3× 加成**不触发**。无需额外逻辑，互斥规则自然保证。

---

### 3.2 TimeManager

**职责**：
- 持有 `time_scale: float`（当前时间流速倍数，默认 1.0）
- 持有 `_is_slow_motion: bool` / `_is_time_rush: bool`（离散状态标志，供 GravitySkillComponent 等读取精度模式，避免浮点比较）
- 管理 CE 资源（上限 100，自然回复 5/秒）；**CE 不参与快照，不随回溯还原**
- 维护帧快照 Ring Buffer
- 调度回溯：`is_rewinding` 标志 + 分发快照
- 管理 `in_rewind_free_zone` 状态（失效区域标志）

**关键常量**：

```gdscript
const REWIND_SPEED: float    = 2.0   # 回溯倍率：2 游戏秒 / 真实秒（8s历史 → 4s看完）
const MIN_TIME_SCALE: float  = 0.5   # 全局 time_scale 下限（慢动作最低 0.5×）
const MAX_REWIND_GAME_SEC: float = 10.0  # 最大可回溯游戏时间（升级上限）；默认 5.0s
const MAX_FRAMES: int        = 1200  # 60fps × 20真实秒；保证 0.5× 慢动作下仍覆盖 10s 游戏历史
```

> **数值自洽验证**：`1200 帧 / 60fps × 0.5（MIN_TIME_SCALE）= 10.0 游戏秒` ← 恰好覆盖升级后上限。

**帧快照 Ring Buffer**：

```
MAX_FRAMES = 1200            # 见上方常量
_buffer: Array               # 环形数组，固定大小
_write_head: int             # 当前写入位置
_rewind_cursor: int          # 回溯时的读取游标
_valid_frame_count: int      # 当前 Buffer 中有效帧数（进入失效区域后归零）

每帧 snapshot 结构：
{
  "game_time": float,          # 累积游戏时间戳（effective_delta 之和，非真实时间）
  "snapshots": {
    <rewind_id: String>: <snapshot_data>   # rewind_id 为字典键（见 Q3）
  }
}
```

**失效区域（Rewind-Free Zone）接口**：

```gdscript
var in_rewind_free_zone: bool = false

func enter_rewind_free_zone() -> void:
    in_rewind_free_zone = true
    is_rewinding = false          # 强制中断任何正在进行的回溯
    _cancel_active_time_effects() # 取消慢动作 / 加速（time_scale → 1.0）
    _clear_buffer()               # 清空全部历史帧
    ce = ce_max                   # CE 回满（Rest Station 入场奖励，见 GDD §5.8.3）

func exit_rewind_free_zone() -> void:
    in_rewind_free_zone = false
    # Ring Buffer 从当前帧起重新积累，_valid_frame_count 已归零

func _clear_buffer() -> void:
    _buffer.fill(null)
    _write_head = 0
    _rewind_cursor = 0
    _valid_frame_count = 0
```

`post_tick()` 在失效区域内跳过快照积累：

```gdscript
func post_tick() -> void:
    if in_rewind_free_zone:
        return   # 失效区域内不积累历史帧
    var frame = {"game_time": _game_time, "snapshots": {}}
    for registrant in _registry:
        frame["snapshots"][registrant.rewind_id] = registrant.capture_snapshot()
    _buffer[_write_head] = frame
    _write_head = (_write_head + 1) % MAX_FRAMES
    _valid_frame_count = min(_valid_frame_count + 1, MAX_FRAMES)
```

`pre_tick()` — 回溯调度（游戏时间步进）：

```gdscript
func pre_tick(delta: float) -> void:
    effective_delta = delta * time_scale
    if is_rewinding:
        if in_rewind_free_zone or _valid_frame_count == 0:
            is_rewinding = false   # 无历史帧可用，强制终止
            return

        # 本 tick 目标：消耗 REWIND_SPEED × delta 的游戏时间历史
        # 游标以 game_time 差步进，确保"2× 游戏时间/真实秒"的回放速率
        var game_time_budget: float = REWIND_SPEED * delta

        while game_time_budget > 0.0 and _valid_frame_count > 0:
            var cur      = _buffer[_rewind_cursor]
            var prev_idx = (_rewind_cursor - 1 + MAX_FRAMES) % MAX_FRAMES
            var prev     = _buffer[prev_idx]
            if prev == null:
                break
            var frame_dt: float = cur["game_time"] - prev["game_time"]
            game_time_budget -= frame_dt
            _rewind_cursor   = prev_idx
            _valid_frame_count -= 1

        _apply_rewind_frame(_buffer[_rewind_cursor])
        return
```

**CE 消耗规则**：所有消耗速率均以**真实时间**计，与 `time_scale` 无关。

| 操作 | CE 消耗速率（真实秒） | 备注 |
|------|------------|------|
| 时间回溯 | 12 CE/秒 | 回溯触发时 time_scale 强制重置为 1.0（见下方说明） |
| 慢动作（0.5×） | 10 CE/秒 | — |
| 时间加速（2.0×） | 5 CE/秒 | — |
| LCF 维持 | 8 CE/秒 · 个 | — |

> **回溯与时间流速的互斥机制**：触发时间回溯时，所有正在进行的时间流速操控（慢动作 / 加速）**立即取消**，`time_scale` 强制重置为 1.0，再进入回溯状态。因此回溯期间不存在"Time Rush + 回溯同时生效"的状态，原有 "24 CE/秒" 的说法已废弃。

**CE 消耗与恢复互斥**：每帧只执行其一，代码如下：

```gdscript
# TimeManager — CE tick（在 post_tick() 或独立 tick 中调用，使用真实 delta）
func _tick_ce(real_delta: float) -> void:
    var ce_drain: float = 0.0
    if is_rewinding:         ce_drain += 12.0
    elif _is_slow_motion:    ce_drain += 10.0
    elif _is_time_rush:      ce_drain += 5.0
    ce_drain += _active_lcf_count * 8.0

    if ce_drain > 0.0:
        ce = max(ce - ce_drain * real_delta, 0.0)
        if ce == 0.0:
            _on_ce_exhausted()   # 强制中断所有时间操控，启动 2s 冷却
    else:
        var recovery = CE_RECOVERY_RATE   # 5 CE/秒（基础）
        if _zero_g_bonus_active:
            recovery *= 3.0               # 零重力时间失锚加成（仅在无消耗时生效）
        ce = min(ce + recovery * real_delta, ce_max)
```

> **零重力 3× CE 回复**仅在 `ce_drain == 0`（无任何时间技能消耗）时才叠加，与消耗互斥。

#### 回溯期间的行为约束

回溯进行中（`is_rewinding = true`），系统进入**纯历史回放模式**，所有游戏事件暂停产生：

```
玩家侧：
  PlayerInputComponent  → 锁定所有输入（移动 / 攻击 / 技能均不响应）
  MovementComponent     → 位置由快照直接赋值，不走物理模拟
  HealthComponent       → take_damage() 调用被忽略（拒绝新增伤害）

世界侧：
  敌人 AI               → 不运行，仅执行快照回放（apply_snapshot）
  敌人 HealthComponent  → 同样拒绝 take_damage()（防止碰撞信号误触发）
  回溯结束时            → 玩家与敌人血量均还原为回溯目标帧快照中的值
```

```gdscript
# HealthComponent.gd
func take_damage(amount: int) -> void:
    if TimeManager.is_rewinding:
        return   # 回溯期间拒绝所有伤害事件
    _hp -= amount
    emit_signal("health_changed", _hp)

# PlayerInputComponent.gd
func _unhandled_input(event: InputEvent) -> void:
    if TimeManager.is_rewinding:
        return   # 回溯期间锁定所有输入
    # ... 正常输入处理
```

> 回溯 = 玩家"在时间外观看历史"——画面泛蓝的视觉表现与此语义一致。期间既不受伤，也无法攻击，是完全隔离于游戏循环的回放状态。回溯结束时，一切（包括玩家血量）恢复到目标时刻的状态。

#### LCF 接口预留（MVP stub）

LCF（局部时间场）与 LGF 在架构上完全对称：

```
LGF（局部重力场）                         LCF（局部时间场）
───────────────────────────────────────────────────────────
GravityManager.get_gravity_at(pos) → V2   TimeManager.get_time_scale_at(pos) → float
LGFNode (Area2D)                          LCFNode (Area2D)   ← 后续迭代新增
GravityReceiverComponent                  （对应组件，后续迭代新增）
```

MVP 阶段提供 stub 实现，忽略 `world_position`，仅返回全局倍率：

```gdscript
# TimeManager.gd
var global_time_scale: float = 1.0

# MVP stub：忽略 world_position，仅返回全局倍率
# 后续引入 LCF 时，扩展此函数查询已注册的 LCFNode 列表
func get_time_scale_at(world_position: Vector2) -> float:
    return global_time_scale

func get_effective_delta(base_delta: float) -> float:
    return base_delta * global_time_scale
```

后续 LCF 实现路径（不影响当前 MVP 架构）：
1. 新增 `LCFNode (Area2D)` — 镜像 `LGFNode`，自注册到 TimeManager
2. `get_time_scale_at(pos)` 查询 LCF 栈，叠加全局倍率
3. 各移动 Component 改为调用 `get_time_scale_at(global_position)` 而非 `get_effective_delta()`

LCF 本身状态在 Ring Buffer 中，回溯时随之消失/还原；快照记录的是 position（已包含 LCF 影响），还原时无需重新计算，天然解耦。

---

### 3.3 IRewindable 接口（快照契约）

GDScript 无强制接口，以约定方式定义：

```gdscript
# 所有参与回溯的 RewindableComponent / RewindableSystem 必须实现：

var rewind_id: String          # 协议一等字段，命名规范见下方

func capture_snapshot() -> Dictionary:
    # 返回当前状态的快照字典，内容由实现方自己决定
    pass

func apply_snapshot(snapshot: Dictionary) -> void:
    # 从快照字典中恢复状态
    pass
```

**`rewind_id` 命名规范**：

| 前缀 | 适用对象 | 示例 |
|------|----------|------|
| `sys/` | Autoload 全局系统 | `sys/gravity` |
| `player/` | 玩家 Component | `player/movement`, `player/lgf-slot-0` |
| `zone_<id>/` | 区域内的场景节点 | `zone_core/time-lock-gate`, `zone_a/lgf-1` |

各注册者的快照内容参考：

| 注册者 | 类型 | capture 内容 | 参与回溯？ |
|--------|------|-------------|-----------|
| `GravityManager` | RewindableSystem | `{direction, magnitude, target_magnitude, mag_interp_t, ge, zero_g_timer, zero_g_bonus_active}` | ✅ |
| `LGFNode`（场景机制） | RewindableComponent | `{active, direction, magnitude, blend_factor, remaining_time, placement_order}` | ✅ |
| `LGFNode`（玩家技能池） | RewindableComponent | `{active, direction, magnitude, blend_factor, remaining_time, placement_order}` | ✅ |
| `MovementComponent` | RewindableComponent | `{position, velocity, rotation}` | ✅ |
| `GravityReceiverComponent` | RewindableComponent | `{effective_gravity}` | ✅ |
| `GravitySkillComponent` | RewindableComponent | `{active_count, next_placement_order}` | ✅ |
| `TimeSkillComponent` | RewindableComponent | `{active_lcf_list}` | ✅ |
| `HealthComponent` | RewindableComponent | `{hp}` | ✅ |

---

**✅ Q2 — Component 注册机制（已确认）**

> **决策**：方式 2（显式注册/注销）+ Godot Group 作为设计期标注。

```gdscript
# 所有 RewindableComponent._ready()
func _ready() -> void:
    add_to_group("rewindable")        # 设计标记：编辑器 Remote 面板可见
    TimeManager.register(self)        # 运行时注册：操作主路径

func _exit_tree() -> void:
    TimeManager.unregister(self)

# TimeManager.register()：注册时立即做接口校验
func register(node) -> void:
    assert(node.has_method("capture_snapshot"), "Missing capture_snapshot: %s" % node.name)
    assert(node.has_method("apply_snapshot"),   "Missing apply_snapshot: %s" % node.name)
    assert(node.get("rewind_id") != null,       "Missing rewind_id: %s" % node.name)
    for r in _registry:
        assert(r.rewind_id != node.rewind_id,   "Duplicate rewind_id: %s" % node.rewind_id)
    _registry.append(node)
```

> **关于直接依赖**：Component 直接调用 `TimeManager.register(self)` 产生耦合，但这是 Godot Autoload 哲学的标准用法（等同于访问 `Input`、`get_tree()` 等全局服务），耦合是单向且轻量的，在本项目规模下完全可接受。

---

**✅ Q3 — 快照键名方案（已确认）**

> **决策**：Ring Buffer 使用 `rewind_id` 字符串作为字典键；`rewind_id` 是 IRewindable 协议的一等字段。

**核心原因**：游戏世界采用动态区域加载（ZoneManager），区域卸载会导致 `_registry` 缩减，纯数组索引在此情况下会产生错位。字典键方案天然支持注册表动态变化。

```gdscript
# TimeManager.post_tick()（capture）
func post_tick() -> void:
    var frame = {"game_time": _game_time, "snapshots": {}}
    for registrant in _registry:
        frame["snapshots"][registrant.rewind_id] = registrant.capture_snapshot()
    _buffer[_write_head] = frame
    _write_head = (_write_head + 1) % MAX_FRAMES

# TimeManager.pre_tick()（apply rewind）
func _apply_rewind_frame(frame: Dictionary) -> void:
    for registrant in _registry:
        if registrant.rewind_id in frame["snapshots"]:
            registrant.apply_snapshot(frame["snapshots"][registrant.rewind_id])
        else:
            # 该注册者是在此帧之后才加载的区域节点 → 还原为初始状态
            registrant.reset_to_initial()

# 未来局部回溯（按 rewind_id 前缀筛选）
func _apply_partial_rewind(frame: Dictionary, target_ids: Array[String]) -> void:
    for registrant in _registry:
        if registrant.rewind_id in target_ids and registrant.rewind_id in frame["snapshots"]:
            registrant.apply_snapshot(frame["snapshots"][registrant.rewind_id])
```

**区域节点的初始快照**：Zone 加载后捕获一次初始状态，用于回溯到该区域加载之前的时刻：

```gdscript
# ZoneNode._ready()（在所有子节点就绪后）
func _ready() -> void:
    await get_tree().process_frame
    for child in _get_rewindable_children():
        child.initial_snapshot = child.capture_snapshot()

# RewindableComponent.reset_to_initial()
func reset_to_initial() -> void:
    if initial_snapshot:
        apply_snapshot(initial_snapshot)
```

---

### 3.4 Player Entity 结构

```
Player (CharacterBody2D)
│  export var move_speed: float = 200.0
│
├── MovementComponent
│     capture: {position, velocity}
│     apply:   position = s.position; velocity = s.velocity
│
├── GravityReceiverComponent
│     每帧调用 GravityManager.get_gravity_at(global_position)
│     缓存结果供 MovementComponent 使用
│     capture: {cached_gravity}
│
├── PlayerInputComponent
│     不参与快照（输入是实时的，不需要回溯）
│
├── GravitySkillComponent
│     管理玩家技能 LGF 预分配对象池（6 个 LGFNode 子节点，各自独立注册 TimeManager）
│     GE 读取自 GravityManager（不持有副本，不参与 GE 快照）
│     capture: {active_count, next_placement_order}
│
│     ⏳ 慢动作精度增益（设计已定，实现待关卡格子尺寸确定后补全）：
│       place_lgf()      → 慢动作时像素对齐；正常时格子对齐（GRID_SNAP 待定）
│       adjust_magnitude() → 慢动作时步进 0.05×；正常时 0.25×
│       精度状态来源：TimeManager._is_slow_motion（离散 bool 标志，非 time_scale 浮点比较）
│
├── TimeSkillComponent
│     持有 active_lcf_list: Array[LCFData]
│     CE 由 TimeManager 持有，不参与快照（CE 是回溯能力本身的代价，不随回溯还原）
│     capture: {lcf_list 序列化}
│
└── HealthComponent
      注册到 TimeManager，血量随时间回溯还原
```

---

## 4. 开放问题

---

### Q5 — 动态生成物体的存在性快照

> **背景**：玩家可以与动态物理物体交互（木箱、铁球等）。如果一个物体在 T=3s 生成，玩家在 T=7s 回溯到 T=2s，这个物体应该消失。

**问题**：快照系统目前只记录"状态"，不记录"存在性"。

**可能的方案**：

```
方案 A：在 World/Scene 层面记录"实体存在快照"
  每帧额外记录：{spawned_entities: [id, ...], despawned_entities: [id, ...]}
  回溯时，将不应存在的实体隐藏/销毁，将应存在的实体复活

  ✅ 概念清晰
  ⚠️  销毁再复活的对象如何保留其 Component 注册？需要对象池

方案 B：动态物体一律使用对象池（Object Pool）
  所有可交互物体从池中取用，"销毁"只是归还（隐藏）
  回溯时根据快照中的"应存在列表"激活/隐藏对象

  ✅ 对象池天然解决注册问题
  ⚠️  需要额外的 SpawnManager 系统（本次 non-goal？）

方案 C：MVP 阶段：禁止测试场景中出现动态生成/销毁的物体
  测试场景中的所有交互物体在场景加载时就存在，不会动态生成
  回避此问题，等世界系统完善后再处理

  ✅ 大幅降低 MVP 复杂度
  ⚠️  限制了测试场景的测试覆盖面
```

**当前倾向**：方案 C（MVP 阶段回避），记录为未来 SpawnManager 的需求。

---

## 3.5 ZoneManager

**职责**：
- 管理所有区域子场景（`.tscn`）的动态加载与卸载
- 在玩家接近区域边界时提前预加载相邻区域（无感知加载）
- 基于回溯窗口感知，在安全时机卸载远离区域

**加载/卸载规则**：

```
加载时机：玩家进入相邻区域的"触发边界"（预加载，在玩家到达前完成）
卸载时机：当前时间（真实时间）- 玩家最后离开该区域的时间 > MAX_REWIND_DURATION（20 秒）
         → Ring Buffer 固定 1200 帧 / 60fps = 20 真实秒上限，届时该区域所有历史帧
           已被新帧完全覆盖，卸载绝对安全（此为真实时间，与 time_scale 无关）
```

**核心实现**：

```gdscript
# ZoneManager.gd（Autoload）
# 安全阈值 = MAX_FRAMES / physics_fps = 1200 / 60 = 20.0 真实秒
# 注意：_zone_exit_timestamps 与本常量均为真实时间（秒），与 time_scale / game_time 无关
const MAX_REWIND_DURATION := 20.0

var _loaded_zones: Dictionary = {}          # zone_id → ZoneNode
var _zone_exit_timestamps: Dictionary = {}  # zone_id → 玩家最后离开时刻

func _physics_process(_delta: float) -> void:
    _check_safe_to_unload()

func player_entered_zone(zone_id: String) -> void:
    _zone_exit_timestamps.erase(zone_id)        # 取消卸载倒计时
    _preload_adjacent_zones(zone_id)            # 预加载相邻区域

func player_exited_zone(zone_id: String) -> void:
    _zone_exit_timestamps[zone_id] = Time.get_ticks_msec() / 1000.0

func _load_zone(zone_id: String) -> void:
    if zone_id in _loaded_zones: return
    var zone = load("res://Scenes/Zones/%s.tscn" % zone_id).instantiate()
    get_tree().root.get_node("Main").add_child(zone)
    _loaded_zones[zone_id] = zone
    # zone._ready() → 所有子节点 TimeManager.register(self)

func _check_safe_to_unload() -> void:
    var now = Time.get_ticks_msec() / 1000.0
    for zone_id in _zone_exit_timestamps.keys():
        if now - _zone_exit_timestamps[zone_id] > MAX_REWIND_DURATION:
            _unload_zone(zone_id)

func _unload_zone(zone_id: String) -> void:
    _zone_exit_timestamps.erase(zone_id)
    _loaded_zones[zone_id].queue_free()
    _loaded_zones.erase(zone_id)
    # queue_free() → 所有子节点 _exit_tree() → TimeManager.unregister(self)
    # Ring Buffer 中的旧帧保留，过期后自然被新帧覆盖，无需主动清理
```

**内存估算**：
- 同时在内存中的区域 ≈ 玩家在 20 真实秒内能经过的区域数（通常 1~3 个，极端情况 ≤5 个）
- 远优于"永不卸载"时全部 ~10 个区域同时驻留



测试场景 `SkillTestLab.tscn` 的可用性依赖以下系统就绪：

```
最小可测试集（P0）：
  ✅ GravityManager 运行（Player 能感知重力方向/强度）
  ✅ TimeManager 运行（time_scale 生效，慢动作/加速可触发）
  ✅ Player Entity 有基础移动（MovementComponent + GravityReceiverComponent）
  ✅ Player 有重力技能输入（GravitySkillComponent，至少方向切换）
  ✅ Player 有时间技能输入（TimeSkillComponent，至少回溯 + 慢动作）
  ✅ HUD 显示 GE/CE/time_scale/gravity_vector

可选扩展（P1）：
  ⬜ LGF 放置与可视化
  ⬜ 静态交互物体（木箱）参与快照
  ⬜ 重力强度调节 UI
  ⬜ 引力时间膨胀联动效果可视化
```

---

## 3.6 RewindFreeZoneTrigger

**职责**：检测玩家进出失效区域（Rewind-Free Zone），通知 TimeManager 切换状态。

**节点结构**：

```
RewindFreeZoneTrigger (Area2D)
└── CollisionShape2D   ← 区域边界，覆盖整个休息站空间
```

**实现**：

```gdscript
# RewindFreeZoneTrigger.gd
extends Area2D

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        TimeManager.enter_rewind_free_zone()

func _on_body_exited(body: Node) -> void:
    if body.is_in_group("player"):
        TimeManager.exit_rewind_free_zone()
```

**约定**：
- 每个休息站场景（`RestStation.tscn`）包含且仅包含一个 `RewindFreeZoneTrigger`
- `RewindFreeZoneTrigger` 不注册 TimeManager（不参与快照）——它是触发器，不是游戏状态
- `TimeSkillComponent` 在触发任何时间技能前检查 `TimeManager.in_rewind_free_zone`：

```gdscript
# TimeSkillComponent.gd
func try_start_rewind() -> void:
    if TimeManager.in_rewind_free_zone:
        return   # 失效区域内禁止触发
    if TimeManager._valid_frame_count == 0:
        return   # 无历史帧
    # 取消所有正在进行的时间流速操控，强制重置为 1.0
    _cancel_active_time_effects()
    TimeManager.time_scale = 1.0
    TimeManager.is_rewinding = true
```

---

## 6. 场景布局草图

```
SkillTestLab.tscn
┌─────────────────────────────────────────────────────────────────┐
│  [HUD Layer]  GE: ████░░  CE: ███░░  ×1.0  ↓9.8               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    顶部边界（StaticBody2D）               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──┐                                                    ┌──┐   │
│  │左│    ·  ·  [木箱]   [玩家初始]   [铁球]  ·  ·       │右│   │
│  │墙│                                                    │墙│   │
│  │  │    平台A          平台B（高）         平台C         │  │   │
│  └──┘                                                    └──┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    底部边界（StaticBody2D）               │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  [调试面板]  当前重力向量 | time_scale | CE/GE 数值 | 回溯状态  │
└─────────────────────────────────────────────────────────────────┘
```

场景构成元素：
- 四面封闭墙体（StaticBody2D）——确保所有重力方向下玩家不会飞出
- 若干不同高度的平台——测试重力方向切换后的移动
- 若干静态物理物体（木箱/铁球）——测试回溯还原
- HUD CanvasLayer——实时显示系统状态
- 调试面板（Label 节点）——显示内部数值，便于开发期验证
