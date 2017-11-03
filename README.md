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

## Tests

You can run a simple test suite with -

```
make test
```

## Issues

Currently getting the following runtime error during `make test` -

```
Exception in thread "main" java.lang.ClassFormatError: Invalid method Code length 185470 in class file eta_parser/language/eta/parser/Lexer$$Lr1SA4Elvl4456
        at java.lang.ClassLoader.defineClass1(Native Method)
        at java.lang.ClassLoader.defineClass(ClassLoader.java:763)
        at java.security.SecureClassLoader.defineClass(SecureClassLoader.java:142)
        at java.net.URLClassLoader.defineClass(URLClassLoader.java:467)
        at java.net.URLClassLoader.access$100(URLClassLoader.java:73)
        at java.net.URLClassLoader$1.run(URLClassLoader.java:368)
        at java.net.URLClassLoader$1.run(URLClassLoader.java:362)
        at java.security.AccessController.doPrivileged(Native Method)
        at java.net.URLClassLoader.findClass(URLClassLoader.java:361)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:424)
        at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:335)
        at java.lang.ClassLoader.loadClass(ClassLoader.java:357)
        at main.Main$main1.applyV(Test.hs:24)
        at main.Main$DZCmain.applyV(Test.hs)
        at eta.runtime.stg.Closures$EvalLazyIO.enter(Closures.java:104)
        at eta.runtime.stg.Capability.schedule(Capability.java:157)
        at eta.runtime.stg.Capability.scheduleClosure(Capability.java:102)
        at eta.runtime.Runtime.evalLazyIO(Runtime.java:189)
        at eta.runtime.Runtime.main(Runtime.java:182)
        at eta.main.main(Unknown Source)
Test suite test: FAIL
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
