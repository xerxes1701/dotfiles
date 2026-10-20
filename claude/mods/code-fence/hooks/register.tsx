// ctrl+x c puts a fenced code block in the prompt. With a text marked by the
// mouse (fullscreen only), the block holds that text and Haiku, at low effort,
// names its language for the fence; marked inside the prompt, the text is
// wrapped where it stands. Without one, the block is empty and the next key
// typed lands inside it.
//
// A mod cannot bind a key of its own. A Button can take an engine action's
// chord instead, while no engine handler of that action is mounted:
// app:toggleDiffNoiseFilter has one only in the diff panel, so ctrl+x c is
// bound to it in the Global context (~/.claude/keybindings.json). A chord,
// as Claude Code's own ctrl+x keys are: every terminal and keyboard layout
// sends it, where ctrl+` is a dead key on a German one.
import type { EngineInterface, Register } from 'claude-code'

const ACTION = 'app:toggleDiffNoiseFilter'
const LANGUAGE = /^[a-z0-9][a-z0-9+#._-]{0,31}$/
const PLAIN = new Set(['text', 'plaintext', 'plain', 'none'])
// Haiku sees no more of a long text than this; the language shows early.
const SAMPLE = 4000

async function language($: EngineInterface, code: string): Promise<string> {
  const reply = await $.model.complete({
    model: 'haiku',
    effort: 'low',
    maxTokens: 16,
    timeoutMs: 15000,
    system:
      'You name the language of a snippet for the info string of a Markdown code fence. ' +
      'You reply with one lowercase word and nothing else: no sentence, no explanation.',
    prompt:
      'The info string, as Markdown uses it (python, ts, tsx, bash, powershell, json, yaml, toml, sql, ' +
      'csharp, cpp, diff, log, ...); text when it is no code, such as a path or prose.\n\n' +
      `<snippet>\n${code.slice(0, SAMPLE)}\n</snippet>`,
  })
  if (!reply.isAnswered) return ''
  // Anything but one word (a sentence about the snippet) names no language.
  const word = reply.text.trim().replace(/^`+|`+$/g, '').toLowerCase()

  return LANGUAGE.test(word) && !PLAIN.has(word) ? word : ''
}

// A fence longer than any run of backticks in the code, so none closes it.
function ticks(code: string): string {
  const longest = Math.max(0, ...Array.from(code.matchAll(/`+/g), m => m[0].length))

  return '`'.repeat(Math.max(3, longest + 1))
}

// The block on lines of its own between what stands before and after it.
function framed(text: string, start: number, end: number, block: string): string {
  const before = start > 0 && text[start - 1] !== '\n' ? '\n' : ''
  const after = end < text.length && text[end] !== '\n' ? '\n' : ''

  return before + block + after
}

// Where the marked text stands in the draft, the place nearest the cursor.
function locate(draft: string, marked: string, cursor: number): number {
  let best = -1
  for (let at = draft.indexOf(marked); at !== -1; at = draft.indexOf(marked, at + 1)) {
    if (best === -1 || Math.abs(at - cursor) < Math.abs(best - cursor)) best = at
  }

  return best
}

type Memo = {
  // The engine answers the last mouse selection until the next prompt runs,
  // long after its highlight is gone, so a text already put in a block counts
  // as nothing marked.
  used?: string
  // After an empty block the cursor stands past its closing fence: the next
  // text typed right there goes to `target`, the block's empty line.
  caret?: { at: number; target: number }
}

async function insert($: EngineInterface, memo: Memo): Promise<void> {
  const marked = await $.ui.selection()
  const code = marked?.text.replace(/\s+$/, '') ?? ''

  if (marked === undefined || code.trim() === '' || marked.text === memo.used) {
    const box = await $.prompt.read()
    const text = framed(box.text, box.cursor, box.cursor, '```\n\n```')
    const filled = await $.prompt.fill({ text, mode: 'insert' })
    const inside = text.indexOf('```\n') + '```\n'.length
    if (filled.isFilled) memo.caret = { at: filled.cursor, target: filled.cursor - text.length + inside }

    return
  }

  $.ui.status('code-fence: naming the language...')
  const name = await language($, code).finally(() => $.ui.status(undefined))
  const block = `${ticks(code)}${name}\n${code}\n${ticks(code)}`
  const box = await $.prompt.read()
  const at = marked.requestId === undefined ? locate(box.text, marked.text, box.cursor) : -1
  const filled =
    at === -1
      ? await $.prompt.fill({ text: framed(box.text, box.cursor, box.cursor, block), mode: 'insert' })
      : await $.prompt.fill({
          text:
            box.text.slice(0, at) +
            framed(box.text, at, at + marked.text.length, block) +
            box.text.slice(at + marked.text.length),
        })
  if (filled.isFilled) memo.used = marked.text
}

export const register: Register = on => {
  const memo: Memo = {}

  on('prompt.submit', ($, e, next) => {
    memo.used = undefined
    memo.caret = undefined

    return next(e)
  })

  on('prompt.edit', ($, e, next) => {
    const pending = memo.caret
    memo.caret = undefined
    const isTypedThere = e.inputText !== '' && e.start === pending?.at && e.end === pending.at
    if (pending === undefined || !isTypedThere || e.text.length < pending.at) return next(e)

    return {
      text: e.text.slice(0, pending.target) + e.inputText + e.text.slice(pending.target),
      cursor: pending.target + e.inputText.length,
    }
  })

  // The Button only has to be mounted to take the chord; it is never shown.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) return next(e)
    const { Box, Button } = $.ui.resolve(e)
    const below = await next(e)

    return (
      <Box flexDirection="column">
        <Box display="none">
          <Button key="code-fence" label="code block" action={ACTION} onPress={() => insert($, memo)} />
        </Box>
        {below}
      </Box>
    )
  })
}
