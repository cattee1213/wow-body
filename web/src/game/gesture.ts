import { nextSpell, type SpellType } from './spells'
import type { GestureState, HandSample } from '../types'

/** Open palm starts showing charge orb. */
const OPEN_CHARGE = 0.14
/** Must push forward this hard to manually release (no auto fire). */
const CAST_FORWARD = 0.55
/** Minimum charge before a forward push will release. */
const MIN_CAST_CHARGE = 0.12
/** Charge fill rate multiplier (openness * this * dt). Wider range = longer hold possible feel. */
const CHARGE_RATE = 0.85
/** How fast charge drains when palm closes (not on cast). */
const CHARGE_DECAY = 0.55
const COOLDOWN_MS = 320
const FIST_SWITCH_COOLDOWN_MS = 550
const HISTORY_MS = 160
const OPEN_SMOOTH = 14

export interface HistoryPoint {
  t: number
  handSize: number
  depth: number
}

export type HandHistoryMap = Map<string, HistoryPoint[]>

export function createGestureState(): GestureState {
  return {
    phase: 'idle',
    charge: 0,
    openness: 0,
    spell: 'fire',
    cooldownMs: 0,
    fistCooldownMs: 0,
    wasFist: false,
    lastCastAt: 0,
    debug: { openness: 0, forward: 0, handSize: 0, hands: 0, fist: false },
  }
}

export interface GestureUpdateResult {
  cast: boolean
  castHand: HandSample | null
  /** Charge consumed on this cast (0 if none). */
  chargeUsed: number
  spellSwitched: boolean
  spell: SpellType
}

/**
 * Multi-hand gesture FSM.
 * - Open palm: accumulate charge (does NOT auto-release at full)
 * - Forward push: manual release if charged
 * - Fist (edge): cycle spell 火球 → 寒冰 → 雷电
 */
export function updateGesture(
  state: GestureState,
  hands: HandSample[],
  histories: HandHistoryMap,
  dt: number,
  now: number,
): GestureUpdateResult {
  const result: GestureUpdateResult = {
    cast: false,
    castHand: null,
    chargeUsed: 0,
    spellSwitched: false,
    spell: state.spell,
  }

  if (state.cooldownMs > 0) {
    state.cooldownMs = Math.max(0, state.cooldownMs - dt * 1000)
    if (state.cooldownMs === 0 && state.phase === 'cooldown') {
      state.phase = state.charge > 0.05 ? 'charging' : 'idle'
    }
  }
  if (state.fistCooldownMs > 0) {
    state.fistCooldownMs = Math.max(0, state.fistCooldownMs - dt * 1000)
  }

  // Prune stale hand histories
  const liveKeys = new Set(hands.map(handKey))
  for (const key of histories.keys()) {
    if (!liveKeys.has(key)) histories.delete(key)
  }

  if (hands.length === 0) {
    state.openness = Math.max(0, state.openness - dt * 3)
    state.charge = Math.max(0, state.charge - CHARGE_DECAY * dt)
    if (state.phase !== 'cooldown') {
      state.phase = state.charge > 0.05 ? 'charging' : 'idle'
    }
    state.wasFist = false
    state.debug = {
      openness: state.openness,
      forward: 0,
      handSize: 0,
      hands: 0,
      fist: false,
    }
    return result
  }

  // —— Fist spell switch (any hand) ——
  const anyFist = hands.some((h) => h.isFist)
  if (
    anyFist &&
    !state.wasFist &&
    state.fistCooldownMs <= 0 &&
    state.phase !== 'cooldown'
  ) {
    state.spell = nextSpell(state.spell)
    state.fistCooldownMs = FIST_SWITCH_COOLDOWN_MS
    result.spellSwitched = true
    result.spell = state.spell
    // Fist clears charge slightly so you don't instantly fire after switch
    state.charge = Math.max(0, state.charge * 0.35)
  }
  state.wasFist = anyFist

  // Cast / charge hand: prefer most open non-fist hand
  const openHands = hands.filter((h) => !h.isFist)
  const castHand =
    openHands.sort((a, b) => b.openness - a.openness)[0] ?? null

  // Track openness of display hand (or fist hand for feedback)
  const display = castHand ?? hands[0]
  const k = 1 - Math.exp(-OPEN_SMOOTH * dt)
  state.openness += (display.openness - state.openness) * k

  let forward = 0
  if (castHand) {
    const key = handKey(castHand)
    let hist = histories.get(key)
    if (!hist) {
      hist = []
      histories.set(key, hist)
    }
    hist.push({
      t: castHand.timestamp,
      handSize: castHand.handSize,
      depth: castHand.depth,
    })
    const cutoff = castHand.timestamp - HISTORY_MS
    while (hist.length > 1 && hist[0].t < cutoff) hist.shift()

    if (hist.length >= 2) {
      const oldest = hist[0]
      const newest = hist[hist.length - 1]
      const elapsed = Math.max((newest.t - oldest.t) / 1000, 0.016)
      const sizeSpeed = (newest.handSize - oldest.handSize) / elapsed
      const depthSpeed = (oldest.depth - newest.depth) / elapsed
      forward = Math.max(sizeSpeed * 6.5, depthSpeed * 3.5, 0)
    }

    // Charge only while open — wider range: openness strongly drives fill rate
    if (castHand.openness >= OPEN_CHARGE && state.phase !== 'cooldown') {
      state.phase = 'charging'
      // Extra headroom: partial open still charges, full open charges fast
      const fill = 0.15 + castHand.openness * castHand.openness * 1.35
      state.charge = Math.min(1, state.charge + fill * CHARGE_RATE * dt)
    } else if (state.phase !== 'cooldown') {
      state.charge = Math.max(0, state.charge - CHARGE_DECAY * dt)
      if (state.charge <= 0.02) state.phase = 'idle'
    }

    // Manual release only — never auto-fire when full
    if (
      state.phase !== 'cooldown' &&
      state.charge >= MIN_CAST_CHARGE &&
      castHand.openness >= OPEN_CHARGE &&
      forward >= CAST_FORWARD
    ) {
      result.cast = true
      result.castHand = castHand
      result.chargeUsed = state.charge
      state.lastCastAt = now
      state.phase = 'cooldown'
      state.cooldownMs = COOLDOWN_MS
      // Consume charge on release
      state.charge = 0
    }
  } else {
    // Only fists visible — decay charge
    state.charge = Math.max(0, state.charge - CHARGE_DECAY * 1.2 * dt)
    if (state.phase !== 'cooldown' && state.charge <= 0.02) state.phase = 'idle'
  }

  state.debug = {
    openness: state.openness,
    forward,
    handSize: display.handSize,
    hands: hands.length,
    fist: anyFist,
  }

  return result
}

function handKey(h: HandSample): string {
  return h.handedness || 'Unknown'
}

/**
 * Palm effect scale: strongly tied to charge + openness (wide visual range).
 */
export function palmEffectScale(charge: number, openness: number): number {
  const c = Math.max(0, Math.min(1, charge))
  const o = Math.max(0, Math.min(1, openness))
  if (c < 0.02 && o < 0.08) return 0
  // Charge dominates size; openness adds extra amplitude
  const t = Math.max(c, o * 0.55)
  const eased = t * t * (3 - 2 * t) // smoothstep
  return 0.25 + eased * 2.35
}

/** @deprecated use palmEffectScale */
export function flameScaleFromOpenness(openness: number): number {
  return palmEffectScale(openness, openness)
}
