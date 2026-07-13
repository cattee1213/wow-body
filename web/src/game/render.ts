import { getHandConnections } from './handMath'
import type { GameState, GestureState, HandSample } from '../types'

export function clearStage(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
) {
  ctx.clearRect(0, 0, width, height)
}

export function drawVignette(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
) {
  const g = ctx.createRadialGradient(
    width / 2,
    height / 2,
    Math.min(width, height) * 0.2,
    width / 2,
    height / 2,
    Math.max(width, height) * 0.7,
  )
  g.addColorStop(0, 'rgba(10, 8, 16, 0.15)')
  g.addColorStop(1, 'rgba(6, 4, 10, 0.72)')
  ctx.fillStyle = g
  ctx.fillRect(0, 0, width, height)
}

export function drawHand(
  ctx: CanvasRenderingContext2D,
  sample: HandSample,
  width: number,
  height: number,
  gesture: GestureState,
) {
  const pts = sample.landmarks.map((p) => ({
    x: p.x * width,
    y: p.y * height,
  }))

  ctx.lineWidth = 3
  ctx.strokeStyle =
    gesture.phase === 'charging'
      ? `rgba(255, 170, 60, ${0.45 + gesture.charge * 0.55})`
      : 'rgba(120, 200, 255, 0.75)'
  ctx.beginPath()
  for (const [a, b] of getHandConnections()) {
    const pa = pts[a]
    const pb = pts[b]
    ctx.moveTo(pa.x, pa.y)
    ctx.lineTo(pb.x, pb.y)
  }
  ctx.stroke()

  for (const p of pts) {
    ctx.beginPath()
    ctx.fillStyle = 'rgba(255, 240, 210, 0.95)'
    ctx.arc(p.x, p.y, 3.5, 0, Math.PI * 2)
    ctx.fill()
  }

  // Charge orb at palm
  const palmX = sample.palm.x * width
  const palmY = sample.palm.y * height
  if (gesture.phase === 'charging' || gesture.charge > 0.05) {
    const r = 12 + gesture.charge * 28
    const glow = ctx.createRadialGradient(palmX, palmY, 2, palmX, palmY, r)
    glow.addColorStop(0, `rgba(255, 220, 120, ${0.55 + gesture.charge * 0.4})`)
    glow.addColorStop(0.45, `rgba(255, 120, 20, ${0.35 + gesture.charge * 0.3})`)
    glow.addColorStop(1, 'rgba(255, 60, 0, 0)')
    ctx.fillStyle = glow
    ctx.beginPath()
    ctx.arc(palmX, palmY, r, 0, Math.PI * 2)
    ctx.fill()
  }
}

export function drawGame(
  ctx: CanvasRenderingContext2D,
  state: GameState,
  gesture: GestureState,
) {
  const shakeX =
    state.shake > 0 ? (Math.random() - 0.5) * state.shake * 18 : 0
  const shakeY =
    state.shake > 0 ? (Math.random() - 0.5) * state.shake * 18 : 0

  ctx.save()
  ctx.translate(shakeX, shakeY)

  // Arena floor glow
  const floor = ctx.createLinearGradient(0, state.height * 0.55, 0, state.height)
  floor.addColorStop(0, 'rgba(40, 20, 10, 0)')
  floor.addColorStop(1, 'rgba(80, 30, 10, 0.25)')
  ctx.fillStyle = floor
  ctx.fillRect(0, state.height * 0.55, state.width, state.height * 0.45)

  // Monsters
  for (const m of state.monsters) {
    drawMonster(ctx, m)
  }

  // Fireballs
  for (const f of state.fireballs) {
    const t = f.life / f.maxLife
    const g = ctx.createRadialGradient(f.x, f.y, 2, f.x, f.y, f.radius * 1.6)
    g.addColorStop(0, `rgba(255, 250, 200, ${0.95 * t})`)
    g.addColorStop(0.35, `rgba(255, 160, 40, ${0.85 * t})`)
    g.addColorStop(1, 'rgba(255, 40, 0, 0)')
    ctx.fillStyle = g
    ctx.beginPath()
    ctx.arc(f.x, f.y, f.radius * 1.6, 0, Math.PI * 2)
    ctx.fill()

    ctx.fillStyle = `rgba(255, 240, 180, ${0.9 * t})`
    ctx.beginPath()
    ctx.arc(f.x, f.y, f.radius * 0.45, 0, Math.PI * 2)
    ctx.fill()
  }

  // Particles
  for (const p of state.particles) {
    const alpha = Math.max(0, p.life / p.maxLife)
    ctx.globalAlpha = alpha
    ctx.fillStyle = p.color
    ctx.beginPath()
    ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2)
    ctx.fill()
  }
  ctx.globalAlpha = 1

  ctx.restore()

  drawHud(ctx, state, gesture)
}

