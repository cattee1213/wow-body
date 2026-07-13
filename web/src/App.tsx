import { useCallback, useMemo, useState } from 'react'
import { GameStage } from './components/GameStage'
import { StartScreen } from './components/StartScreen'
import { useCamera } from './hooks/useCamera'
import { useHandLandmarker } from './hooks/useHandLandmarker'
import type { AppPhase } from './types'
import './App.css'

function App() {
  const camera = useCamera()
  const hands = useHandLandmarker()
  const [phase, setPhase] = useState<AppPhase>('start')

  const insecureHint = useMemo(() => {
    return !window.isSecureContext && location.hostname !== 'localhost'
  }, [])

  const onStart = useCallback(async () => {
    setPhase('loading')
    const result = await camera.start()
    if (!result.ok) {
      setPhase(result.kind === 'denied' ? 'denied' : 'error')
      return
    }
    setPhase('playing')
  }, [camera.start])

  const playing = phase === 'playing'

  return (
    <div className="app-root">
      <video
        ref={camera.videoRef}
        className={`camera-video ${playing ? 'camera-video--live' : ''}`}
        playsInline
        muted
        autoPlay
      />

      {playing && (
        <GameStage
          videoRef={camera.videoRef}
          detect={hands.detect}
          active={playing && hands.ready}
        />
      )}

      {phase !== 'playing' && (
        <StartScreen
          starting={camera.starting || phase === 'loading'}
          modelReady={hands.ready}
          modelError={hands.error}
          cameraError={camera.errorMessage}
          insecureHint={insecureHint}
          onStart={onStart}
        />
      )}

      {playing && (
        <div className="corner-tip">
          张开手掌聚火 · 向前推掌发射 · 空格调试 · R 重开
        </div>
      )}
    </div>
  )
}

export default App
