// The status line's three strips (statusline.mjs in the status-band package),
// drawn again as a band above the prompt whose parts are buttons: model,
// effort, folder, branch, changes, stash, vim mode, output style and session
// each open a menu under the strips, in the band, which then holds the keys:
// its hotkeys and Tab work at once, Esc goes back to the prompt. Changes and
// stashes ask before they touch anything.
//
// Claude Code tells the status line what no hook is told (the vim mode, the
// effort, the session's name), so statusline.mjs writes its input to
// ~/.claude/status-band/sessions/<session>.json, and the band reads it. While
// the band runs it touches <session>.band there, and the status line leaves
// its strips to the band. Model, folder, output style and vim on or off are
// read live as well, so a change made here shows at once; git is read here.
//
// /status-band mod|band|off picks who draws the strips, in every session: the
// band (mod, the default), the status line alone (band), or neither (off). It
// writes ~/.claude/status-band/mode, which statusline.mjs reads as well; bare,
// it moves on to the next of the three.
//
// Git runs through $.process.run, which runs it with the repository's hooks
// off: a commit made here skips pre-commit and commit-msg hooks.
import { atom, read, update } from 'claude-code'
import type { Elements, EngineInterface, Register, RenderElement } from 'claude-code'

import type { BandMode, Branch, Confirm, GitInfo, GitOp, Menu, MenuState, SessionEntry, Snapshot, Stash } from '../types'
import {
  BANDS, COLORS, DASH, EFFORTS, EFFORT_ICONS, EFFORT_SCALE, EMPTY_COUNTS, ICON, NO_EFFORT_ICON, VIM_MODES,
  age, baseName, changeCount, childOf, compactTokens, hex, mix, modelScale, parentOf, parseMode, parseStatus,
  pickMode, prettyModel, timeUntil, USED_TINTS, usedScale, usedTint,
} from './look'
import type { BandName, Rgb } from './look'

const snapshot = atom({ plugin: 'status-band', key: 'snapshot' } as const, null)
const gitInfo = atom({ plugin: 'status-band', key: 'git' } as const, null)
const menuState = atom({ plugin: 'status-band', key: 'menu' } as const, null)
const bandMode = atom({ plugin: 'status-band', key: 'mode' } as const, 'mod')

const COMMAND = 'status-band'
const MODE_TEXT: Record<BandMode, string> = {
  mod: 'mod, the band of buttons above the prompt draws the strips.',
  band: 'band, the status line draws the strips under the prompt; it shows again within 10 s.',
  off: 'off, neither the band nor the status line draws the strips.',
}

const POLL_MS = 400
// In polls: the live values every 2 s, the heartbeat every 4 s.
const LIVE_EVERY = 5
const BEAT_EVERY = 10
// git status at most every 30 s, and only while the band draws the strips and
// the session was used (a prompt edited or sent, a model turn step) in the last
// 5 minutes. An untouched session, as a herdr restart resumes them all, keeps
// its last counters instead of running git (git.exe on a Windows drive) around
// the clock. soon() still asks for one at once.
const GIT_MS = 30_000
const IDLE_MS = 5 * 60_000
// Letters, not digits: a bare digit typed into an empty prompt presses the
// band's Button of that hotkey, so an open menu would act on a prompt that
// starts with one. y, n and x are the question's and the close button's.
const HOTKEYS = 'abcdefghijklmopqrstuvwz'
const MAX_ITEMS = 20

type $ = EngineInterface
type Els = Pick<Elements['terminal'], 'Box' | 'Text' | 'Button' | 'Input'>

const TITLES: Record<Menu['kind'], string> = {
  context: 'Context',
  model: 'Model', effort: 'Effort', folder: 'Folder', branch: 'Branch', changes: 'Changes',
  stash: 'Stash', vim: 'Editor mode', style: 'Output style', session: 'Session',
}

// ---------------------------------------------------------------------------
// Reading: the status line's input, the live values, git.

type Dump = Omit<Snapshot, 'sessionId' | 'isVim' | 'readAt'>
type Live = { modelId: string; cwd: string; outputStyle?: string; isVim?: boolean }

let stateDir: string | null = null
let dump: Dump | null = null
let dumpSeen = { path: '', mtime: 0 }
let live: Live | null = null
let pendingEffort: { level: string; at: number } | null = null
let published = ''
let ticks = 0
// Whether the band's last drawing was the strips: only then is the status
// line told to leave them to the band, so that a band that does not draw
// (a survey, no input from the status line yet, a surface without a band)
// never hides both.
let isDrawn = false
let isPolling = false
let isGitRunning = false
let isGitAgain = false
let publishedGit = ''
// When the last git refresh started, 0 to have one at the next drawn poll; and
// when the session was last used, isUsed marking a use for the next poll.
let gitAt = 0
let usedAt = 0
let isUsed = false
const repos = new Map<string, { root: string; gitDir: string } | null>()

const num = (value: unknown) => (typeof value === 'number' && Number.isFinite(value) ? value : null)
const str = (value: unknown) => (typeof value === 'string' && value !== '' ? value : null)
const limitWindow = (value: unknown) => {
  const w = value as { used?: unknown; resetsAt?: unknown } | undefined
  const [used, resetsAt] = [num(w?.used), num(w?.resetsAt)]

  return used !== null && resetsAt !== null ? { used, resetsAt } : null
}
const bare = (id: string) => id.replace(/\[.*?\]/g, '').trim()

async function dirOfState($: $): Promise<string> {
  if (stateDir !== null) return stateDir
  const configured = await $.env.get('CLAUDE_CONFIG_DIR')
  const home = (await $.env.get('USERPROFILE')) || (await $.env.get('HOME')) || ''
  stateDir = `${configured || `${home}/.claude`}/status-band`

  return stateDir
}

const dirOfSessions = async ($: $) => `${await dirOfState($)}/sessions`

// The mode another session's /status-band may have changed.
async function readMode($: $): Promise<void> {
  const text = await $.fs.read(`${await dirOfState($)}/mode`).catch(() => null)
  await useMode($, parseMode(text))
}

async function useMode($: $, mode: BandMode): Promise<void> {
  if ((await read($, bandMode)) === mode) return
  if (mode !== 'mod' && isMenuOpen) await closeMenu($)
  await update($, bandMode, () => mode)
}

