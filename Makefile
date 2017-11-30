.PHONY: all test versions clean sources hpack deps build

# Allow providing binaries in the bin/ dir (etlas, eta, etc.)
export PATH := $(PWD)/bin:$(PATH)

LEXER_HS := gen/src/Language/Eta/Parser/Lexer.hs

all: sources hpack deps build

test: hpack
	etlas test

versions:
	etlas --version
	etlas exec eta -- --version
	eta --version || true

clean:
	rm -rf dist gen

sources:
	./tools/generate-sources
	./tools/post-process-alex-tables $(LEXER_HS)

# Not going to use hpack for now since it doesn't support
# the java-sources field necessary for etlas
hpack:
	echo "skipping hpack..."

deps: hpack
	etlas install --dependencies-only

build: hpack
	etlas build
