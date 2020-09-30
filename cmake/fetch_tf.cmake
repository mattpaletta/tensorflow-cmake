include(FetchContent)
FetchContent_Declare(
    tensorflow_raw
    GIT_REPOSITORY https://github.com/tensorflow/tensorflow.git
    GIT_TAG        v${TF_VERSION}
)

FetchContent_Declare(
    abseil-cpp_raw
    GIT_REPOSITORY https://github.com/abseil/abseil-cpp.git
    GIT_TAG        c51510d1d87ebce8615ae1752fd5aca912f6cf4c
)

FetchContent_Declare(
    gtest_raw
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        4fe018038f87675c083d0cfb6a6b57c274fb1753
)

FetchContent_GetProperties(tensorflow_raw)
if(NOT tensorflow_raw_POPULATED)
    FetchContent_Populate(tensorflow_raw)
endif()
set(TENSORFLOW_DIR ${tensorflow_raw_SOURCE_DIR})
set(TF_BIN_DIR ${tensorflow_raw_BINARY_DIR})
message("Tensorflow: " ${TENSORFLOW_DIR})

FetchContent_GetProperties(gtest_raw)
if(NOT gtest_POPULATED)
    FetchContent_Populate(gtest_raw)
endif()

add_subdirectory(${gtest_raw_SOURCE_DIR} ${gtest_raw_BINARY_DIR} EXCLUDE_FROM_ALL)

FetchContent_GetProperties(abseil-cpp_raw)
if(NOT abseil-cpp_POPULATED)
    FetchContent_Populate(abseil-cpp_raw)
endif()

option(ABSL_RUN_TESTS "" OFF)
set(ABSL_RUN_TESTS OFF)
add_subdirectory(${abseil-cpp_raw_SOURCE_DIR} ${abseil-cpp_raw_BINARY_DIR} EXCLUDE_FROM_ALL)
