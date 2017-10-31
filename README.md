# eta-parser

## Cloning

```
% git clone <repo>
% cd eta-parser
% git submodule update --init --recursive
```

## Building

You will need the following tools installed -

* alex
* etlas
* hpack

You can then build using `make` -

```
% make
```

## Issues

Currently getting the following compiler error -

```
[113 of 159] Compiling Language.Eta.Types.Unify ( gen/src/Language/Eta/Types/Unify.hs, dist/build/Language/Eta/Types/Unify.jar )

<no location info>:
    compiler/ETA/CodeGen/Main.hs:(156,31)-(162,56): Non-exhaustive patterns in case
```

## TODO

Originally I was commenting out all of the CPP macro usages (e.g. `ASSERT`, `WARN`), but this
is unnecessary now that I've figured out how to do it right. So we can uncomment those macro
usages to minimize our patches.

## Hacking

Currently, this project mostly uses patches to make the parser
compilable with the Eta compiler. The easiest way to modify the patches
is to 

* Use `make sources` to generate the sources
* Modify the sources generated in the `gen` directory
* Run `./tools/generate-patches` to update patches in the `patches` directory
