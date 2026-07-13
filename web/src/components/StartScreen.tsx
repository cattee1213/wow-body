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
          用摄像头捕捉手部动作：张开手掌蓄力，向前或向上甩出，向对面怪物丢出火球。
        </p>

        <ol className="howto">
          <li>允许浏览器使用摄像头（建议前置）</li>
          <li>把手伸到画面中，张开手掌蓄力</li>
          <li>快速向前推掌 / 向上甩手施放火球</li>
          <li>调试可用空格键施法、R 键重开</li>
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
