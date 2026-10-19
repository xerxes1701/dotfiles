import { expect, test } from 'claude-code/testing'

import {
  BANDS, childOf, modelScale, parentOf, parseMode, parseStatus, pickMode, prettyModel, timeUntil, USED_TINTS, usedTint,
} from './look'

test('git status is counted the way the status line counts it', async () => {
  const out = [
    '# branch.oid 302a58e0123456789abcdef0123456789abcdef0',
    '# branch.head main',
    '# branch.upstream origin/main',
    '# branch.ab +2 -1',
    '# stash 3',
    '1 .M N... 100644 100644 100644 a a claude/a.mjs',
    '1 M. N... 100644 100644 100644 a a b.txt',
    '1 MM N... 100644 100644 100644 a a c.txt',
    '1 .D N... 100644 100644 000000 a a d.txt',
    '2 R. N... 100644 100644 100644 a a R100 new.txt\told.txt',
    'u UU N... 100644 100644 100644 100644 a a a conflict.txt',
    '? notes.md',
    '? other.md',
  ].join('\n')

  expect(parseStatus(out)).toEqual({
    branch: 'main',
    hash: '302a58e',
    counts: {
      conflicted: 1, staged: 2, renamed: 1, modified: 2, deleted: 1, typechanged: 0, untracked: 2, stashed: 3, ahead: 2, behind: 1,
    },
  })
})

test('a new repository and a detached head have no branch or no hash', async () => {
  expect(parseStatus('# branch.oid (initial)\n# branch.head main\n')).toMatchObject({ branch: 'main', hash: null })
  expect(parseStatus('# branch.oid 0123456789abcdef\n# branch.head (detached)\n')).toMatchObject({ branch: null, hash: '0123456' })
})

test('models read as the status line names and colours them', async () => {
  expect(prettyModel('claude-opus-5-5', 'Opus')).toBe('Opus 5.5')
  expect(prettyModel('claude-sonnet-5-5[1m]', null)).toBe('Sonnet 5.5 (1M)')
  expect(modelScale('claude-haiku-5-5', null)).toBe('green')
  expect(modelScale('claude-fable-5-1', null)).toBe('red')
})

test('the folder menu walks up and down on either separator', async () => {
  expect(parentOf('/home/me/dotfiles')).toBe('/home/me')
  expect(parentOf('/home')).toBe('/')
  expect(parentOf('/')).toBe('/')
  expect(parentOf('C:\\Users\\me')).toBe('C:\\Users')
  expect(parentOf('C:\\Users')).toBe('C:\\')
  expect(childOf('/home/me', 'src')).toBe('/home/me/src')
  expect(childOf('C:\\Users', 'me')).toBe('C:\\Users\\me')
  expect(childOf('/', 'tmp')).toBe('/tmp')
})

test('limits count down in days, hours and minutes', async () => {
  const now = 1_000_000_000_000
  expect(timeUntil(now + 4 * 3_600_000 + 27 * 60_000, now)).toBe('4h 27m')
  expect(timeUntil(now + 35 * 3_600_000, now)).toBe('1d 11h')
  expect(timeUntil(now + 5 * 60_000, now)).toBe('5m')
})

test('usage runs from green at 0% to red at 100%', async () => {
  expect(usedTint(USED_TINTS.band, 0)).toEqual(BANDS.green.text)
  expect(usedTint(USED_TINTS.band, 50)).toEqual(BANDS.yellow.text)
  expect(usedTint(USED_TINTS.band, 100)).toEqual(BANDS.red.text)
  expect(usedTint(USED_TINTS.surface, 150)).toEqual(USED_TINTS.surface[4])
})

test('the mode file and /status-band pick who draws the strips', async () => {
  expect(parseMode(null)).toBe('mod')
  expect(parseMode('band\n')).toBe('band')
  expect(parseMode(' OFF ')).toBe('off')
  expect(parseMode('bogus')).toBe('mod')
  expect(pickMode('', 'mod')).toBe('band')
  expect(pickMode('', 'band')).toBe('off')
  expect(pickMode('', 'off')).toBe('mod')
  expect(pickMode(' Off', 'mod')).toBe('off')
  expect(pickMode('on', 'mod')).toBe(null)
})
