.PHONY: all clean sources hpack deps build

# Allow providing an etlas script instead of requiring it to
# be on the PATH
ifneq ($(wildcard ./etlas),)
ETLAS = ./etlas
else
ETLAS = etlas
endif

all: sources hpack deps build

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
	$(ETLAS) install --dependencies-only

build:
	$(ETLAS) build
