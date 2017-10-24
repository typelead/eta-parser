.PHONY: all clean hpack lexers sources build

all: lexers sources hpack build

clean:
	rm -rf \
	  eta-parse.cabal \
	  dist \
	  gen \
	  resources/lexers/*.patched.x

hpack:
	hpack

lexers:
	patch \
	  resources/lexers/Lexer.x \
	  resources/lexers/Lexer.patch \
	  -o resources/lexers/Lexer.patched.x
	mkdir -p gen/Language/Eta/Parser
	alex \
	  -o gen/Language/Eta/Parser/Lexer.hs \
	  resources/lexers/Lexer.patched.x

sources:
	mkdir -p gen/Language/Eta/Parser
	patch \
		resources/sources/compiler/ETA/Parser/ApiAnnotation.hs \
		resources/sources/compiler/ETA/Parser/ApiAnnotation.hs.patch \
		-o gen/Language/Eta/Parser/ApiAnnotation.hs

build:
	./etlas build
