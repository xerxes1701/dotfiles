import { expect, test } from 'claude-code/testing'
import type { On, RenderElement } from 'claude-code'

const BAND = {
  plugin: 'code-fence',
  surface: 'terminal',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 80, scroll: { offset: 0, bodyRows: 10 }, view: {} },
} as const
const USAGE = { input_tokens: 1, output_tokens: 1, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }

type Box = { text: string; cursor: number }

// Beneath the mod: an empty band, a prompt box, the mouse selection and
// Haiku's answer.
function engine(on: On, box: Box, marked: { text: string; requestId?: string } | undefined, answer = 'python') {
  const asked: string[] = []
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => h($.ui.resolve(e).Box, {}) as RenderElement)
  on('ui.selection', () => ({ value: marked }))
  on('prompt.read', () => ({ value: { ...box } }))
  on('prompt.fill', (_$, e) => {
    if (e.mode === 'insert') {
      box.text = box.text.slice(0, box.cursor) + e.text + box.text.slice(box.cursor)
      box.cursor += e.text.length
    } else {
      box.text = e.mode === 'append' ? box.text + e.text : e.text
      box.cursor = box.text.length
    }

    return { isFilled: true, text: box.text, cursor: box.cursor }
  })
  on('model.complete', (_$, e) => {
    asked.push(e.prompt)

    return { value: { isAnswered: true as const, text: answer, usage: USAGE } }
  })

  return asked
}

// The next key landing inside the empty block is the prompt.edit hook's, which
// no test can raise: it is checked live.
test('nothing marked: an empty block on lines of its own', async ($, on) => {
  const box = { text: 'see', cursor: 3 }
  const asked = engine(on, box, undefined)
  const ui = await $.ui.mount(BAND)
  await ui.press({ key: 'code-fence' })

  expect(box.text).toBe('see\n```\n\n```')
  expect(asked).toEqual([])
})

test('a text marked in the transcript goes in a block at the cursor, its language named', async ($, on) => {
  const box = { text: 'fix this\nplease', cursor: 8 }
  const asked = engine(on, box, { text: 'print(1)\n', requestId: 'row-1' })
  const ui = await $.ui.mount(BAND)
  await ui.press({ key: 'code-fence' })

  expect(box.text).toBe('fix this\n```python\nprint(1)\n```\nplease')
  expect(asked[0]).toContain('print(1)')
})

test('a text marked in the prompt is wrapped where it stands', async ($, on) => {
  const box = { text: 'why does ls -la fail', cursor: 0 }
  engine(on, box, { text: 'ls -la' }, 'bash')
  const ui = await $.ui.mount(BAND)
  await ui.press({ key: 'code-fence' })

  expect(box.text).toBe('why does \n```bash\nls -la\n```\n fail')
})

test('a text already put in a block counts as nothing marked', async ($, on) => {
  const box = { text: '', cursor: 0 }
  const asked = engine(on, box, { text: 'a = 1', requestId: 'row-1' })
  const ui = await $.ui.mount(BAND)
  await ui.press({ key: 'code-fence' })
  await ui.press({ key: 'code-fence' })

  expect(box.text).toBe('```python\na = 1\n```\n```\n\n```')
  expect(asked).toHaveLength(1)
})

test('backticks in the code lengthen the fence; an answer that is no language leaves it bare', async ($, on) => {
  const box = { text: '', cursor: 0 }
  engine(on, box, { text: 'use ```js``` here', requestId: 'row-1' }, 'This is prose about js, not code: text')
  const ui = await $.ui.mount(BAND)
  await ui.press({ key: 'code-fence' })

  expect(box.text).toBe('````\nuse ```js``` here\n````')
})
