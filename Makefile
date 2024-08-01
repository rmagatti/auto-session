# Using my fork of plenary just for https://github.com/nvim-lua/plenary.nvim/pull/611
PLENARY_VER = master
PLENARY_DIR = .test/plenary
PLENARY_URL = https://github.com/cameronr/plenary.nvim

# Telescope for session-lens test
TELESCOPE_VER = 0.1.8
TELESCOPE_DIR = .test/telescope
TELESCOPE_URL = https://github.com/nvim-telescope/telescope.nvim

MINI_DIR = .test/mini.nvim

PLUGINS := $(PLENARY_DIR) $(TELESCOPE_DIR) ${MINI_DIR}

FILES := $(wildcard tests/*_spec.lua)

.PHONY: test ${FILES} plenary-tests mini-tests

test: plenary-tests mini-tests

# It's faster to run the tests via PlenaryBustedDirectory because it only needs one overall, managing nvim process and then one per spec.
# PlenaryBustedFile, on the other hand, starts two processes per spec (one to manage running the spec and then one to actually run the spec)
# But it's very convenient to be able to run a single spec when test/developing
plenary-tests: $(PLUGINS)
	nvim --clean --headless -u scripts/minimal_init.lua +"PlenaryBustedDirectory tests {minimal_init = 'scripts/minimal_init.lua', sequential=true}"

# Rule that lets you run an individual spec. Currently requires my Plenary fork above
$(FILES): $(PLUGINS)
	nvim --clean --headless -u scripts/minimal_init.lua +"PlenaryBustedFile $@ {minimal_init = 'scripts/minimal_init.lua'}"
	
# We use mini.test for some end to end UI testing of session lens
mini-tests: $(PLUGINS)
	nvim --headless --noplugin -u scripts/minimal_init_mini.lua -c "lua MiniTest.run()"

$(PLENARY_DIR):
	git clone --depth=1 --branch $(PLENARY_VER) $(PLENARY_URL) $@

$(TELESCOPE_DIR):
	git clone --depth=1 --branch $(TELESCOPE_VER) $(TELESCOPE_URL) $@

$(MINI_DIR):
	git clone --depth=1 --filter=blob:none https://github.com/echasnovski/mini.nvim $@
