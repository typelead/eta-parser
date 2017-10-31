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

## Hacking

Currently, this project mostly uses patches to make the parser
compilable with the Eta compiler. The easiest way to modify the patches
is to 

* Use `make sources` to generate the sources
* Modify the sources generated in the `gen` directory
* Run `./tools/generate-patches` to update patches in the `patches` directory

