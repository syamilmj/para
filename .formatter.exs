locals_without_parens = [
  required: 1,
  required: 2,
  required: 3,
  optional: 1,
  optional: 2,
  optional: 3,
  callback: 1,
  embeds_one: 2,
  embeds_many: 2
]

[
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
