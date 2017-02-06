LibYAML-Ada
===========

This repository provides a tiny Ada wrapper around the
[LibYAML](https://github.com/yaml/libyaml) C library.

For now, it only supports reading YAML documents in a single shot (from an
in-memory string or from a file) and exploring nodes in resulting documents.


How to use
----------

Assuming you use a [project
file](http://docs.adacore.com/gprbuild-docs/html/gprbuild_ug.html), just add
a dependency on `libyaml_ada.gpr` as a dependency:

```
with "libyaml_ada.gpr";

project Foo is
--  ...
```

Doing so will include object files in your program/library build.


Why not writing a pure Ada library?
-----------------------------------

Writing a correct and comprehensive parser seems to be a huge task. Binding an
existing libraary looked easy enough: I managed to write a basic binding in
approximately one dayy. Feel free to start your own library.


What about the license?
-----------------------

I'm not a lawyer, so I need to figure out what constraints I have given the
dependency on LibYAML.


TODO
----

*   Decent handling for parsing errors: right now, users just get a rude
    `Program_Error`.

*   Expose marks (source locations) in nodes.

*   Document construction.

*   Document emission (YAML document dump to a text file).
