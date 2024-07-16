PLENARY_VER = v0.1.4
PLENARY_DIR = .build_tools/plenary
PLENARY_URL = https://github.com/nvim-lua/plenary.nvim

FILES := $(wildcard tests/*_spec.lua)

.PHONY: test $(FILES) args-tests
test: $(PLENARY_DIR) $(FILES) args-tests

$(FILES):
	nvim --clean --headless --embed -u tests/minimal.vim +"PlenaryBustedFile $@"

args-tests:
	nvim --clean --headless --embed -u tests/minimal.vim +"PlenaryBustedFile tests/args/args_setup_spec.lua"
	nvim --clean --headless --embed -u tests/minimal.vim +"PlenaryBustedFile tests/args/args_not_enabled_spec.lua"
	nvim --clean --headless --embed -u tests/minimal.vim +"PlenaryBustedFile tests/args/args_single_dir_enabled_spec.lua"
	nvim --clean --headless --embed -u tests/minimal.vim +"PlenaryBustedFile tests/args/args_files_enabled_spec.lua"


$(PLENARY_DIR):
	git clone --depth=1 --branch $(PLENARY_VER) $(PLENARY_URL) $(PLENARY_DIR)
