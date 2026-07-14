# WoW Body · Godot 版现状与缺口

> 更新日期：2026-07-14  
> 范围：仅 `godot/` 客户端（Web 版见 `../web/`，非当前重心）

本文总结**已实现玩法**、**技术结构**、**素材状态**，以及**仍缺什么 / 建议优先级**，便于继续开发与实机调参。

---

## 1. 产品定位

- **macOS 体感优先**的 2D 魔法对战：摄像头 + 手部 21 点 → 瞄准与施法。
- **键鼠为 fallback**（无真手 / 服务断开时）。
- 目标手感：玩家像真正的法师——**开局选学派（火/冰）**，平时用**指尖即射**基础弹，用**双手仪式**放全屏终极。
- 体感激活后丢手**不会**自动切键鼠；只有鼠标/键盘活动才激活备用。

---

## 2. 核心玩法设计（当前方案）

### 2.1 流程

```
开始界面（悬停 3s / 点击）
    → 选择基础学派（火 / 冰，悬停 1.5s 或 1/2）
    → 战斗
        · 指尖：本系基础弹（即射 + 短冷却，无蓄力）
        · 双手仪式：暴风雪 / 火风暴（独立 CD）
    → 战败 → 悬停重开 → 回开始界面（可重选系）
```

### 2.2 基础法（2 选 1，本局锁定）

| 学派 | ID | 基础弹 | 命中特色 |
|------|-----|--------|----------|
| 火 | `fire` | 火球 | 灼烧 DoT |
| 冰 | `frost` | 寒冰箭 | 减速 |

- **操作**：指尖瞄准 → **立即发射**（约 0.38s 冷却），**无蓄力条/蓄力阶段**。
- 已移除：雷电基础系、闪电链终极、基础蓄力模式。
- 键鼠备用时：鼠标瞄准 + 空格射击。

### 2.3 终极法（全员可用，独立 CD）

| 终极 | ID | 体感手势 | 效果概要 | 默认 CD |
|------|-----|----------|----------|---------|
| 暴风雪 | `blizzard` | 双手高举开掌，蓄约 1s | 全屏持续冰伤 + 强减速 | 20s |
| 火风暴 | `firestorm` | 双手合掌靠近，蓄约 1s | 全屏持续火伤 + 灼烧 | 20s |

- 仪式识别中**优先于**基础射击；蓄满自动释放。
- 键鼠：`4` / `5` 或底部按钮。

### 2.4 体感 vs 键鼠

| 规则 | 说明 |
|------|------|
| 进入体感 | 识别到真手 → 体感模式 |
| 退出体感 | **仅当**鼠标移动/键盘按键（且当前无直播真手）→ 键鼠 |
| 丢手 | **不**自动切键鼠；沿用最后一帧手势 |
| 体感中 | 不合成键鼠手、隐藏光标；有真手时忽略鼠标激活 |
| 再伸手 | 立刻切回体感 |

### 2.5 设计取舍

| 早期想法 | 当前结论 |
|----------|----------|
| 三系 + 蓄力射击 | 火/冰 2 选 1 + 指尖即射 |
| 闪电系 / 闪电链 | 已移除 |
| 手势词表 | 指尖=基础；高举/合掌=终极 |

---

## 3. 已实现清单

### 3.1 核心玩法

| 模块 | 状态 | 说明 |
|------|------|------|
| 对战循环 | ✅ | 刷怪、波次、生命、分数、战败 |
| 开局选系 | ✅ | 火/冰 + dwell / 键 1–2 |
| 基础弹即射 | ✅ | 无蓄力，短 CD 连射 |
| 火灼烧 / 冰减速 | ✅ | `Monster.apply_hit` |
| 双终极全屏 | ✅ | 暴风雪 / 火风暴 |
| 终极独立 CD | ✅ | `GameBus.ultimate_cd` |
| 体感/键鼠切换 | ✅ | 有手=体感；丢手保持；键鼠仅手动激活 |
| 波末 Roguelike 3 选 1 | ✅ | 伤害/攻速/终CD/连发，详见 `docs/ROGUELIKE_UPGRADES.md` |
| 战败重开 | ✅ | 回开始界面，可重选系 |

