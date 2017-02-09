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
existing library looked easy enough: I managed to write a basic binding in
approximately one day. Feel free to start your own library.


Running the testsuite
---------------------

From the top-level directory, run:

```
$ ./runtests.py
```

This will run all tests in the `tests` sub-directory and print their status on
the standard output.  Each Ada source file (`*.adb`) in this directory is
considered to be a main.  They are all compiled as a single project, then each
is run and its output is checked against the corresponding `.out` text file. If
both match, the test passes, otherwise it fails.

Using Valgrind's memcheck tool, it is possible to check for memory leaks in
testcases: just add the `--valgrind` argument to the above command. Errors will
appear on the standard output and will thus make the output comparison fail.


TODO
----

*   Document construction.

*   Document emission (YAML document dump to a text file).