async function setMode($: $, args: string): Promise<{ text: string }> {
  const mode = pickMode(args, await read($, bandMode))
  if (mode === null) return { text: `takes mod, band or off, not "${args.trim()}".` }
  try {
    await $.fs.write(`${await dirOfState($)}/mode`, `${mode}\n`)
  } catch (error) {
    return { text: `mode not written to status-band/mode: ${String(error)}` }
  }
  await useMode($, mode)
  soon($)

  return { text: MODE_TEXT[mode] }
}

function fromInput(input: Record<string, any>): Dump {
  const resolved = input.status_band ?? {}

  return {
    modelId: str(input.model?.id) ?? '',
    modelName: str(input.model?.display_name),
    effort: str(resolved.effort) ?? str(input.effort?.level),
    cwd: str(input.workspace?.current_dir) ?? str(input.cwd) ?? '',
    contextPercent: num(input.context_window?.used_percentage),
    contextSize: num(input.context_window?.context_window_size),
    fiveHour: limitWindow(resolved.five_hour),
    sevenDay: limitWindow(resolved.seven_day),
    vimMode: str(input.vim?.mode),
    outputStyle: str(input.output_style?.name),
    sessionName: str(input.session_name),
    transcriptPath: str(input.transcript_path),
  }
}

async function readDump($: $, sessionId: string): Promise<void> {
  const path = `${await dirOfSessions($)}/${sessionId}.json`
  let mtime: number
  try {
    mtime = (await $.fs.stat(path)).mtimeMs
  } catch {
    if (dumpSeen.path !== path) dump = null
    return
  }
  if (path === dumpSeen.path && mtime === dumpSeen.mtime) return
  try {
    dump = fromInput(JSON.parse(await $.fs.read(path)))
    dumpSeen = { path, mtime }
  } catch {}
}

async function readLive($: $): Promise<void> {
  const [modelId, cwd, rows] = await Promise.all([$.session.model(), $.session.cwd(), $.config.list()])
  const style = rows.find(row => row.key === 'outputStyle')?.value
  const editor = rows.find(row => row.key === 'editor')?.value
  live = {
    modelId,
    cwd,
    outputStyle: typeof style === 'string' ? style : undefined,
    isVim: editor === undefined ? undefined : editor === 'vim',
  }
}

// The status line's input with the live values over it.
async function publish($: $, sessionId: string, now: number): Promise<void> {
  const base: Dump = dump ?? {
    modelId: '', modelName: null, effort: null, cwd: '', contextPercent: null, contextSize: null,
    fiveHour: null, sevenDay: null, vimMode: null, outputStyle: null, sessionName: null, transcriptPath: null,
  }
  const isVim = live?.isVim ?? base.vimMode !== null
  if (pendingEffort !== null && (base.effort === pendingEffort.level || now - pendingEffort.at > 15_000)) {
    pendingEffort = null
  }
  const liveModel = live?.modelId ?? ''
  const next: Snapshot = {
    ...base,
    sessionId,
    modelId: liveModel === '' || bare(liveModel) === bare(base.modelId) ? base.modelId : liveModel,
    modelName: liveModel === '' || bare(liveModel) === bare(base.modelId) ? base.modelName : null,
    effort: pendingEffort?.level ?? base.effort,
    cwd: live?.cwd || base.cwd,
    outputStyle: live?.outputStyle ?? base.outputStyle,
    isVim,
    vimMode: isVim ? (base.vimMode ?? 'INSERT') : null,
    // A minute's grain: the limits' countdowns move on, nothing else redraws.
    readAt: Math.floor(now / 60_000) * 60_000,
  }
  const text = JSON.stringify(next)
  if (text === published) return
  const isFirst = published === ''
  published = text
  await update($, snapshot, () => next)
  // A band that has not drawn yet (the mod loaded into a running session)
  // reads no state to be redrawn by: ask for a drawing.
  if (isFirst || !isDrawn) $.ui.invalidate('ui.render')
}

async function gitState($: $, gitDir: string): Promise<string | null> {
  const at = (name: string) => $.fs.exists(`${gitDir}/${name}`)
  if (await at('rebase-merge')) return 'REBASING'
  if (await at('rebase-apply')) return (await at('rebase-apply/applying')) ? 'AM' : 'REBASING'
  if (await at('MERGE_HEAD')) return 'MERGING'
  if (await at('CHERRY_PICK_HEAD')) return 'CHERRY-PICKING'
  if (await at('REVERT_HEAD')) return 'REVERTING'
  if (await at('BISECT_LOG')) return 'BISECTING'

  return null
}

// On WSL, git runs through the git in ~/.local/lib/wsl-git (scripts package):
// it hands a repository on a Windows drive to Windows' git.exe, which reads
// NTFS fast and keeps its index the way Windows' tools do, and the rest to
// Linux's git.
let gitCommand: Promise<string> | null = null

function gitPath($: $): Promise<string> {
  gitCommand ??= (async () => {
    const [distro, home] = await Promise.all([$.env.get('WSL_DISTRO_NAME'), $.env.get('HOME')])
    const shim = `${home}/.local/lib/wsl-git/git`

    return distro && home && (await $.fs.exists(shim)) ? shim : 'git'
  })()

  return gitCommand
}

const git = async ($: $, cwd: string, args: string[], timeoutMs = 60_000) =>
  $.process.run([await gitPath($), '--no-optional-locks', ...args], { cwd, timeoutMs })

// undefined: could not tell (keep what is shown); null: not a repository.
async function readGit($: $, cwd: string): Promise<GitInfo | null | undefined> {
  if (cwd === '') return undefined
  let repo = repos.get(cwd)
  if (repo === undefined) {
    const found = await git($, cwd, ['rev-parse', '--show-toplevel', '--absolute-git-dir'])
    const [root, gitDir] = found.stdout.split('\n').map(line => line.trim())
    repo = found.exitCode === 0 && root && gitDir ? { root, gitDir } : null
    repos.set(cwd, repo)
  }
  if (repo === null) return null
  const status = await git($, cwd, ['status', '--porcelain=v2', '--branch', '--show-stash'])
  if (status.exitCode !== 0) return undefined

  return { root: repo.root, ...parseStatus(status.stdout), state: await gitState($, repo.gitDir) }
}

