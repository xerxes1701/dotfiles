// The status line's look (statusline.mjs in the status-band package) and the
// plain parsing the band needs: colours, icons, model names, git's porcelain
// status, ages. Keep the colours and icons in step with statusline.mjs.
import type { GitCounts, GitInfo } from '../types'

export type Rgb = readonly [number, number, number]

// Muted colours on the prompt's One Half Dark: a coloured band has one
// brightness and a text of its own hue at 4.6 against it.
export const BANDS = {
  green: { bg: [72, 96, 64], text: [181, 222, 167] },
  lime: { bg: [87, 93, 62], text: [205, 217, 155] },
  yellow: { bg: [96, 89, 64], text: [222, 210, 168] },
  orange: { bg: [106, 85, 71], text: [230, 205, 188] },
  red: { bg: [118, 79, 84], text: [235, 202, 207] },
  blue: { bg: [72, 92, 109], text: [193, 213, 231] },
  cyan: { bg: [65, 94, 98], text: [171, 218, 223] },
  grey: { bg: [86, 90, 97], text: [208, 211, 215] },
  purple: { bg: [101, 81, 121], text: [220, 204, 236] },
} as const satisfies Record<string, { bg: Rgb; text: Rgb }>
export type BandName = keyof typeof BANDS

export const COLORS = {
  surface: [62, 68, 81], deep: [53, 58, 69], overlay: [90, 99, 116],
  subtext: [175, 179, 187], red: [213, 167, 171], orange: [201, 174, 147], yellow: [215, 193, 152],
  green: [161, 186, 142], cyan: [140, 187, 193], blue: [143, 183, 215], purple: [201, 167, 211],
} as const satisfies Record<string, Rgb>

export const hex = (rgb: Rgb): string => `#${rgb.map(x => x.toString(16).padStart(2, '0')).join('')}`
export const mix = (a: Rgb, b: Rgb, t: number): Rgb =>
  [0, 1, 2].map(i => Math.round(a[i]! + (b[i]! - a[i]!) * t)) as unknown as Rgb

export const MODEL_SCALE: Record<string, BandName> = { haiku: 'green', sonnet: 'yellow', opus: 'orange', fable: 'red' }
export const EFFORT_SCALE: Record<string, BandName> = { low: 'green', medium: 'lime', high: 'yellow', xhigh: 'orange', max: 'red' }
export const EFFORTS = ['low', 'medium', 'high', 'xhigh', 'max'] as const

const cp = (code: number) => String.fromCodePoint(code)
export const ICON = {
  capLeft: cp(0xe0b6), arrow: cp(0xe0b0), thinArrow: cp(0xe0b1),
  model: cp(0xf06c4), folder: cp(0xf024b), branch: cp(0xf418), commit: cp(0xf417), context: cp(0xf035b),
  fiveHour: cp(0xf0150), weekly: cp(0xf0a33), style: cp(0xf03d8), session: cp(0xf0ede), vim: cp(0xe7c5),
  ahead: cp(0xf19b2), behind: cp(0xf19b3),
}
export const EFFORT_ICONS: Record<string, string> = {
  low: cp(0xf0a9f), medium: cp(0xf0aa1), high: cp(0xf0aa3), xhigh: cp(0xf0aa4), max: cp(0xf0aa5),
}
export const NO_EFFORT_ICON = cp(0xf0a9e)
export const DASH = '–'

export const VIM_MODES: Record<string, [string, BandName]> = {
  NORMAL: ['Normal', 'purple'], INSERT: ['Insert', 'blue'],
  VISUAL: ['Visual', 'orange'], 'VISUAL LINE': ['Visual Line', 'orange'],
}

const capitalize = (word: string) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
const MODEL_ID = /(opus|sonnet|haiku|fable)-(\d+)(?:-(\d{1,2}))?(?:-\d{8})?$/i

export function prettyModel(id: string, displayName: string | null): string {
  const isLongContext = /\[1m\]/i.test(id)
  const bare = id.replace(/\[.*?\]/g, '').trim()
  const found = MODEL_ID.exec(bare)
  const name = found
    ? `${capitalize(found[1] ?? '')} ${found[2]}${found[3] ? `.${found[3]}` : ''}`
    : displayName || bare || 'unknown'

  return isLongContext && !/1m/i.test(name) ? `${name} (1M)` : name
}

