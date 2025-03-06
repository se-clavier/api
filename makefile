.PHONY: all
all: src/lib.rs index.ts

.PHONY: clean
clean:
	rm src/lib.rs index.ts

.PHONY: prepare
prepare:
	apt --no-install-recommends install -y racket

src/lib.rs: api.rkt rust.rkt 
	racket rust.rkt < $< > $@

index.ts: api.rkt rust.rkt
	racket typescript.rkt < $< > $@

