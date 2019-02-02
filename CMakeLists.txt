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

#=============================================================================
# CMAKE CODING STANDARD
#
# Structure
# ---------------------------------------------------------------------------
#
# * Common functions are included in base.cmake.
#
# * All C++ projects are run in ubuntu system.
#
# Formatting
# ---------------------------------------------------------------------------
#
# * Use hard indents.
#
# * All function and script arguments are upper case.
#
# * All local variables are lower case.
#
# * All cmake functions are lower case.
#
# * For else, endif, endfunction, etc, never put the name of the statement
#
# Functions/Macros
# ---------------------------------------------------------------------------
#
# * Use parse_function_args to parse functions and check for required
#   arguments. Unless there is only one argument in the function and it is clear.
#
# * Never use macros. They allow overwriting global variables and this
#	makes variable declarations hard to locate.
#
# * Avoid use of global variables in functions. Functions in a nested
#	scope may use global variables, but this makes it difficult to
#	reuse functions.
#
# Included CMake Files
# ---------------------------------------------------------------------------
#
# * All variables in config files must have the prefix "config_".
#
# * Never set global variables in an included .cmake file,
#	you may only define functions. This excludes config and Toolchain files.
#	This makes it clear to the user when variables are being set or targets
#	are being created.
#
# * Setting a global variable in a CMakeLists.txt file is ok, because
#	each CMakeLists.txt file has scope in the current directory and all
#	subdirectories, so it is not truly global.
#
# * All toolchain files should be included in the cmake
#	directory and named Toolchain-"name".cmake.
#
# Misc
# ---------------------------------------------------------------------------
#
# * If referencing a string variable, don't put it in quotes.
#	Don't do "${PX4_PLATFORM}" STREQUAL "posix",
#	instead type ${PX4_PLATFORM} STREQUAL "posix". This will throw an
#	error when ${PX4_PLATFORM} is not defined instead of silently
#	evaluating to false.
#
#=============================================================================

cmake_minimum_required(VERSION 3.2)

