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
} as const

const FINGER_TIPS = [
  LM.THUMB_TIP,
  LM.INDEX_TIP,
  LM.MIDDLE_TIP,
  LM.RING_TIP,
  LM.PINKY_TIP,
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
  const dx = a.x - b.x
  const dy = a.y - b.y
  return Math.hypot(dx, dy)
}

function clamp(v: number, min: number, max: number) {
  return Math.max(min, Math.min(max, v))
}

/**
 * Convert MediaPipe landmarks (image space) to selfie-mirrored normalized points.
 * Video is drawn with scaleX(-1), so we mirror x to keep overlay aligned.
 */
export function landmarksToSample(
  raw: Array<{ x: number; y: number; z: number }>,
  timestamp: number,
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

  // Hand size: palm span — grows when hand moves toward the camera.
  const handSize = Math.max(
    dist(wrist, middleMcp),
    dist(indexMcp, pinkyMcp),
    0.015,
  )

  // Openness: fingertip distance from palm, relative to hand size.
  let tipSum = 0
  for (const tip of FINGER_TIPS) {
    tipSum += dist(landmarks[tip], palm)
  }
  const rawOpen = tipSum / (FINGER_TIPS.length * handSize)
  // Soft curve so partial open already reads as charging.
  const openness = clamp((rawOpen - 0.55) / 1.35, 0, 1)

  const depth = raw[LM.MIDDLE_MCP]?.z ?? 0

  return { palm, openness, handSize, depth, landmarks, timestamp }
}
