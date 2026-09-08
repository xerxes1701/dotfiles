// Imported by main.typ, so the fixture is a project and not a lone file:
// resolving the import is work only a language server with a correct root can
// do, which is what the probe in verify/check.lua is there to catch.

#let golden-ratio = calc.round((1.0 + calc.sqrt(5.0)) / 2.0, digits: 5)

#let fixture-heading(title) = [
  = #title
  #emph[Fixture opened by verify/check.lua.]
]
