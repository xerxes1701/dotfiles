// Fixture for verify.sh. Exercises the F# path: filetype detection (.fs is
// also Forth), treesitter parse and highlight, fsautocomplete attach, hover
// and Fantomas formatting.

module Program

let greet (who: string) = $"hello, {who}"

[<EntryPoint>]
let main _ =
    printfn "%s" (greet "world")
    0
