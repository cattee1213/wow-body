import { useCallback, useEffect, useRef, useState } from 'react'
import { FilesetResolver, HandLandmarker } from '@mediapipe/tasks-vision'
import { landmarksToSample } from '../game/handMath'
import type { HandSample } from '../types'

const WASM_CDN =
  'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.21/wasm'
const MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task'

export interface UseHandLandmarkerResult {
  ready: boolean
  error: string | null
  detect: (video: HTMLVideoElement, timestampMs: number) => HandSample[]
}

export function useHandLandmarker(): UseHandLandmarkerResult {
  const landmarkerRef = useRef<HandLandmarker | null>(null)
  const [ready, setReady] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const lastVideoTimeRef = useRef(-1)
  const lastHandsRef = useRef<HandSample[]>([])

  useEffect(() => {
    let cancelled = false

    async function create(delegate: 'GPU' | 'CPU') {
      const vision = await FilesetResolver.forVisionTasks(WASM_CDN)
      return HandLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath: MODEL_URL,
          delegate,
        },
        runningMode: 'VIDEO',
        numHands: 2,
        minHandDetectionConfidence: 0.55,
        minHandPresenceConfidence: 0.55,
        minTrackingConfidence: 0.5,
      })
    }

    async function init() {
      try {
        const landmarker = await create('GPU')
        if (cancelled) {
          landmarker.close()
          return
        }
        landmarkerRef.current = landmarker
        setReady(true)
      } catch {
        try {
          const landmarker = await create('CPU')
          if (cancelled) {
            landmarker.close()
            return
          }
          landmarkerRef.current = landmarker
          setReady(true)
        } catch (fallbackErr) {
          const message =
            fallbackErr instanceof Error
              ? fallbackErr.message
              : '手部模型加载失败'
          if (!cancelled) setError(message)
        }
      }
    }

    void init()

    return () => {
      cancelled = true
      landmarkerRef.current?.close()
      landmarkerRef.current = null
    }
  }, [])

  const detect = useCallback(
    (video: HTMLVideoElement, timestampMs: number): HandSample[] => {
      const landmarker = landmarkerRef.current
      if (!landmarker || video.readyState < 2) return lastHandsRef.current

      // Skip duplicate video frames; keep last hands briefly for stability.
      if (video.currentTime === lastVideoTimeRef.current) {
        return lastHandsRef.current
      }
      lastVideoTimeRef.current = video.currentTime

      const result = landmarker.detectForVideo(video, timestampMs)
      const hands: HandSample[] = []

      for (let i = 0; i < result.landmarks.length; i++) {
        const lm = result.landmarks[i]
        if (!lm || lm.length < 21) continue
        const handed =
          result.handedness[i]?.[0]?.categoryName ??
          result.handedness[i]?.[0]?.displayName ??
          `Hand${i}`
        hands.push(landmarksToSample(lm, timestampMs, handed, true))
      }

      lastHandsRef.current = hands
      return hands
    },
    [],
  )

  return { ready, error, detect }
}
