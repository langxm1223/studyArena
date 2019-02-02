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

include(base)

#=============================================================================
#
#	add_project
#
#	This function builds a static library from a project description.
#
#	Usage:
#		add_project(PROJECT <string>
#			MAIN <string>
#			[ STACK_MAIN <string> ]
#			[ STACK_MAX <string> ]
#			[ COMPILE_FLAGS <list> ]
#			[ INCLUDES <list> ]
#			[ DEPENDS <string> ]
#			[ SRCS <list> ]
#			[ PROJECT_CONFIG <list> ]
#			[ EXTERNAL ]
#			)
#
#	Input:
#		PROJECT			: unique name of project
#		MAIN				: entry point
#		STACK_MAIN	: size of stack for main function
#		STACK_MAX		: maximum stack size of any frame
#		COMPILE_FLAGS		: compile flags
#		LINK_FLAGS		: link flags
#		SRCS			: source files
#		PROJECT_CONFIG		: yaml config file(s)
#		INCLUDES		: include directories
#		DEPENDS			: targets which this project depends on
#		EXTERNAL		: flag to indicate that this project is out-of-tree
#		UNITY_BUILD		: merge all source files and build this project as a single compilation unit
#
#	Output:
#		Static library with name matching PROJECT.
#
#	Example:
#		add_project(PROJECT test
#			SRCS
#				file.cpp
#			STACK_MAIN 1024
#			DEPENDS
#				git_nuttx
#			)
#
function(add_project)

	px4_parse_function_args(
		NAME add_project
		ONE_VALUE PROJECT MAIN STACK STACK_MAIN STACK_MAX PRIORITY
		MULTI_VALUE COMPILE_FLAGS LINK_FLAGS SRCS INCLUDES DEPENDS MODULE_CONFIG
		OPTIONS EXTERNAL DYNAMIC UNITY_BUILD
		REQUIRED PROJECT MAIN
		ARGN ${ARGN})

	if(UNITY_BUILD AND (${PX4_PLATFORM} STREQUAL "nuttx"))
		# build standalone test library to catch compilation errors and provide sane output
		add_library(${PROJECT}_original STATIC EXCLUDE_FROM_ALL ${SRCS})
		if(DEPENDS)
			add_dependencies(${PROJECT}_original ${DEPENDS})
		endif()

		if(INCLUDES)
			target_include_directories(${PROJECT}_original PRIVATE ${INCLUDES})
		endif()
		target_compile_definitions(${PROJECT}_original PRIVATE PX4_MAIN=${MAIN}_app_main)
		target_compile_definitions(${PROJECT}_original PRIVATE MODULE_NAME="${MAIN}_original")

		# unity build
		add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT}_unity.cpp
			COMMAND cat ${SRCS} > ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT}_unity.cpp
			DEPENDS ${PROJECT}_original ${DEPENDS} ${SRCS}
			COMMENT "${PROJECT} merging source"
			WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
			)
		set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/${PROJECT}_unity.cpp PROPERTIES GENERATED true)

		add_library(${PROJECT} STATIC EXCLUDE_FROM_ALL ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT}_unity.cpp)
		target_include_directories(${PROJECT} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

		if(DEPENDS)
			# using target_link_libraries for dependencies provides linking
			#  as well as interface include and libraries
			foreach(dep ${DEPENDS})
				get_target_property(dep_type ${dep} TYPE)
				if (${dep_type} STREQUAL "STATIC_LIBRARY")
					target_link_libraries(${PROJECT}_original PRIVATE ${dep})
				else()
					add_dependencies(${PROJECT}_original ${dep})
				endif()
			endforeach()
		endif()

	elseif(DYNAMIC AND MAIN AND (${OS} STREQUAL "posix"))
		add_library(${PROJECT} SHARED ${SRCS})
		target_compile_definitions(${PROJECT} PRIVATE ${MAIN}_main=px4_project_main)
		set_target_properties(${PROJECT} PROPERTIES
			PREFIX ""
			SUFFIX ".px4mod"
			)
		target_link_libraries(${PROJECT} PRIVATE px4)
		if(APPLE)
			# Postpone resolving symbols until loading time, which is the default on most systems, but not Mac.
			set_target_properties(${PROJECT} PROPERTIES LINK_FLAGS "-undefined dynamic_lookup")
		endif()

	else()
		add_library(${PROJECT} STATIC EXCLUDE_FROM_ALL ${SRCS})
	endif()

	# all projects can potentially use parameters and uORB
	add_dependencies(${PROJECT} uorb_headers)

	if(NOT DYNAMIC)
		target_link_libraries(${PROJECT} PRIVATE prebuild_targets parameters_interface platforms__common px4_layer systemlib)
		set_property(GLOBAL APPEND PROPERTY PX4_MODULE_LIBRARIES ${PROJECT})
		set_property(GLOBAL APPEND PROPERTY PX4_MODULE_PATHS ${CMAKE_CURRENT_SOURCE_DIR})
	endif()

	# Pass variable to the parent add_project.
	set(_no_optimization_for_target ${_no_optimization_for_target} PARENT_SCOPE)

	# set defaults if not set
	set(MAIN_DEFAULT MAIN-NOTFOUND)
	set(STACK_MAIN_DEFAULT 1024)
	set(PRIORITY_DEFAULT SCHED_PRIORITY_DEFAULT)

	foreach(property MAIN STACK_MAIN PRIORITY)
		if(NOT ${property})
			set(${property} ${${property}_DEFAULT})
		endif()
		set_target_properties(${PROJECT} PROPERTIES ${property} ${${property}})
	endforeach()

	# default stack max to stack main
	if(NOT STACK_MAX)
		set(STACK_MAX ${STACK_MAIN})
	endif()
	set_target_properties(${PROJECT} PROPERTIES STACK_MAX ${STACK_MAX})

	if(${PX4_PLATFORM} STREQUAL "qurt")
		set_property(TARGET ${PROJECT} PROPERTY POSITION_INDEPENDENT_CODE TRUE)
	elseif(${PX4_PLATFORM} STREQUAL "nuttx")
		target_compile_options(${PROJECT} PRIVATE -Wframe-larger-than=${STACK_MAX})
	endif()

	if(MAIN)
		target_compile_definitions(${PROJECT} PRIVATE PX4_MAIN=${MAIN}_app_main)
		target_compile_definitions(${PROJECT} PRIVATE MODULE_NAME="${MAIN}")
	else()
		target_compile_definitions(${PROJECT} PRIVATE MODULE_NAME="${PROJECT}")
	endif()

	if(COMPILE_FLAGS)
		target_compile_options(${PROJECT} PRIVATE ${COMPILE_FLAGS})
	endif()

	if(INCLUDES)
		target_include_directories(${PROJECT} PRIVATE ${INCLUDES})
	endif()

	if(DEPENDS)
		# using target_link_libraries for dependencies provides linking
		#  as well as interface include and libraries
		foreach(dep ${DEPENDS})
			get_target_property(dep_type ${dep} TYPE)
			if (${dep_type} STREQUAL "STATIC_LIBRARY")
				target_link_libraries(${PROJECT} PRIVATE ${dep})
			else()
				add_dependencies(${PROJECT} ${dep})
			endif()
		endforeach()
	endif()

	foreach (prop LINK_FLAGS STACK_MAIN MAIN PRIORITY)
		if (${prop})
			set_target_properties(${PROJECT} PROPERTIES ${prop} ${${prop}})
		endif()
	endforeach()

	if(MODULE_CONFIG)
		foreach(project_config ${MODULE_CONFIG})
			set_property(GLOBAL APPEND PROPERTY PX4_MODULE_CONFIG_FILES ${CMAKE_CURRENT_SOURCE_DIR}/${project_config})
		endforeach()
	endif()
endfunction()
