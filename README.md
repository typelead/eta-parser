# eta-parser

## Cloning

```
git clone --recursive https://github.com/typelead/eta-parser
```

If you forgot to add the recursive flag, you can run the following commands:
```
cd eta-parser
git submodule sync
git submodule update --init --recursive
```

## Building

You will need the following tools installed:

* alex
* etlas
* hpack

You can then build using `make`:

```
make
```

## Tests

You can run a simple test suite with:

```
make test
```

## Hacking

Currently, this project mostly uses patches to make the parser
compilable with the Eta compiler. The easiest way to modify the patches
is to 

* Use `make sources` to generate the sources
* Modify the sources generated in the `gen` directory
* Run `./tools/generate-patches` to update patches in the `patches` directory
