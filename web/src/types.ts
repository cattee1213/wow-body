export type AppPhase = 'start' | 'loading' | 'playing' | 'denied' | 'error'

export type GesturePhase = 'idle' | 'charging' | 'cast' | 'cooldown'

export interface Point2D {
  x: number
  y: number
}

export interface HandSample {
  /** Normalized 0–1, already mirrored to match selfie video. */
  palm: Point2D
  /** 0 closed → 1 fully open. */
  openness: number
  /** Approximate hand span in normalized image space (grows when closer to camera). */
  handSize: number
  /** Depth relative to wrist (MediaPipe z). Smaller ≈ closer to camera. */
  depth: number
  landmarks: Point2D[]
  timestamp: number
}

export interface GestureState {
  phase: GesturePhase
  /** 0–1, driven by palm openness (for flame size / HUD). */
  charge: number
  /** Continuous palm openness (smoothed), drives flame scale. */
  openness: number
  cooldownMs: number
  lastCastAt: number
  debug: {
    openness: number
    /** Forward speed toward camera (higher = thrusting at camera). */
    forward: number
    handSize: number
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
  /** Initial visual scale for SVG (from palm flame size at cast). */
  birthScale: number
  spin: number
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
