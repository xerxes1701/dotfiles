import { expect, mock, test } from 'claude-code/testing'

test('/cls runs /clear and prints nothing of its own', async ($, on) => {
  const clock = mock.clock(on)
  const cleared: string[] = []
  on('command.run', { command: 'clear' }, (_$, e) => {
    cleared.push(e.args)
    return {}
  })

  const result = await $.command.run({
    command: 'cls',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })
  await clock.advance(1)

  expect(result.text).toBe(undefined)
  expect(cleared).toEqual([''])
})