### 3.2 输入 / 体感

| 模块 | 状态 | 说明 |
|------|------|------|
| 摄像头预览 | ✅ | `CameraServer`，镜像背景 |
| macOS Vision 手部 | ✅ | `macos_hand_server` → TCP 21 点 |
| 双手样本 | ✅ | 可同时用于仪式 |
| 握拳识别 | ✅ | `FistDetector` 多特征 + 滞后 |
| 指尖 / 开掌分类 | ✅ | `PoseClassifier` |
| 双手仪式 | ✅ | `RitualDetector` |
| 悬停 UI | ✅ | 开始 / 选系 / 重开 |
| 掌心光标 | ✅ | 指尖优先、仪式蓄力时放大 |
| 骨架绘制 | ✅ | 低置信度不连线 |
| 键鼠 fallback | ✅ | 仅鼠标/键盘活动时激活 |
| 体感藏鼠标 | ✅ | `Input.MOUSE_MODE_HIDDEN` |

### 3.3 特效与音频

| 模块 | 状态 | 说明 |
|------|------|------|
| 基础 VFX 四态 | ✅ | hold / charge / projectile / impact |
| 终极 VFX 四态 | ✅ | hold / charge / cast / loop |
| 掌心 hold→charge | ✅ | `PalmVfx` |
| 投射物 + 击中 | ✅ | `SpellProjectile` / impact |
| 终极全屏叠加 | ✅ | cast 爆发 + loop 场 + 色洗 |
| 命中 SFX | ⚠️ | 火/冰 hit；终极复用同文件 |
| BGM | ❌ | 无 |

### 3.4 导出

| 平台 | 状态 |
|------|------|
| macOS preset | ✅ 含摄像头用途说明 |
| Android preset | ⚠️ CAMERA 权限有；真手管线未接 |

---

## 4. 操作一览

### 体感

| 操作 | 效果 |
|------|------|
| 悬停开始 3s | 进入选系 |
| 悬停火/冰 1.5s | 锁定本局学派 |
| 指尖瞄准 | 基础弹即射 |
| 双手高举开掌 ~1s | 暴风雪 |
| 双手合掌 ~1s | 火风暴 |
| 战败悬停重开 2s | 回开始 |

### 键鼠（仅无体感时）

| 键 | 效果 |
|----|------|
| 点击开始 / 选系 / 重开 | 对应操作 |
| `1` / `2` | 火 / 冰 |
| 鼠标 | 瞄准 |
| 空格 | 强制基础弹 |
| `4` / `5` | 暴风雪 / 火风暴 |
| `R` | 重开 |

---

## 5. 技术结构

### 5.1 关键脚本

```
scripts/
  main.gd                      # 流程：菜单 → 选系 → 战斗；HUD；输入模式
  autoload/game_bus.gd         # 法术 meta、基础系锁定、终极 CD、信号
  tracking/
    hand_tracker.gd            # Vision TCP + 键鼠合成手
    hand_math.gd / hand_types.gd
    fist_detector.gd
    pose_classifier.gd         # open / point / fist
    ritual_detector.gd         # blizzard / firestorm
    gesture_controller.gd      # 指尖即射 + 仪式优先
  game/
    game_world.gd              # 怪、弹、cast_spell / cast_ultimate
    monster.gd / projectile.gd / sfx_player.gd
  vfx/
    spell_vfx_library.gd       # 按目录加载 PNG 帧
    palm_vfx.gd / animated_vfx_sprite.gd
  ui/dwell_target.gd
```

### 5.2 施法优先级（每帧）

```
双手仪式条件满足且 CD 好 → 仪式蓄力 → 满则 cast_ultimate
    否则
指尖就绪且基础 CD 好 → 立即 cast_spell(basic_spell)
```

### 5.3 素材约定

```
assets/vfx/{spell}/{state}_0.png
```

| 类型 | 目录 | 状态文件 |
|------|------|----------|
| 基础 | `fire` `frost` | `hold` `charge` `projectile` `impact` |
| 终极 | `blizzard` `firestorm` | `hold` `charge` `cast` `loop` |

