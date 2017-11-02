.PHONY: all versions clean sources hpack deps build

# Allow providing binaries in the bin/ dir (etlas, eta, etc.)
export PATH := $(PWD)/bin:$(PATH)

all: sources hpack deps build

versions:
	etlas --version
	etlas exec eta -- --version

clean:
	rm -rf \
	  eta-parse.cabal \
	  dist \
	  gen

sources:
	./tools/generate-sources

hpack:
	hpack

deps:
	etlas install --dependencies-only

build:
	etlas build
