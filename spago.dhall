{ name = "ocarina"
, dependencies =
  [ "aff"
  , "aff-promise"
  , "arraybuffer-types"
  , "bolson"
  , "control"
  , "convertable-options"
  , "effect"
  , "fast-vect"
  , "foldable-traversable"
  , "foreign"
  , "foreign-object"
  , "homogeneous"
  , "hyrule"
  , "integers"
  , "js-timers"
  , "lcg"
  , "lists"
  , "maybe"
  , "newtype"
  , "numbers"
  , "ordered-collections"
  , "prelude"
  , "profunctor"
  , "profunctor-lenses"
  , "quickcheck"
  , "refs"
  , "safe-coerce"
  , "simple-json"
  , "sized-vectors"
  , "st"
  , "tuples"
  , "type-equality"
  , "typelevel"
  , "typelevel-prelude"
  , "unsafe-coerce"
  , "unsafe-reference"
  , "variant"
  , "web-events"
  , "web-file"
  , "web-html"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
}