async function refreshGit($: $): Promise<void> {
  if (isGitRunning) {
    isGitAgain = true
    return
  }
  isGitRunning = true
  try {
    do {
      isGitAgain = false
      const cwd = (await read($, snapshot))?.cwd ?? ''
      const info = await readGit($, cwd).catch(() => undefined)
      if (info === undefined) continue
      const text = JSON.stringify(info)
      if (text !== publishedGit) {
        publishedGit = text
        await update($, gitInfo, () => info)
      }
    } while (isGitAgain)
  } finally {
    isGitRunning = false
  }
}

async function poll($: $): Promise<void> {
  if (isPolling) return
  isPolling = true
  try {
    const tick = ticks++
    const [sessionId, now] = await Promise.all([$.session.id(), $.clock.now()])
    await readDump($, sessionId)
    if (tick % LIVE_EVERY === 0) await Promise.all([readLive($), readMode($)])
    await publish($, sessionId, now)
    if (isUsed) {
      isUsed = false
      usedAt = now
    }
    if (isDrawn && (gitAt === 0 || (now - usedAt < IDLE_MS && now - gitAt >= GIT_MS))) {
      gitAt = now
      void refreshGit($)
    }
    await closeIfLeft($)
    if (tick % BEAT_EVERY === 0 && isDrawn) {
      await $.fs.write(`${await dirOfSessions($)}/${sessionId}.band`, String(now)).catch(() => undefined)
    }
  } catch {
  } finally {
    isPolling = false
  }
}

// The next poll reads everything.
function soon($: $): void {
  ticks = 0
  gitAt = 0
  void poll($)
}

// ---------------------------------------------------------------------------
// The band: three powerline strips, as statusline.mjs draws them.

type Part = { text: string; color: Rgb; bold?: boolean }
type Item = { key?: string; parts: Part[]; onPress?: () => unknown }
type Seg = { bg: Rgb; items: Item[] }

const coloured = (name: BandName, key: string | undefined, text: string, onPress?: () => void, bold = false): Seg => ({
  bg: BANDS[name].bg,
  items: [{ key, onPress, parts: [{ text, color: BANDS[name].text, bold }] }],
})

function gauge(percent: number, color: Rgb, track: Rgb, width = 5): Part[] {
  const filled = Math.min(width, Math.max(0, Math.round((percent / 100) * width)))

  return [{ text: '━'.repeat(filled), color }, { text: '━'.repeat(width - filled), color: track }]
}

function strip(E: Els, key: string, segs: Seg[]): RenderElement {
  const { Box, Button, Text } = E
  const out: RenderElement[] = [<Text color={hex(segs[0]?.bg ?? COLORS.deep)}>{ICON.capLeft}</Text>]
  segs.forEach((seg, i) => {
    const bg = hex(seg.bg)
    for (const item of seg.items) {
      const texts = item.parts.map(part => (
        <Text color={hex(part.color)} backgroundColor={bg} bold={part.bold}>
          {part.text}
        </Text>
      ))
      out.push(
        item.onPress && item.key
          ? <Button key={item.key} plain onPress={item.onPress}>{texts}</Button>
          : <Text>{texts}</Text>,
      )
    }
    if (seg.items.length > 0) out.push(<Text backgroundColor={bg}> </Text>)
    const next = segs[i + 1]?.bg
    if (next === undefined) out.push(<Text color={bg}>{ICON.arrow}</Text>)
    else if (hex(next) === bg) {
      out.push(<Text color={hex(mix(seg.bg, [255, 255, 255], 0.3))} backgroundColor={bg}>{ICON.thinArrow}</Text>)
    } else out.push(<Text color={bg} backgroundColor={hex(next)}>{ICON.arrow}</Text>)
  })

  return <Box key={key} flexDirection="row" flexWrap="nowrap">{out}</Box>
}

function gitItems($: $, info: GitInfo | null): Item[] {
  if (info === null) return []
  const c = info.counts ?? EMPTY_COUNTS
  const head: Part[] = [{ text: ` ${ICON.branch} ${info.branch ?? 'HEAD'}`, color: COLORS.purple }]
  if (info.hash) head.push({ text: ` ${ICON.commit} ${info.hash}`, color: COLORS.yellow })
  if (info.state) head.push({ text: ` ${info.state}`, color: COLORS.orange, bold: true })
  const items: Item[] = [{ key: 'branch', parts: head, onPress: () => openMenu($, 'branch') }]
  const changes: Part[] = (
    [
      ['conflicted', '=', COLORS.orange], ['staged', '+', COLORS.green], ['renamed', '»', COLORS.purple],
      ['modified', '~', COLORS.yellow], ['deleted', '-', COLORS.red], ['typechanged', 't', COLORS.purple],
      ['untracked', '?', COLORS.subtext],
    ] as const
  )
    .filter(([kind]) => c[kind] > 0)
    .map(([kind, sign, color]) => ({ text: ` ${sign}${c[kind]}`, color }))
  if (changes.length > 0) items.push({ key: 'changes', parts: changes, onPress: () => openMenu($, 'changes') })
  if (c.stashed > 0) {
    items.push({ key: 'stash', parts: [{ text: ` ≡${c.stashed}`, color: COLORS.blue }], onPress: () => openMenu($, 'stash') })
  }
  const arrows: Part[] = []
  if (c.ahead > 0) arrows.push({ text: ` ${ICON.ahead}${c.ahead}`, color: COLORS.cyan })
  if (c.behind > 0) arrows.push({ text: ` ${ICON.behind}${c.behind}`, color: COLORS.cyan })
  if (arrows.length > 0) items.push({ parts: arrows })

  return items
}

// Pressed, it offers `/context` and `/context all`.
function contextSeg($: $, snap: Snapshot): Seg {
  const onPress = () => openMenu($, 'context')
  if (snap.contextPercent === null) {
    const size = snap.contextSize === null ? DASH : `${DASH} of ${compactTokens(snap.contextSize)}`
    return { bg: BANDS.grey.bg, items: [{ key: 'context', onPress, parts: [{ text: ` ${ICON.context} ctx ${size}`, color: BANDS.grey.text }] }] }
  }
  const rounded = Math.round(snap.contextPercent)
  const { bg, text } = BANDS[usedScale(rounded)]
  const tint = usedTint(USED_TINTS.band, rounded)

  return {
    bg,
    items: [{
      key: 'context',
      onPress,
      parts: [
        { text: ` ${ICON.context} ctx `, color: text },
        ...gauge(rounded, tint, mix(bg, text, 0.3)),
        { text: ` ${rounded}%`, color: tint, bold: true },
      ],
    }],
  }
}

