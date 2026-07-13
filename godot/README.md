# WoW Body · Godot 4.7 客户端

原生客户端（**非 Web 导出**），目标平台：**macOS**、**Android**。

开掌蓄力 → 向前推掌手动释放 → 握拳切换 **火球 / 寒冰 / 雷电**。  
Web 版仍在仓库 `../web/`。

## 环境

- Godot **4.7+**（4.3–4.6 一般也可打开，建议 4.7）
- 导出：
  - macOS：Xcode / 命令行工具
  - Android：JDK 17 + Android SDK，编辑器中配置 Export Templates

## 运行

1. 用 Godot 打开本目录 `godot/`（选择 `project.godot`）
2. 按 F5 运行
3. 点「开始游戏」

### 桌面调试操作

| 操作 | 效果 |
|------|------|
| 按住左键 | 开掌蓄力（掌心特效随蓄力变大） |
| 空格 / 快甩鼠标 | 向前释放当前法术 |
| 右键 / F | 握拳 → 切换法术 |
| Shift | 模拟第二只手 |
| Q | 键盘切法术 |
| R | 重开 |

### 手机（Android）

| 操作 | 效果 |
|------|------|
| 按住屏幕 | 蓄力 |
| 快速滑动 | 推掌释放 |
| 系统会请求摄像头权限 | 前置画面作背景 |

## 特效

- `shaders/spell_orb.gdshader`：火 / 冰 / 电投射物（噪声火焰、冰晶、电弧）
- `shaders/palm_aura.gdshader`：掌心蓄力光环
- GPUParticles2D 命中爆发与拖尾

## 握拳识别（优化点）

`scripts/tracking/fist_detector.gd`：

1. 四指卷曲比（指尖相对 PIP 到腕的距离）
2. 指尖簇紧凑度
3. 拇指内收（靠近食指 MCP）
4. 开掌度反比
5. **进入/退出双阈值滞后** + **连续帧确认**（防抖）

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

- MediaPipe / ML Kit GDExtension 喂入 21 点关键点（替换 `HandTracker` 合成手）
- 音效与法术独立伤害表
- iOS 导出（需额外权限与签名）
