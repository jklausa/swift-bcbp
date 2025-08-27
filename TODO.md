to not be embarassed:

* write tests for round-tripping
    * fix round-tripping for spec-violating BPs
* test with more BPs
* clean up the interface

to have fun:

* add a better interface to it, that abstracts from "RawBoardingPass" and has
  abstractions for like, cabins, and interpretations for all the weird fields,
  like what does "M" as a issuing point
* layer extra interpretaion for airline private data? should be able to extract
  status at least easily?
* idk like, airport mapping or whatever? probably should live a layer above
  rather than here
