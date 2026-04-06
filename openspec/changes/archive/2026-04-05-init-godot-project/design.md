# Design: init-godot-project

## Context

GravityRush 目前只有文档骨架与空目录，没有任何可运行的 Godot 工程文件。引擎二进制（Godot 4.6.2）已就绪于 `Engine/Godot.app`。

本设计决策将指导搭建最小可运行的 Godot 4 初始工程，使引擎能够顺利启动并执行第一条脚本命令。

## Goals / Non-Goals

### Goals

- 确定 Godot 项目根目录位置（`Game/`）
- 确定 Autoload 单例的数量策略与职责划分
- 确定日志格式约定，从第一行日志起保持一致性
- 提供快捷启动脚本，降低引擎启动门槛
- 产出可立即实现的最小文件集

### Non-Goals

- 实现任何游戏功能（重力系统、时间系统等）
- 设计场景结构或节点层级
- 设计资源管理方案

## Decisions

### 1. 项目根目录：`Game/` 子目录

将 `Game/` 作为 Godot 项目根（`project.godot` 放置于此），而非 workspace 根目录。

**理由**：`Documents/`、`Engine/`、`openspec/` 等非游戏目录不应出现在 Godot 编辑器的文件系统视图中，保持编辑器视图干净；游戏文件与文档/工具完全隔离，职责边界清晰。

**备选方案**：将 `project.godot` 放在 workspace 根 → 被否决，编辑器视图污染，且将来难以迁移。

---

### 2. Autoload 策略：多单例、职责分离

注册多个 Autoload，每个单例拥有独立职责，按顺序在主场景之前初始化。

```text
Autoload 初始化顺序
[1] Bootstrap       ← 启动日志，系统就绪汇总（本次实现）
[2] GravitySystem   ← 重力全局状态（将来）
[3] TimeSystem      ← 时间全局状态（将来）
```

**Bootstrap 的长期定位**：轻量的"启动记录员"。仅负责打印启动确认信息与将来各子系统的就绪状态汇总，**不持有任何游戏状态**。

**理由**：职责分离使每个系统的 Autoload 都可以独立测试、独立替换，避免单一"GameManager"随项目膨胀成难以维护的上帝对象。

**备选方案**：单一 Bootstrap 统一管理所有子系统初始化 → 被否决，违背职责单一原则，将来扩展性差。

---

### 3. 日志格式：`[模块名]` 方括号前缀

所有 Autoload 及系统级日志统一使用以下格式：

```text
[模块名] 消息内容
```

示例：

```text
[Bootstrap] Hello GravityRush - Engine started successfully
[GravitySystem] Initialized
[TimeSystem] Initialized
```

**理由**：方括号前缀是游戏引擎领域的惯用约定（Godot 内置日志、Unity Console 均使用类似格式），便于在输出中快速定位来源模块，也便于将来用正则过滤日志。

**备选方案**：`模块名 | 消息` 管道符风格 → 被否决，可读性略差，与 Godot 内置日志风格不统一。

### 4. 启动脚本：`run.sh`（macOS 专用，支持可选 `--editor` 参数）

在 workspace 根目录提供 `run.sh`，封装 Godot 命令行调用，支持两种模式：

```text
./run.sh           → 直接运行游戏（headless，不打开编辑器）
./run.sh --editor  → 打开 Godot 编辑器
```

**实现方式**：

```bash
# 检测 --editor 参数，选择对应启动命令
if [ "$1" = "--editor" ]; then
    Engine/Godot.app/Contents/MacOS/Godot -e --path Game/
else
    Engine/Godot.app/Contents/MacOS/Godot --path Game/
fi
```

**理由**：避免每次手动输入长路径；`--editor` 参数符合开发阶段的双重需求（调试运行 + 编辑器操作），模式 C 比仅支持单一模式更灵活。

**平台范围**：当前仅支持 macOS（`Engine/Godot.app` 为 macOS 格式），跨平台扩展留待将来按需添加。

**备选方案**：仅支持运行游戏（无 `--editor` 参数）→ 被否决，初始工程阶段编辑器是主要使用场景，过度限制不实用。

---

## Risks / Trade-offs

- **`Game/` 路径约定需全员对齐** → 在 `AGENTS.md` 中同步更新目录结构说明，作为唯一权威参考
- **Autoload 注册顺序影响初始化依赖** → 现阶段各单例相互独立，暂无风险；将来若存在依赖，需在 `project.godot` 中严格维护顺序
- **`run.sh` macOS 专用，跨平台不可用** → 脚本顶部添加注释说明平台限制，将来扩展时按 OS 检测分支

## Migration Plan

1. 新建 `Game/` 目录及子目录（`Scripts/`、`Resources/`、`Scenes/`）
2. 创建 `Game/Scripts/Bootstrap.gd`（Autoload 脚本）
3. 创建 `Game/Scenes/Main.tscn`（空主场景）
4. 创建 `Game/project.godot`，注册 Bootstrap 为 Autoload，设置 Main.tscn 为主场景
5. 将根目录现有的空 `Scripts/` 和 `Resources/` 迁移至 `Game/` 内（或直接替换）
6. 创建 `run.sh`（workspace 根目录），赋予可执行权限（`chmod +x run.sh`）
7. 更新 `AGENTS.md` 中的目录结构
8. 执行 `./run.sh` 验证控制台输出 `[Bootstrap] Hello GravityRush - Engine started successfully`

回滚：删除 `Game/` 目录即可完全还原，无破坏性操作。

## Open Questions

（无——所有设计决策已在探索阶段确认）
