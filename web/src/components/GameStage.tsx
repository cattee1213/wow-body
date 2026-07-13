import { useEffect, useRef } from 'react'
import {
  castSpell,
  createGameState,
  restartGame,
  resizeGame,
  updateGame,
} from '../game/engine'
import {
  createGestureState,
  updateGesture,
  type HandHistoryMap,
} from '../game/gesture'
import { SPELLS } from '../game/spells'
import {
  clearStage,
  drawGame,
  drawHands,
  drawVignette,
} from '../game/render'
import type { HandSample } from '../types'
import { FlameLayer, type FlameLayerHandle, type PalmFx } from './FlameLayer'

interface GameStageProps {
  videoRef: React.RefObject<HTMLVideoElement | null>
  detect: (video: HTMLVideoElement, timestampMs: number) => HandSample[]
  active: boolean
}

export function GameStage({ videoRef, detect, active }: GameStageProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const flameRef = useRef<FlameLayerHandle | null>(null)
  const gameRef = useRef(createGameState(1, 1))
  const gestureRef = useRef(createGestureState())
  const historiesRef = useRef<HandHistoryMap>(new Map())
  const lastHandsRef = useRef<HandSample[]>([])
  const lastSpellRef = useRef(gestureRef.current.spell)
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
      const g = gameRef.current
      const gesture = gestureRef.current
      if (e.code === 'Space') {
        e.preventDefault()
        if (g.gameOver) {
          restartGame(g)
          return
        }
        const hands = lastHandsRef.current
        const open = hands.find((h) => !h.isFist) ?? hands[0]
        // Manual debug cast uses current charge (or 0.6)
        const power = Math.max(gesture.charge, 0.6)
        castSpell(g, open?.palm ?? { x: 0.5, y: 0.7 }, gesture.spell, power)
        gesture.charge = 0
        gesture.phase = 'cooldown'
        gesture.cooldownMs = 280
      }
      if (e.code === 'KeyR') restartGame(g)
      // Q cycle spell for keyboard debug
      if (e.code === 'KeyQ') {
        const order = ['fire', 'frost', 'lightning'] as const
        const i = order.indexOf(gesture.spell)
        gesture.spell = order[(i + 1) % order.length]
        g.message = `法术：${SPELLS[gesture.spell].name}`
        g.messageTtl = 1.2
        flameRef.current?.setSpell(gesture.spell)
      }
    }

    const onClick = () => {
      if (gameRef.current.gameOver) restartGame(gameRef.current)
    }

    window.addEventListener('keydown', onKey)
    canvas.addEventListener('click', onClick)

    // init palm spell art
    flameRef.current?.setSpell(gestureRef.current.spell)

    const loop = (ts: number) => {
      const last = lastTsRef.current || ts
      const dt = Math.min(0.05, (ts - last) / 1000)
      lastTsRef.current = ts

      const video = videoRef.current
      const game = gameRef.current
      const gesture = gestureRef.current

      let hands: HandSample[] = []
      if (video) {
        hands = detect(video, ts)
        if (hands.length > 0) lastHandsRef.current = hands
        else if (
          lastHandsRef.current.length > 0 &&
          ts - (lastHandsRef.current[0]?.timestamp ?? 0) < 140
        ) {
          hands = lastHandsRef.current
        } else {
          lastHandsRef.current = []
        }
      }

      const gest = updateGesture(
        gesture,
        hands,
        historiesRef.current,
        dt,
        ts,
      )

      if (gest.spellSwitched || lastSpellRef.current !== gesture.spell) {
        lastSpellRef.current = gesture.spell
        flameRef.current?.setSpell(gesture.spell)
        game.message = `切换法术：${SPELLS[gesture.spell].badge} ${SPELLS[gesture.spell].name}`
        game.messageTtl = 1.3
      }

      if (gest.cast && gest.castHand) {
        castSpell(
          game,
          gest.castHand.palm,
          gesture.spell,
          Math.max(0.2, gest.chargeUsed),
        )
      }

      updateGame(game, dt)

      clearStage(ctx, game.width, game.height)
      drawVignette(ctx, game.width, game.height)
      drawHands(ctx, hands, game.width, game.height, gesture)
      drawGame(ctx, game, gesture)

      const fx = flameRef.current
      if (fx) {
        const palms: PalmFx[] = hands
          .filter((h) => !h.isFist)
          .slice(0, 2)
          .map((h) => ({
            x: h.palm.x * game.width,
            y: h.palm.y * game.height,
            // 掌心特效强绑定该手开掌幅度 + 全局蓄力
            charge: Math.max(gesture.charge * (0.4 + h.openness * 0.6), h.openness * 0.85),
            openness: h.openness,
            spell: gesture.spell,
          }))
        // If only one open hand, still show charge on it; second slot empty
        fx.syncPalms(palms)
        fx.syncProjectiles(game.fireballs)
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
