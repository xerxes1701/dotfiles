// Pastes the clipboard's image into the prompt as an @-mention of a file in
// the session's scratchpad, written by ~/.local/bin/paste-image.sh.
//
// The paste itself cannot be hooked: on WSL Claude Code answers an empty
// paste (what the terminal sends for an image) and a pasted image path on
// its own, and Ctrl+V is its own binding, so no hook ever sees them. Two
// triggers stand in: /paste-image, and #img# typed anywhere in the prompt.
import type { EngineInterface, Register } from 'claude-code'

const COMMAND = 'paste-image'
const TOKEN = '#img#'

// The scratchpad is <tmp>/claude-<uid>/<project dir, sanitized>/<session>/
// scratchpad. The session id is unique, so the folder is looked up by it,
// and only built from the project root when Claude Code has not made it yet.
const SAVE = `
sid=$1 root=$2
base=\${CLAUDE_CODE_TMPDIR:-/tmp}/claude-$(id -u)
dir=
for d in "$base"/*/"$sid"/scratchpad; do
    [ -d "$d" ] && { dir=$d; break; }
done
[ -n "$dir" ] || dir=$base/$(printf '%s' "$root" | sed 's/[^A-Za-z0-9]/-/g')/$sid/scratchpad
mkdir -p -m 700 "$dir" || exit 1
script=$HOME/.local/bin/paste-image.sh
[ -x "$script" ] || script=paste-image.sh
exec "$script" -- "$dir/"
`

// Exit 3 is paste-image.sh's "no image on the clipboard".
async function saveClipboardImage($: EngineInterface): Promise<{ path: string } | { error: string }> {
  const [sid, root] = await Promise.all([$.session.id(), $.session.root()])
  const run = await $.process.run(['sh', '-c', SAVE, 'sh', sid, root], { timeoutMs: 20_000 })
  const path = run.stdout.trim().split('\n').at(-1) ?? ''
  if (run.exitCode === 0 && path !== '') return { path }
  if (run.exitCode === 3) return { error: 'No image on the clipboard.' }
  const reason = run.stderr.trim().split('\n')[0] || `exit ${run.exitCode}`

  return { error: `paste-image.sh failed: ${reason}` }
}

// `before` is put ahead of the mention where the text before the cursor
// would otherwise run into the @ and keep it from being read as a mention.
async function pasteIntoPrompt($: EngineInterface, before = ''): Promise<string | undefined> {
  const saved = await saveClipboardImage($)
  if ('error' in saved) return saved.error
  const { isFilled } = await $.prompt.fill({ text: `${before}@${saved.path} `, mode: 'insert' })

  return isFilled ? undefined : `Saved ${saved.path}, but the prompt box did not take it.`
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: COMMAND,
      description: "Save the clipboard's image to the scratchpad and mention it in the prompt",
    })

    return next(e)
  })

  on('command.run', { command: COMMAND }, async $ => {
    const error = await pasteIntoPrompt($)

    return error === undefined ? {} : { text: error }
  })

  // The token is taken out at once; the script takes a second or so (Windows
  // PowerShell starting), longer than an edit may wait, so the mention is
  // inserted at the cursor from a timer once the file is written.
  on('prompt.edit', async ($, e, next) => {
    const box = await next(e)
    const at = box.text.indexOf(TOKEN)
    if (at === -1) return box
    const text = box.text.slice(0, at) + box.text.slice(at + TOKEN.length)
    const cursor = box.cursor >= at + TOKEN.length ? box.cursor - TOKEN.length : Math.min(box.cursor, at)
    const before = at > 0 && !/\s/.test(text.charAt(at - 1)) ? ' ' : ''
    $.clock.after(0, () => {
      void pasteIntoPrompt($, before).then(error => {
        if (error !== undefined) $.ui.toast(error)
      })
    })

    return { text, cursor }
  })
}
