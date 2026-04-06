extends IntegrationTestBase
## AT-01 系统启动验收测试（12.1）

func before_each() -> void:
	super.before_each()

func after_each() -> void:
	super.after_each()

# ── 12.1 AT-01 启动后 Autoload 初始值正确 ────────────────────────────────────
# 自动化部分：验证 Autoload 初始状态与 GDD §6 数值一致；
# HUD 可视确认（GE=100、CE=100、×1.0、↓1.0）属于手动步骤，参见下方说明。
func test_at01_autoload_initial_values() -> void:
	# GravityManager
	assert_almost_eq(GravityManager.ge, 100.0, 0.001,
		"GravityManager.ge 初始应为 100")
	assert_almost_eq(GravityManager.ge_max, 100.0, 0.001,
		"GravityManager.ge_max 应为 100")
	assert_almost_eq(GravityManager.magnitude, 1.0, 0.001,
		"GravityManager.magnitude 初始应为 1.0")
	assert_eq(GravityManager.direction, Vector2.DOWN,
		"GravityManager.direction 初始应为 DOWN")

	# TimeManager
	assert_almost_eq(TimeManager.ce, 100.0, 0.001,
		"TimeManager.ce 初始应为 100")
	assert_almost_eq(TimeManager.time_scale, 1.0, 0.001,
		"TimeManager.time_scale 初始应为 1.0")
	assert_false(TimeManager.is_rewinding,
		"TimeManager.is_rewinding 初始应为 false")
	assert_false(TimeManager.in_rewind_free_zone,
		"TimeManager.in_rewind_free_zone 初始应为 false")

# ── 12.1 手动步骤说明（不计入自动断言） ─────────────────────────────────────
func test_at01_manual_hud_visual_check() -> void:
	pending("【手动】运行 ./run.sh → 加载 SkillTestLab.tscn → 等待 3s\n"
		+ "确认：\n"
		+ "  · Godot 输出窗口无 ERROR / SCRIPT ERROR\n"
		+ "  · HUD 左上角显示 GE=100，CE=100\n"
		+ "  · HUD 显示时间倍率 ×1.0，重力方向 ↓，强度 1.0")
