# WoW Body · Godot 4.7 客户端

原生客户端（**非 Web 导出**），目标平台：**macOS**（优先真手识别）、**Android**。

**macOS 真手势**：Apple Vision 手部关键点（`macos_hand_server`）→ 开场悬停 3 秒开始 → 自动发射。  
无手 / 服务未启动时回退鼠标。Web 版 MediaPipe 在 `../web/`。

## 环境

- Godot **4.7+**（4.3–4.6 一般也可打开，建议 4.7）
- **macOS 手部识别**：Xcode / Swift 5.9+（仅构建手部服务时需要）
- 导出：
  - macOS：Xcode / 命令行工具
  - Android：JDK 17 + Android SDK，编辑器中配置 Export Templates

## 运行（macOS 真手）

1. 构建手部服务（只需一次，或代码更新后）：

```bash
cd godot
./tools/macos_hand_server/build.sh
```

2. 用 Godot 打开 `godot/project.godot`，F5 运行  
   - 游戏会自动拉起 `bin/macos_hand_server.app`  
   - 首次可能弹出**摄像头权限**（系统设置 → 隐私与安全性 → 摄像头，勾选 Godot 与 Hand Server）
3. 把手伸到摄像头前，骨架应跟随真实的手  
4. 把手移到「开始」按钮上 **停 3 秒**

调试手部服务（可选）：

```bash
./bin/macos_hand_server --port 17452
# 另开终端: nc 127.0.0.1 17452
```

### 纯体感操作（无键鼠）

| 操作 | 效果 |
|------|------|
| 真手移到「开始」上停 3 秒 | 开始游戏 |
| 移动手掌 | 瞄准 |
| 开掌 | **自动蓄力并发射** |
| 手停在底部 🔥❄⚡ 约 1 秒 | 切换法术 |
| 握拳（Vision） | 也可切换法术 |
| 战败后停在重开按钮 2 秒 | 重新开始 |

**已禁用**：鼠标瞄准 / 点击按钮 / 空格 / Q / R 等键盘操作。

## 操作逻辑

### macOS 真手识别管线

```
FaceTime 摄像头
    ├─ Godot CameraServer → 背景预览
    └─ macos_hand_server (Vision VNDetectHumanHandPoseRequest)
           → TCP 127.0.0.1:17452 NDJSON 21 点
           → HandTracker → HandMath.landmarks_to_sample
           → 悬停 UI / 自动发射
```

- 服务源码：`tools/macos_hand_server/`（Swift + AVFoundation + Vision）
- 产物：`bin/macos_hand_server.app`（含 `NSCameraUsageDescription`）
- `HandTracker` 在 macOS 上自动 `OS.create_process` 拉起服务；进程退出时会 kill
- **纯体感**：`mouse_fallback = false`，无真手则无输入；低置信度关节不画线（避免飞到右上角）

### 玩法

- **开场就跟手**：掌心光标 + 骨架
- **悬停激活**：`scripts/ui/dwell_target.gd`（开始 3s / 法术 1.15s / 重开 2s）
- `GestureController.auto_fire = true`：蓄力到阈值自动释放
- 投射物优先锁定最近怪物

若要恢复「按住蓄力 + 推掌释放」经典模式，在 `main.gd` 的 `_ready` 中设：

```gdscript
_gesture.auto_fire = false
tracker.always_open = false
```

## 特效与音效

- `shaders/spell_orb.gdshader`：火 / 冰 / 电投射物
- `shaders/palm_aura.gdshader`：掌心蓄力光环
- **火球命中**：灼烧 DoT + 火焰粒子 + 橙红体色
- **寒冰命中**：强减速 + 冰蓝光环 + 冰晶爆发
- **雷电命中**：链式溅射附近最多 3 个怪 + 闪电折线
- 音效：`assets/sfx/fire_hit.wav` · `frost_hit.wav` · `lightning_hit.wav`（发射时播放）

## 握拳识别（进阶）

`scripts/tracking/fist_detector.gd` 仍保留完整握拳逻辑，供将来接入真实关键点：

1. 四指卷曲比
2. 指尖簇紧凑度
3. 拇指内收
4. 开掌度反比
5. **进入/退出双阈值滞后** + **连续帧确认**

真实 MediaPipe 关键点可接入同一套 `HandMath.landmarks_to_sample` + `FistDetector`。

## 导出

编辑器 → Project → Export：

- **macOS**：`export_presets.cfg` 已含 Camera 用途说明  
- **Android**：已勾选 `CAMERA` 权限，建议 arm64-v8a

```
build/macos/WoWBody.app
build/android/WoWBody.apk
```

## 目录

```
godot/
  project.godot
  export_presets.cfg
  scenes/main.tscn
  scripts/
    autoload/game_bus.gd
    tracking/   # 手部、握拳、手势
    game/       # 怪物、投射物、世界
    vfx/        # 掌心特效
  shaders/
```

## 后续可接

- Android：ML Kit Hand / MediaPipe GDExtension（复用同一 NDJSON 或直接喂 `landmarks_to_sample`）
- 音效与法术独立伤害表
- iOS 导出（需额外权限与签名）
