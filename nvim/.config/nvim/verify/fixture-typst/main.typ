// Entry point of the Typst fixture. verify/check.lua opens this file and
// requires that it gets the `typst` filetype, a typst treesitter parse, and --
// when a tinymist binary is on PATH -- an attached tinymist client.

#import "chapter.typ": fixture-heading, golden-ratio

#set page(width: 10cm, height: auto, margin: 1cm)
#set text(size: 10pt)

#fixture-heading("Typst fixture")

The golden ratio is $phi approx #golden-ratio$, the positive root of

$ phi = (1 + sqrt(5)) / 2. $

#for i in range(1, 4) [
  - item #i
]
