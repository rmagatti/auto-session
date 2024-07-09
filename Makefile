PLENARY_VER = v0.1.4
PLENARY_DIR = .build_tools/plenary
PLENARY_URL = https://github.com/nvim-lua/plenary.nvim

test: $(PLENARY_DIR)
	nvim --clean --headless --embed -u tests/minimal.vim +"PlenaryBustedFile tests/setup_spec.lua"


$(PLENARY_DIR):
	git clone --depth=1 --branch $(PLENARY_VER) $(PLENARY_URL) $(PLENARY_DIR)
	@rm -rf $(PLENARY_DIR)/.git
