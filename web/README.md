# WoW Body · Web

浏览器端手势施法小游戏：摄像头捕捉手部 → 蓄力甩出火球 → 消灭对面怪物。

## 开发

```bash
npm install
npm run dev
```

浏览器打开终端提示的本地地址。手机调试需要 **HTTPS**（局域网 HTTP 通常无法开摄像头）。

## 操作

| 动作 | 效果 |
|------|------|
| 张开手掌 | 蓄力 |
| 向前推掌 / 向上甩手 | 施放火球 |
| 空格 | 调试施法 |
| R / 战败后点击 | 重新开始 |

## 技术

- React + Vite + TypeScript
- `getUserMedia` 摄像头
- MediaPipe Hand Landmarker 手部关键点
- Canvas 2D 游戏层