源图集（便于重切）：

- `assets/atlas_basic_3x4.png` — 基础 3×4  
- `assets/atlas_ultimate_3x4.png` — 终极 3×4  
- `assets/vfx/spell_atlas_basic.png` / `spell_atlas_ultimate.png` — 副本  

加载逻辑：`SpellVfxLibrary` 直接读 PNG 文件（不依赖 import 缓存），改图后重启场景即可。

### 5.4 运行（macOS）

```bash
cd godot
./tools/macos_hand_server/build.sh   # 首次或服务更新后
# Godot 打开 project.godot → F5
```

系统设置需允许 **Godot** 与 **Hand Server** 使用摄像头。

---

## 6. 还缺什么

### 6.1 高优先（体感体验）

| 缺口 | 说明 |
|------|------|
| 仪式 / 指尖实机调参 | 阈值未在真实摄像头前系统校准，可能难触发或误触 |
| 新手引导 | 缺开局手势教学（指尖 + 三个大招示意） |
| 终极 CD 可视化 | 仅按钮文字倒计时，无扇形/进度环 |
| 仪式蓄力表现 | 有条变色，缺双手专属 hold/charge 大特效叠加 |

### 6.2 中优先（完整度）

| 缺口 | 说明 |
|------|------|
| 本系共鸣 | 选火加强火风暴等未做 |
| 终极独立音效 | 现复用三系 hit wav |
| BGM / 环境音 | 无 |
| 多帧序列动画 | 每状态仍 1 帧静图 |
| VFX 抠底质量 | 部分帧仍带深色底板，叠加可能发脏 |
| 战败结算页 | 无本局统计 / 最高分 |
| 切片工具入库 | 换 atlas 时缺少固定 `tools/slice_atlas.py` |

### 6.3 低优先 / 远期

| 缺口 | 说明 |
|------|------|
| Android 真手 | ML Kit / MediaPipe native 未接 |
| 设置页 | 灵敏度、藏鼠标、自动射 vs 推掌 |
| 推掌手动释放产品化 | `auto_fire = false` 未做成选项 |
| 难度内容 | 精英、Boss、道具等 |
| 存档 / 成就 | 无 |
| Web 版对齐 | 未同步选系 + 终极 |

### 6.4 工程

| 缺口 | 说明 |
|------|------|
| 变更提交 | 终极与新素材可能仍在 working tree，需自行 commit |
| 自动化测试 | 手势与战斗依赖人测 |
| README 清单表 | 部分旧描述可能滞后，以本文与实机为准 |

---

## 7. 建议下一步（性价比）

1. **实机 10 分钟**：记录指尖稳定性、三个大招哪个最难放 / 最易误触。  
2. **只调阈值**：`pose_classifier.gd`、`ritual_detector.gd`（必要时 `gesture_controller.gd`）。  
3. **开局教学 1 屏**（图文或短演示）。  
4. **终极 CD 环 + 专属音效**。  
5. 满意后 **git commit**，并视需要补 `tools/slice_atlas.py`。

---

## 8. 相关文件速查

| 用途 | 路径 |
|------|------|
| 主场景 | `scenes/main.tscn` |
| 总控 | `scripts/main.gd` |
| 法术与 CD | `scripts/autoload/game_bus.gd` |
| 手势总成 | `scripts/tracking/gesture_controller.gd` |
| 仪式 | `scripts/tracking/ritual_detector.gd` |
| 指尖分类 | `scripts/tracking/pose_classifier.gd` |
| 战斗与终极 | `scripts/game/game_world.gd` |
| VFX 加载 | `scripts/vfx/spell_vfx_library.gd` |
| 手部服务 | `tools/macos_hand_server/` |
| 项目说明（简） | `README.md` |
| 本文 | `docs/STATUS.md` |

---

## 9. 一句话结论

**玩法骨架已齐**（火/冰选系 + 指尖即射 + 双终极 + 体感优先键鼠手动 + 素材接入）。  
当前主要缺口在 **体感调参、引导与大招反馈打磨**，以及音效 / UI / 结算等完整度。
