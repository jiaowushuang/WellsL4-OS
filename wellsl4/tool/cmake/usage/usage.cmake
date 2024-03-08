# SPDX-License-Identifier: Apache-2.0
if(NOT DEFINED ENV{WELLSL4_BASE})
  message(FATAL_ERROR "WELLSL4_BASE not set")
endif()

include ($ENV{WELLSL4_BASE}/tool/cmake/boards.cmake)

# TODO: Set to make when make is used as a generator
set(CMAKE_MAKE_PROGRAM ninja)
get_filename_component(generator ${CMAKE_MAKE_PROGRAM} NAME)

string(REPLACE " " ";" BOARD_ROOT "${BOARD_ROOT_SPACE_SEPARATED}")
#string(REPLACE " " ";" SHIELD_LIST "${SHIELD_LIST_SPACE_SEPARATED}")

message("Cleaning targets:")
message("  clean     - Remove most generated files but keep configuration and backup files")
message("  pristine  - Remove all files in the build directory")
message("")
message("Configuration targets:")
message("")
message("  menuconfig - Update configuration using an interactive configuration interface")
message("")
message("Other generic targets:")
message("  all          - Build a wellsl4 application")
message("  run          - Build a wellsl4 application and run it if the board supports emulation")
message("  flash        - Build and flash an application")
message("  debug        - Build and debug an application using GDB")
message("  debugserver  - Build and start a GDB server (port 1234 for Qemu targets)")
message("  ram_report   - Build and create RAM usage report")
message("  rom_report   - Build and create ROM usage report")
message("  usage        - Display this text")
message("")
message("Supported Boards:")
message("")
message("  To generate project files for one of the supported boards below, run:")
message("")
#message("  $ cmake -DBOARD=<BOARD NAME> [-DSHIELD=<SHIELD NAME>] -Bpath/to/build_dir -Hpath/to/source_dir")
message("")
message("  or")
message("")
message("  $ export BOARD=<BOARD NAME>")
#message("  $ export SHIELD=<SHIELD NAME> #optional")
message("  $ cmake -Bpath/to/build_dir -Hpath/to/source_dir")
message("")
dump_all_boards("" "  ")
message("")
#message("Supported Shields:")
message("")
#foreach(shield ${SHIELD_LIST})
#  message(" ${shield}")
#endforeach()
message("")
message("Build flags:")
message("")
message("  ${generator} VERBOSE=1 [targets] verbose build")
message("  cmake -DW=n   Enable extra gcc checks, n=1,2,3 where")
message("   1: warnings which may be relevant and do not occur too often")
message("   2: warnings which occur quite often but may still be relevant")
message("   3: more obscure warnings, can most likely be ignored")
message("   Multiple levels can be combined with W=12 or W=123")
