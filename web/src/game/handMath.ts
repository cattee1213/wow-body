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
  const palm: Point2D = {
    x: (wrist.x + middleMcp.x) / 2,
    y: (wrist.y + middleMcp.y) / 2,
  }

  // Openness: fingertip distance from palm, relative to hand size.
  const handSize = Math.max(dist(wrist, middleMcp), 0.02)
  let tipSum = 0
  for (const tip of FINGER_TIPS) {
    tipSum += dist(landmarks[tip], palm)
  }
  const openness = Math.min(1.4, tipSum / (FINGER_TIPS.length * handSize)) / 1.4

  const depth = raw[LM.MIDDLE_MCP]?.z ?? 0

  return { palm, openness, depth, landmarks, timestamp }
}
