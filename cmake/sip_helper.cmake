if(__PYTHON_QT_BINDING_SIP_HELPER_INCLUDED)
  return()
endif()
set(__PYTHON_QT_BINDING_SIP_HELPER_INCLUDED TRUE)

set(__PYTHON_QT_BINDING_SIP_HELPER_DIR ${CMAKE_CURRENT_LIST_DIR})

find_package(Python3 ${Python3_VERSION} REQUIRED COMPONENTS Interpreter Development)

execute_process(
  COMMAND ${Python3_EXECUTABLE} -c "import sipconfig; print(sipconfig.Configuration().sip_bin)"
  OUTPUT_VARIABLE PYTHON_SIP_EXECUTABLE
  ERROR_QUIET)

if(PYTHON_SIP_EXECUTABLE)
  string(STRIP ${PYTHON_SIP_EXECUTABLE} SIP_EXECUTABLE)
else()
  find_program(SIP_EXECUTABLE NAMES sip sip-build)
endif()

if(SIP_EXECUTABLE)
  message(STATUS "SIP binding generator available at: ${SIP_EXECUTABLE}")
  set(sip_helper_FOUND TRUE)
else()
  message(WARNING "SIP binding generator NOT available.")
  set(sip_helper_NOTFOUND TRUE)
endif()

if(sip_helper_FOUND)
  execute_process(
    COMMAND ${SIP_EXECUTABLE} -V
    OUTPUT_VARIABLE SIP_VERSION
    ERROR_QUIET)
  # string(STRIP ${SIP_VERSION} SIP_VERSION)
  # message(STATUS "SIP binding generator version: ${SIP_VERSION}")
endif()

