import type { HandSample, Point2D } from '../types'

/** MediaPipe hand landmark indices. */
export const LM = {
  WRIST: 0,
  THUMB_TIP: 4,
  INDEX_TIP: 8,
  MIDDLE_TIP: 12,
  RING_TIP: 16,
  PINKY_TIP: 20,
  MIDDLE_MCP: 9,
  INDEX_MCP: 5,
  RING_MCP: 13,
  PINKY_MCP: 17,
  INDEX_PIP: 6,
  MIDDLE_PIP: 10,
  RING_PIP: 14,
  PINKY_PIP: 18,
} as const

const FINGER_TIPS = [
  LM.THUMB_TIP,
  LM.INDEX_TIP,
  LM.MIDDLE_TIP,
  LM.RING_TIP,
  LM.PINKY_TIP,
] as const

const FINGER_PIPS = [
  LM.INDEX_PIP,
  LM.MIDDLE_PIP,
  LM.RING_PIP,
  LM.PINKY_PIP,
] as const

const HAND_CONNECTIONS: Array<[number, number]> = [
  [0, 1],
  [1, 2],
  [2, 3],
  [3, 4],
  [0, 5],
  [5, 6],
  [6, 7],
  [7, 8],
  [0, 9],
  [9, 10],
  [10, 11],
  [11, 12],
  [0, 13],
  [13, 14],
  [14, 15],
  [15, 16],
  [0, 17],
  [17, 18],
  [18, 19],
  [19, 20],
  [5, 9],
  [9, 13],
  [13, 17],
]

export function getHandConnections(): Array<[number, number]> {
  return HAND_CONNECTIONS
}

function dist(a: Point2D, b: Point2D): number {
  return Math.hypot(a.x - b.x, a.y - b.y)
}

function clamp(v: number, min: number, max: number) {
  return Math.max(min, Math.min(max, v))
}

/**
 * Convert MediaPipe landmarks to selfie-mirrored normalized points.
 */
export function landmarksToSample(
  raw: Array<{ x: number; y: number; z: number }>,
  timestamp: number,
  handedness = 'Unknown',
  mirrorX = true,
): HandSample {
  const landmarks: Point2D[] = raw.map((p) => ({
    x: mirrorX ? 1 - p.x : p.x,
    y: p.y,
  }))

  const wrist = landmarks[LM.WRIST]
  const middleMcp = landmarks[LM.MIDDLE_MCP]
  const indexMcp = landmarks[LM.INDEX_MCP]
  const pinkyMcp = landmarks[LM.PINKY_MCP]

  const palm: Point2D = {
    x: (wrist.x + middleMcp.x + indexMcp.x + pinkyMcp.x) / 4,
    y: (wrist.y + middleMcp.y + indexMcp.y + pinkyMcp.y) / 4,
  }

  const handSize = Math.max(
    dist(wrist, middleMcp),
    dist(indexMcp, pinkyMcp),
    0.015,
  )

  // Tip spread relative to palm — wider dynamic range for charge/flame.
  let tipSum = 0
  for (const tip of FINGER_TIPS) {
    tipSum += dist(landmarks[tip], palm)
  }
  const rawOpen = tipSum / (FINGER_TIPS.length * handSize)
  // Map a broad physical range → 0..1 so small open changes still move the meter.
  const openness = clamp((rawOpen - 0.45) / 1.55, 0, 1)

  // Fist: fingertips curled near palm / PIP joints closer to wrist than tips would be open.
  let curled = 0
  for (let i = 0; i < FINGER_PIPS.length; i++) {
    const tip = landmarks[FINGER_TIPS[i + 1]] // index..pinky tips
    const pip = landmarks[FINGER_PIPS[i]]
    if (dist(tip, wrist) < dist(pip, wrist) * 1.15) curled += 1
  }
  // Thumb rough curl: tip near index MCP
  if (dist(landmarks[LM.THUMB_TIP], indexMcp) < handSize * 1.1) curled += 0.5

  const isFist = openness < 0.22 && curled >= 3

  // MediaPipe handedness is from camera view; after mirror, swap label for UI.
  let handLabel = handedness
  if (mirrorX) {
    if (handedness === 'Left') handLabel = 'Right'
    else if (handedness === 'Right') handLabel = 'Left'
  }

  return {
    palm,
    openness,
    isFist,
    handSize,
    depth: raw[LM.MIDDLE_MCP]?.z ?? 0,
    landmarks,
    handedness: handLabel,
    timestamp,
  }
}
