# rust: rustup installs no toolchain itself, and puts a rust-analyzer proxy on
# PATH whether the component is there or not. rustaceanvim and nvim's
# verify.sh, which has no mason, run that proxy, and it fails without the
# component.

# winget's rustup lands in ~/.cargo/bin, which a shell started before the
# install does not have on PATH yet.
rustup=$(command -v rustup || echo "$HOME/.cargo/bin/rustup")

setup_needed() {
    [ -x "$rustup" ] || return 1
    ! "$rustup" show active-toolchain >/dev/null 2>&1 && return 0
    ! "$rustup" component list --installed 2>/dev/null | grep -q '^rust-analyzer'
}

setup_apply() {
    "$rustup" show active-toolchain >/dev/null 2>&1 || run "$rustup" default stable || return
    run "$rustup" component add rust-analyzer
}