#
# Run the SIP generator and compile the generated code into a library.
#
# .. note:: The target lib${PROJECT_NAME} is created.
#
# :param PROJECT_NAME: The name of the sip project
# :type PROJECT_NAME: string
# :param SIP_FILE: the SIP file to be processed
# :type SIP_FILE: string
#
# The following options can be used to override the default behavior:
#   SIP_CONFIGURE: the used configure script for SIP
#     (default: sip_configure.py in the same folder as this file)
#   SOURCE_DIR: the source dir (default: ${PROJECT_SOURCE_DIR}/src)
#   LIBRARY_DIR: the library dir (default: ${PROJECT_SOURCE_DIR}/src)
#   BINARY_DIR: the binary dir (default: ${PROJECT_BINARY_DIR})
#
# The following keywords arguments can be used to specify:
#   DEPENDS: depends for the custom command
#     (should list all sip and header files)
#   DEPENDENCIES: target dependencies
#     (should list the library for which SIP generates the bindings)
#
function(build_sip_binding PROJECT_NAME SIP_FILE)
    cmake_parse_arguments(sip "" "SIP_CONFIGURE;SOURCE_DIR;LIBRARY_DIR;BINARY_DIR" "DEPENDS;DEPENDENCIES" ${ARGN})
    if(sip_UNPARSED_ARGUMENTS)
        message(WARNING "build_sip_binding(${PROJECT_NAME}) called with unused arguments: ${sip_UNPARSED_ARGUMENTS}")
    endif()

    # set default values for optional arguments
    if(NOT sip_SIP_CONFIGURE)
        # default to sip_configure.py in this directory
        set(sip_SIP_CONFIGURE ${__PYTHON_QT_BINDING_SIP_HELPER_DIR}/sip_configure.py)
    endif()
    if(NOT sip_SOURCE_DIR)
        set(sip_SOURCE_DIR ${PROJECT_SOURCE_DIR}/src)
    endif()
    if(NOT sip_LIBRARY_DIR)
        set(sip_LIBRARY_DIR ${PROJECT_SOURCE_DIR}/lib)
    endif()
    if(NOT sip_BINARY_DIR)
        set(sip_BINARY_DIR ${PROJECT_BINARY_DIR})
    endif()

    set(SIP_BUILD_DIR ${sip_BINARY_DIR}/sip/${PROJECT_NAME})

    set(INCLUDE_DIRS ${${PROJECT_NAME}_INCLUDE_DIRS} ${Python3_INCLUDE_DIRS})
    set(LIBRARIES ${${PROJECT_NAME}_LIBRARIES})
    set(LIBRARY_DIRS ${${PROJECT_NAME}_LIBRARY_DIRS})
    set(LDFLAGS_OTHER ${${PROJECT_NAME}_LDFLAGS_OTHER})

    if(${SIP_VERSION} VERSION_GREATER_EQUAL "5.0.0")
      find_program(QMAKE_EXECUTABLE NAMES qmake REQUIRED)
      file(REMOVE_RECURSE ${SIP_BUILD_DIR})
      file(MAKE_DIRECTORY ${sip_LIBRARY_DIR})
      set(SIP_FILES_DIR ${sip_SOURCE_DIR})

        set(SIP_INCLUDE_DIRS "")
        foreach(_x ${INCLUDE_DIRS})
          set(SIP_INCLUDE_DIRS "${SIP_INCLUDE_DIRS},\"${_x}\"")
        endforeach()
        #TODO : add the Qt include dirs here (currently hardcoded in pyproject.toml.in)
        string(REGEX REPLACE "^," "" SIP_INCLUDE_DIRS ${SIP_INCLUDE_DIRS})

        # SIP expects the libraries WITHOUT the file extension.
        set(SIP_LIBARIES "")
        set(SIP_LIBRARY_DIRS "")

        if(APPLE)
          set(LIBRARIES_TO_LOOP ${LIBRARIES})
        else()
          set(LIBRARIES_TO_LOOP ${LIBRARIES} ${PYTHON_LIBRARIES})
        endif()

        foreach(_x ${LIBRARIES_TO_LOOP})
          get_filename_component(_x_NAME "${_x}" NAME_WLE)
          get_filename_component(_x_DIR "${_x}" DIRECTORY)
          get_filename_component(_x "${_x_DIR}/${_x_NAME}" ABSOLUTE)
          STRING(REGEX REPLACE "^lib" "" _x_NAME_NOPREFIX ${_x_NAME})

          string(FIND "${_x_NAME_NOPREFIX}" "$<TARGET_FILE" out)
          string(FIND "${_x_NAME_NOPREFIX}" "::" out2)
          if("${out}" EQUAL 0)
            STRING(REGEX REPLACE "\\$<TARGET_FILE:" "" _x_NAME_NOPREFIX ${_x_NAME_NOPREFIX})
            STRING(REGEX REPLACE ">" "" _x_NAME_NOPREFIX ${_x_NAME_NOPREFIX})
            if(NOT "${out2}" EQUAL -1)
              message(STATUS "IGNORE: ${_x_NAME_NOPREFIX}")
            else()
              STRING(FIND "${_x_NAME_NOPREFIX}" ".so" p1)
              if(NOT "${p1}" EQUAL -1)
               message(WARNING "found bad lib: ${_x_NAME_NOPREFIX}")
               STRING(SUBSTRING "${_x_NAME_NOPREFIX}" 0 ${p1} _x_NAME_NOPREFIX)
              endif()
              set(SIP_LIBARIES "${SIP_LIBARIES},\"${_x_NAME_NOPREFIX}\"")
            endif()
          else()
              STRING(FIND "${_x_NAME_NOPREFIX}" ".so" p1)
              if(NOT "${p1}" EQUAL -1)
               message(WARNING "found bad lib: ${_x_NAME_NOPREFIX}")
               STRING(SUBSTRING "${_x_NAME_NOPREFIX}" 0 ${p1} _x_NAME_NOPREFIX)
              endif()
            set(SIP_LIBARIES "${SIP_LIBARIES},\"${_x_NAME_NOPREFIX}\"")
            set(SIP_LIBRARY_DIRS "${SIP_LIBRARY_DIRS},\"${_x_DIR}\"")
          endif()
        endforeach()
        string(REGEX REPLACE "^," "" SIP_LIBARIES ${SIP_LIBARIES})

        foreach(_x ${LIBRARY_DIRS})
          set(SIP_LIBRARY_DIRS "${SIP_LIBRARY_DIRS},\"${_x}\"")
        endforeach()
        string(REGEX REPLACE "^," "" SIP_LIBRARY_DIRS ${SIP_LIBRARY_DIRS})
        message(WARNING "test lib dir: ${SIP_LIBRARY_DIRS}")
        message(WARNING "SIP FILE: ${SIP_FILE}")
        message(WARNING "sip library dir: ${sip_LIBRARY_DIR}")
        # TODO:
        #   I don't know what to do about LDFLAGS_OTHER: what's the equivalent construct in sip5?
        #      KLP: this may be extra-link-args in pyproject.toml.in
        #   location of Qt sip bindings are hardcoded in pyproject.toml.in: discover the paths here instead

        configure_file(
            ${__PYTHON_QT_BINDING_SIP_HELPER_DIR}/pyproject.toml.in
            ${sip_BINARY_DIR}/sip/pyproject.toml
        )
        add_custom_command(
            OUTPUT ${sip_LIBRARY_DIR}/lib${PROJECT_NAME}.cpython-311-x86_64-linux-gnu${CMAKE_SHARED_LIBRARY_SUFFIX}
            # we just made pyproject.toml, so 'pip install' will invoke sip-build/sip-install
            COMMAND ${Python3_EXECUTABLE} -m pip install . --target ${sip_LIBRARY_DIR} --no-deps --verbose --upgrade
            COMMAND cp -f ${sip_LIBRARY_DIR}/lib${PROJECT_NAME}.cpython-311-x86_64-linux-gnu${CMAKE_SHARED_LIBRARY_SUFFIX} ${sip_LIBRARY_DIR}/lib${PROJECT_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}
            DEPENDS ${sip_SIP_CONFIGURE} ${SIP_FILE} ${sip_DEPENDS}
            WORKING_DIRECTORY ${sip_BINARY_DIR}/sip
            COMMENT "Running SIP-build generator for ${PROJECT_NAME} Python bindings..."
        )
    else()
      add_custom_command(
          OUTPUT ${SIP_BUILD_DIR}/Makefile
          COMMAND ${Python3_EXECUTABLE} ${sip_SIP_CONFIGURE} ${SIP_BUILD_DIR} ${SIP_FILE} ${sip_LIBRARY_DIR}
            \"${INCLUDE_DIRS}\" \"${LIBRARIES}\" \"${LIBRARY_DIRS}\" \"${LDFLAGS_OTHER}\"
          DEPENDS ${sip_SIP_CONFIGURE} ${SIP_FILE} ${sip_DEPENDS}
          WORKING_DIRECTORY ${sip_SOURCE_DIR}
          COMMENT "Running SIP generator for ${PROJECT_NAME} Python bindings..."
      )
  
      if(NOT EXISTS "${sip_LIBRARY_DIR}")
          file(MAKE_DIRECTORY ${sip_LIBRARY_DIR})
      endif()
  
      if(WIN32)
        set(MAKE_EXECUTABLE NMake.exe)
      else()
        find_program(MAKE_PROGRAM NAMES make)
        message(STATUS "Found required make: ${MAKE_PROGRAM}")
        set(MAKE_EXECUTABLE ${MAKE_PROGRAM})
      endif()
  
      add_custom_command(
          OUTPUT ${sip_LIBRARY_DIR}/lib${PROJECT_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}
          COMMAND ${MAKE_EXECUTABLE}
          DEPENDS ${SIP_BUILD_DIR}/Makefile
          WORKING_DIRECTORY ${SIP_BUILD_DIR}
          COMMENT "Compiling generated code for ${PROJECT_NAME} Python bindings..."
      )
    endif()

    add_custom_target(lib${PROJECT_NAME} ALL
        DEPENDS ${sip_LIBRARY_DIR}/lib${PROJECT_NAME}.cpython-311-x86_64-linux-gnu${CMAKE_SHARED_LIBRARY_SUFFIX}
        COMMENT "Meta target for ${PROJECT_NAME} Python bindings..."
    )
    add_dependencies(lib${PROJECT_NAME} ${sip_DEPENDENCIES})
endfunction()
