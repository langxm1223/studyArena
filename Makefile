############################################################################
#
# Copyright (c) 2019 Xiaoming Lang. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
# 3. Neither the name Xiaoming Lang nor the names of its contributors may be
#    used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
############################################################################

# This Makefile is an imitative file from PX4.
# At the mean time, it is an experimental place to learn makefile rules.
# All the make rules can be found in the official manual below:
# https://www.gnu.org/software/make/manual/html_node/index.html

# Another way to execute them in one shell is
# .ONESHELL:

# Enforce the presence of the GIT repository
ifeq ($(wildcard .git),)
    $(error YOU HAVE TO USE GIT TO DOWNLOAD THIS REPOSITORY. ABORTING.)
endif

# Help
# --------------------------------------------------------------------
# Don't be afraid of this makefile, it is just passing
# arguments to cmake to allow us to keep the organization clean.
#
# Example usage:
#
# make msckf_vio 					(builds)
# make msckf_vio upload 	(builds and uploads)
# make msckf_vio test 		(builds and tests)
#
# This tells cmake to build msckf_vio project in the
# directory build/msckf_vio and then call make
# in that directory with the target upload.

# explicity set default build target
all: simple

# Parsing
# --------------------------------------------------------------------
# assume 1st argument passed is the main target, the
# rest are arguments to pass to the makefile generated
# by cmake in the subdirectory
FIRST_ARG := $(firstword $(MAKECMDGOALS))
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
j ?= 4

NINJA_BIN := ninja
ifndef NO_NINJA_BUILD
	NINJA_BUILD := $(shell $(NINJA_BIN) --version 2>/dev/null)

	ifndef NINJA_BUILD
		NINJA_BIN := ninja-build
		NINJA_BUILD := $(shell $(NINJA_BIN) --version 2>/dev/null)
	endif
endif

ifdef NINJA_BUILD
	CUSTOM_CMAKE_GENERATOR := Ninja
	CUSTOM_MAKE := $(NINJA_BIN)

	ifdef VERBOSE
		CUSTOM_MAKE_ARGS := -v
	else
		CUSTOM_MAKE_ARGS :=
	endif
else
	ifdef SYSTEMROOT
		# Windows
		CUSTOM_CMAKE_GENERATOR := "MSYS\ Makefiles"
	else
		CUSTOM_CMAKE_GENERATOR := "Unix\ Makefiles"
	endif
	CUSTOM_MAKE = $(MAKE)
	CUSTOM_MAKE_ARGS = -j$(j) --no-print-directory
endif

# Here SRC_DIR extracts the root folder absolute path where the makefile is
SRC_DIR := $(shell dirname "$(realpath $(lastword $(MAKEFILE_LIST)))")

ifdef CUSTOM_CMAKE_BUILD_TYPE
	CMAKE_ARGS += -DCMAKE_BUILD_TYPE=${CUSTOM_CMAKE_BUILD_TYPE}
else

	# Address Sanitizer
	ifdef CUSTOM_ASAN
		CMAKE_ARGS += -DCMAKE_BUILD_TYPE=AddressSanitizer
	endif

	# Memory Sanitizer
	ifdef CUSTOM_MSAN
		CMAKE_ARGS += -DCMAKE_BUILD_TYPE=MemorySanitizer
	endif

	# Thread Sanitizer
	ifdef CUSTOM_TSAN
		CMAKE_ARGS += -DCMAKE_BUILD_TYPE=ThreadSanitizer
	endif

	# Undefined Behavior Sanitizer
	ifdef CUSTOM_UBSAN
		CMAKE_ARGS += -DCMAKE_BUILD_TYPE=UndefinedBehaviorSanitizer
	endif

endif

# Functions
# --------------------------------------------------------------------
# Describe how to build a cmake config
# Assign the target project and build directory variables
# If CMakeCache does not exists in build folder, mkdir a build folder
# If use ninja later, $(MAKE) should be replaced by $(CUSTOM_MAKE)
define cmake-build
+@$(eval TARGET_PROJECT = $(1))
+@$(eval BUILD_DIR = "$(SRC_DIR)"/build/$(TARGET_PROJECT))
+@if [ ! -e $(BUILD_DIR)/CMakeCache.txt ]; then mkdir -p $(BUILD_DIR) && cd $(BUILD_DIR) && cmake "$(SRC_DIR)" -G"$(CUSTOM_CMAKE_GENERATOR)" -DCONFIG=$(TARGET_PROJECT) || (rm -rf $(BUILD_DIR)); fi
+@$(MAKE) -C $(BUILD_DIR) $(CUSTOM_MAKE_ARGS) $(ARGS)
endef

