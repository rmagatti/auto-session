PLENARY_VER = v0.1.4
PLENARY_DIR = .build_tools/plenary
PLENARY_URL = https://github.com/nvim-lua/plenary.nvim

FILES := $(wildcard tests/*_spec.lua)

.PHONY: test $(FILES)
test: $(PLENARY_DIR) $(FILES)

$(FILES):
	nvim --clean --headless --embed -u tests/minimal.vim +"PlenaryBustedFile $@"

$(PLENARY_DIR):
	git clone --depth=1 --branch $(PLENARY_VER) $(PLENARY_URL) $(PLENARY_DIR)
