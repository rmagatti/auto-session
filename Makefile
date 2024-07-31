# Using my fork of plenary just for https://github.com/nvim-lua/plenary.nvim/pull/611
PLENARY_VER = master
PLENARY_DIR = .test/plenary
PLENARY_URL = https://github.com/cameronr/plenary.nvim

# Telescope for session-lens test
TELESCOPE_VER = 0.1.8
TELESCOPE_DIR = .test/telescope
TELESCOPE_URL = https://github.com/nvim-telescope/telescope.nvim

PLUGINS := $(PLENARY_DIR) $(TELESCOPE_DIR)

FILES := $(wildcard tests/*_spec.lua)

.PHONY: test ${FILES} args-tests

# It's faster to run the tests via PlenaryBustedDirectory because it only needs one overall, managing nvim process and then one per spec.
# PlenaryBustedFile, on the other hand, starts two processes per spec (one to manage running the spec and then one to actually run the spec)
# But it's very convenient to be able to run a single spec when test/developing
test: $(PLUGINS)
	nvim --clean --headless -u tests/minimal.lua +"PlenaryBustedDirectory tests {minimal_init = 'tests/minimal.lua', sequential=true}"
	
# Rule that lets you run an individual spec. Currently requires my Plenary fork above
$(FILES): $(PLUGINS)
	nvim --clean --headless -u tests/minimal.lua +"PlenaryBustedFile $@ {minimal_init = 'tests/minimal.lua'}"

$(PLENARY_DIR):
	git clone --depth=1 --branch $(PLENARY_VER) $(PLENARY_URL) $(PLENARY_DIR)

$(TELESCOPE_DIR):
	git clone --depth=1 --branch $(TELESCOPE_VER) $(TELESCOPE_URL) $(TELESCOPE_DIR)
