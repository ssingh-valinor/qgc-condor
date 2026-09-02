# ============================================================================
# Toolbar Unit Tests
# Tests for toolbar indicator controllers
# ============================================================================

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        ConopControllerTest.cc
        ConopControllerTest.h
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_qgc_test(ConopControllerTest LABELS Integration Vehicle)
