interface StartScreenProps {
  starting: boolean
  modelReady: boolean
  modelError: string | null
  cameraError: string | null
  insecureHint: boolean
  onStart: () => void
}

export function StartScreen({
  starting,
  modelReady,
  modelError,
  cameraError,
  insecureHint,
  onStart,
}: StartScreenProps) {
  const busy = starting || !modelReady

  return (
    <div className="overlay-panel start-screen">
      <div className="panel-card">
        <p className="eyebrow">WoW Body · Web</p>
        <h1>火球术施法训练</h1>
        <p className="lead">
          双手识别 · 开掌蓄力（不满不自动放）· 向前推掌手动释放 · 握拳切换
          火球 / 寒冰 / 雷电。
        </p>

        <ol className="howto">
          <li>允许摄像头（建议前置），可同时伸出双手</li>
          <li>张开手掌蓄力 — 蓄力条与掌心特效随开掌/蓄力变大</li>
          <li>向前推掌释放当前法术（蓄满也不会自动发射）</li>
          <li>握拳切换：火球 → 寒冰 → 雷电</li>
          <li>调试：空格施法 · Q 切法术 · R 重开</li>
        </ol>

        {insecureHint && (
          <p className="warn">
            当前不是安全上下文。手机访问局域网 HTTP 通常无法开摄像头，请用
            HTTPS 或隧道部署。
          </p>
        )}
        {modelError && <p className="warn">手部模型：{modelError}</p>}
        {cameraError && <p className="warn">{cameraError}</p>}

        <button
          type="button"
          className="primary-btn"
          disabled={busy || Boolean(modelError)}
          onClick={onStart}
        >
          {!modelReady && !modelError
            ? '正在加载手部模型…'
            : starting
              ? '正在打开摄像头…'
              : '开启摄像头并开始'}
        </button>

        <p className="fineprint">
          手部识别模型首次加载需要联网。数据仅在本地浏览器处理。
        </p>
      </div>
    </div>
  )
}
