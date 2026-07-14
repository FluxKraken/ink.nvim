TREE_SITTER ?= tree-sitter
NVIM ?= nvim

ROOT := $(CURDIR)
GRAMMAR := $(ROOT)/tree-sitter-inkcss
TEST_RUNTIME := $(ROOT)/.test-runtime
PARSER := $(TEST_RUNTIME)/parser/inkcss.so

.PHONY: generate test test-grammar test-nvim build-parser clean

generate:
	cd $(GRAMMAR) && $(TREE_SITTER) generate --js-runtime native

test: test-grammar test-nvim

test-grammar: generate
	cd $(GRAMMAR) && $(TREE_SITTER) test

build-parser: generate
	mkdir -p $(TEST_RUNTIME)/parser
	$(TREE_SITTER) build --output $(PARSER) $(GRAMMAR)

test-nvim: build-parser
	mkdir -p $(TEST_RUNTIME)/xdg/config $(TEST_RUNTIME)/xdg/data $(TEST_RUNTIME)/xdg/state $(TEST_RUNTIME)/xdg/cache
	INK_NVIM_ROOT=$(ROOT) \
	XDG_CONFIG_HOME=$(TEST_RUNTIME)/xdg/config \
	XDG_DATA_HOME=$(TEST_RUNTIME)/xdg/data \
	XDG_STATE_HOME=$(TEST_RUNTIME)/xdg/state \
	XDG_CACHE_HOME=$(TEST_RUNTIME)/xdg/cache \
	$(NVIM) --headless -u $(ROOT)/tests/minimal_init.lua -l $(ROOT)/tests/run.lua

clean:
	rm -rf $(TEST_RUNTIME)
