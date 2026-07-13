export type SpellType = 'fire' | 'frost' | 'lightning'

export const SPELL_ORDER: SpellType[] = ['fire', 'frost', 'lightning']

export interface SpellDef {
  id: SpellType
  name: string
  castName: string
  /** Primary particle / burst color */
  color: string
  /** Secondary accent */
  accent: string
  /** Core bright color */
  core: string
  /** HUD badge */
  badge: string
}

export const SPELLS: Record<SpellType, SpellDef> = {
  fire: {
    id: 'fire',
    name: '火球',
    castName: '火球术！',
    color: '#ff6a00',
    accent: '#ffb347',
    core: '#fff6c8',
    badge: '🔥',
  },
  frost: {
    id: 'frost',
    name: '寒冰',
    castName: '寒冰箭！',
    color: '#3dbbff',
    accent: '#9ae6ff',
    core: '#e8fbff',
    badge: '❄️',
  },
  lightning: {
    id: 'lightning',
    name: '雷电',
    castName: '闪电链！',
    color: '#a78bfa',
    accent: '#fde047',
    core: '#f5f3ff',
    badge: '⚡',
  },
}

export function nextSpell(current: SpellType): SpellType {
  const i = SPELL_ORDER.indexOf(current)
  return SPELL_ORDER[(i + 1) % SPELL_ORDER.length]
}

export function spellLabel(spell: SpellType): string {
  return SPELLS[spell].name
}