function drawMonster(
  ctx: CanvasRenderingContext2D,
  m: {
    x: number
    y: number
    radius: number
    hp: number
    maxHp: number
    hitFlash: number
  },
) {
  const flash = m.hitFlash > 0
  const body = ctx.createRadialGradient(
    m.x,
    m.y - m.radius * 0.2,
    m.radius * 0.2,
    m.x,
    m.y,
    m.radius,
  )
  body.addColorStop(0, flash ? '#ffd0d0' : '#6b3fa0')
  body.addColorStop(0.55, flash ? '#ff6b6b' : '#3a1d5c')
  body.addColorStop(1, '#120818')

  ctx.fillStyle = body
  ctx.beginPath()
  ctx.ellipse(m.x, m.y, m.radius * 0.95, m.radius * 1.05, 0, 0, Math.PI * 2)
  ctx.fill()

  // Horns
  ctx.fillStyle = flash ? '#ffaaaa' : '#c9a227'
  ctx.beginPath()
  ctx.moveTo(m.x - m.radius * 0.45, m.y - m.radius * 0.55)
  ctx.lineTo(m.x - m.radius * 0.7, m.y - m.radius * 1.15)
  ctx.lineTo(m.x - m.radius * 0.1, m.y - m.radius * 0.65)
  ctx.fill()
  ctx.beginPath()
  ctx.moveTo(m.x + m.radius * 0.45, m.y - m.radius * 0.55)
  ctx.lineTo(m.x + m.radius * 0.7, m.y - m.radius * 1.15)
  ctx.lineTo(m.x + m.radius * 0.1, m.y - m.radius * 0.65)
  ctx.fill()

  // Eyes
  ctx.fillStyle = '#ff3b3b'
  ctx.beginPath()
  ctx.arc(m.x - m.radius * 0.28, m.y - m.radius * 0.1, 4, 0, Math.PI * 2)
  ctx.arc(m.x + m.radius * 0.28, m.y - m.radius * 0.1, 4, 0, Math.PI * 2)
  ctx.fill()

  // HP bar
  const barW = m.radius * 1.6
  const barH = 6
  const bx = m.x - barW / 2
  const by = m.y - m.radius - 16
  ctx.fillStyle = 'rgba(0,0,0,0.55)'
  ctx.fillRect(bx, by, barW, barH)
  ctx.fillStyle = '#e74c3c'
  ctx.fillRect(bx, by, barW * (m.hp / m.maxHp), barH)
  ctx.strokeStyle = 'rgba(255,255,255,0.35)'
  ctx.strokeRect(bx, by, barW, barH)
}

function drawHud(
  ctx: CanvasRenderingContext2D,
  state: GameState,
  gesture: GestureState,
) {
  const pad = 16
  ctx.font = '600 16px system-ui, sans-serif'
  ctx.fillStyle = 'rgba(0,0,0,0.45)'
  ctx.fillRect(pad - 8, pad - 10, 220, 92)
  ctx.fillStyle = '#f6e7c1'
  ctx.fillText(`分数 ${state.score}`, pad, pad + 12)
  ctx.fillText(`击杀 ${state.kills}  ·  波次 ${state.wave}`, pad, pad + 36)

  // Player HP hearts
  ctx.fillText('生命', pad, pad + 62)
  for (let i = 0; i < state.maxPlayerHp; i++) {
    ctx.fillStyle = i < state.playerHp ? '#ff5a5a' : 'rgba(255,255,255,0.2)'
    ctx.beginPath()
    ctx.arc(pad + 52 + i * 18, pad + 57, 6, 0, Math.PI * 2)
    ctx.fill()
  }

  // Gesture strip
  const gx = state.width - 180
  ctx.fillStyle = 'rgba(0,0,0,0.45)'
  ctx.fillRect(gx - 8, pad - 10, 172, 78)
  ctx.fillStyle = '#f6e7c1'
  ctx.fillText(`状态 ${labelPhase(gesture.phase)}`, gx, pad + 12)
  ctx.fillStyle = 'rgba(255,255,255,0.2)'
  ctx.fillRect(gx, pad + 28, 140, 10)
  ctx.fillStyle = '#ff9f1c'
  ctx.fillRect(gx, pad + 28, 140 * gesture.charge, 10)
  ctx.fillStyle = '#9aa3b2'
  ctx.font = '12px system-ui, sans-serif'
  ctx.fillText(
    `开掌 ${gesture.debug.openness.toFixed(2)}  速度 ${gesture.debug.speed.toFixed(2)}`,
    gx,
    pad + 56,
  )

  if (state.messageTtl > 0 && state.message) {
    ctx.font = '700 22px system-ui, sans-serif'
    ctx.textAlign = 'center'
    ctx.fillStyle = 'rgba(0,0,0,0.5)'
    const text = state.message
    const tw = ctx.measureText(text).width
    ctx.fillRect(state.width / 2 - tw / 2 - 16, state.height * 0.42 - 28, tw + 32, 44)
    ctx.fillStyle = '#ffd27a'
    ctx.fillText(text, state.width / 2, state.height * 0.42)
    ctx.textAlign = 'left'
  }

  if (state.gameOver) {
    ctx.fillStyle = 'rgba(0,0,0,0.55)'
    ctx.fillRect(0, 0, state.width, state.height)
    ctx.textAlign = 'center'
    ctx.fillStyle = '#ffb347'
    ctx.font = '800 36px system-ui, sans-serif'
    ctx.fillText('战败', state.width / 2, state.height / 2 - 10)
    ctx.fillStyle = '#f6e7c1'
    ctx.font = '16px system-ui, sans-serif'
    ctx.fillText(
      `分数 ${state.score} · 击杀 ${state.kills} · 点击或按 R 重开`,
      state.width / 2,
      state.height / 2 + 28,
    )
    ctx.textAlign = 'left'
  }
}

function labelPhase(phase: GestureState['phase']): string {
  switch (phase) {
    case 'idle':
      return '待机'
    case 'charging':
      return '蓄力'
    case 'cast':
      return '施法'
    case 'cooldown':
      return '冷却'
  }
}
