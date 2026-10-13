// Status line for Claude Code, drawn as chevrons in muted colours: every line
// is one powerline strip, coloured bands first, then dark greys, fading out
// into the background. Model and effort, each coloured from green (the
// smallest model, the lowest effort) to red, then directory and git; then the
// context window and the 5-hour and weekly limits; then the output style and
// session name. All text is tinted like its band and has a contrast of at
// least 4.6 against it. Reads the status line JSON on stdin and prints
// ANSI-coloured lines. statusline.ps1 beside it is its Windows twin; keep the
// two in step.
//
// The git band's branch, commit and state come from one quick git call. Its
// counters come from `starship module git_status` with git-status.toml beside
// this file, which takes seconds in a large repo and far longer on /mnt/c, so
// it runs in the background: at most one scan per repository at a time, a
// refresh during a scan only queues one rerun, and every refresh shows the
// last result. A `git fetch` runs the same way, at most every two minutes, so
// the commits to pull stay current. Either job shows an icon once it has run
// for two seconds.
import { execFileSync, spawn } from 'node:child_process'
import { createHash } from 'node:crypto'
import {
  closeSync, existsSync, mkdirSync, openSync, readFileSync, renameSync, rmSync, statSync, writeFileSync,
} from 'node:fs'
import { homedir } from 'node:os'
import { basename, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

// Claude Code's directory rather than this file's: the file is stowed as a
// link into the dotfiles, and Node runs a linked script from where it points.
const CONFIG_DIR = process.env.CLAUDE_CONFIG_DIR || join(homedir(), '.claude')
const STATE_DIR = join(CONFIG_DIR, 'status-band')
const SCAN_DIR = join(STATE_DIR, 'git')
// ...which is also why git-status.toml is found beside the real file.
const SELF = fileURLToPath(import.meta.url)
const GIT_STATUS_CONFIG = join(dirname(SELF), 'git-status.toml')

const FETCH_EVERY = 2 * 60_000
const SLOW = 2_000

// Muted colours on the prompt's One Half Dark. A coloured band has one
// brightness (2.0 against the background) and a text of its own hue at 4.6
// against it; the scale runs green, lime, yellow, orange, red in even hue
// steps. The text colours for the dark bands reach 4.6 against `surface`.
const BANDS = {
  green: { bg: [72, 96, 64], text: [181, 222, 167] },
  lime: { bg: [87, 93, 62], text: [205, 217, 155] },
  yellow: { bg: [96, 89, 64], text: [222, 210, 168] },
  orange: { bg: [106, 85, 71], text: [230, 205, 188] },
  red: { bg: [118, 79, 84], text: [235, 202, 207] },
  blue: { bg: [72, 92, 109], text: [193, 213, 231] },
  cyan: { bg: [65, 94, 98], text: [171, 218, 223] },
  grey: { bg: [86, 90, 97], text: [208, 211, 215] },
}
const COLORS = {
  surface: [62, 68, 81], deep: [53, 58, 69], overlay: [90, 99, 116],
  subtext: [175, 179, 187], red: [213, 167, 171], orange: [201, 174, 147], yellow: [215, 193, 152],
  green: [161, 186, 142], cyan: [140, 187, 193], blue: [143, 183, 215], purple: [201, 167, 211],
}
const sgr = (code, rgb) => `\x1b[${code};2;${rgb.join(';')}m`
const fg = name => sgr(38, COLORS[name])
const bold = text => `\x1b[1m${text}\x1b[22m`
const RESET = '\x1b[0m'
const mix = (a, b, t) => a.map((x, i) => Math.round(x + (b[i] - x) * t))

// Green for the smallest model and the lowest effort, red for the largest and
// the highest.
const MODEL_SCALE = { haiku: 'green', sonnet: 'yellow', opus: 'orange', fable: 'red' }
const EFFORT_SCALE = { low: 'green', medium: 'lime', high: 'yellow', xhigh: 'orange', max: 'red' }

const cp = code => String.fromCodePoint(code)
const ICON = {
  capLeft: cp(0xe0b6), arrow: cp(0xe0b0), thinArrow: cp(0xe0b1),
  model: cp(0xf06c4), folder: cp(0xf024b), branch: cp(0xf418), commit: cp(0xf417), context: cp(0xf035b),
  fiveHour: cp(0xf0150), weekly: cp(0xf0a33), style: cp(0xf03d8), session: cp(0xf0ede),
  fetching: cp(0xf063f), scanning: cp(0xf0c7d),
}
// Fills up with the level: low is almost empty, max is full.
const EFFORT_ICONS = {
  low: cp(0xf0a9f), medium: cp(0xf0aa1), high: cp(0xf0aa3), xhigh: cp(0xf0aa4), max: cp(0xf0aa5),
}
const NO_EFFORT_ICON = cp(0xf0a9e)
const DASH = '–'
const BLANK_LINES = 2

// One powerline strip: bands of [rgb, text] joined by arrows, rounded at the
// start. An empty band is just its arrow, so the dark bands at the end always
// fade out in steps. Two bands of one colour (Opus at xhigh) are parted by a
// thin arrow in a lighter tint, since a full one would vanish. Whatever resets
// the background inside a band (the git counters do) is covered by setting it
// again before the band's last space.
function strip(bands) {
  let out = `${sgr(38, bands[0][0])}${ICON.capLeft}`
  bands.forEach(([rgb, text], i) => {
    out += `${sgr(48, rgb)}${text}${text ? `${sgr(48, rgb)} ` : ''}`
    const next = bands[i + 1]?.[0]
    if (!next) out += `${RESET}${sgr(38, rgb)}${ICON.arrow}${RESET}`
    else if (next.join() === rgb.join()) out += `${sgr(38, mix(rgb, [255, 255, 255], 0.3))}${ICON.thinArrow}`
    else out += `${sgr(38, rgb)}${sgr(48, next)}${ICON.arrow}`
  })

  return out
}

// A coloured band: its background, and the text in its own tint.
const band = (name, text) => [BANDS[name].bg, `${sgr(38, BANDS[name].text)}${text}`]

const capitalize = word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()
const MODEL_ID = /(opus|sonnet|haiku|fable)-(\d+)(?:-(\d{1,2}))?(?:-\d{8})?$/i

function prettyModel(id, displayName) {
  const isLongContext = /\[1m\]/i.test(id ?? '')
  const bare = (id ?? '').replace(/\[.*?\]/g, '').trim()
  const found = MODEL_ID.exec(bare)
  const name = found
    ? `${capitalize(found[1])} ${found[2]}${found[3] ? `.${found[3]}` : ''}`
    : displayName || bare || 'unknown'

  return isLongContext && !/1m/i.test(name) ? `${name} (1M)` : name
}

function modelScale(id, displayName) {
  const family =
    MODEL_ID.exec((id ?? '').replace(/\[.*?\]/g, '').trim())?.[1] ?? /opus|sonnet|haiku|fable/i.exec(displayName ?? '')?.[0]

  return MODEL_SCALE[String(family).toLowerCase()] ?? 'grey'
}

function configuredEffort(modelId) {
  try {
    const settings = JSON.parse(readFileSync(join(CONFIG_DIR, 'settings.json'), 'utf8'))
    const bare = (modelId ?? '').replace(/\[.*?\]/g, '').trim()

    return (
      settings.modelSettings?.[modelId]?.effortLevel ??
      settings.modelSettings?.[bare]?.effortLevel ??
      settings.effortLevel ??
      null
    )
  } catch {
    return null
  }
}

const readText = path => {
  try {
    return readFileSync(path, 'utf8').trim()
  } catch {
    return null
  }
}

// What starship's git_state shows, from the files git leaves in its directory.
function gitState(gitDir) {
  const at = name => join(gitDir, name)
  const progress = (current, total) => {
    const [c, t] = [readText(at(current)), readText(at(total))]

    return c && t ? ` ${c}/${t}` : ''
  }
  if (existsSync(at('rebase-merge'))) return `REBASING${progress('rebase-merge/msgnum', 'rebase-merge/end')}`
  if (existsSync(at('rebase-apply'))) {
    const kind = existsSync(at('rebase-apply/rebasing')) ? 'REBASING' : existsSync(at('rebase-apply/applying')) ? 'AM' : 'AM/REBASE'

    return `${kind}${progress('rebase-apply/next', 'rebase-apply/last')}`
  }
  if (existsSync(at('MERGE_HEAD'))) return 'MERGING'
  if (existsSync(at('CHERRY_PICK_HEAD'))) return 'CHERRY-PICKING'
  if (existsSync(at('REVERT_HEAD'))) return 'REVERTING'
  if (existsSync(at('BISECT_LOG'))) return 'BISECTING'

  return null
}

// One git call for the repository's root, its git directory and the short
// commit; the branch is read from HEAD. A new repository has no commit yet, and
// git then stops at HEAD after printing the other two.
function gitHead(cwd) {
  let out
  try {
    out = execFileSync('git', ['rev-parse', '--show-toplevel', '--absolute-git-dir', '--short', 'HEAD'], {
      cwd, encoding: 'utf8', timeout: 2000, stdio: ['ignore', 'pipe', 'ignore'],
    })
  } catch (error) {
    out = typeof error.stdout === 'string' ? error.stdout : ''
  }
  const [root, gitDir, hash] = out.split('\n').map(line => line.trim())
  if (!root || !gitDir) return null
  const head = readText(join(gitDir, 'HEAD')) ?? ''
  const ref = /^ref: refs\/heads\/(.+)$/.exec(head)

  return { root, branch: ref ? ref[1] : null, hash: hash || null, state: gitState(gitDir) }
}

// A background job holds a lock file with its pid; one that died without
// removing it no longer counts.
function jobRunning(lock) {
  try {
    const pid = Number(readFileSync(lock, 'utf8'))
    // Claimed but its pid not written yet: give the claimant a moment.
    if (!pid) return Date.now() - statSync(lock).mtimeMs < 10_000
    process.kill(pid, 0)

    return true
  } catch (error) {
    return error.code === 'EPERM'
  }
}

// Running for longer than SLOW, by the lock's age.
function jobSlow(lock) {
  try {
    return Date.now() - statSync(lock).mtimeMs > SLOW && jobRunning(lock)
  } catch {
    return false
  }
}

// Start `node this MODE root base` in the background unless a job holds the
// lock; returns whether it started one.
function startJob(mode, lock, root, base) {
  for (let attempt = 0; attempt < 2; attempt++) {
    let fd
    try {
      fd = openSync(lock, 'wx')
    } catch {
      if (jobRunning(lock)) return false
      rmSync(lock, { force: true })
      continue
    }
    try {
      // detached and without our stdio, so Claude Code isn't kept waiting for it.
      const child = spawn(process.execPath, [SELF, mode, root, base], { detached: true, stdio: 'ignore' })
      child.on('error', () => {})
      child.unref()
      writeFileSync(fd, String(child.pid ?? ''))
    } finally {
      closeSync(fd)
    }
    return true
  }

  return false
}

// A scan during a scan only queues one rerun.
function requestScan(root, base) {
  if (!startJob('--scan', `${base}.lock`, root, base)) writeFileSync(`${base}.rerun`, '')
}

// A fetch at most every FETCH_EVERY, counted from the last one's start, so a
// failing remote isn't retried on every refresh.
function requestFetch(root, base) {
  const stamp = `${base}.fetched`
  try {
    if (Date.now() - statSync(stamp).mtimeMs < FETCH_EVERY) return
  } catch {}
  if (startJob('--fetch', `${base}.fetch.lock`, root, base)) writeFileSync(stamp, '')
}

// The last counters for this repository and an icon for each slow job, and
// background jobs to refresh them.
function gitAsync(root) {
  const base = join(SCAN_DIR, createHash('sha1').update(root).digest('hex').slice(0, 16))
  let last = ''
  try {
    last = readFileSync(`${base}.status`, 'utf8')
  } catch {}
  try {
    mkdirSync(SCAN_DIR, { recursive: true })
    requestScan(root, base)
    requestFetch(root, base)
  } catch {}
  const icons = [
    jobSlow(`${base}.fetch.lock`) ? `${fg('cyan')} ${ICON.fetching}` : '',
    jobSlow(`${base}.lock`) ? `${fg('yellow')} ${ICON.scanning}` : '',
  ].join('')

  return last + icons
}

// The background side: scan, and scan again while refreshes asked for it.
// GIT_OPTIONAL_LOCKS=0 keeps `git status` from holding .git/index.lock, which
// would make your own git commands fail while it runs.
function scan(root, base) {
  const rerun = `${base}.rerun`
  try {
    do {
      rmSync(rerun, { force: true })
      const env = { ...process.env, STARSHIP_CONFIG: GIT_STATUS_CONFIG, GIT_OPTIONAL_LOCKS: '0' }
      delete env.STARSHIP_SHELL
      const out = execFileSync('starship', ['module', 'git_status'], {
        cwd: root, env, encoding: 'utf8', timeout: 310_000, stdio: ['ignore', 'pipe', 'ignore'],
      })
      writeFileSync(`${base}.tmp`, out.replace(/\n$/, ''))
      renameSync(`${base}.tmp`, `${base}.status`)
    } while (existsSync(rerun))
  } catch {
  } finally {
    rmSync(`${base}.lock`, { force: true })
  }
}

// The other background side: fetch, then scan so the counters show the new
// commits to pull. Nothing may prompt: no terminal, no credential window, no
// ssh passphrase; a remote that would need one just isn't fetched.
function fetch(root, base) {
  try {
    const env = { ...process.env, GIT_TERMINAL_PROMPT: '0', GCM_INTERACTIVE: 'never' }
    let sshCommand = ''
    try {
      sshCommand = execFileSync('git', ['config', 'core.sshCommand'], {
        cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
      })
    } catch {}
    if (!sshCommand.trim() && !env.GIT_SSH_COMMAND) env.GIT_SSH_COMMAND = 'ssh -o BatchMode=yes'
    execFileSync('git', ['fetch', '--quiet'], { cwd: root, env, timeout: 120_000, stdio: 'ignore' })
  } catch {
  } finally {
    rmSync(`${base}.fetch.lock`, { force: true })
  }
  try {
    requestScan(root, base)
  } catch {}
}

// The git band's text, empty outside a repository.
function gitText(cwd) {
  const head = gitHead(cwd)
  if (head === null) return ''

  return [
    `${fg('purple')} ${ICON.branch} ${head.branch ?? 'HEAD'}`,
    head.hash ? `${fg('yellow')} ${ICON.commit} ${head.hash}` : '',
    head.state ? `${fg('orange')}${bold(` ${head.state}`)}` : '',
    gitAsync(head.root),
  ].join('')
}

const compactTokens = n =>
  n >= 1_000_000 ? `${+(n / 1_000_000).toFixed(1)}M` : n >= 1_000 ? `${Math.round(n / 1_000)}k` : String(n)

// A slim gauge: the filled part in one colour, the rest in a quieter track.
function gauge(percent, color, track, width = 10) {
  const filled = Math.min(width, Math.max(0, Math.round((percent / 100) * width)))

  return `${sgr(38, color)}${'━'.repeat(filled)}${sgr(38, track)}${'━'.repeat(width - filled)}`
}

const usedScale = percent => (percent >= 80 ? 'red' : percent >= 50 ? 'yellow' : 'green')

function toMs(resetsAt) {
  if (resetsAt === undefined || resetsAt === null) return null
  const at =
    typeof resetsAt === 'number' ? (resetsAt < 1e12 ? resetsAt * 1000 : resetsAt) : Date.parse(resetsAt)

  return Number.isNaN(at) ? null : at
}

function timeUntil(at) {
  const minutes = Math.max(0, Math.ceil((at - Date.now()) / 60_000))
  const days = Math.floor(minutes / 1440)
  const hours = Math.floor((minutes % 1440) / 60)
  const mins = minutes % 60

  if (days > 0) return `${days}d ${hours}h`
  if (hours > 0) return `${hours}h ${String(mins).padStart(2, '0')}m`

  return `${mins}m`
}

const num = value => (typeof value === 'number' && Number.isFinite(value) ? value : null)

// Claude Code leaves a window out until it has usage (after a reset, and in a
// new session before its first response), so the last reading is kept here.
const LIMITS_CACHE = join(STATE_DIR, 'limits.json')
const SPANS = { five_hour: 5 * 3_600_000, seven_day: 7 * 86_400_000 }

function readCache() {
  try {
    return JSON.parse(readFileSync(LIMITS_CACHE, 'utf8'))
  } catch {
    return {}
  }
}

// What a window stands at now: the live reading, else the last one while its
// window runs, else an unused window (a weekly one resets on the same weekly
// schedule; a 5-hour one starts with the next message).
function resolveWindow(kind, live, cache, now) {
  const span = SPANS[kind]
  const resetsAt = toMs(live?.resets_at)
  // A reading whose window has ended says nothing about the one running now.
  const used = resetsAt !== null && resetsAt <= now ? null : num(live?.used_percentage)
  if (used !== null && resetsAt !== null) {
    cache[kind] = { used, resetsAt }

    return { used, resetsAt }
  }
  const cached = cache[kind]
  if (cached && cached.resetsAt > now) return { used: used ?? cached.used, resetsAt: cached.resetsAt }
  const known = [cached?.resetsAt, resetsAt].filter(at => typeof at === 'number')
  if (kind === 'seven_day' && known.length > 0) {
    const lastReset = Math.max(...known)
    const periods = Math.max(0, Math.floor((now - lastReset) / span) + 1)

    return { used: used ?? 0, resetsAt: lastReset + periods * span }
  }

  return { used: used ?? 0, resetsAt: now + span }
}

// How much of a limit is left, and when it resets, as text for a dark band.
function limit(name, icon, { used, resetsAt }) {
  const left = Math.max(0, Math.round(100 - used))

  return (
    `${fg('blue')} ${icon} ${name} ${gauge(left, COLORS.blue, COLORS.overlay)} ` +
    `${fg('blue')}${bold(`${left}%`)} ${fg('subtext')}${timeUntil(resetsAt)}`
  )
}

// How much of the context window is used: a band coloured by how full it is.
function context(window) {
  const percent = num(window?.used_percentage)
  const size = num(window?.context_window_size)
  if (percent === null) {
    return band('grey', ` ${ICON.context} ctx ${size === null ? DASH : `${DASH} of ${compactTokens(size)}`}`)
  }
  const rounded = Math.round(percent)
  const { bg, text } = BANDS[usedScale(rounded)]

  return [bg, `${sgr(38, text)} ${ICON.context} ctx ${gauge(rounded, text, mix(bg, text, 0.3))} ${sgr(38, text)}${bold(`${rounded}%`)}`]
}

const valueOr = (value, color) => (value === null || value === undefined ? `${fg('subtext')} ${DASH}` : `${fg(color)} ${value}`)

function render(input) {
  const modelId = input.model?.id ?? ''
  const level = input.effort?.level ?? configuredEffort(modelId) ?? 'default'
  const effort = String(level).toLowerCase()
  const cwd = input.workspace?.current_dir ?? input.cwd ?? process.cwd()
  const columns = Number(process.env.COLUMNS) || 0
  const now = Date.now()
  const cache = readCache()
  const fiveHour = resolveWindow('five_hour', input.rate_limits?.five_hour, cache, now)
  const weekly = resolveWindow('seven_day', input.rate_limits?.seven_day, cache, now)
  try {
    mkdirSync(STATE_DIR, { recursive: true })
    writeFileSync(LIMITS_CACHE, JSON.stringify(cache))
  } catch {}

  // Each line fades out over the two dark greys; the git band is the first of
  // them, so outside a repository it is only the fade.
  const first = strip([
    band(modelScale(modelId, input.model?.display_name), bold(` ${ICON.model} ${prettyModel(modelId, input.model?.display_name)}`)),
    band(EFFORT_SCALE[effort] ?? 'grey', ` ${EFFORT_ICONS[effort] ?? NO_EFFORT_ICON} ${level}`),
    band('blue', ` ${ICON.folder} ${basename(cwd) || cwd}`),
    [COLORS.surface, gitText(cwd)],
    [COLORS.deep, ''],
  ])
  const second = strip([
    context(input.context_window),
    [COLORS.surface, limit('5h', ICON.fiveHour, fiveHour)],
    [COLORS.deep, limit('7d', ICON.weekly, weekly)],
  ])
  // Claude Code sends session_name only once the session has one (/rename).
  const third = strip([
    band('cyan', ` ${ICON.style} ${input.output_style?.name ?? DASH}`),
    [COLORS.surface, `${fg('yellow')} ${ICON.session}${valueOr(input.session_name, 'yellow')}`],
    [COLORS.deep, ''],
  ])
  const rule = `\x1b[2m${'─'.repeat(columns > 0 ? columns : 80)}\x1b[22m`

  // A line of one no-break space survives where an empty line would be dropped.
  return [first, second, third, ...Array(BLANK_LINES).fill(' '), rule].join('\n')
}

if (process.argv[2] === '--scan') {
  scan(process.argv[3], process.argv[4])
} else if (process.argv[2] === '--fetch') {
  fetch(process.argv[3], process.argv[4])
} else {
  let raw = ''
  process.stdin.setEncoding('utf8')
  process.stdin.on('data', chunk => (raw += chunk))
  process.stdin.on('end', () => {
    let input = {}
    try {
      input = JSON.parse(raw)
    } catch {}
    process.stdout.write(render(input))
  })
}