COLOR_BLUE = \033[0;34m
COLOR_GREEN = \033[0;32m
COLOR_CYAN = \033[0;36m
COLOR_PURPLE = \033[0;35m
COLOR_YELLOW = \033[1;33m
NO_COLOR   = \033[m

define colorecho
+@echo -e '${COLOR_BLUE}${1} ${NO_COLOR}'
endef

# Get a list of all config targets cmake/*.cmake
ALL_CONFIG_TARGETS := $(shell find cmake/ -maxdepth 2 -mindepth 1 ! -name '*base*' ! -name '*Find*' -name '*.cmake' -print | sed -e 's/cmake\///' | sed -e 's/\.cmake//' | sort)

# ADD CONFIGS HERE
# --------------------------------------------------------------------
#  Do not put any spaces between function arguments.

# All targets.
$(ALL_CONFIG_TARGETS):
	$(call cmake-build,$@)

# Abbreviated config targets.
simple: simple

# All targets with just dependencies but no recipe must either be marked as phony (or have the special @: as recipe).
.PHONY: all simple

.PHONY: check_format

check_%:
	@echo
	$(call colorecho,'Building' $(subst check_,,$@))
	@$(MAKE) --no-print-directory $(subst check_,,$@)
	@echo

# Documentation
# --------------------------------------------------------------------
.PHONY: project_documentation doxygen

project_documentation:
	:

doxygen:
	@mkdir -p "$(SRC_DIR)"/build/doxygen
	@cd "$(SRC_DIR)"/build/doxygen && cmake "$(SRC_DIR)" $(CMAKE_ARGS) -G"$(CUSTOM_CMAKE_GENERATOR)" -DCONFIG=simple -DBUILD_DOXYGEN=ON
	@$(MAKE) -C "$(SRC_DIR)"/build/doxygen
	@touch "$(SRC_DIR)"/build/doxygen/Documentation/.nojekyll

# Astyle
# --------------------------------------------------------------------
.PHONY: check_format format

check_format:
	$(call colorecho,'Checking formatting with astyle')
	@"$(SRC_DIR)"/tools/astyle/check_code_style_all.sh
	@cd "$(SRC_DIR)" && git diff --check

format:
	$(call colorecho,'Formatting with astyle')
	@"$(SRC_DIR)"/tools/astyle/check_code_style_all.sh --fix

# Testing
# --------------------------------------------------------------------
# .PHONY: tests tests_coverage tests_mission tests_mission_coverage tests_offboard rostest python_coverage

# Cleanup
# --------------------------------------------------------------------
.PHONY: clean submodulesclean submodulesupdate distclean

clean:
	@rm -rf "$(SRC_DIR)"/build

submodulesclean:
	@git submodule foreach --quiet --recursive git clean -ff -x -d
	@git submodule update --quiet --init --recursive --force || true
	@git submodule sync --recursive
	@git submodule update --init --recursive --force

submodulesupdate:
	@git submodule update --quiet --init --recursive || true
	@git submodule sync --recursive
	@git submodule update --init --recursive

distclean:
	@git submodule deinit -f .
	@git clean -ff -x -d -e ".project" -e ".cproject" -e ".idea" -e ".settings" -e ".vscode"

# --------------------------------------------------------------------
# All other targets are handled. Add a rule here to avoid printing an error.
%:
	$(if $(filter $(FIRST_ARG),$@), \
		$(error "$@ cannot be the first argument. Use '$(MAKE) help|list_config_targets' to get a list of all possible [configuration] targets.")\
		$(error "unrecognized target, please try again!"))

empty :=
space := $(empty) $(empty)

# Print a list of non-config targets (based on http://stackoverflow.com/a/26339924/1487069)
help:
	@echo "Usage: $(MAKE) <target>"
	@echo "Where <target> is one of:"
	@echo
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | \
		awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | \
		egrep -v -e '^[^[:alnum:]]'
	@echo
	@echo "Or, $(MAKE) <config_target> [<make_target(s)>]"
	@echo "Use '$(MAKE) list_config_targets' for a list of configuration targets."

# Print a list of all config targets.
list_config_targets:
	@for targ in $(ALL_CONFIG_TARGETS); do echo $$targ; done