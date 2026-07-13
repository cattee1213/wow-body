import type { GestureState, HandSample } from '../types'

/** Soft open threshold — any half-open palm can charge / cast. */
const OPEN_VISIBLE = 0.12
/** Minimum openness required to fire (free cast, low bar). */
const CAST_OPENNESS = 0.18
/**
 * Forward thrust threshold (toward camera).
 * Uses hand-size growth (primary) + depth decrease (secondary).
 */
const CAST_FORWARD = 0.22
const COOLDOWN_MS = 220
const HISTORY_MS = 140
const OPEN_SMOOTH = 12

interface HistoryPoint {
  t: number
  handSize: number
  depth: number
}

export function createGestureState(): GestureState {
  return {
    phase: 'idle',
    charge: 0,
    openness: 0,
    cooldownMs: 0,
    lastCastAt: 0,
    debug: { openness: 0, forward: 0, handSize: 0 },
  }
}

/**
 * Updates gesture FSM. Returns true on the frame a cast is triggered.
 * Only forward (toward camera) counts — no upward swipe.
 */
export function updateGesture(
  state: GestureState,
  sample: HandSample | null,
  history: HistoryPoint[],
  dt: number,
  now: number,
): boolean {
  let cast = false

  if (state.phase === 'cooldown') {
    state.cooldownMs -= dt * 1000
    if (state.cooldownMs <= 0) {
      state.phase = 'idle'
      state.cooldownMs = 0
    }
  }

  if (!sample) {
    // Fade flame when hand lost
    state.openness = Math.max(0, state.openness - dt * 3)
    state.charge = state.openness
    if (state.phase === 'charging' && state.openness <= 0.02) {
      state.phase = 'idle'
    }
    state.debug = {
      openness: state.openness,
      forward: 0,
      handSize: state.debug.handSize,
    }
    return false
  }

  // Smooth openness for flame rendering
  const targetOpen = sample.openness
  const k = 1 - Math.exp(-OPEN_SMOOTH * dt)
  state.openness += (targetOpen - state.openness) * k
  // charge mirrors openness for HUD / free cast readiness
  state.charge = state.openness

  history.push({
    t: sample.timestamp,
    handSize: sample.handSize,
    depth: sample.depth,
  })
  const cutoff = sample.timestamp - HISTORY_MS
  while (history.length > 1 && history[0].t < cutoff) history.shift()

  let forward = 0
  if (history.length >= 2) {
    const oldest = history[0]
    const newest = history[history.length - 1]
    const elapsed = Math.max((newest.t - oldest.t) / 1000, 0.016)
    // Hand grows on screen when moving toward camera
    const sizeSpeed = (newest.handSize - oldest.handSize) / elapsed
    // Depth decreases when moving toward camera (scale up — z is small)
    const depthSpeed = (oldest.depth - newest.depth) / elapsed
    forward = Math.max(sizeSpeed * 6.5, depthSpeed * 3.5, 0)
  }

  state.debug = {
    openness: state.openness,
    forward,
    handSize: sample.handSize,
  }

  if (state.phase === 'cooldown') return false

  if (state.openness >= OPEN_VISIBLE) {
    state.phase = 'charging'
  } else if (state.phase === 'charging') {
    state.phase = 'idle'
  }

  // Free cast: open enough + push toward camera — no long charge gate
  if (
    state.phase === 'charging' &&
    state.openness >= CAST_OPENNESS &&
    forward >= CAST_FORWARD
  ) {
    cast = true
    state.lastCastAt = now
    state.phase = 'cooldown'
    state.cooldownMs = COOLDOWN_MS
  }

  return cast
}

export type { HistoryPoint }

/**
 * Palm flame visual scale from openness.
 * 张开程度高 → 火焰更大；闭合时缩小到几乎看不见。
 * （尺寸在「大 ↔ 小」间随开掌连续变化）
 */
export function flameScaleFromOpenness(openness: number): number {
  if (openness < 0.05) return 0
  // Ease-out so early open already shows a solid flame
  const t = Math.min(1, openness)
  const eased = 1 - (1 - t) * (1 - t)
  return 0.35 + eased * 1.35
}
