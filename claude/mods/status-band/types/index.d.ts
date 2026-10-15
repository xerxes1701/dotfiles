// What the status band draws from, and the menu it has open.

/** A limit's window as the status line resolved it: percent used, reset time. */
export type LimitWindow = { used: number; resetsAt: number }

/** What the status line was last told, with the live values laid over it. */
export type Snapshot = {
  sessionId: string
  modelId: string
  modelName: string | null
  effort: string | null
  cwd: string
  contextPercent: number | null
  contextSize: number | null
  fiveHour: LimitWindow | null
  sevenDay: LimitWindow | null
  /** NORMAL, INSERT, VISUAL, VISUAL LINE; null while vim mode is off. */
  vimMode: string | null
  isVim: boolean
  outputStyle: string | null
  sessionName: string | null
  transcriptPath: string | null
  /** When it was read, so the limits' countdowns are drawn from then. */
  readAt: number
}

export type GitCounts = {
  conflicted: number
  staged: number
  renamed: number
  modified: number
  deleted: number
  typechanged: number
  untracked: number
  stashed: number
  ahead: number
  behind: number
}

export type GitInfo = {
  root: string
  branch: string | null
  hash: string | null
  state: string | null
  counts: GitCounts
}

/** A run of git commands, each an argv after `git`, in the repository. */
export type GitOp = { cwd: string; steps: string[][]; done: string }

/** A question before a git op runs: what it does, and the op. */
export type Confirm = { text: string; detail: string[]; op: GitOp }

export type Branch = { name: string; isCurrent: boolean; isRemote: boolean; age: string }
export type Stash = { ref: string; subject: string; age: string }
export type SessionEntry = { id: string; title: string; age: string }

export type Menu =
  | { kind: 'context' }
  | { kind: 'model'; options: string[]; current: string }
  | { kind: 'effort'; current: string | null }
  | { kind: 'folder'; cwd: string; dir: string; subdirs: string[] }
  | { kind: 'branch'; cwd: string; branches: Branch[] }
  | {
      kind: 'changes'
      cwd: string
      files: string[]
      hasStaged: boolean
      hasUntracked: boolean
      ask?: 'commit-staged' | 'commit-all' | 'stash'
    }
  | { kind: 'stash'; cwd: string; stashes: Stash[]; selected?: number; ask?: 'rename' }
  | { kind: 'vim'; isVim: boolean; mode: string | null }
  | { kind: 'style'; options: string[]; current: string }
  | { kind: 'session'; name: string | null; sessions: SessionEntry[]; ask?: 'rename' }

/**
 * Who draws the strips, as /status-band sets it in status-band/mode: the band
 * (`mod`), the status line (`band`), or neither (`off`).
 */
export type BandMode = 'mod' | 'band' | 'off'

export type MenuState = { menu: Menu; confirm?: Confirm; busy?: string; error?: string }

declare module 'claude-code' {
  interface PluginState {
    'status-band': {
      snapshot: Snapshot | null
      git: GitInfo | null
      menu: MenuState | null
      mode: BandMode
    }
  }
}
