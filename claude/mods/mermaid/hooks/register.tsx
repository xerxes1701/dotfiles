// Draws the ```mermaid blocks of Claude's replies as pictures. mmdc (pacman's
// mermaid-cli) renders each block's source once to a PNG in
// ~/.cache/claude-mermaid, named by a hash of the source, and the reply's row
// draws it as an Image, which the terminal shows over the kitty graphics
// protocol. Only the drawing changes: the stored reply, and ctrl+o, keep the
// source.
//
// A block is drawn as the engine draws it, as code, until its picture is
// ready, while the reply is still writing it (an unclosed fence), and for good
// where no picture can be: a terminal that shows no images (herdr, whose
// panes answer as libghostty, which Claude Code draws no images for), no mmdc,
// a surface other than the terminal. A block mmdc refuses keeps its code, with
// mmdc's error under it.
import type { EngineInterface, ImageSource, Register, RenderElement } from 'claude-code'

const THEME = 'dark'
// mmdc renders at twice the diagram's size, so the picture stays sharp when
// the terminal scales it up to its cells.
const SCALE = 2
// A diagram's pixels (at scale 1) per terminal column: mermaid's 16px font then
// comes out about as large as the terminal's own text.
const PIXELS_PER_COLUMN = 8
// A terminal cell's height over its width. The Image fills the cells it is
// given, so the rows are counted from this to keep the diagram's proportions.
const CELL_ASPECT = 2.1
// Rows kept free of a diagram, so a tall one still fits the screen whole.
const SPARE_ROWS = 6

const OPEN = /^ {0,3}(`{3,}|~{3,})\s*([^\s`]*)/
const CLOSE = /^ {0,3}(`{3,}|~{3,})\s*$/

export type Part = { kind: 'markdown'; text: string } | { kind: 'mermaid'; text: string; source: string }

// The reply's text cut at its closed ```mermaid fences. A fence inside another
// one (a markdown example) is that block's text, and an unclosed one at the end
// (the reply still being written) stays markdown.
export function parts(text: string): Part[] {
  const lines = text.split('\n')
  const found: Part[] = []
  let markdown: string[] = []
  let at = 0

  while (at < lines.length) {
    const opened = OPEN.exec(lines[at] ?? '')
    if (opened === null) {
      markdown.push(lines[at] ?? '')
      at += 1
      continue
    }
    const fence = opened[1] ?? '```'
    let end = at + 1
    for (; end < lines.length; end += 1) {
      const closed = CLOSE.exec(lines[end] ?? '')
      if (closed !== null && closed[1]?.[0] === fence[0] && (closed[1]?.length ?? 0) >= fence.length) break
    }
    const block = lines.slice(at, end + 1)
    if (end < lines.length && opened[2]?.toLowerCase() === 'mermaid') {
      if (markdown.length > 0) found.push({ kind: 'markdown', text: markdown.join('\n') })
      markdown = []
      found.push({ kind: 'mermaid', text: block.join('\n'), source: lines.slice(at + 1, end).join('\n') })
    } else {
      markdown.push(...block)
    }
    at = end + 1
  }
  if (markdown.length > 0) found.push({ kind: 'markdown', text: markdown.join('\n') })

  return found
}

// cyrb53: a 53-bit hash, enough to name a cache file.
export function hash(text: string): string {
  let h1 = 0xdeadbeef
  let h2 = 0x41c6ce57
  for (let i = 0; i < text.length; i += 1) {
    const c = text.charCodeAt(i)
    h1 = Math.imul(h1 ^ c, 2654435761)
    h2 = Math.imul(h2 ^ c, 1597334677)
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909)
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909)

  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(16).padStart(14, '0')
}

const BASE64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

// A PNG's size, from its IHDR chunk: the first 24 bytes, 32 base64 characters.
export function pngSize(base64: string): { width: number; height: number } | undefined {
  const bytes: number[] = []
  for (let i = 0; i + 4 <= Math.min(32, base64.length); i += 4) {
    let n = 0
    for (let j = 0; j < 4; j += 1) n = n * 64 + Math.max(0, BASE64.indexOf(base64[i + j] ?? 'A'))
    bytes.push((n >> 16) & 255, (n >> 8) & 255, n & 255)
  }
  const word = (at: number) => bytes.slice(at, at + 4).reduce((n, b) => n * 256 + b, 0)
  const isPng = bytes.length >= 24 && bytes[0] === 0x89 && String.fromCharCode(...bytes.slice(12, 16)) === 'IHDR'

  return isPng ? { width: word(16), height: word(20) } : undefined
}

// The cells a picture of `width` by `height` pixels takes: as wide as its
// pixels ask, within the room, and as tall as its proportions then are.
export function cells(
  width: number,
  height: number,
  room: { columns: number; rows: number },
): { columns: number; rows: number } {
  const ratio = height / width / CELL_ASPECT
  let columns = Math.min(room.columns, 255, Math.ceil(width / SCALE / PIXELS_PER_COLUMN))
  let rows = Math.round(columns * ratio)
  if (rows > Math.min(room.rows, 255)) {
    rows = Math.min(room.rows, 255)
    columns = Math.round(rows / ratio)
  }

  return { columns: Math.max(1, columns), rows: Math.max(1, rows) }
}