function limitSeg(bg: Rgb, name: string, icon: string, window: Snapshot['fiveHour'], now: number): Seg {
  if (window === null) return { bg, items: [{ parts: [{ text: ` ${icon} ${name} ${DASH}`, color: COLORS.subtext }] }] }
  const percent = Math.min(100, Math.max(0, Math.round(window.used)))
  const tint = usedTint(USED_TINTS.surface, percent)

  return {
    bg,
    items: [{
      parts: [
        { text: ` ${icon} ${name} `, color: COLORS.blue },
        ...gauge(percent, tint, COLORS.overlay),
        { text: ` ${percent}%`, color: tint, bold: true },
        { text: ` ${timeUntil(window.resetsAt, now)}`, color: COLORS.subtext },
      ],
    }],
  }
}

// How many cells a strip takes: the cap, each band's text and closing space,
// and an arrow after each band.
const cells = (text: string) => Array.from(text).length
function stripWidth(segs: Seg[]): number {
  return segs.reduce(
    (sum, seg) =>
      sum + 1 + (seg.items.length > 0 ? 1 : 0) +
      seg.items.reduce((n, item) => n + item.parts.reduce((m, part) => m + cells(part.text), 0), 0),
    1,
  )
}

// Two lines on one row are one strip: the first's empty fade is dropped, so
// its last band runs into the next line's first.
function joinLines(a: Seg[], b: Seg[]): Seg[] {
  const kept = a.length > 1 && a[a.length - 1]?.items.length === 0 ? a.slice(0, -1) : a

  return [...kept, ...b]
}

// The lines in order, as many on each row as fit in `columns`; a line that
// does not fit starts the next row whole.
function foldLines(lines: Seg[][], columns: number): Seg[][] {
  const rows: Seg[][] = []
  for (const line of lines) {
    const last = rows[rows.length - 1]
    const joined = last && joinLines(last, line)
    if (last && joined && stripWidth(joined) <= columns) rows[rows.length - 1] = joined
    else rows.push(line)
  }

  return rows
}

function band($: $, E: Els, snap: Snapshot, info: GitInfo | null, columns: number): RenderElement {
  const effort = (snap.effort ?? 'default').toLowerCase()
  const [vimLabel, vimColor]: [string, BandName] = snap.vimMode === null
    ? ['vim off', 'grey']
    : VIM_MODES[snap.vimMode] ?? [snap.vimMode, 'grey']
  const open = (kind: Menu['kind']) => () => openMenu($, kind)

  const lines: Seg[][] = [
    [
      coloured(modelScale(snap.modelId, snap.modelName), 'model', ` ${ICON.model} ${prettyModel(snap.modelId, snap.modelName)}`, open('model'), true),
      coloured(EFFORT_SCALE[effort] ?? 'grey', 'effort', ` ${EFFORT_ICONS[effort] ?? NO_EFFORT_ICON} ${snap.effort ?? 'default'}`, open('effort')),
      coloured('blue', 'folder', ` ${ICON.folder} ${baseName(snap.cwd)}`, open('folder')),
      { bg: COLORS.surface, items: gitItems($, info) },
      { bg: COLORS.deep, items: [] },
    ],
    [
      contextSeg($, snap),
      limitSeg(COLORS.surface, '5h', ICON.fiveHour, snap.fiveHour, snap.readAt),
      limitSeg(COLORS.surface, '7d', ICON.weekly, snap.sevenDay, snap.readAt),
    ],
    [
      coloured(vimColor, 'vim', ` ${ICON.vim} ${vimLabel}`, open('vim'), snap.vimMode !== null),
      coloured('cyan', 'style', ` ${ICON.style} ${snap.outputStyle ?? DASH}`, open('style')),
      {
        bg: COLORS.surface,
        items: [{
          key: 'session',
          onPress: open('session'),
          parts: [
            { text: ` ${ICON.session}`, color: COLORS.yellow },
            snap.sessionName === null
              ? { text: ` ${DASH}`, color: COLORS.subtext }
              : { text: ` ${snap.sessionName}`, color: COLORS.yellow },
          ],
        }],
      },
      { bg: COLORS.deep, items: [] },
    ],
  ]
  const rows = foldLines(lines, columns)

  return <E.Box flexDirection="column">{rows.map((segs, i) => strip(E, `row${i}`, segs))}</E.Box>
}

// ---------------------------------------------------------------------------
// Opening a menu: what it lists is read when it opens.

const lines = (text: string) => text.split('\n').map(line => line.trimEnd()).filter(Boolean)
const lastLines = (text: string, n = 6) => lines(text).slice(-n)

async function subdirs($: $, dir: string): Promise<string[]> {
  try {
    return (await $.fs.list(dir))
      .filter(entry => entry.kind === 'dir' && !entry.name.startsWith('.'))
      .map(entry => entry.name)
      .sort((a, b) => a.localeCompare(b))
  } catch {
    return []
  }
}

async function branches($: $, cwd: string): Promise<Branch[]> {
  const out = await git($, cwd, [
    'for-each-ref', '--sort=-committerdate', '--format=%(refname)%09%(HEAD)%09%(committerdate:relative)',
    'refs/heads', 'refs/remotes',
  ])
  const local: Branch[] = []
  const remote: Branch[] = []
  for (const line of lines(out.stdout)) {
    const [ref = '', head, when = ''] = line.split('\t')
    if (ref.startsWith('refs/heads/')) {
      local.push({ name: ref.slice(11), isCurrent: head === '*', isRemote: false, age: when })
    } else if (ref.startsWith('refs/remotes/') && !ref.endsWith('/HEAD')) {
      const name = ref.slice(13).split('/').slice(1).join('/')
      if (name) remote.push({ name, isCurrent: false, isRemote: true, age: when })
    }
  }
  // A remote branch with no local one of its name; `git switch` makes it.
  const names = new Set(local.map(branch => branch.name))
  const remoteOnly = remote.filter(branch => {
    if (names.has(branch.name)) return false
    names.add(branch.name)
    return true
  })

  return [...local, ...remoteOnly].slice(0, MAX_ITEMS - 1)
}

