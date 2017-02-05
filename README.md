LibYAML-Ada
===========

This repository provides a tiny Ada wrapper around LibYAML. For now it only
supports reading YAML documents in a single shot.


How to use
==========

Assuming you use a [project
file](http://docs.adacore.com/gprbuild-docs/html/gprbuild_ug.html), just add
a dependency on `libyaml_ada.gpr` as a dependency:

```
with "libyaml_ada.gpr";

project Foo is
--  ...
```
