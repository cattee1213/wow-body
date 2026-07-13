import type { GestureState, HandSample } from '../types'

const CHARGE_OPENNESS = 0.42
const CAST_SPEED = 1.15
const MIN_CHARGE = 0.55
const CHARGE_RATE = 1.8
const DISCHARGE_RATE = 1.2
const COOLDOWN_MS = 700
const HISTORY_MS = 180

interface HistoryPoint {
  t: number
  y: number
  depth: number
}

export function createGestureState(): GestureState {
  return {
    phase: 'idle',
    charge: 0,
    cooldownMs: 0,
    lastCastAt: 0,
    debug: { openness: 0, speed: 0, palmY: 0.5 },
  }
}

/**
 * Updates gesture FSM. Returns true on the frame a cast is triggered.
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
      state.charge = 0
    }
  }

  if (!sample) {
    if (state.phase === 'charging') {
      state.charge = Math.max(0, state.charge - DISCHARGE_RATE * dt)
      if (state.charge <= 0) state.phase = 'idle'
    }
    state.debug = { openness: 0, speed: 0, palmY: state.debug.palmY }
    return false
  }

  history.push({ t: sample.timestamp, y: sample.palm.y, depth: sample.depth })
  const cutoff = sample.timestamp - HISTORY_MS
  while (history.length > 1 && history[0].t < cutoff) history.shift()

  let speed = 0
  if (history.length >= 2) {
    const oldest = history[0]
    const newest = history[history.length - 1]
    const elapsed = Math.max((newest.t - oldest.t) / 1000, 0.016)
    // Up on screen (y decreases) + toward camera (depth decreases) both count as throw.
    const upSpeed = (oldest.y - newest.y) / elapsed
    const towardSpeed = (oldest.depth - newest.depth) / elapsed
    speed = Math.max(upSpeed, towardSpeed * 2.2, 0)
  }

  state.debug = {
    openness: sample.openness,
    speed,
    palmY: sample.palm.y,
  }

  if (state.phase === 'cooldown') return false

  const isOpen = sample.openness >= CHARGE_OPENNESS

  if (state.phase === 'idle' || state.phase === 'charging') {
    if (isOpen) {
      state.phase = 'charging'
      state.charge = Math.min(1, state.charge + CHARGE_RATE * dt)
    } else {
      state.charge = Math.max(0, state.charge - DISCHARGE_RATE * dt)
      if (state.charge <= 0) state.phase = 'idle'
    }
  }

  if (
    state.phase === 'charging' &&
    state.charge >= MIN_CHARGE &&
    speed >= CAST_SPEED
  ) {
    state.phase = 'cast'
    cast = true
    state.lastCastAt = now
    state.charge = 0
    state.phase = 'cooldown'
    state.cooldownMs = COOLDOWN_MS
  }

  return cast
}

export type { HistoryPoint }
