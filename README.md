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

Currently we get a compiler panic due to a native call -

```
<no location info>:
    eta: panic! (the 'impossible' happened)
  (Eta version 0.0.9b2):
        tcCheckFIType: Unsupported calling convention.
  ccall unsafe "value ghc_strlen"
```
