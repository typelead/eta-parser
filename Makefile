.PHONY: all test versions clean sources hpack deps build

# Allow providing binaries in the bin/ dir (etlas, eta, etc.)
export PATH := $(PWD)/bin:$(PATH)

all: sources hpack deps build

test: hpack
	etlas test

versions:
	etlas --version
	etlas exec eta -- --version

clean:
	rm -rf \
	  eta-parser.cabal \
	  dist \
	  gen

sources:
	./tools/generate-sources

hpack:
	hpack

deps: hpack
	etlas install --dependencies-only

build: hpack
	etlas build
