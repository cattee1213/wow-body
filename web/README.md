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
| 张开手掌 | 蓄力（不满不自动放；掌心特效随开掌/蓄力变大） |
| 向前推掌（朝摄像头） | 手动释放当前法术 |
| 握拳 | 切换 火球 → 寒冰 → 雷电 |
| 空格 / Q / R | 调试施法 / 切法术 / 重开 |

## 技术

- React + Vite + TypeScript
- `getUserMedia` 摄像头
- MediaPipe Hand Landmarker 手部关键点
- Canvas 2D 游戏层
