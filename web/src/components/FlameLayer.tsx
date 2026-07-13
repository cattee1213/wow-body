import { forwardRef, useImperativeHandle, useRef } from 'react'
import { PalmFlameSvg } from './FlameSvg'
import type { Fireball } from '../types'
import { flameScaleFromOpenness } from '../game/gesture'

export interface FlameLayerHandle {
  syncPalm: (
    visible: boolean,
    x: number,
    y: number,
    openness: number,
  ) => void
  syncFireballs: (balls: Fireball[]) => void
}

/**
 * DOM/SVG flame layer — updated from the game loop via refs (no React re-render).
 */
export const FlameLayer = forwardRef<FlameLayerHandle>(function FlameLayer(
  _props,
  ref,
) {
  const palmRef = useRef<HTMLDivElement | null>(null)
  const rootRef = useRef<HTMLDivElement | null>(null)
  const ballEls = useRef<Map<number, HTMLDivElement>>(new Map())

  useImperativeHandle(ref, () => ({
    syncPalm(visible, x, y, openness) {
      const el = palmRef.current
      if (!el) return
      if (!visible || openness < 0.05) {
        el.style.opacity = '0'
        el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -60%) scale(0.2)`
        return
      }
      // 开掌越大火焰越大（大↔小随张开程度连续变化）
      const scale = flameScaleFromOpenness(openness)
      const opacity = Math.min(1, 0.25 + openness * 0.9)
      el.style.opacity = String(opacity)
      el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -60%) scale(${scale})`
    },

    syncFireballs(balls) {
      const root = rootRef.current
      if (!root) return
      const live = new Set<number>()

      for (const b of balls) {
        live.add(b.id)
        let el = ballEls.current.get(b.id)
        if (!el) {
          el = document.createElement('div')
          el.className = 'fireball-node'
          el.innerHTML = fireballMarkup(b.id)
          root.appendChild(el)
          ballEls.current.set(b.id, el)
        }

        const lifeT = Math.max(0, b.life / b.maxLife)
        // 飞行中从大到小略收
        const scale = b.birthScale * (0.55 + lifeT * 0.55)
        el.style.transform = `translate(${b.x}px, ${b.y}px) translate(-50%, -50%) scale(${scale}) rotate(${b.spin}deg)`
        el.style.opacity = String(Math.min(1, lifeT * 1.2))
      }

      for (const [id, el] of ballEls.current) {
        if (!live.has(id)) {
          el.remove()
          ballEls.current.delete(id)
        }
      }
    },
  }))

  return (
    <div className="flame-layer" aria-hidden>
      <div ref={palmRef} className="palm-flame-node">
        <PalmFlameSvg />
      </div>
      <div ref={rootRef} className="fireball-root" />
    </div>
  )
})

/** Inline SVG string so fireballs can be cloned into DOM without React. */
function fireballMarkup(id: number): string {
  const core = `ballCore-${id}`
  const halo = `ballHalo-${id}`
  const glow = `ballGlow-${id}`
  return `<svg class="fireball-svg" viewBox="0 0 100 100" width="100" height="100" aria-hidden="true">
  <defs>
    <radialGradient id="${core}" cx="42%" cy="40%" r="55%">
      <stop offset="0%" stop-color="#fff8d6"/>
      <stop offset="28%" stop-color="#ffd36a"/>
      <stop offset="62%" stop-color="#ff7a18"/>
      <stop offset="100%" stop-color="#ff2200" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="${halo}" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#ff9a2e" stop-opacity="0.55"/>
      <stop offset="100%" stop-color="#ff3b00" stop-opacity="0"/>
    </radialGradient>
    <filter id="${glow}" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="3.5" result="b"/>
      <feMerge>
        <feMergeNode in="b"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <g class="fireball-spin" filter="url(#${glow})">
    <circle cx="50" cy="50" r="46" fill="url(#${halo})"/>
    <circle cx="50" cy="50" r="28" fill="url(#${core})"/>
    <path class="fireball-lick" fill="#ff6a00" opacity="0.75"
      d="M50 18 C42 30 38 40 40 50 C36 42 30 38 22 40 C32 34 40 26 50 18 Z"/>
    <path class="fireball-lick fireball-lick--2" fill="#ffb347" opacity="0.7"
      d="M50 22 C56 32 60 40 58 50 C64 44 72 40 80 44 C68 36 58 28 50 22 Z"/>
    <circle cx="42" cy="42" r="7" fill="#fff6c8" opacity="0.9"/>
  </g>
</svg>`
}