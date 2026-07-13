/** Animated SVG palm flame (charge). Size controlled by parent scale. */
export function PalmFlameSvg() {
  return (
    <svg
      className="palm-flame-svg"
      viewBox="0 0 120 140"
      width="120"
      height="140"
      aria-hidden
    >
      <defs>
        <radialGradient id="palmCore" cx="50%" cy="58%" r="45%">
          <stop offset="0%" stopColor="#fff6c8" stopOpacity="1" />
          <stop offset="35%" stopColor="#ffd36a" stopOpacity="0.95" />
          <stop offset="70%" stopColor="#ff7a18" stopOpacity="0.75" />
          <stop offset="100%" stopColor="#ff2a00" stopOpacity="0" />
        </radialGradient>
        <linearGradient id="palmLick" x1="50%" y1="100%" x2="50%" y2="0%">
          <stop offset="0%" stopColor="#ffb347" stopOpacity="0.9" />
          <stop offset="55%" stopColor="#ff5a00" stopOpacity="0.75" />
          <stop offset="100%" stopColor="#ff3b00" stopOpacity="0" />
        </linearGradient>
        <filter id="palmGlow" x="-40%" y="-40%" width="180%" height="180%">
          <feGaussianBlur stdDeviation="4" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      <g className="flame-wobble" filter="url(#palmGlow)">
        <path
          className="flame-tongue flame-tongue--a"
          fill="url(#palmLick)"
          d="M60 128 C38 110 28 88 34 64 C40 40 52 28 60 12 C68 28 80 40 86 64 C92 88 82 110 60 128 Z"
        />
        <path
          className="flame-tongue flame-tongue--b"
          fill="url(#palmLick)"
          opacity="0.85"
          d="M60 122 C46 108 40 90 44 70 C48 50 56 40 60 24 C64 40 72 50 76 70 C80 90 74 108 60 122 Z"
        />
        <ellipse cx="60" cy="96" rx="28" ry="22" fill="url(#palmCore)" />
        <circle className="flame-spark s1" cx="48" cy="70" r="3" fill="#ffe9a8" />
        <circle className="flame-spark s2" cx="72" cy="62" r="2.4" fill="#ffd27a" />
        <circle className="flame-spark s3" cx="60" cy="48" r="2" fill="#fff3c4" />
      </g>
    </svg>
  )
}

/** Animated SVG fireball projectile. */
export function FireballSvg() {
  return (
    <svg
      className="fireball-svg"
      viewBox="0 0 100 100"
      width="100"
      height="100"
      aria-hidden
    >
      <defs>
        <radialGradient id="ballCore" cx="42%" cy="40%" r="55%">
          <stop offset="0%" stopColor="#fff8d6" />
          <stop offset="28%" stopColor="#ffd36a" />
          <stop offset="62%" stopColor="#ff7a18" />
          <stop offset="100%" stopColor="#ff2200" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="ballHalo" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#ff9a2e" stopOpacity="0.55" />
          <stop offset="100%" stopColor="#ff3b00" stopOpacity="0" />
        </radialGradient>
        <filter id="ballGlow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="3.5" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      <g className="fireball-spin" filter="url(#ballGlow)">
        <circle cx="50" cy="50" r="46" fill="url(#ballHalo)" />
        <circle cx="50" cy="50" r="28" fill="url(#ballCore)" />
        <path
          className="fireball-lick"
          fill="#ff6a00"
          opacity="0.75"
          d="M50 18 C42 30 38 40 40 50 C36 42 30 38 22 40 C32 34 40 26 50 18 Z"
        />
        <path
          className="fireball-lick fireball-lick--2"
          fill="#ffb347"
          opacity="0.7"
          d="M50 22 C56 32 60 40 58 50 C64 44 72 40 80 44 C68 36 58 28 50 22 Z"
        />
        <circle cx="42" cy="42" r="7" fill="#fff6c8" opacity="0.9" />
      </g>
    </svg>
  )
}
