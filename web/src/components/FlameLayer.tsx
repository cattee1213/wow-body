import { forwardRef, useImperativeHandle, useRef } from 'react'
import { PalmFlameSvg } from './FlameSvg'
import { SPELLS, type SpellType } from '../game/spells'
import { palmEffectScale } from '../game/gesture'
import type { Projectile } from '../types'

export interface PalmFx {
  x: number
  y: number
  /** 0–1 charge */
  charge: number
  /** 0–1 openness */
  openness: number
  spell: SpellType
}

export interface FlameLayerHandle {
  syncPalms: (palms: PalmFx[]) => void
  syncProjectiles: (balls: Projectile[]) => void
  setSpell: (spell: SpellType) => void
}

/**
 * DOM/SVG VFX layer — updated from the game loop via refs.
 */
export const FlameLayer = forwardRef<FlameLayerHandle>(function FlameLayer(
  _props,
  ref,
) {
  const palmARef = useRef<HTMLDivElement | null>(null)
  const palmBRef = useRef<HTMLDivElement | null>(null)
  const palmSvgA = useRef<HTMLDivElement | null>(null)
  const palmSvgB = useRef<HTMLDivElement | null>(null)
  const rootRef = useRef<HTMLDivElement | null>(null)
  const ballEls = useRef<Map<number, HTMLDivElement>>(new Map())
  const spellRef = useRef<SpellType>('fire')

  useImperativeHandle(ref, () => ({
    setSpell(spell) {
      spellRef.current = spell
      // Force remount-like recolor by data attribute (CSS + inner swap)
      for (const wrap of [palmSvgA.current, palmSvgB.current]) {
        if (!wrap) continue
        wrap.dataset.spell = spell
        wrap.innerHTML = palmMarkup(spell)
      }
    },

    syncPalms(palms) {
      const nodes = [palmARef.current, palmBRef.current]
      for (let i = 0; i < nodes.length; i++) {
        const el = nodes[i]
        if (!el) continue
        const p = palms[i]
        if (!p || (p.charge < 0.03 && p.openness < 0.1)) {
          el.style.opacity = '0'
          el.style.transform =
            'translate(-9999px, -9999px) translate(-50%, -60%) scale(0.15)'
          continue
        }
        const scale = palmEffectScale(p.charge, p.openness)
        // Strong link: opacity also follows charge/open
        const strength = Math.max(p.charge, p.openness * 0.7)
        const opacity = Math.min(1, 0.2 + strength * 0.95)
        el.style.opacity = String(opacity)
        el.style.transform = `translate(${p.x}px, ${p.y}px) translate(-50%, -60%) scale(${scale})`
        el.style.filter = glowFor(p.spell, strength)
      }
    },

    syncProjectiles(balls) {
      const root = rootRef.current
      if (!root) return
      const live = new Set<number>()

      for (const b of balls) {
        live.add(b.id)
        let el = ballEls.current.get(b.id)
        if (!el) {
          el = document.createElement('div')
          el.className = `fireball-node fireball-node--${b.spell}`
          el.innerHTML = projectileMarkup(b.id, b.spell)
          root.appendChild(el)
          ballEls.current.set(b.id, el)
        }

        const lifeT = Math.max(0, b.life / b.maxLife)
        const scale = b.birthScale * (0.5 + lifeT * 0.6)
        el.style.transform = `translate(${b.x}px, ${b.y}px) translate(-50%, -50%) scale(${scale}) rotate(${b.spin}deg)`
        el.style.opacity = String(Math.min(1, lifeT * 1.25))
        el.style.filter = glowFor(b.spell, b.power)
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
      <div ref={palmARef} className="palm-flame-node">
        <div ref={palmSvgA} data-spell="fire" dangerouslySetInnerHTML={{ __html: palmMarkup('fire') }} />
      </div>
      <div ref={palmBRef} className="palm-flame-node">
        <div ref={palmSvgB} data-spell="fire" dangerouslySetInnerHTML={{ __html: palmMarkup('fire') }} />
      </div>
      {/* Keep React tree for types; hidden template not needed */}
      <div className="sr-only" aria-hidden>
        <PalmFlameSvg spell="fire" />
      </div>
      <div ref={rootRef} className="fireball-root" />
    </div>
  )
})

function glowFor(spell: SpellType, strength: number): string {
  const s = Math.max(0.2, Math.min(1, strength))
  const c =
    spell === 'frost'
      ? `rgba(80, 180, 255, ${0.45 + s * 0.4})`
      : spell === 'lightning'
        ? `rgba(180, 140, 255, ${0.45 + s * 0.4})`
        : `rgba(255, 120, 20, ${0.45 + s * 0.4})`
  return `drop-shadow(0 0 ${10 + s * 16}px ${c})`
}

function palmMarkup(spell: SpellType): string {
  const t = SPELLS[spell]
  const uid = `p-${spell}-${Math.random().toString(36).slice(2, 7)}`
  if (spell === 'lightning') {
    return `<svg class="palm-flame-svg" viewBox="0 0 120 140" width="120" height="140">
      <defs>
        <radialGradient id="${uid}c" cx="50%" cy="58%" r="45%">
          <stop offset="0%" stop-color="${t.core}"/><stop offset="55%" stop-color="${t.accent}"/>
          <stop offset="100%" stop-color="${t.color}" stop-opacity="0"/>
        </radialGradient>
      </defs>
      <g class="flame-wobble">
        <path class="flame-tongue flame-tongue--a" fill="${t.color}" opacity="0.9"
          d="M60 120 L48 78 L58 78 L42 40 L78 88 L64 88 L80 120 Z"/>
        <ellipse cx="60" cy="100" rx="26" ry="20" fill="url(#${uid}c)"/>
      </g>
    </svg>`
  }
  if (spell === 'frost') {
    return `<svg class="palm-flame-svg" viewBox="0 0 120 140" width="120" height="140">
      <defs>
        <radialGradient id="${uid}c" cx="50%" cy="58%" r="45%">
          <stop offset="0%" stop-color="${t.core}"/><stop offset="50%" stop-color="${t.accent}"/>
          <stop offset="100%" stop-color="${t.color}" stop-opacity="0"/>
        </radialGradient>
      </defs>
      <g class="flame-wobble">
        <path class="flame-tongue flame-tongue--a" fill="${t.accent}" opacity="0.85" d="M60 128 L48 70 L60 18 L72 70 Z"/>
        <path class="flame-tongue flame-tongue--b" fill="${t.color}" opacity="0.7" d="M38 105 L60 48 L82 105 L60 118 Z"/>
        <ellipse cx="60" cy="100" rx="28" ry="22" fill="url(#${uid}c)"/>
      </g>
    </svg>`
  }
  return `<svg class="palm-flame-svg" viewBox="0 0 120 140" width="120" height="140">
    <defs>
      <radialGradient id="${uid}c" cx="50%" cy="58%" r="45%">
        <stop offset="0%" stop-color="${t.core}"/><stop offset="40%" stop-color="${t.accent}"/>
        <stop offset="100%" stop-color="${t.color}" stop-opacity="0"/>
      </radialGradient>
      <linearGradient id="${uid}l" x1="50%" y1="100%" x2="50%" y2="0%">
        <stop offset="0%" stop-color="${t.accent}"/><stop offset="100%" stop-color="${t.color}" stop-opacity="0"/>
      </linearGradient>
    </defs>
    <g class="flame-wobble">
      <path class="flame-tongue flame-tongue--a" fill="url(#${uid}l)"
        d="M60 128 C38 110 28 88 34 64 C40 40 52 28 60 12 C68 28 80 40 86 64 C92 88 82 110 60 128 Z"/>
      <path class="flame-tongue flame-tongue--b" fill="url(#${uid}l)" opacity="0.85"
        d="M60 122 C46 108 40 90 44 70 C48 50 56 40 60 24 C64 40 72 50 76 70 C80 90 74 108 60 122 Z"/>
      <ellipse cx="60" cy="96" rx="28" ry="22" fill="url(#${uid}c)"/>
    </g>
  </svg>`
}

function projectileMarkup(id: number, spell: SpellType): string {
  const t = SPELLS[spell]
  const core = `bc-${id}`
  const halo = `bh-${id}`
  const glow = `bg-${id}`
  if (spell === 'lightning') {
    return `<svg class="fireball-svg" viewBox="0 0 100 100" width="100" height="100">
      <defs>
        <radialGradient id="${core}" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="${t.core}"/><stop offset="45%" stop-color="${t.accent}"/>
          <stop offset="100%" stop-color="${t.color}" stop-opacity="0"/>
        </radialGradient>
        <filter id="${glow}" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      <g class="fireball-spin" filter="url(#${glow})">
        <circle cx="50" cy="50" r="40" fill="url(#${core})" opacity="0.55"/>
        <path fill="${t.accent}" d="M52 12 L40 48 L52 48 L36 88 L68 44 L54 44 Z"/>
      </g>
    </svg>`
  }
  if (spell === 'frost') {
    return `<svg class="fireball-svg" viewBox="0 0 100 100" width="100" height="100">
      <defs>
        <radialGradient id="${core}" cx="42%" cy="40%" r="55%">
          <stop offset="0%" stop-color="${t.core}"/><stop offset="40%" stop-color="${t.accent}"/>
          <stop offset="100%" stop-color="${t.color}" stop-opacity="0"/>
        </radialGradient>
        <radialGradient id="${halo}" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="${t.accent}" stop-opacity="0.5"/>
          <stop offset="100%" stop-color="${t.color}" stop-opacity="0"/>
        </radialGradient>
        <filter id="${glow}" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="3.5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      <g class="fireball-spin" filter="url(#${glow})">
        <circle cx="50" cy="50" r="46" fill="url(#${halo})"/>
        <circle cx="50" cy="50" r="26" fill="url(#${core})"/>
        <path fill="${t.accent}" opacity="0.85" d="M50 18 L56 44 L82 50 L56 56 L50 82 L44 56 L18 50 L44 44 Z"/>
      </g>
    </svg>`
  }
  return `<svg class="fireball-svg" viewBox="0 0 100 100" width="100" height="100">
    <defs>
      <radialGradient id="${core}" cx="42%" cy="40%" r="55%">
        <stop offset="0%" stop-color="${t.core}"/><stop offset="28%" stop-color="${t.accent}"/>
        <stop offset="62%" stop-color="${t.color}"/><stop offset="100%" stop-color="#ff2200" stop-opacity="0"/>
      </radialGradient>
      <radialGradient id="${halo}" cx="50%" cy="50%" r="50%">
        <stop offset="0%" stop-color="#ff9a2e" stop-opacity="0.55"/>
        <stop offset="100%" stop-color="#ff3b00" stop-opacity="0"/>
      </radialGradient>
      <filter id="${glow}" x="-50%" y="-50%" width="200%" height="200%">
        <feGaussianBlur stdDeviation="3.5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
    </defs>
    <g class="fireball-spin" filter="url(#${glow})">
      <circle cx="50" cy="50" r="46" fill="url(#${halo})"/>
      <circle cx="50" cy="50" r="28" fill="url(#${core})"/>
      <path class="fireball-lick" fill="#ff6a00" opacity="0.75"
        d="M50 18 C42 30 38 40 40 50 C36 42 30 38 22 40 C32 34 40 26 50 18 Z"/>
      <circle cx="42" cy="42" r="7" fill="#fff6c8" opacity="0.9"/>
    </g>
  </svg>`
}