// mmdc's error without its stack: `Error: Parse error on line 4:`, the line,
// the caret, what it expected.
export function reason(stderr: string): string {
  const lines = stderr.split('\n').map(line => line.trimEnd())
  const start = lines.findIndex(line => line.startsWith('Error'))
  const kept: string[] = []
  for (const line of start === -1 ? lines : lines.slice(start)) {
    if (/^\s+at |^[\w$.#]+ \(/.test(line)) break
    if (line !== '') kept.push(line)
  }

  return kept.slice(0, 6).join('\n') || 'mmdc failed'
}

type Diagram =
  | { kind: 'rendering' }
  | { kind: 'ready'; source: ImageSource; width: number; height: number }
  | { kind: 'failed'; error: string }

type Memo = {
  diagrams: Map<string, Diagram>
  // One mmdc at a time: each starts a Chromium.
  queue: Promise<void>
  folder?: Promise<string>
  isMmdcMissing: boolean
  // Whether this terminal shows the Images: found out by the first drawn.
  images: 'unknown' | 'probing' | 'yes' | 'no'
}

function cacheFolder($: EngineInterface, memo: Memo): Promise<string> {
  memo.folder ??= $.process
    .run(['sh', '-c', 'd="${XDG_CACHE_HOME:-$HOME/.cache}/claude-mermaid" && mkdir -p "$d" && printf %s "$d"'])
    .then(made => {
      if (made.exitCode !== 0 || made.stdout === '') throw new Error(made.stderr || 'no cache folder')

      return made.stdout
    })

  return memo.folder
}

async function render($: EngineInterface, memo: Memo, key: string, source: string): Promise<Diagram> {
  const png = `${await cacheFolder($, memo)}/${key}.png`
  if (!(await $.fs.exists(png))) {
    const argv = ['mmdc', '-i', '-', '-o', png, '-t', THEME, '-b', 'transparent', '-s', String(SCALE), '-q']
    const made = await $.process.run(argv, { stdin: source, timeoutMs: 60000 }).catch((error: unknown) => {
      memo.isMmdcMissing = true
      $.ui.toast(`mermaid: mmdc did not start (pacman -S mermaid-cli): ${String(error)}`)

      return undefined
    })
    if (made === undefined) return { kind: 'failed', error: 'mmdc did not start' }
    if (made.exitCode !== 0) return { kind: 'failed', error: reason(made.stderr) }
  }
  const { base64 } = await $.fs.read(png, { as: 'bytes' })
  const size = pngSize(base64)
  if (size === undefined) return { kind: 'failed', error: `mmdc wrote no PNG: ${png}` }

  return { kind: 'ready', source: { file: png, format: 'png' }, ...size }
}

function start($: EngineInterface, memo: Memo, key: string, source: string): void {
  memo.diagrams.set(key, { kind: 'rendering' })
  memo.queue = memo.queue.then(async () => {
    const diagram = await render($, memo, key, source).catch(
      (error: unknown): Diagram => ({ kind: 'failed', error: String(error) }),
    )
    memo.diagrams.set(key, diagram)
    $.ui.invalidate('ui.render')
  })
}

// A blit of an Image's own source sends nothing new, and is denied where the
// Image draws its alt: the terminal shows no images.
function probe(
  $: EngineInterface,
  memo: Memo,
  requestId: string,
  key: string,
  source: ImageSource,
  size: { columns: number; rows: number },
): void {
  memo.images = 'probing'
  void (async () => {
    await $.clock.sleep(300)
    const answer = await $.ui.blit({ requestId, key, source, ...size })
    memo.images = answer.deny === undefined ? 'yes' : answer.deny.includes('alt') ? 'no' : 'unknown'
    if (memo.images === 'no') $.ui.invalidate('ui.render')
  })()
}

export const register: Register = on => {
  const memo: Memo = { diagrams: new Map(), queue: Promise.resolve(), isMmdcMissing: false, images: 'unknown' }

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || e.props.isSummary || memo.isMmdcMissing || memo.images === 'no') return next(e)
    const found = parts(e.props.text)
    if (!found.some(part => part.kind === 'mermaid')) return next(e)

    const room = {
      columns: Math.max(20, (e.viewport?.columns ?? 80) - 4),
      rows: Math.max(8, (e.viewport?.rows ?? 40) - SPARE_ROWS),
    }
    const { Box, Image, Markdown, Text } = $.ui.resolve(e)
    let isDrawn = false
    const drawn: RenderElement[] = found.map((part, index) => {
      if (part.kind === 'markdown') return <Markdown text={part.text} />
      const key = hash(`${THEME}|${SCALE}|${part.source}`)
      const diagram = memo.diagrams.get(key)
      if (diagram === undefined) start($, memo, key, part.source)
      if (diagram?.kind === 'failed') {
        isDrawn = true

        return (
          <Box flexDirection="column">
            <Markdown text={part.text} />
            <Text dimColor>mermaid: {diagram.error}</Text>
          </Box>
        )
      }
      if (diagram?.kind !== 'ready') return <Markdown text={part.text} />
      isDrawn = true
      const size = cells(diagram.width, diagram.height, room)
      if (memo.images === 'unknown') probe($, memo, e.requestId, `d${index}`, diagram.source, size)

      return <Image key={`d${index}`} source={diagram.source} {...size} alt="[mermaid diagram]" />
    })

    // Nothing of the mod's own yet: the engine draws the reply as it is.
    if (!isDrawn) return next(e)

    return (
      <Box flexDirection="column" gap={1}>
        {drawn}
      </Box>
    )
  })
}
