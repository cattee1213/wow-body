import type { SpellType } from './game/spells'

export type AppPhase = 'start' | 'loading' | 'playing' | 'denied' | 'error'

export type GesturePhase = 'idle' | 'charging' | 'cooldown'

export interface Point2D {
  x: number
  y: number
}

export interface HandSample {
  /** Normalized 0–1, already mirrored to match selfie video. */
  palm: Point2D
  /** 0 closed/fist → 1 fully open. */
  openness: number
  /** True when hand is a fist (spell switch). */
  isFist: boolean
  /** Approximate hand span in normalized image space. */
  handSize: number
  /** Depth relative to wrist (MediaPipe z). Smaller ≈ closer to camera. */
  depth: number
  landmarks: Point2D[]
  /** 'Left' | 'Right' | 'Unknown' from MediaPipe (image space, pre-mirror). */
  handedness: string
  timestamp: number
}

export interface GestureState {
  phase: GesturePhase
  /** Accumulated charge 0–1. Does NOT auto-release. */
  charge: number
  /** Smoothed openness of the active cast hand. */
  openness: number
  spell: SpellType
  cooldownMs: number
  fistCooldownMs: number
  wasFist: boolean
  lastCastAt: number
  debug: {
    openness: number
    forward: number
    handSize: number
    hands: number
    fist: boolean
  }
}

export interface Projectile {
  id: number
  spell: SpellType
  x: number
  y: number
  vx: number
  vy: number
  radius: number
  life: number
  maxLife: number
  /** Visual scale from charge at cast time. */
  birthScale: number
  /** 0–1 power from charge. */
  power: number
  spin: number
}

/** @deprecated alias kept for fewer renames in engine loop */
export type Fireball = Projectile

export interface Monster {
  id: number
  x: number
  y: number
  radius: number
  hp: number
  maxHp: number
  vx: number
  hitFlash: number
}

export interface Particle {
  id: number
  x: number
  y: number
  vx: number
  vy: number
  life: number
  maxLife: number
  color: string
  size: number
}

export interface GameState {
  width: number
  height: number
  monsters: Monster[]
  fireballs: Projectile[]
  particles: Particle[]
  score: number
  kills: number
  wave: number
  playerHp: number
  maxPlayerHp: number
  shake: number
  message: string
  messageTtl: number
  elapsed: number
  nextMonsterId: number
  nextFireballId: number
  nextParticleId: number
  spawnTimer: number
  gameOver: boolean
}