export function modelScale(id: string, displayName: string | null): BandName {
  const family =
    MODEL_ID.exec(id.replace(/\[.*?\]/g, '').trim())?.[1] ?? /opus|sonnet|haiku|fable/i.exec(displayName ?? '')?.[0]

  return MODEL_SCALE[String(family).toLowerCase()] ?? 'grey'
}

export const usedScale = (percent: number): BandName => (percent >= 80 ? 'red' : percent >= 50 ? 'yellow' : 'green')

export const compactTokens = (n: number) =>
  n >= 1_000_000 ? `${+(n / 1_000_000).toFixed(1)}M` : n >= 1_000 ? `${Math.round(n / 1_000)}k` : String(n)

export function timeUntil(at: number, now: number): string {
  const minutes = Math.max(0, Math.ceil((at - now) / 60_000))
  const days = Math.floor(minutes / 1440)
  const hours = Math.floor((minutes % 1440) / 60)
  const mins = minutes % 60
  if (days > 0) return `${days}d ${hours}h`
  if (hours > 0) return `${hours}h ${String(mins).padStart(2, '0')}m`

  return `${mins}m`
}

export function age(ms: number, now: number): string {
  const minutes = Math.max(0, Math.round((now - ms) / 60_000))
  if (minutes < 60) return `${minutes}m`
  if (minutes < 48 * 60) return `${Math.round(minutes / 60)}h`

  return `${Math.round(minutes / 1440)}d`
}

export const EMPTY_COUNTS: GitCounts = {
  conflicted: 0, staged: 0, renamed: 0, modified: 0, deleted: 0, typechanged: 0, untracked: 0, stashed: 0, ahead: 0, behind: 0,
}

// `git status --porcelain=v2 --branch --show-stash`, counted the way
// starship's git_status counts (git-status.toml beside statusline.mjs).
export function parseStatus(out: string): Omit<GitInfo, 'root' | 'state'> {
  const counts = { ...EMPTY_COUNTS }
  let branch: string | null = null
  let hash: string | null = null
  for (const line of out.split('\n')) {
    if (line.startsWith('# branch.oid ')) {
      const oid = line.slice(13).trim()
      hash = /^[0-9a-f]{7,}$/.test(oid) ? oid.slice(0, 7) : null
    } else if (line.startsWith('# branch.head ')) {
      const head = line.slice(14).trim()
      branch = head === '(detached)' ? null : head
    } else if (line.startsWith('# branch.ab ')) {
      const ab = /\+(\d+) -(\d+)/.exec(line)
      counts.ahead = Number(ab?.[1] ?? 0)
      counts.behind = Number(ab?.[2] ?? 0)
    } else if (line.startsWith('# stash ')) {
      counts.stashed = Number(line.slice(8)) || 0
    } else if (line.startsWith('1 ') || line.startsWith('2 ')) {
      const [x, y] = [line[2], line[3]]
      if (x === 'R' || x === 'C') counts.renamed++
      else if (x === 'D') counts.deleted++
      else if (x === 'T') counts.typechanged++
      else if (x !== '.') counts.staged++
      if (y === 'M') counts.modified++
      else if (y === 'D') counts.deleted++
      else if (y === 'T') counts.typechanged++
    } else if (line.startsWith('u ')) {
      counts.conflicted++
    } else if (line.startsWith('? ')) {
      counts.untracked++
    }
  }

  return { branch, hash, counts }
}

export const changeCount = (c: GitCounts) =>
  c.conflicted + c.staged + c.renamed + c.modified + c.deleted + c.typechanged + c.untracked

// The parent of a path, and a child of it, on either kind of separator.
export function parentOf(dir: string): string {
  const trimmed = dir.length > 1 ? dir.replace(/[\\/]+$/, '') : dir
  const cut = Math.max(trimmed.lastIndexOf('/'), trimmed.lastIndexOf('\\'))
  if (cut < 0) return trimmed
  if (cut === 0) return trimmed.slice(0, 1)
  // C:\ stays C:\
  if (cut === 2 && /^[A-Za-z]:/.test(trimmed)) return trimmed.slice(0, 3)

  return trimmed.slice(0, cut)
}

export function childOf(dir: string, name: string): string {
  const sep = dir.includes('\\') && !dir.includes('/') ? '\\' : '/'

  return /[\\/]$/.test(dir) ? `${dir}${name}` : `${dir}${sep}${name}`
}

export const baseName = (path: string) => path.replace(/[\\/]+$/, '').split(/[\\/]/).pop() || path
