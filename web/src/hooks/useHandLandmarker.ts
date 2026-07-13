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
  detect: (video: HTMLVideoElement, timestampMs: number) => HandSample | null
}

export function useHandLandmarker(): UseHandLandmarkerResult {
  const landmarkerRef = useRef<HandLandmarker | null>(null)
  const [ready, setReady] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const lastVideoTimeRef = useRef(-1)

  useEffect(() => {
    let cancelled = false

    async function init() {
      try {
        const vision = await FilesetResolver.forVisionTasks(WASM_CDN)
        const landmarker = await HandLandmarker.createFromOptions(vision, {
          baseOptions: {
            modelAssetPath: MODEL_URL,
            delegate: 'GPU',
          },
          runningMode: 'VIDEO',
          numHands: 1,
          minHandDetectionConfidence: 0.6,
          minHandPresenceConfidence: 0.6,
          minTrackingConfidence: 0.5,
        })
        if (cancelled) {
          landmarker.close()
          return
        }
        landmarkerRef.current = landmarker
        setReady(true)
      } catch (err) {
        // GPU may fail on some devices — retry CPU
        try {
          const vision = await FilesetResolver.forVisionTasks(WASM_CDN)
          const landmarker = await HandLandmarker.createFromOptions(vision, {
            baseOptions: {
              modelAssetPath: MODEL_URL,
              delegate: 'CPU',
            },
            runningMode: 'VIDEO',
            numHands: 1,
          })
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
              : err instanceof Error
                ? err.message
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
    (video: HTMLVideoElement, timestampMs: number): HandSample | null => {
      const landmarker = landmarkerRef.current
      if (!landmarker || video.readyState < 2) return null

      // MediaPipe requires strictly increasing timestamps; skip duplicate frames.
      if (video.currentTime === lastVideoTimeRef.current) return null
      lastVideoTimeRef.current = video.currentTime

      const result = landmarker.detectForVideo(video, timestampMs)
      const hand = result.landmarks[0]
      if (!hand || hand.length < 21) return null

      return landmarksToSample(hand, timestampMs, true)
    },
    [],
  )

  return { ready, error, detect }
}
