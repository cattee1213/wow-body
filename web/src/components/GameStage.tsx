import { useEffect, useRef } from 'react'
import {
  castFireball,
  createGameState,
  restartGame,
  resizeGame,
  updateGame,
} from '../game/engine'
import {
  createGestureState,
  updateGesture,
  type HistoryPoint,
} from '../game/gesture'
import {
  clearStage,
  drawGame,
  drawHand,
  drawVignette,
} from '../game/render'
import type { HandSample } from '../types'
import { FlameLayer, type FlameLayerHandle } from './FlameLayer'

interface GameStageProps {
  videoRef: React.RefObject<HTMLVideoElement | null>
  detect: (video: HTMLVideoElement, timestampMs: number) => HandSample | null
  active: boolean
}

export function GameStage({ videoRef, detect, active }: GameStageProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const flameRef = useRef<FlameLayerHandle | null>(null)
  const gameRef = useRef(createGameState(1, 1))
  const gestureRef = useRef(createGestureState())
  const historyRef = useRef<HistoryPoint[]>([])
  const lastSampleRef = useRef<HandSample | null>(null)
  const rafRef = useRef(0)
  const lastTsRef = useRef(0)

  useEffect(() => {
    if (!active) return

    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      const w = window.innerWidth
      const h = window.innerHeight
      canvas.width = Math.floor(w * dpr)
      canvas.height = Math.floor(h * dpr)
      canvas.style.width = `${w}px`
      canvas.style.height = `${h}px`
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      resizeGame(gameRef.current, w, h)
    }

    resize()
    window.addEventListener('resize', resize)

    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Space') {
        e.preventDefault()
        const sample = lastSampleRef.current
        const g = gameRef.current
        if (g.gameOver) {
          restartGame(g)
          return
        }
        const open = gestureRef.current.openness || 0.7
        castFireball(g, sample?.palm ?? { x: 0.5, y: 0.7 }, open)
        gestureRef.current.phase = 'cooldown'
        gestureRef.current.cooldownMs = 200
      }
      if (e.code === 'KeyR') {
        restartGame(gameRef.current)
      }
    }

    const onClick = () => {
      if (gameRef.current.gameOver) restartGame(gameRef.current)
    }

    window.addEventListener('keydown', onKey)
    canvas.addEventListener('click', onClick)

    const loop = (ts: number) => {
      const last = lastTsRef.current || ts
      const dt = Math.min(0.05, (ts - last) / 1000)
      lastTsRef.current = ts

      const video = videoRef.current
      const game = gameRef.current
      const gesture = gestureRef.current

      let sample: HandSample | null = null
      if (video) {
        const detected = detect(video, ts)
        if (detected) {
          sample = detected
          lastSampleRef.current = detected
        } else {
          const prev = lastSampleRef.current
          if (prev && ts - prev.timestamp < 140) sample = prev
          else lastSampleRef.current = null
        }
      }

      const didCast = updateGesture(
        gesture,
        sample,
        historyRef.current,
        dt,
        ts,
      )
      if (didCast && sample) {
        castFireball(game, sample.palm, gesture.openness)
      }

      updateGame(game, dt)

      clearStage(ctx, game.width, game.height)
      drawVignette(ctx, game.width, game.height)
      if (sample) drawHand(ctx, sample, game.width, game.height, gesture)
      drawGame(ctx, game, gesture)

      // SVG flame layer
      const fx = flameRef.current
      if (fx) {
        if (sample && gesture.openness > 0.04) {
          fx.syncPalm(
            true,
            sample.palm.x * game.width,
            sample.palm.y * game.height,
            gesture.openness,
          )
        } else {
          fx.syncPalm(false, game.width * 0.5, game.height * 0.7, 0)
        }
        fx.syncFireballs(game.fireballs)
      }

      rafRef.current = requestAnimationFrame(loop)
    }

    rafRef.current = requestAnimationFrame(loop)

    return () => {
      cancelAnimationFrame(rafRef.current)
      window.removeEventListener('resize', resize)
      window.removeEventListener('keydown', onKey)
      canvas.removeEventListener('click', onClick)
      lastTsRef.current = 0
    }
  }, [active, detect, videoRef])

  return (
    <>
      <canvas ref={canvasRef} className="game-canvas" />
      <FlameLayer ref={flameRef} />
    </>
  )
}