async function stashes($: $, cwd: string): Promise<Stash[]> {
  // %gs, the reflog's message: what `git stash list` shows, and what a
  // rename (store -m) changes; the commit's own subject keeps the old one.
  const out = await git($, cwd, ['stash', 'list', '--format=%gd%x09%gs%x09%cr'])

  return lines(out.stdout).map(line => {
    const [ref = '', subject = '', when = ''] = line.split('\t')
    return { ref, subject, age: when }
  })
}

async function sessions($: $, snap: Snapshot | null): Promise<SessionEntry[]> {
  if (!snap?.transcriptPath) return []
  const dir = parentOf(snap.transcriptPath)
  const now = await $.clock.now()
  let files
  try {
    files = (await $.fs.list(dir))
      .filter(entry => entry.kind === 'file' && entry.name.endsWith('.jsonl'))
      .filter(entry => entry.name !== `${snap.sessionId}.jsonl`)
      .sort((a, b) => b.mtimeMs - a.mtimeMs)
      .slice(0, 9)
  } catch {
    return []
  }
  const titles = new Map<string, { custom?: string; ai?: string }>()
  try {
    const found = await $.process.run(
      ['grep', '-oE', '"(customTitle|aiTitle)":"([^"\\\\]|\\\\.)*"', ...files.map(file => childOf(dir, file.name))],
      { timeoutMs: 10_000 },
    )
    for (const line of lines(found.stdout)) {
      const match = /([^/\\]+)\.jsonl:("(customTitle|aiTitle)":.*)$/.exec(line)
      if (!match) continue
      const value = JSON.parse(`{${match[2]}}`) as { customTitle?: string; aiTitle?: string }
      const id = match[1] ?? ''
      const title = titles.get(id) ?? {}
      if (value.customTitle) title.custom = value.customTitle
      if (value.aiTitle) title.ai = value.aiTitle
      titles.set(id, title)
    }
  } catch {}

  return files.map(file => {
    const id = file.name.slice(0, -6)
    const title = titles.get(id)
    return { id, title: title?.custom ?? title?.ai ?? `(untitled) ${id.slice(0, 8)}`, age: age(file.mtimeMs, now) }
  })
}

async function changedFiles($: $, cwd: string) {
  const out = await git($, cwd, ['status', '--short', '--untracked-files=all'])
  const files = lines(out.stdout)

  return {
    files,
    hasStaged: files.some(line => line[0] !== ' ' && line[0] !== '?'),
    hasUntracked: files.some(line => line.startsWith('??')),
  }
}

async function openMenu($: $, kind: Menu['kind']): Promise<void> {
  // The item of an open menu closes it.
  if ((await read($, menuState))?.menu.kind === kind) return closeMenu($)
  const snap = await read($, snapshot)
  const cwd = snap?.cwd || (await $.session.cwd())
  let menu: Menu
  try {
    switch (kind) {
      case 'context':
        menu = { kind }
        break
      case 'model': {
        const row = (await $.config.list()).find(r => r.key === 'model')
        menu = { kind, options: [...(row?.options ?? ['default', 'sonnet', 'opus', 'haiku'])], current: String(row?.value ?? '') }
        break
      }
      case 'effort':
        menu = { kind, current: snap?.effort ?? null }
        break
      case 'folder':
        menu = { kind, cwd, dir: cwd, subdirs: await subdirs($, cwd) }
        break
      case 'branch':
        menu = { kind, cwd, branches: await branches($, cwd) }
        break
      case 'changes':
        menu = { kind, cwd, ...(await changedFiles($, cwd)) }
        break
      case 'stash':
        menu = { kind, cwd, stashes: await stashes($, cwd) }
        break
      case 'vim':
        menu = { kind, isVim: snap?.isVim ?? false, mode: snap?.vimMode ?? null }
        break
      case 'style': {
        const row = (await $.config.list()).find(r => r.key === 'outputStyle')
        menu = { kind, options: [...(row?.options ?? ['default'])], current: String(row?.value ?? 'default') }
        break
      }
      case 'session':
        menu = { kind, name: snap?.sessionName ?? null, sessions: await sessions($, snap) }
        break
    }
  } catch (error) {
    $.ui.toast(`${TITLES[kind]}: ${String(error)}`)
    return
  }
  await update($, menuState, () => ({ menu }))
  isMenuOpen = true
  await focusMenu($)
}

// ---------------------------------------------------------------------------
// Doing what was picked.

// Whether a menu is open, so that the prompt's every keystroke need not read
// the state to know.
let isMenuOpen = false

async function closeMenu($: $): Promise<void> {
  isMenuOpen = false
  await update($, menuState, () => null)
}

async function setMenu($: $, fn: (state: MenuState) => MenuState): Promise<void> {
  await update($, menuState, state => (state === null ? null : fn(state)))
  await focusMenu($)
}

// The element the ring goes to as a menu shows something new: the field to
// type in, No in a question, else the first item. The band holds the keys
// after the press that opened it, so its hotkeys and Tab work at once.
function focusKey(state: MenuState): string | undefined {
  const { menu } = state
  if (state.busy) return undefined
  if (state.confirm) return 'no'
  switch (menu.kind) {
    case 'context':
      return 'context:plain'
    case 'model':
      return `model:${menu.options[0]}`
    case 'effort':
      return 'effort:low'
    case 'folder':
      return 'cd'
    case 'branch': {
      const first = menu.branches[0]
      return first ? `branch:${first.isRemote ? 'remote:' : ''}${first.name}` : 'new-branch'
    }
    case 'changes':
      return menu.ask ? 'message' : menu.hasStaged ? 'commit-staged' : 'commit-all'
    case 'stash': {
      const first = menu.stashes[0]
      if (menu.selected === undefined) return first ? `stash:${first.ref}` : 'close'
      return menu.ask ? 'stash-name' : 'apply'
    }
    case 'vim':
      return 'editor:vim'
    case 'style':
      return `style:${menu.options[0]}`
    case 'session':
      return menu.ask ? 'session-name' : 'rename'
  }
}

let bandId: string | null = null

async function focusMenu($: $): Promise<void> {
  const state = await read($, menuState)
  const key = state === null ? undefined : focusKey(state)
  if (bandId === null || key === undefined) return
  const moved = await $.ui.focus({ requestId: bandId, key }).catch(() => undefined)
  if (moved && !('deny' in moved)) focusedKey = key
}

