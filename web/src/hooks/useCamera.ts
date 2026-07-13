import { useCallback, useEffect, useRef, useState } from 'react'

export type CameraErrorKind = 'denied' | 'notfound' | 'insecure' | 'unknown'

export type CameraStartResult =
  | { ok: true }
  | { ok: false; kind: CameraErrorKind; message: string }

export interface UseCameraResult {
  videoRef: React.RefObject<HTMLVideoElement | null>
  stream: MediaStream | null
  error: CameraErrorKind | null
  errorMessage: string | null
  starting: boolean
  start: () => Promise<CameraStartResult>
  stop: () => void
}

function classifyError(err: unknown): { kind: CameraErrorKind; message: string } {
  if (!window.isSecureContext && location.hostname !== 'localhost') {
    return {
      kind: 'insecure',
      message: '摄像头需要 HTTPS 或 localhost。手机请用安全链接打开。',
    }
  }

  const name = err instanceof DOMException ? err.name : ''
  if (name === 'NotAllowedError' || name === 'PermissionDeniedError') {
    return { kind: 'denied', message: '摄像头权限被拒绝，请在浏览器设置中允许后重试。' }
  }
  if (name === 'NotFoundError' || name === 'DevicesNotFoundError') {
    return { kind: 'notfound', message: '未检测到可用摄像头。' }
  }
  if (name === 'NotReadableError') {
    return { kind: 'unknown', message: '摄像头正被其他应用占用。' }
  }
  const message = err instanceof Error ? err.message : '无法打开摄像头'
  return { kind: 'unknown', message }
}

export function useCamera(): UseCameraResult {
  const videoRef = useRef<HTMLVideoElement | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const [stream, setStream] = useState<MediaStream | null>(null)
  const [error, setError] = useState<CameraErrorKind | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [starting, setStarting] = useState(false)

  const stop = useCallback(() => {
    streamRef.current?.getTracks().forEach((t) => t.stop())
    streamRef.current = null
    setStream(null)
    if (videoRef.current) {
      videoRef.current.srcObject = null
    }
  }, [])

  const start = useCallback(async () => {
    setStarting(true)
    setError(null)
    setErrorMessage(null)

    try {
      if (!navigator.mediaDevices?.getUserMedia) {
        throw new Error('当前浏览器不支持 getUserMedia')
      }

      stop()

      const media = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          facingMode: 'user',
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      })

      streamRef.current = media
      setStream(media)

      const video = videoRef.current
      if (video) {
        video.srcObject = media
        video.playsInline = true
        video.muted = true
        await video.play()
      }

      setStarting(false)
      return { ok: true } satisfies CameraStartResult
    } catch (err) {
      const { kind, message } = classifyError(err)
      setError(kind)
      setErrorMessage(message)
      setStarting(false)
      return { ok: false, kind, message } satisfies CameraStartResult
    }
  }, [stop])

  useEffect(() => () => stop(), [stop])

  return { videoRef, stream, error, errorMessage, starting, start, stop }
}
