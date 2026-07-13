import { SPELLS } from './spells'
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
  g.addColorStop(0, 'rgba(10, 8, 16, 0.12)')
  g.addColorStop(1, 'rgba(6, 4, 10, 0.68)')
  ctx.fillStyle = g
  ctx.fillRect(0, 0, width, height)
}

export function drawHands(
  ctx: CanvasRenderingContext2D,
  hands: HandSample[],
  width: number,
  height: number,
  gesture: GestureState,
) {
  for (const sample of hands) {
    drawOneHand(ctx, sample, width, height, gesture)
  }
}

function drawOneHand(
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

  const spell = SPELLS[gesture.spell]
  ctx.lineWidth = sample.isFist ? 3.5 : 2.5
  if (sample.isFist) {
    ctx.strokeStyle = 'rgba(220, 220, 255, 0.85)'
  } else {
    const a = 0.35 + Math.max(gesture.charge, sample.openness) * 0.55
    ctx.strokeStyle = hexAlpha(spell.accent, a)
  }

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
    ctx.fillStyle = sample.isFist
      ? 'rgba(200, 210, 255, 0.95)'
      : 'rgba(255, 240, 210, 0.92)'
    ctx.arc(p.x, p.y, sample.isFist ? 4 : 3.2, 0, Math.PI * 2)
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

  const floor = ctx.createLinearGradient(0, state.height * 0.55, 0, state.height)
  floor.addColorStop(0, 'rgba(40, 20, 10, 0)')
  floor.addColorStop(1, 'rgba(80, 30, 10, 0.25)')
  ctx.fillStyle = floor
  ctx.fillRect(0, state.height * 0.55, state.width, state.height * 0.45)

  for (const m of state.monsters) {
    drawMonster(ctx, m)
  }

  for (const f of state.fireballs) {
    const t = f.life / f.maxLife
    const col = SPELLS[f.spell].color
    const g = ctx.createRadialGradient(f.x, f.y, 2, f.x, f.y, f.radius * 1.8)
    g.addColorStop(0, hexAlpha(col, 0.28 * t))
    g.addColorStop(1, hexAlpha(col, 0))
    ctx.fillStyle = g
    ctx.beginPath()
    ctx.arc(f.x, f.y, f.radius * 1.8, 0, Math.PI * 2)
    ctx.fill()
  }

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

  ctx.fillStyle = '#ff3b3b'
  ctx.beginPath()
  ctx.arc(m.x - m.radius * 0.28, m.y - m.radius * 0.1, 4, 0, Math.PI * 2)
  ctx.arc(m.x + m.radius * 0.28, m.y - m.radius * 0.1, 4, 0, Math.PI * 2)
  ctx.fill()

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

  ctx.fillText('生命', pad, pad + 62)
  for (let i = 0; i < state.maxPlayerHp; i++) {
    ctx.fillStyle = i < state.playerHp ? '#ff5a5a' : 'rgba(255,255,255,0.2)'
    ctx.beginPath()
    ctx.arc(pad + 52 + i * 18, pad + 57, 6, 0, Math.PI * 2)
    ctx.fill()
  }

  // Larger charge / spell panel (top-right)
  const panelW = 248
  const panelH = 128
  const gx = state.width - panelW - 12
  const gy = pad - 6
  const spell = SPELLS[gesture.spell]

  ctx.fillStyle = 'rgba(0,0,0,0.55)'
  roundRect(ctx, gx, gy, panelW, panelH, 12)
  ctx.fill()
  ctx.strokeStyle = hexAlpha(spell.accent, 0.45)
  ctx.lineWidth = 1.5
  ctx.stroke()

  ctx.font = '700 18px system-ui, sans-serif'
  ctx.fillStyle = spell.accent
  ctx.fillText(`${spell.badge} ${spell.name}`, gx + 14, gy + 28)

  ctx.font = '600 14px system-ui, sans-serif'
  ctx.fillStyle = '#f6e7c1'
  ctx.fillText(`状态 ${labelPhase(gesture.phase)}`, gx + 14, gy + 52)

  // Big charge bar
  const barX = gx + 14
  const barY = gy + 66
  const barW = panelW - 28
  const barH = 18
  ctx.fillStyle = 'rgba(255,255,255,0.12)'
  roundRect(ctx, barX, barY, barW, barH, 8)
  ctx.fill()

  const chargeW = barW * gesture.charge
  if (chargeW > 0) {
    const grad = ctx.createLinearGradient(barX, 0, barX + barW, 0)
    grad.addColorStop(0, spell.color)
    grad.addColorStop(1, spell.accent)
    ctx.fillStyle = grad
    roundRect(ctx, barX, barY, chargeW, barH, 8)
    ctx.fill()
  }
  ctx.strokeStyle = 'rgba(255,255,255,0.25)'
  ctx.lineWidth = 1
  roundRect(ctx, barX, barY, barW, barH, 8)
  ctx.stroke()

  ctx.font = '12px system-ui, sans-serif'
  ctx.fillStyle = '#c5c9d4'
  ctx.fillText(
    `蓄力 ${(gesture.charge * 100).toFixed(0)}%  ·  开掌 ${gesture.debug.openness.toFixed(2)}  ·  向前 ${gesture.debug.forward.toFixed(2)}`,
    gx + 14,
    gy + 104,
  )
  ctx.fillStyle = '#9aa3b2'
  ctx.fillText(
    `双手 ${gesture.debug.hands}  ·  握拳切法术  ·  推掌释放`,
    gx + 14,
    gy + 120,
  )

  if (state.messageTtl > 0 && state.message) {
    ctx.font = '700 22px system-ui, sans-serif'
    ctx.textAlign = 'center'
    ctx.fillStyle = 'rgba(0,0,0,0.5)'
    const text = state.message
    const tw = ctx.measureText(text).width
    ctx.fillRect(
      state.width / 2 - tw / 2 - 16,
      state.height * 0.42 - 28,
      tw + 32,
      44,
    )
    ctx.fillStyle = spell.accent
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
      return '蓄力中'
    case 'cooldown':
      return '冷却'
  }
}

function hexAlpha(hex: string, a: number): string {
  const h = hex.replace('#', '')
  const full =
    h.length === 3
      ? h
          .split('')
          .map((c) => c + c)
          .join('')
      : h
  const n = parseInt(full, 16)
  const r = (n >> 16) & 255
  const g = (n >> 8) & 255
  const b = n & 255
  return `rgba(${r},${g},${b},${a})`
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
) {
  const rr = Math.min(r, w / 2, h / 2)
  ctx.beginPath()
  ctx.moveTo(x + rr, y)
  ctx.arcTo(x + w, y, x + w, y + h, rr)
  ctx.arcTo(x + w, y + h, x, y + h, rr)
  ctx.arcTo(x, y + h, x, y, rr)
  ctx.arcTo(x, y, x + w, y, rr)
  ctx.closePath()
}
