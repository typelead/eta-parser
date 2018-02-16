.PHONY: all test versions clean sources hpack deps build

# Allow providing binaries in the bin/ dir (etlas, eta, etc.)
export PATH := $(PWD)/bin:$(PATH)

LEXER_HS := gen/src/Language/Eta/Parser/Lexer.hs

all: sources hpack deps build

sources: gen/include gen/src gen/lexer

gen/include:
	mkdir -p gen/include
	cp eta/include/HsVersions.h gen/include

gen/src:
	./tools/generate-sources

gen/lexer:
	./tools/generate-lexer
	stack runghc -- ./tools/post-process-alex-tables.hs $(LEXER_HS)

test: all
	etlas test

versions:
	etlas --version
	etlas exec eta -- --version
	eta --version || true

clean:
	rm -rf dist gen eta-parser.cabal

hpack:
	./tools/hpack

deps: hpack
	etlas install --dependencies-only

build: hpack
	etlas build
