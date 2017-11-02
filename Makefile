.PHONY: all versions clean sources hpack deps build

# Allow providing binaries in the bin/ dir (etlas, eta, etc.)
export PATH := bin:$(PATH)

all: sources hpack deps build

versions:
	eta --version
	etlas --version

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