// The band's element that holds the ring, as the person and focusMenu last
// moved it.
let focusedKey: string | null = null

// Esc (or a click elsewhere) hands the keys back without telling the band.
// While a menu is open, the ring is put again where it is; once that is
// refused because the band holds no keys, they are gone, and so is the menu.
async function closeIfLeft($: $): Promise<void> {
  if (!isMenuOpen || bandId === null || focusedKey === null) return
  const held = await $.ui.focus({ requestId: bandId, key: focusedKey }).catch(() => undefined)
  if (held && 'deny' in held) {
    $.ui.log(`status-band focus check: ${held.deny}`, { to: 'debug' })
    if (/keyboard|keys/i.test(String(held.deny))) await closeMenu($)
  }
}

async function slash($: $, command: string, args: string): Promise<void> {
  await closeMenu($)
  try {
    await $.command.run({ command, args })
  } catch (error) {
    $.ui.toast(`/${command} ${args}: ${String(error)}`)
  }
  soon($)
}

async function configure($: $, key: string, value: string, label: string): Promise<void> {
  await closeMenu($)
  const result = await $.config.set({ key, value })
  if ('deny' in result) $.ui.toast(`${label} not changed: ${result.deny}`)
  soon($)
}

async function runGit($: $, op: GitOp): Promise<void> {
  await setMenu($, state => ({ ...state, confirm: undefined, error: undefined, busy: `git ${op.steps.map(s => s[0]).join(', ')}…` }))
  for (const step of op.steps) {
    let failure: string[] | null = null
    try {
      const ran = await git($, op.cwd, step, 120_000)
      if (ran.exitCode !== 0) failure = lastLines(ran.stderr || ran.stdout || `git ${step[0]} exited ${ran.exitCode}`)
    } catch (error) {
      failure = [String(error)]
    }
    if (failure !== null) {
      await setMenu($, state => ({ ...state, busy: undefined, error: [`git ${step.join(' ')}`, ...failure].join('\n') }))
      soon($)
      return
    }
  }
  await closeMenu($)
  $.ui.toast(op.done)
  soon($)
}

const ask = ($: $, confirm: Confirm) => setMenu($, state => ({ ...state, confirm, error: undefined }))

// ---------------------------------------------------------------------------
// The menu pane.

type Choice = { key: string; label: string; detail?: string; isCurrent?: boolean; onPress: () => unknown }

// A list of choices with hotkeys; where one of them is the current value, a
// dot marks it.
function choices(E: Els, items: Choice[]): RenderElement[] {
  const isPick = items.some(item => item.isCurrent)

  return items.slice(0, MAX_ITEMS).map((item, i) => {
    const children: (string | RenderElement)[] = [item.label]
    if (isPick) children.unshift(item.isCurrent ? <E.Text color={hex(COLORS.green)}>● </E.Text> : <E.Text dimColor>○ </E.Text>)
    if (item.detail) children.push(<E.Text dimColor> {item.detail}</E.Text>)
    return <E.Button key={item.key} plain hotkey={HOTKEYS[i]} onPress={item.onPress}>{children}</E.Button>
  })
}

function heading(E: Els, text: string, value?: string | null): RenderElement {
  return (
    <E.Text>
      <E.Text bold>{text}</E.Text>
      {value ? <E.Text dimColor> {value}</E.Text> : ''}
    </E.Text>
  )
}

function confirmView($: $, E: Els, confirm: Confirm): RenderElement[] {
  return [
    <E.Text color={hex(COLORS.orange)} bold>{confirm.text}</E.Text>,
    ...confirm.detail.slice(0, 10).map(line => <E.Text dimColor>  {line}</E.Text>),
    ...(confirm.detail.length > 10 ? [<E.Text dimColor>  … {confirm.detail.length - 10} more</E.Text>] : []),
    <E.Box flexDirection="row" gap={2}>
      <E.Button key="yes" plain hotkey="y" variant="primary" onPress={() => runGit($, confirm.op)}>Yes</E.Button>
      <E.Button key="no" plain hotkey="n" onPress={() => setMenu($, state => ({ ...state, confirm: undefined }))}>No</E.Button>
    </E.Box>,
  ]
}

function textField(E: Els, key: string, label: string, value: string, onSubmit: (text: string) => void, isFocused = false) {
  return isFocused
    ? <E.Input key={key} label={label} value={value} autoFocus onSubmit={text => onSubmit(text.trim())} />
    : <E.Input key={key} label={label} value={value} onSubmit={text => onSubmit(text.trim())} />
}