set(MY_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
set(MY_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}")

list(APPEND CMAKE_MODULE_PATH ${MY_SOURCE_DIR}/cmake)

#=============================================================================
# git
#


#=============================================================================
# configuration
#

set(CONFIG "simple" CACHE STRING "desired configuration")

include(add_project)
set(config_project_list)

# find cmake config
#  look for in tree board config that matches CONFIG input
if(NOT PX4_CONFIG_FILE)

	file(GLOB_RECURSE board_configs
		RELATIVE "${PX4_SOURCE_DIR}/boards"
		"boards/*.cmake"
		)

	set(PX4_CONFIGS ${board_configs} CACHE STRINGS "PX4 board configs" FORCE)

	foreach(filename ${board_configs})
		# parse input CONFIG into components to match with existing in tree configs
		#  the platform prefix (eg nuttx_) is historical, and removed if present
		string(REPLACE ".cmake" "" filename_stripped ${filename})
		string(REPLACE "/" ";" config ${filename_stripped})
		list(LENGTH config config_len)

		if(${config_len} EQUAL 3)


			list(GET config 0 vendor)
			list(GET config 1 model)
			list(GET config 2 label)

			set(board "${vendor}${model}")

			# <VENDOR>_<MODEL>_<LABEL> (eg px4_fmu-v2_default)
			# <VENDOR>_<MODEL>_default (eg px4_fmu-v2) # allow skipping label if "default"
			if ((${CONFIG} MATCHES "${vendor}_${model}_${label}") OR # match full vendor, model, label
			    ((${label} STREQUAL "default") AND (${CONFIG} STREQUAL "${vendor}_${model}")) # default label can be omitted
			)
				set(PX4_CONFIG_FILE "${PX4_SOURCE_DIR}/boards/${filename}" CACHE FILEPATH "path to PX4 CONFIG file" FORCE)
				break()
			endif()

			# <BOARD>_<LABEL> (eg px4_fmu-v2_default)
			# <BOARD>_default (eg px4_fmu-v2) # allow skipping label if "default"
			if ((${CONFIG} MATCHES "${board}_${label}") OR # match full board, label
			    ((${label} STREQUAL "default") AND (${CONFIG} STREQUAL "${board}")) # default label can be omitted
			)
				set(PX4_CONFIG_FILE "${PX4_SOURCE_DIR}/boards/${filename}" CACHE FILEPATH "path to PX4 CONFIG file" FORCE)
				break()
			endif()


			# LEGACY form
			# <OS>_<BOARD>_<LABEL> (eg nuttx_px4_fmu-v2_default)
			string(REGEX REPLACE "^nuttx_|^posix_|^qurt_" "" config_no_os ${CONFIG}) # ignore OS prefix

			if ((${config_no_os} MATCHES "${board}_${label}"))
				set(PX4_CONFIG_FILE "${PX4_SOURCE_DIR}/boards/${filename}" CACHE FILEPATH "path to PX4 CONFIG file" FORCE)
				break()
			endif()


			# LEGACY form special case to ease board layout transition (2018-11-18)
			#  match board with model and label only: eg sitl_default -> px4_sitl_default
			if ((${config_no_os} MATCHES "${model}_${label}"))
				set(PX4_CONFIG_FILE "${PX4_SOURCE_DIR}/boards/${filename}" CACHE FILEPATH "path to PX4 CONFIG file" FORCE)
				break()
			endif()

		endif()

	endforeach()
endif()

if(NOT PX4_CONFIG_FILE)
	message(FATAL_ERROR "PX4 config file not set, try one of ${PX4_CONFIGS}")
endif()

message(STATUS "PX4 config file: ${PX4_CONFIG_FILE}")
include(px4_add_board)
include(${PX4_CONFIG_FILE})
message(STATUS "PX4 config: ${PX4_CONFIG}")
message(STATUS "PX4 platform: ${PX4_PLATFORM}")

# external modules
set(EXTERNAL_MODULES_LOCATION "" CACHE STRING "External modules source location")

if (NOT EXTERNAL_MODULES_LOCATION STREQUAL "")
	get_filename_component(EXTERNAL_MODULES_LOCATION "${EXTERNAL_MODULES_LOCATION}" ABSOLUTE)
endif()

set_property(GLOBAL PROPERTY PX4_MODULE_CONFIG_FILES)

include(platforms/${PX4_PLATFORM}/cmake/px4_impl_os.cmake)
list(APPEND CMAKE_MODULE_PATH ${PX4_SOURCE_DIR}/platforms/${PX4_PLATFORM}/cmake)

# CMake build type (Debug Release RelWithDebInfo MinSizeRel Coverage)
if (NOT CMAKE_BUILD_TYPE)
	if (${PX4_PLATFORM} STREQUAL "nuttx")
		set(PX4_BUILD_TYPE "MinSizeRel")
	else()
		set(PX4_BUILD_TYPE "RelWithDebInfo")
	endif()

	set(CMAKE_BUILD_TYPE ${PX4_BUILD_TYPE} CACHE STRING "Build type" FORCE)
endif()

set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug;Release;RelWithDebInfo;MinSizeRel;Coverage;AddressSanitizer;UndefinedBehaviorSanitizer")

#=============================================================================

message(STATUS "PX4 version: ${PX4_GIT_TAG}")
message(STATUS "cmake build type: ${CMAKE_BUILD_TYPE}")



project(StudyArena)
add_executable(hello src/main.cpp)

# Version
set(StudyArena_VERSION_MAJOR 0)
set(StudyArena_VERSION_MINOR 1)

# configure a header file to pass some of the CMake settings
# to the source code
configure_file (
  "${PROJECT_SOURCE_DIR}/CmakeConfig.h.in"
  "${PROJECT_BINARY_DIR}/CmakeConfig.h"
  )
 
# add the binary tree to the search path for include files
# so that we will find TutorialConfig.h
include_directories("${PROJECT_BINARY_DIR}")

# glog
#find_package(glog REQUIRED)
#include_directories(BEFORE ${GLOG_INCLUDE_DIRS})

# test
include(CTest)
# does the application run
add_test(StudyArenaRuns hello 25)
