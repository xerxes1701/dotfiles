import { expect, mock, test } from 'claude-code/testing'
import type { Engine, EngineCall } from 'claude-code/testing'
import type { On } from 'claude-code'

const SAVED = '/tmp/claude-1000/-home-me-repo/s1/scratchpad/clipboard-20261013-101500.png'

// The engine beneath the plugin: a session, a script that answers `exitCode`
// (printing `saved`), and a prompt box that records what it was filled with.
// `env` stands for the host's environment, which tells Windows apart.
function engine(on: On, exitCode = 0, env: Record<string, string> = {}, saved = SAVED) {
  const fills: { text: string; mode?: string }[] = []
  const toasts: string[] = []
  const runs: { argv: readonly string[]; env?: Record<string, string> }[] = []
  mock.env(on, env)
  on('session.id', () => ({ value: 's1' }))
  on('session.root', () => ({ value: '/home/me/repo' }))
  on('process.run', (_$, e) => {
    runs.push({ argv: e.argv, env: e.init?.env })
    return {
      value: {
        exitCode,
        stdout: exitCode === 0 ? `${saved}\r\n` : '',
        stderr: exitCode === 3 ? 'paste-image.sh: no image on the clipboard\n' : '',
        isStdoutTruncated: false,
        isStderrTruncated: false,
      },
    }
  })
  on('prompt.fill', (_$, e) => {
    fills.push({ text: e.text, mode: e.mode })
    return { isFilled: true }
  })
  on('ui.toast', (_$, e) => {
    toasts.push(e.text)
    return { value: undefined }
  })
  on('prompt.edit', (_$, e) => ({
    text: e.text.slice(0, e.start) + e.inputText + e.text.slice(e.end),
    cursor: e.start + e.inputText.length,
  }))

  return { fills, toasts, runs }
}

// The terminal's edits reach prompt.edit from the engine alone; the kit's
// typings leave the call off `$`, but the engine answers it.
const edit = ($: Engine, text: string, inputText: string) =>
  ($.prompt as unknown as { edit: EngineCall<'prompt.edit'> }).edit(typed(text, inputText))

const command = ($: Engine, name: string) =>
  $.command.run({
    command: name,
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })

const typed = (text: string, inputText: string) => ({
  origin: { kind: 'composer' as const },
  text,
  cursor: text.length,
  start: text.length,
  end: text.length,
  inputText,
})

test('#img# is taken out and the saved image mentioned at the cursor', async ($, on) => {
  const clock = mock.clock(on)
  const { fills, runs } = engine(on)

  const box = await edit($, 'look at #img', '#')
  expect(box).toEqual({ text: 'look at ', cursor: 8 })

  await clock.advance(1)
  expect(runs[0]?.argv.slice(0, 2)).toEqual(['sh', '-c'])
  expect(runs[0]?.argv.slice(-2)).toEqual(['s1', '/home/me/repo'])
  expect(fills).toEqual([{ text: `@${SAVED} `, mode: 'insert' }])
})

test('a space keeps the mention apart from a word before it', async ($, on) => {
  const clock = mock.clock(on)
  const { fills } = engine(on)

  await edit($, 'see#img', '#')
  await clock.advance(1)
  expect(fills).toEqual([{ text: ` @${SAVED} `, mode: 'insert' }])
})

test('an edit without the token is left alone', async ($, on) => {
  const clock = mock.clock(on)
  const { runs } = engine(on)

  const box = await edit($, '#im', 'g')
  expect(box).toEqual({ text: '#img', cursor: 4 })
  await clock.advance(1)
  expect(runs).toEqual([])
})

test('/paste-image mentions the saved image and shows no row', async ($, on) => {
  const { fills } = engine(on)

  const result = await command($, 'paste-image')
  expect(result.text).toBe(undefined)
  expect(fills).toEqual([{ text: `@${SAVED} `, mode: 'insert' }])
})

test('/paste-image says so when the clipboard holds no image', async ($, on) => {
  const { fills } = engine(on, 3)

  const result = await command($, 'paste-image')
  expect(result.text).toBe('No image on the clipboard.')
  expect(fills).toEqual([])
})

test('#img# toasts when the clipboard holds no image', async ($, on) => {
  const clock = mock.clock(on)
  const { fills, toasts } = engine(on, 3)

  await edit($, '#img', '#')
  await clock.advance(1)
  expect(fills).toEqual([])
  expect(toasts).toEqual(['No image on the clipboard.'])
})

test('on Windows paste-image.ps1 saves it and the mention takes forward slashes', async ($, on) => {
  const saved = 'C:\\Users\\me\\AppData\\Local\\Temp\\claude\\C--repo\\s1\\scratchpad\\clipboard-1.png'
  const { fills, runs } = engine(on, 0, { OS: 'Windows_NT' }, saved)

  await command($, 'paste-image')
  expect(runs[0]?.argv[0]).toBe('powershell.exe')
  expect(runs[0]?.argv.at(-1)).toContain('paste-image.ps1')
  expect(runs[0]?.argv.at(-1)).not.toContain('"')
  expect(runs[0]?.env).toEqual({ PIMG_SESSION: 's1', PIMG_ROOT: '/home/me/repo' })
  expect(fills).toEqual([
    { text: '@C:/Users/me/AppData/Local/Temp/claude/C--repo/s1/scratchpad/clipboard-1.png ', mode: 'insert' },
  ])
})

test('on Windows a failure names paste-image.ps1', async ($, on) => {
  const { fills } = engine(on, 1, { OS: 'Windows_NT' })

  const result = await command($, 'paste-image')
  expect(result.text).toBe('paste-image.ps1 failed: exit 1')
  expect(fills).toEqual([])
})
