import { expect, mock, test } from 'claude-code/testing'
import type { On, RenderElement } from 'claude-code'

import { cells, hash, parts, pngSize, reason } from './register'

const DIAGRAM = 'flowchart LR\n  A --> B'
const REPLY = `Here it is:\n\n\`\`\`mermaid\n${DIAGRAM}\n\`\`\`\n\nDone.`
// The first 24 bytes of a 1568 by 360 PNG.
const HEADER = 'iVBORw0KGgoAAAANSUhEUgAABiAAAAFo'
const ROW = {
  plugin: 'mermaid',
  surface: 'terminal',
  component: 'AssistantMessage',
  props: { text: REPLY, isFirstOfReply: true },
} as const

type Engine = { runs: string[][]; blits: number; clock: ReturnType<typeof mock.clock> }

// Beneath the mod: the engine's own row, the cache folder, mmdc, the PNG it
// wrote, and a terminal that shows images (or not).
function engine(on: On, { mmdc = 0, shows = true } = {}): Engine {
  const seen: Engine = { runs: [], blits: 0, clock: mock.clock(on) }
  on('ui.render', { component: 'AssistantMessage' }, ($, e) => {
    const { Markdown } = $.ui.resolve(e)

    return h(Markdown, { text: e.props.text }) as RenderElement
  })
  on('process.run', (_$, e) => {
    seen.runs.push([...e.argv])
    const isMmdc = e.argv[0] === 'mmdc'
    const stderr = isMmdc && mmdc !== 0 ? 'Error: Parse error on line 2:\n  A -->\n------^\nParser.parseError (x.mjs:1:1)' : ''

    return {
      value: {
        exitCode: isMmdc ? mmdc : 0,
        stdout: isMmdc ? '' : '/cache/claude-mermaid',
        stderr,
        isStdoutTruncated: false,
        isStderrTruncated: false,
      },
    }
  })
  on('fs.exists', () => ({ value: false }))
  on('fs.read', () => ({ value: { base64: `${HEADER}AAAA` } }))
  on('ui.blit', () => {
    seen.blits += 1

    return { value: shows ? {} : { deny: 'the Image draws its alt here: the terminal draws neither ...' } }
  })

  return seen
}

test('parts: a closed mermaid fence is cut out, other fences stay markdown', () => {
  expect(parts(REPLY)).toEqual([
    { kind: 'markdown', text: 'Here it is:\n' },
    { kind: 'mermaid', text: `\`\`\`mermaid\n${DIAGRAM}\n\`\`\``, source: DIAGRAM },
    { kind: 'markdown', text: '\nDone.' },
  ])
  expect(parts('```ts\nconst a = 1\n```')).toEqual([{ kind: 'markdown', text: '```ts\nconst a = 1\n```' }])
  // A mermaid example inside a markdown block is that block's text.
  const nested = '````markdown\n```mermaid\nA --> B\n```\n````'
  expect(parts(nested)).toEqual([{ kind: 'markdown', text: nested }])
  // Still being written: no closing fence yet.
  expect(parts('```mermaid\nflowchart LR\n  A')).toEqual([{ kind: 'markdown', text: '```mermaid\nflowchart LR\n  A' }])
})

test('pngSize reads the IHDR; cells keep the proportions within the room', () => {
  expect(pngSize(HEADER)).toEqual({ width: 1568, height: 360 })
  expect(pngSize('aGVsbG8gd29ybGQgaGVsbG8gd29ybGQh')).toBeUndefined()
  expect(cells(1568, 360, { columns: 150, rows: 40 })).toEqual({ columns: 98, rows: 11 })
  expect(cells(1568, 360, { columns: 76, rows: 40 })).toEqual({ columns: 76, rows: 8 })
  // Taller than the room: as many rows as it has, narrower to match.
  expect(cells(400, 4000, { columns: 150, rows: 30 })).toEqual({ columns: 6, rows: 30 })
  expect(hash('a')).not.toBe(hash('b'))
  expect(hash('a')).toHaveLength(14)
})

test('reason keeps mmdc error without its stack', () => {
  expect(reason('\nError: Parse error on line 4:\nA--\n---^\nExpecting X\nParser.parseError (https://x:1:2)\n    at y')).toBe(
    'Error: Parse error on line 4:\nA--\n---^\nExpecting X',
  )
})

test('a mermaid block is drawn as an Image once mmdc wrote it', async ($, on) => {
  const seen = engine(on)
  const ui = await $.ui.mount(ROW)

  const image = await ui.find({ type: 'Image' })
  expect(image?.props).toMatchObject({ source: { format: 'png' }, columns: 76, rows: 8 })
  expect(String((image?.props.source as { file: string }).file)).toMatch(/^\/cache\/claude-mermaid\/[0-9a-f]{14}\.png$/)
  expect(await ui.findAll({ type: 'Markdown' })).toHaveLength(2)
  const mmdc = seen.runs.find(argv => argv[0] === 'mmdc')
  expect(mmdc).toContain('dark')

  // The terminal showed it: the Image stays.
  await seen.clock.advance(300)
  expect(seen.blits).toBe(1)
  expect(await ui.find({ type: 'Image' })).toBeDefined()
})

test('a terminal that shows no images (herdr) gets the engine row back', async ($, on) => {
  const seen = engine(on, { shows: false })
  const ui = await $.ui.mount(ROW)
  expect(await ui.find({ type: 'Image' })).toBeDefined()

  await seen.clock.advance(300)
  expect(await ui.drawn()).toMatchObject({ type: 'Markdown', props: { text: REPLY } })
})

test('a block mmdc refuses keeps its code, with the error under it', async ($, on) => {
  engine(on, { mmdc: 1 })
  const ui = await $.ui.mount(ROW)

  expect(await ui.find({ type: 'Image' })).toBeUndefined()
  expect((await ui.find({ text: /Parse error on line 2/ }))?.text).toContain('------^')
  expect((await ui.find({ type: 'Markdown', text: /```mermaid/ }))?.text).toContain(DIAGRAM)
})

test('no mermaid block: the engine draws the row', async ($, on) => {
  const seen = engine(on)
  const ui = await $.ui.mount({ ...ROW, props: { ...ROW.props, text: 'plain `code`' } })

  expect(await ui.drawn()).toMatchObject({ type: 'Markdown', props: { text: 'plain `code`' } })
  expect(seen.runs).toEqual([])
})

test('the desktop draws the row as the engine does', async ($, on) => {
  const seen = engine(on)
  const ui = await $.ui.mount({ ...ROW, surface: 'desktop' })

  expect(await ui.drawn()).toMatchObject({ type: 'Markdown', props: { text: REPLY } })
  expect(seen.runs).toEqual([])
})
