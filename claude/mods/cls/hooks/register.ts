import type { Register } from 'claude-code'

// A command.run hook can neither rename the command it serves nor run another
// one while the turn waits on it, so /cls answers at once and runs /clear from
// a timer right after.
export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'cls', description: 'Clear conversation history (alias for /clear)' })

    return next(e)
  })

  on('command.run', { command: 'cls' }, async $ => {
    $.clock.after(0, () => $.command.run({ command: 'clear' }))

    return {}
  })
}
