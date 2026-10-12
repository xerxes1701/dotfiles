// Status line for Claude Code: model and effort, directory, branch, then the
// context window and the 5-hour and weekly limits, then the session name and
// output style. Reads the status line JSON on stdin and prints ANSI-coloured
// lines.
import { execFileSync } from 'node:child_process'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { basename, join } from 'node:path'

// Claude Code's directory rather than this file's: the file is stowed as a
// link into the dotfiles, and Node runs a linked script from where it points.
const CONFIG_DIR = process.env.CLAUDE_CONFIG_DIR || join(homedir(), '.claude')
const STATE_DIR = join(CONFIG_DIR, 'status-band')

const rgb = (r, g, b) => text => `\x1b[38;2;${r};${g};${b}m${text}\x1b[39m`
const bold = text => `\x1b[1m${text}\x1b[22m`
const dim = text => `\x1b[2m${text}\x1b[22m`

const CLAUDE = rgb(215, 119, 87)
const LABEL = rgb(107, 107, 107)
const LIMIT = rgb(97, 175, 239)
const SUCCESS = rgb(78, 186, 101)
const WARNING = rgb(255, 193, 7)
const ERROR = rgb(255, 107, 128)

const SEP = dim('|')
const BLANK_LINES = 2

// Fills up with the level: low is almost empty, max is full.
const EFFORT_ICONS = { low: '◔', medium: '◑', high: '◕', xhigh: '◉', max: '●' }

const capitalize = word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()

function prettyModel(id, displayName) {
  const isLongContext = /\[1m\]/i.test(id ?? '')
  const bare = (id ?? '').replace(/\[.*?\]/g, '').trim()
  const found = /(opus|sonnet|haiku|fable)-(\d+)(?:-(\d{1,2}))?(?:-\d{8})?$/i.exec(bare)
  const name = found
    ? `${capitalize(found[1])} ${found[2]}${found[3] ? `.${found[3]}` : ''}`
    : displayName || bare || 'unknown'

  return isLongContext && !/1m/i.test(name) ? `${name} (1M)` : name
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

function branchOf(cwd) {
  const git = args =>
    execFileSync('git', args, { cwd, encoding: 'utf8', timeout: 2000, stdio: ['ignore', 'pipe', 'ignore'] }).trim()
  try {
    return git(['branch', '--show-current']) || `@${git(['rev-parse', '--short', 'HEAD'])}`
  } catch {
    return null
  }
}

const compactTokens = n =>
  n >= 1_000_000 ? `${+(n / 1_000_000).toFixed(1)}M` : n >= 1_000 ? `${Math.round(n / 1_000)}k` : String(n)

function bar(percent, width = 10) {
  const filled = Math.min(width, Math.max(0, Math.round((percent / 100) * width)))

  return '█'.repeat(filled) + '░'.repeat(width - filled)
}

const usedColor = percent => (percent >= 80 ? ERROR : percent >= 50 ? WARNING : SUCCESS)

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

function limit(label, { used, resetsAt }) {
  const left = Math.max(0, Math.round(100 - used))

  return `${LABEL(label)} ${LIMIT(`${bar(left)} ${bold(`${left}% left`)}`)} ${dim(`(${timeUntil(resetsAt)})`)}`
}

function context(window) {
  const percent = num(window?.used_percentage)
  const size = num(window?.context_window_size)
  if (percent === null) return `${LABEL('Context')} ${dim(size === null ? '–' : `– of ${compactTokens(size)}`)}`
  const rounded = Math.round(percent)
  const tokens = num(window?.total_input_tokens)
  const counts = tokens !== null && size !== null ? ` ${dim(`${compactTokens(tokens)}/${compactTokens(size)}`)}` : ''

  return `${LABEL('Context')} ${usedColor(rounded)(`${bar(rounded)} ${rounded}%`)}${counts}`
}

function render(input) {
  const modelId = input.model?.id ?? ''
  const level = input.effort?.level ?? configuredEffort(modelId) ?? 'default'
  const icon = EFFORT_ICONS[String(level).toLowerCase()] ?? '○'
  const cwd = input.workspace?.current_dir ?? input.cwd ?? process.cwd()
  const branch = branchOf(cwd)
  const columns = Number(process.env.COLUMNS) || 0
  const now = Date.now()
  const cache = readCache()
  const fiveHour = resolveWindow('five_hour', input.rate_limits?.five_hour, cache, now)
  const weekly = resolveWindow('seven_day', input.rate_limits?.seven_day, cache, now)
  try {
    mkdirSync(STATE_DIR, { recursive: true })
    writeFileSync(LIMITS_CACHE, JSON.stringify(cache))
  } catch {}

  const first = [
    bold(CLAUDE(`[${prettyModel(modelId, input.model?.display_name)} ${icon} ${level}]`)),
    `${LABEL('Dir')} ${basename(cwd) || cwd}`,
    branch === null ? dim('--') : SUCCESS(branch),
  ].join(` ${SEP} `)
  const second = [
    context(input.context_window),
    limit('5h-Window', fiveHour),
    limit('Weekly', weekly),
  ].join(` ${SEP} `)
  // Claude Code sends session_name only once the session has one (/rename).
  const third = [
    `${LABEL('Session')} ${input.session_name ? CLAUDE(input.session_name) : dim('–')}`,
    `${LABEL('Style')} ${input.output_style?.name ?? dim('–')}`,
  ].join(` ${SEP} `)
  const rule = dim('─'.repeat(columns > 0 ? columns : 80))

  // A line of one no-break space survives where an empty line would be dropped.
  return [first, second, third, ...Array(BLANK_LINES).fill(' '), rule].join('\n')
}

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