function menuBody($: $, E: Els, state: MenuState, snap: Snapshot | null): RenderElement[] {
  const { menu } = state
  switch (menu.kind) {
    case 'context':
      return [
        heading(E, 'Context', snap?.contextPercent == null ? null : `${Math.round(snap.contextPercent)}% used`),
        ...choices(E, [
          { key: 'context:plain', label: '/context', detail: 'the usage by category', onPress: () => slash($, 'context', '') },
          { key: 'context:all', label: '/context all', detail: 'and every tool, memory file and skill', onPress: () => slash($, 'context', 'all') },
        ]),
      ]
    case 'model':
      return [
        heading(E, 'Model', snap ? prettyModel(snap.modelId, snap.modelName) : null),
        ...choices(E, menu.options.map(option => ({
          key: `model:${option}`, label: option, isCurrent: option === menu.current,
          onPress: () => slash($, 'model', option),
        }))),
      ]
    case 'effort':
      return [
        heading(E, 'Effort', menu.current),
        ...choices(E, EFFORTS.map(level => ({
          key: `effort:${level}`, label: `${EFFORT_ICONS[level]} ${level}`, isCurrent: level === menu.current,
          onPress: async () => {
            pendingEffort = { level, at: await $.clock.now() }
            await slash($, 'effort', level)
          },
        }))),
      ]
    case 'folder': {
      const open = (dir: string) => async () => {
        const list = await subdirs($, dir)
        await setMenu($, s => (s.menu.kind === 'folder' ? { ...s, menu: { ...s.menu, dir, subdirs: list } } : s))
      }
      const parent = parentOf(menu.dir)
      return [
        heading(E, 'Folder', menu.dir),
        ...choices(E, [
          { key: 'cd', label: menu.dir === menu.cwd ? 'stay here' : `cd ${baseName(menu.dir)}`, isCurrent: menu.dir === menu.cwd, onPress: () => slash($, 'cd', menu.dir) },
          ...(parent !== menu.dir ? [{ key: 'up', label: '..', detail: parent, onPress: open(parent) }] : []),
          ...menu.subdirs.map(name => ({ key: `dir:${name}`, label: `${name}/`, onPress: open(childOf(menu.dir, name)) })),
        ]),
        ...(menu.subdirs.length > MAX_ITEMS - 2 ? [<E.Text dimColor>  … {menu.subdirs.length - (MAX_ITEMS - 2)} more: type the path</E.Text>] : []),
        textField(E, 'path', 'cd', '', path => (path ? slash($, 'cd', path) : undefined)),
      ]
    }
    case 'branch':
      return [
        heading(E, 'Branch', menu.branches.find(b => b.isCurrent)?.name ?? 'detached HEAD'),
        ...choices(E, menu.branches.map(branch => ({
          key: `branch:${branch.isRemote ? 'remote:' : ''}${branch.name}`,
          label: branch.name,
          detail: `${branch.isRemote ? 'remote, ' : ''}${branch.age}`,
          isCurrent: branch.isCurrent,
          onPress: () => branch.isCurrent
            ? closeMenu($)
            : runGit($, { cwd: menu.cwd, steps: [['switch', branch.name]], done: `Switched to ${branch.name}` }),
        }))),
        textField(E, 'new-branch', 'new branch', '', name => {
          if (name) return runGit($, { cwd: menu.cwd, steps: [['switch', '-c', name]], done: `Created and switched to ${name}` })
        }),
      ]
    case 'changes': {
      if (menu.ask) {
        const isStash = menu.ask === 'stash'
        const what = menu.ask === 'commit-staged' ? 'the staged changes' : 'all changes'
        return [
          heading(E, isStash ? 'Stash all changes' : `Commit ${what}`),
          textField(E, 'message', isStash ? 'message (optional)' : 'message', '', message => {
            if (!isStash && !message) return
            return ask($, isStash
              ? {
                  text: 'Stash all changes, untracked files included?',
                  detail: menu.files,
                  op: { cwd: menu.cwd, steps: [['stash', 'push', '--include-untracked', ...(message ? ['-m', message] : [])]], done: 'Stashed the changes' },
                }
              : {
                  text: `Commit ${what} as “${message}”?`,
                  detail: menu.ask === 'commit-staged' ? menu.files.filter(f => f[0] !== ' ' && f[0] !== '?') : menu.files,
                  op: {
                    cwd: menu.cwd,
                    steps: menu.ask === 'commit-all' ? [['add', '-A'], ['commit', '-m', message]] : [['commit', '-m', message]],
                    done: `Committed: ${message}`,
                  },
                })
          }, true),
        ]
      }
      const askFor = (step: 'commit-staged' | 'commit-all' | 'stash') => () =>
        setMenu($, s => (s.menu.kind === 'changes' ? { ...s, menu: { ...s.menu, ask: step } } : s))
      const items: Choice[] = []
      if (menu.hasStaged) items.push({ key: 'commit-staged', label: 'Commit staged…', onPress: askFor('commit-staged') })
      items.push(
        { key: 'commit-all', label: 'Commit all…', detail: 'git add -A', onPress: askFor('commit-all') },
        { key: 'stash', label: 'Stash…', detail: 'untracked included', onPress: askFor('stash') },
        {
          key: 'reset', label: 'Reset tracked files', detail: 'git reset --hard',
          onPress: () => ask($, {
            text: 'Discard every change to tracked files? This cannot be undone.',
            detail: menu.files.filter(f => !f.startsWith('??')),
            op: { cwd: menu.cwd, steps: [['reset', '--hard', 'HEAD']], done: 'Reset the tracked files' },
          }),
        },
      )
      if (menu.hasUntracked) {
        items.push({
          key: 'reset-all', label: 'Reset all', detail: 'and delete untracked files',
          onPress: () => ask($, {
            text: 'Discard every change and delete the untracked files? This cannot be undone.',
            detail: menu.files,
            op: { cwd: menu.cwd, steps: [['reset', '--hard', 'HEAD'], ['clean', '-fd']], done: 'Reset everything' },
          }),
        })
      }
      return [
        heading(E, 'Changes', `${menu.files.length} file${menu.files.length === 1 ? '' : 's'}`),
        ...menu.files.slice(0, 8).map(file => <E.Text dimColor>  {file}</E.Text>),
        ...(menu.files.length > 8 ? [<E.Text dimColor>  … {menu.files.length - 8} more</E.Text>] : []),
        ...choices(E, items),
      ]
    }
    case 'stash': {
      const chosen = menu.selected === undefined ? undefined : menu.stashes[menu.selected]
      if (chosen === undefined) {
        return [
          heading(E, 'Stash', `${menu.stashes.length} entr${menu.stashes.length === 1 ? 'y' : 'ies'}`),
          ...choices(E, menu.stashes.map((stash, i) => ({
            key: `stash:${stash.ref}`, label: stash.subject, detail: `${stash.ref}, ${stash.age}`,
            onPress: () => setMenu($, s => (s.menu.kind === 'stash' ? { ...s, menu: { ...s.menu, selected: i } } : s)),
          }))),
        ]
      }
      const back = () => setMenu($, s => (s.menu.kind === 'stash' ? { ...s, menu: { ...s.menu, selected: undefined, ask: undefined } } : s))
      if (menu.ask === 'rename') {
        return [
          heading(E, `Rename ${chosen.ref}`, chosen.subject),
          textField(E, 'stash-name', 'new message', chosen.subject.replace(/^(WIP on|On) [^:]+: /, ''), message => {
            if (!message) return
            return (async () => {
              const sha = (await git($, menu.cwd, ['rev-parse', chosen.ref])).stdout.trim()
              await ask($, {
                text: `Rename ${chosen.ref} to “${message}”?`,
                detail: ['It is dropped and stored again, so it becomes stash@{0}.'],
                op: { cwd: menu.cwd, steps: [['stash', 'drop', chosen.ref], ['stash', 'store', '-m', message, sha]], done: `Renamed the stash to ${message}` },
              })
            })()
          }, true),
        ]
      }
      const op = (verb: string, steps: string[][], done: string, text: string) => () =>
        ask($, { text, detail: [`${chosen.ref}: ${chosen.subject}`], op: { cwd: menu.cwd, steps, done } })
      return [
        heading(E, chosen.ref, chosen.subject),
        ...choices(E, [
          { key: 'apply', label: 'Apply', detail: 'keep the stash', onPress: op('apply', [['stash', 'apply', chosen.ref]], `Applied ${chosen.ref}`, `Apply ${chosen.ref} to the working tree?`) },
          { key: 'pop', label: 'Pop', detail: 'apply and drop', onPress: op('pop', [['stash', 'pop', chosen.ref]], `Popped ${chosen.ref}`, `Apply ${chosen.ref} and drop it?`) },
          { key: 'rename', label: 'Rename…', onPress: () => setMenu($, s => (s.menu.kind === 'stash' ? { ...s, menu: { ...s.menu, ask: 'rename' } } : s)) },
          { key: 'drop', label: 'Delete', detail: 'git stash drop', onPress: op('drop', [['stash', 'drop', chosen.ref]], `Dropped ${chosen.ref}`, `Delete ${chosen.ref}? This cannot be undone.`) },
          { key: 'back', label: 'Back', onPress: back },
        ]),
      ]
    }
    case 'vim':
      return [
        heading(E, 'Editor mode', menu.isVim ? `vim, ${(menu.mode ?? 'INSERT').toLowerCase()}` : 'normal'),
        ...choices(E, [
          { key: 'editor:vim', label: 'vim', isCurrent: menu.isVim, onPress: () => configure($, 'editor', 'vim', 'Editor mode') },
          { key: 'editor:normal', label: 'normal', detail: 'vim off', isCurrent: !menu.isVim, onPress: () => configure($, 'editor', 'normal', 'Editor mode') },
        ]),
      ]
    case 'style':
      return [
        heading(E, 'Output style', menu.current),
        ...choices(E, menu.options.map(option => ({
          key: `style:${option}`, label: option, isCurrent: option === menu.current,
          onPress: () => configure($, 'outputStyle', option, 'Output style'),
        }))),
      ]
    case 'session':
      if (menu.ask === 'rename') {
        return [
          heading(E, 'Rename the session'),
          textField(E, 'session-name', 'name', menu.name ?? '', name => (name ? slash($, 'rename', name) : undefined), true),
        ]
      }
      return [
        heading(E, 'Session', menu.name ?? 'unnamed'),
        ...choices(E, [
          { key: 'rename', label: 'Rename…', onPress: () => setMenu($, s => (s.menu.kind === 'session' ? { ...s, menu: { ...s.menu, ask: 'rename' } } : s)) },
          ...menu.sessions.map(session => ({
            key: `resume:${session.id}`, label: session.title, detail: session.age,
            onPress: () => slash($, 'resume', session.id),
          })),
          { key: 'resume', label: 'All sessions…', detail: '/resume', onPress: () => slash($, 'resume', '') },
        ]),
      ]
  }
}

