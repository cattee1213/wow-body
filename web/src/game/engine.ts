import type { Fireball, GameState, Monster, Particle, Point2D } from '../types'
import { flameScaleFromOpenness } from './gesture'

const PLAYER_MAX_HP = 5
const MONSTER_BASE_HP = 3
const FIREBALL_SPEED = 820
const FIREBALL_RADIUS = 22

export function createGameState(width: number, height: number): GameState {
  return {
    width,
    height,
    monsters: [],
    fireballs: [],
    particles: [],
    score: 0,
    kills: 0,
    wave: 1,
    playerHp: PLAYER_MAX_HP,
    maxPlayerHp: PLAYER_MAX_HP,
    shake: 0,
    message: '张开手掌聚火，向前推掌发射火球！',
    messageTtl: 4,
    elapsed: 0,
    nextMonsterId: 1,
    nextFireballId: 1,
    nextParticleId: 1,
    spawnTimer: 0.6,
    gameOver: false,
  }
}

export function resizeGame(state: GameState, width: number, height: number) {
  state.width = width
  state.height = height
}

function spawnMonster(state: GameState) {
  const margin = 60
  const x = margin + Math.random() * Math.max(40, state.width - margin * 2)
  const y = 70 + Math.random() * Math.min(120, state.height * 0.18)
  const hp = MONSTER_BASE_HP + Math.floor((state.wave - 1) / 2)
  const monster: Monster = {
    id: state.nextMonsterId++,
    x,
    y,
    radius: 34 + Math.min(10, state.wave),
    hp,
    maxHp: hp,
    vx: (Math.random() < 0.5 ? -1 : 1) * (40 + state.wave * 8),
    hitFlash: 0,
  }
  state.monsters.push(monster)
}

export function castFireball(
  state: GameState,
  from: Point2D,
  openness = 0.7,
) {
  if (state.gameOver) return

  const originX = from.x * state.width
  const originY = from.y * state.height

  // Aim at nearest living monster; otherwise shoot straight up the lane.
  let targetX = originX
  let targetY = 40
  let best = Infinity
  for (const m of state.monsters) {
    if (m.hp <= 0) continue
    const d = Math.hypot(m.x - originX, m.y - originY)
    if (d < best) {
      best = d
      targetX = m.x
      targetY = m.y
    }
  }

  const dx = targetX - originX
  const dy = targetY - originY
  const len = Math.hypot(dx, dy) || 1
  const speed = FIREBALL_SPEED
  const birthScale = flameScaleFromOpenness(openness) * 0.85

  const ball: Fireball = {
    id: state.nextFireballId++,
    x: originX,
    y: originY,
    vx: (dx / len) * speed,
    vy: (dy / len) * speed,
    radius: FIREBALL_RADIUS * (0.75 + openness * 0.4),
    life: 2.2,
    maxLife: 2.2,
    birthScale,
    spin: Math.random() * 360,
  }
  state.fireballs.push(ball)
  burst(state, originX, originY, '#ffb347', 12)
  state.message = '火球术！'
  state.messageTtl = 0.7
}

function burst(
  state: GameState,
  x: number,
  y: number,
  color: string,
  count: number,
) {
  for (let i = 0; i < count; i++) {
    const angle = Math.random() * Math.PI * 2
    const speed = 40 + Math.random() * 180
    const p: Particle = {
      id: state.nextParticleId++,
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 0.35 + Math.random() * 0.35,
      maxLife: 0.7,
      color,
      size: 2 + Math.random() * 5,
    }
    state.particles.push(p)
  }
}

export function updateGame(state: GameState, dt: number) {
  if (state.gameOver) {
    state.shake = Math.max(0, state.shake - dt * 8)
    return
  }

  state.elapsed += dt
  state.shake = Math.max(0, state.shake - dt * 10)
  if (state.messageTtl > 0) state.messageTtl -= dt

  const targetCount = Math.min(2 + Math.floor(state.wave / 2), 6)
  state.spawnTimer -= dt
  if (state.monsters.length < targetCount && state.spawnTimer <= 0) {
    spawnMonster(state)
    state.spawnTimer = Math.max(0.8, 2.2 - state.wave * 0.12)
  }
  if (state.kills > 0 && state.kills % 5 === 0) {
    const expectedWave = 1 + Math.floor(state.kills / 5)
    if (expectedWave > state.wave) {
      state.wave = expectedWave
      state.message = `第 ${state.wave} 波来袭！`
      state.messageTtl = 2
    }
  }

  for (const m of state.monsters) {
    m.x += m.vx * dt
    if (m.x < m.radius || m.x > state.width - m.radius) {
      m.vx *= -1
      m.x = Math.max(m.radius, Math.min(state.width - m.radius, m.x))
    }
    m.hitFlash = Math.max(0, m.hitFlash - dt)
    m.y += 6 * dt
    if (m.y > state.height * 0.55) {
      state.playerHp -= 1
      state.shake = 0.5
      burst(state, m.x, m.y, '#ff4d4d', 14)
      m.hp = 0
      state.message = '怪物突破防线！'
      state.messageTtl = 1.2
    }
  }
  state.monsters = state.monsters.filter((m) => m.hp > 0)

  for (const f of state.fireballs) {
    f.x += f.vx * dt
    f.y += f.vy * dt
    f.life -= dt
    f.spin += 220 * dt

    for (const m of state.monsters) {
      const d = Math.hypot(f.x - m.x, f.y - m.y)
      if (d < f.radius + m.radius * 0.85) {
        m.hp -= 1
        m.hitFlash = 0.2
        f.life = 0
        burst(state, f.x, f.y, '#ff6a00', 18)
        state.score += 10
        if (m.hp <= 0) {
          state.kills += 1
          state.score += 40
          burst(state, m.x, m.y, '#ffd27a', 26)
          state.shake = 0.25
        }
        break
      }
    }
  }
  state.fireballs = state.fireballs.filter(
    (f) =>
      f.life > 0 &&
      f.x > -60 &&
      f.x < state.width + 60 &&
      f.y > -60 &&
      f.y < state.height + 60,
  )

  for (const p of state.particles) {
    p.x += p.vx * dt
    p.y += p.vy * dt
    p.vy += 120 * dt
    p.life -= dt
  }
  state.particles = state.particles.filter((p) => p.life > 0)

  if (state.playerHp <= 0) {
    state.playerHp = 0
    state.gameOver = true
    state.message = '你被击溃了 — 点击重新开始'
    state.messageTtl = 99
  }
}

export function restartGame(state: GameState) {
  const { width, height } = state
  Object.assign(state, createGameState(width, height))
}
