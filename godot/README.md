# WoW Body · Godot 4.7 客户端（重点）

原生客户端（**非 Web 导出**）。目标：**macOS 体感优先**，**键鼠为 fallback**；Android 导出预留。

Web 版仍在 `../web/`，当前开发重心在本目录。

**现状与缺口总览**（已实现 / 还缺什么 / 建议优先级）见：[`docs/STATUS.md`](docs/STATUS.md)。

---

## 当前已实现清单

### 核心玩法
| 模块 | 状态 | 说明 |
|------|------|------|
| 对战循环 | ✅ | 刷怪、波次、生命、分数、战败重开 |
| 基础法术 | ✅ | 火球 / 寒冰（开局 2 选 1） |
| 指尖即射 | ✅ | 无蓄力，冷却后持续射击 |
| 终极 | ✅ | 暴风雪 / 火风暴 |
| 波末 3 选 1 | ✅ | 伤害/攻速/终CD/连发（最多 5 连） |
| 投射物锁定 | ✅ | 飞向最近怪物 |
| 寒冰减速 | ✅ | 命中降低怪速 |
| 命中音效 | ✅ | `assets/sfx/*_hit.wav` |

### 输入 / 体感
| 模块 | 状态 | 说明 |
|------|------|------|
| 摄像头预览 | ✅ | `CameraServer` 前置画面镜像背景 |
| macOS Vision 手部 | ✅ | `macos_hand_server` → TCP 21 点 |
| 双手结构 | ✅ | 服务可回多只手；UI 用主手 |
| 握拳识别 | ✅ | 多特征 + 滞后 + 连续帧确认 |
| 悬停 UI（dwell） | ✅ | 开始 3s / 切法 1.15s / 重开 2s |
| 掌心手势光标 | ✅ | `GestureCursor` 跟随掌心 |
| 骨架绘制 | ✅ | 低置信度关节不连线 |
| **键鼠 fallback** | ✅ | 仅鼠标/键盘活动时激活（非丢手自动切） |
| **体感时藏鼠标** | ✅ | `Input.MOUSE_MODE_HIDDEN` |

### 特效
| 模块 | 状态 |
|------|------|
| 法术 VFX | ✅ 火/冰基础 + 暴风雪/火风暴终极 |
| 掌心特效 | ✅ `PalmVfx` |
| 发射投射物 | ✅ `SpellProjectile` 用 projectile 序列帧 |
| 击中爆炸 | ✅ `GameWorld._spawn_impact` 用 impact 序列帧 |
| Shader 备用光效 | ✅ `spell_orb` / `palm_aura`（粒子拖尾仍可用） |
| GPU 粒子爆发 | ✅ |

### 导出
| 平台 | 状态 |
|------|------|
| macOS preset | ✅ 含摄像头用途说明 |
| Android preset | ✅ CAMERA 权限；体感管线待接 ML Kit |

---

## 输入优先级

```
有新鲜 Vision 手部数据
    → 体感模式（隐藏系统鼠标，按钮忽略点击，只用悬停/手势）
手部短暂丢失
    → **仍保持体感**（沿用最后一帧手，不自动切键鼠）
检测到鼠标移动 / 键盘按键（且当前无真手）
    → 键鼠备用（显示鼠标，可点击按钮，空格等）
再次检测到真手
    → 立刻切回体感
```

**不会**因为检测失败就自动切到键鼠；只有你真的动鼠标/按键才会激活备用。

### 体感操作
| 操作 | 效果 |
|------|------|
| 手停在开始按钮 3 秒 | 进入选系 |
| 悬停火/冰 1.5 秒 | 锁定本局基础学派 |
| 指尖瞄准 | 基础弹即射（短冷却） |
| 双手高举开掌 ~1s | **暴风雪**（全屏冰，CD 20s） |
| 双手合掌聚能 ~1s | **火风暴**（全屏火，CD 20s） |
| 战败后停重开 2 秒 | 回开始界面 |

体感中若手离开画面会**继续体感**（冻结最后手位）；要键鼠请**移动鼠标或按键**。有真手时会立刻夺回体感。

### 键鼠备用（仅手动激活后）
| 操作 | 效果 |
|------|------|
| 点击开始 / 选系 / 重开 | 对应操作 |
| 1 / 2 | 选火 / 冰 |
| 鼠标移动 | 瞄准（合成手） |
| 空格 | 强制基础弹 |
| 4 / 5 | 暴风雪 / 火风暴 |
| R | 重开 |

---

## 运行（macOS）

```bash
cd godot
./tools/macos_hand_server/build.sh   # 首次或服务代码更新后
# Godot 打开 project.godot → F5
```

首次请在系统设置里允许 **摄像头**（Godot + Hand Server）。

---

## 目录

```
godot/
  scenes/main.tscn
  scripts/
    main.gd                 # 场景总控、体感/键鼠切换、藏鼠标
    tracking/hand_tracker.gd
    tracking/gesture_controller.gd
    tracking/fist_detector.gd
    game/                   # 世界、怪、弹、音效
    ui/dwell_target.gd
    vfx/palm_vfx.gd
  shaders/
  tools/macos_hand_server/  # Swift Vision 服务
  bin/macos_hand_server*    # 构建产物
```

---

## 后续可做

- Android 真手（ML Kit / MediaPipe native）
- 推掌手动释放模式（`auto_fire = false`）
- 更完整的 UI 本地化与设置页（灵敏度、是否藏鼠标）