// The open menu, framed under the strips.
function menuBox($: $, E: Els, state: MenuState, snap: Snapshot | null): RenderElement {
  const body: RenderElement[] = state.busy
    ? [<E.Text color={hex(COLORS.yellow)}>{state.busy}</E.Text>]
    : state.confirm
      ? confirmView($, E, state.confirm)
      : menuBody($, E, state, snap)
  if (state.error) body.unshift(...lines(state.error).map(line => <E.Text color={hex(COLORS.red)}>{line}</E.Text>))

  return (
    <E.Box key="menu" flexDirection="column" alignSelf="flex-start" borderStyle="round" borderColor={hex(COLORS.overlay)} paddingX={1}>
      {body}
      <E.Box flexDirection="row" gap={2}>
        <E.Button key="close" plain hotkey="x" onPress={() => closeMenu($)}>close</E.Button>
        <E.Text dimColor>esc: close</E.Text>
      </E.Box>
    </E.Box>
  )
}

// ---------------------------------------------------------------------------

export const register: Register = on => {
  let timer: { cancel: () => void } | null = null

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: COMMAND,
      description: 'Draw the strips as the band (mod), as the status line (band), or not at all (off)',
      argumentHint: '[mod|band|off]',
      immediate: true,
    })
    const started = await next(e)
    timer?.cancel()
    timer = $.clock.every(POLL_MS, () => poll($))
    soon($)

    return started
  })

  on('command.run', { command: COMMAND }, ($, e) => setMode($, e.args))

  on('turn.complete', ($, e, next) => {
    soon($)

    return next(e)
  })

  on('ui.focus', async ($, e, next) => {
    const moved = await next(e)
    if (e.component === 'AbovePrompt' && e.element !== undefined && !('deny' in moved)) focusedKey = e.element

    return moved
  })

  // Typing in the prompt closes an open menu too, at once.
  on('prompt.edit', ($, e, next) => {
    isUsed = true
    if (isMenuOpen) void closeMenu($)

    return next(e)
  })

  // A prompt sent while a menu is open leaves it behind.
  on('prompt.submit', async ($, e, next) => {
    isUsed = true
    if ((await read($, menuState)) !== null) await closeMenu($)

    return next(e)
  })

  // A running turn keeps the counters current as its tools change files.
  on('turn.step', async function* ($, e, next) {
    isUsed = true

    return yield* next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    isDrawn = false
    if (e.props.hasSurvey || (await read($, bandMode)) !== 'mod') return next(e)
    const snap = await read($, snapshot)
    if (snap === null) return next(e)
    isDrawn = true
    bandId = e.requestId
    const [info, state] = await Promise.all([read($, gitInfo), read($, menuState)])
    const E = $.ui.resolve(e) as Els
    const below = await next(e)
    // A dim rule, as the status line draws one, between the conversation and
    // the band.
    const parts = [<E.Text dimColor>{'─'.repeat(Math.max(1, e.props.bodyColumns))}</E.Text>, band($, E, snap, info, e.props.bodyColumns)]
    if (state !== null) parts.push(menuBox($, E, state, snap))

    return (
      <E.Box flexDirection="column">
        {parts}
        {below}
      </E.Box>
    )
  })
}
