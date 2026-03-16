to not be embarassed:

* write tests for round-tripping
    * fix round-tripping for spec-violating BPs
* test with more BPs
* clean up the interface
* split out the specific parsers into a file
* write up the architecture, what are each specific parsers for?
* add a way to enforce "strict" mode?
* add a way to only enable workaround for specific quirks, not all of them
* have the top level `RawBoardingPass` have more sensible interface than whatever this is
* audit the implementation to be consistent about where we trim the whitespace and where we don't
* fix all `withKnownIssue`
* write better docs

to have fun:

* add a better interface to it, that abstracts from "RawBoardingPass" and has
  abstractions for like, cabins, and interpretations for all the weird fields,
  like what does "M" as a issuing point
* layer extra interpretaion for airline private data? should be able to extract
  status at least easily?
* idk like, airport mapping or whatever? probably should live a layer above
  rather than here
