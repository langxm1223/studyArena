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

# insert here

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

#####################################################################
# test CMake area
set(EXTRA_LIBTEST ${EXTRA_LIBTEST} MathFunctions)
set(EXTRA_LIBTEST ${EXTRA_LIBTEST} LogFunctions)
# Here double quotes are necessary to output EXTRA_LIBTEST as separate variables
message(STATUS "${EXTRA_LIBTEST}")
message(${PROJECT_BINARY_DIR})
message(${MAKE})