NVIM = nvim

FILES := $(wildcard tests/*_spec.lua)

.PHONY: test ${FILES} plenary-tests mini-tests lazy

# test: plenary-tests mini-tests
test tests: plenary-tests mini-tests

# Plugin dependencies are in scripts/lazy_init.lua
PLUGINS := .test/plugins

# It's faster to run the tests via PlenaryBustedDirectory because it only needs one overall, managing nvim process and then one per spec.
# PlenaryBustedFile, on the other hand, starts two processes per spec (one to manage running the spec and then one to actually run the spec)
# But it's very convenient to be able to run a single spec when test/developing
plenary-tests: $(PLUGINS)
	# DEBUG_PLENARY=1 $(NVIM) --clean --headless -u scripts/minimal_init.lua +"PlenaryBustedDirectory tests {minimal_init = 'scripts/minimal_init.lua', sequential=true}"
	$(NVIM) --clean --headless -u scripts/minimal_init.lua +"PlenaryBustedDirectory tests {minimal_init = 'scripts/minimal_init.lua', sequential=true}"

# Rule that lets you run an individual spec. Currently requires my Plenary fork above
$(FILES): $(PLUGINS)
	# $(NVIM) --clean --headless -u scripts/minimal_init.lua +"PlenaryBustedFile $@ {minimal_init = 'scripts/minimal_init.lua'}"
	$(NVIM) --clean --headless -u scripts/minimal_init.lua +"PlenaryBustedFile $@ {minimal_init = 'scripts/minimal_init.lua'}"

# We use mini.test for some end to end UI testing of session lens
mini-tests:
	$(NVIM) --headless --noplugin -u scripts/minimal_init_mini.lua -c "lua MiniTest.run()"

# Use lazy.nvim to download the plugins. The actual tests don't use lazy.nvim
lazy $(PLUGINS):
	$(NVIM) --headless -u scripts/lazy_init.lua +"qa!"

clean:
	rm -rf .test
