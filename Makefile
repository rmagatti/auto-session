PLENARY_VER = v0.1.4
PLENARY_DIR = .test/plenary
PLENARY_URL = https://github.com/nvim-lua/plenary.nvim

FILES := $(wildcard tests/*_spec.lua)

.PHONY: test $(FILES) args-tests
test: $(PLENARY_DIR) $(FILES) args-tests

$(FILES): $(PLENARY_DIR)
	nvim --clean --headless -u tests/minimal.lua +"PlenaryBustedFile $@"
	

args-tests: $(PLENARY_DIR)
	nvim --clean --headless -u tests/minimal.lua +"PlenaryBustedFile tests/args/args_setup_spec.lua"
	nvim --clean --headless -u tests/minimal.lua +"PlenaryBustedFile tests/args/args_not_enabled_spec.lua"
	nvim --clean --headless -u tests/minimal.lua +"PlenaryBustedFile tests/args/args_single_dir_enabled_spec.lua"
	nvim --clean --headless -u tests/minimal.lua +"PlenaryBustedFile tests/args/args_files_enabled_spec.lua"


$(PLENARY_DIR):
	git clone --depth=1 --branch $(PLENARY_VER) $(PLENARY_URL) $(PLENARY_DIR)
