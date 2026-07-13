export type AppPhase = 'start' | 'loading' | 'playing' | 'denied' | 'error'

export type GesturePhase = 'idle' | 'charging' | 'cast' | 'cooldown'

export interface Point2D {
  x: number
  y: number
}

export interface HandSample {
  /** Normalized 0–1, already mirrored to match selfie video. */
  palm: Point2D
  /** 0 open palm → 1 fist-ish openness inverse; higher = more open. */
  openness: number
  /** Depth relative to wrist (MediaPipe z). Smaller ≈ closer to camera. */
  depth: number
  landmarks: Point2D[]
  timestamp: number
}

export interface GestureState {
  phase: GesturePhase
  charge: number
  cooldownMs: number
  lastCastAt: number
  debug: {
    openness: number
    speed: number
    palmY: number
  }
}

export interface Fireball {
  id: number
  x: number
  y: number
  vx: number
  vy: number
  radius: number
  life: number
  maxLife: number
}

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
  fireballs: Fireball[]
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
