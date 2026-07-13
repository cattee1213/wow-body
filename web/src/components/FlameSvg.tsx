import type { SpellType } from '../game/spells'

const THEME: Record<
  SpellType,
  { core: string; mid: string; outer: string; spark: string }
> = {
  fire: {
    core: '#fff6c8',
    mid: '#ffd36a',
    outer: '#ff7a18',
    spark: '#ffe9a8',
  },
  frost: {
    core: '#e8fbff',
    mid: '#9ae6ff',
    outer: '#3dbbff',
    spark: '#dbeafe',
  },
  lightning: {
    core: '#f5f3ff',
    mid: '#fde047',
    outer: '#a78bfa',
    spark: '#fef9c3',
  },
}

/** Animated palm charge effect; recolored by spell. */
export function PalmFlameSvg({ spell = 'fire' }: { spell?: SpellType }) {
  const t = THEME[spell]
  const uid = `palm-${spell}`

  return (
    <svg
      className={`palm-flame-svg palm-flame-svg--${spell}`}
      viewBox="0 0 120 140"
      width="120"
      height="140"
      aria-hidden
    >
      <defs>
        <radialGradient id={`${uid}-core`} cx="50%" cy="58%" r="45%">
          <stop offset="0%" stopColor={t.core} stopOpacity="1" />
          <stop offset="35%" stopColor={t.mid} stopOpacity="0.95" />
          <stop offset="70%" stopColor={t.outer} stopOpacity="0.75" />
          <stop offset="100%" stopColor={t.outer} stopOpacity="0" />
        </radialGradient>
        <linearGradient id={`${uid}-lick`} x1="50%" y1="100%" x2="50%" y2="0%">
          <stop offset="0%" stopColor={t.mid} stopOpacity="0.9" />
          <stop offset="55%" stopColor={t.outer} stopOpacity="0.75" />
          <stop offset="100%" stopColor={t.outer} stopOpacity="0" />
        </linearGradient>
        <filter id={`${uid}-glow`} x="-40%" y="-40%" width="180%" height="180%">
          <feGaussianBlur stdDeviation="4" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      <g className="flame-wobble" filter={`url(#${uid}-glow)`}>
        {spell === 'lightning' ? (
          <>
            <path
              className="flame-tongue flame-tongue--a"
              fill={t.outer}
              opacity="0.85"
              d="M60 120 L48 78 L58 78 L42 40 L78 88 L64 88 L80 120 Z"
            />
            <ellipse
              cx="60"
              cy="100"
              rx="26"
              ry="20"
              fill={`url(#${uid}-core)`}
            />
          </>
        ) : spell === 'frost' ? (
          <>
            <path
              className="flame-tongue flame-tongue--a"
              fill={`url(#${uid}-lick)`}
              d="M60 128 L48 70 L60 20 L72 70 Z"
            />
            <path
              className="flame-tongue flame-tongue--b"
              fill={t.mid}
              opacity="0.7"
              d="M40 100 L60 50 L80 100 L60 115 Z"
            />
            <ellipse
              cx="60"
              cy="100"
              rx="28"
              ry="22"
              fill={`url(#${uid}-core)`}
            />
          </>
        ) : (
          <>
            <path
              className="flame-tongue flame-tongue--a"
              fill={`url(#${uid}-lick)`}
              d="M60 128 C38 110 28 88 34 64 C40 40 52 28 60 12 C68 28 80 40 86 64 C92 88 82 110 60 128 Z"
            />
            <path
              className="flame-tongue flame-tongue--b"
              fill={`url(#${uid}-lick)`}
              opacity="0.85"
              d="M60 122 C46 108 40 90 44 70 C48 50 56 40 60 24 C64 40 72 50 76 70 C80 90 74 108 60 122 Z"
            />
            <ellipse
              cx="60"
              cy="96"
              rx="28"
              ry="22"
              fill={`url(#${uid}-core)`}
            />
          </>
        )}
        <circle className="flame-spark s1" cx="48" cy="70" r="3" fill={t.spark} />
        <circle className="flame-spark s2" cx="72" cy="62" r="2.4" fill={t.mid} />
        <circle className="flame-spark s3" cx="60" cy="48" r="2" fill={t.core} />
      </g>
    </svg>
  )
}
