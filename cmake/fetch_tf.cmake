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

FetchContent_GetProperties(tensorflow_raw)
if(NOT tensorflow_raw_POPULATED)
    FetchContent_Populate(tensorflow_raw)
endif()
set(TENSORFLOW_DIR ${tensorflow_raw_SOURCE_DIR})
set(TF_BIN_DIR ${tensorflow_raw_BINARY_DIR})
message("Tensorflow: " ${TENSORFLOW_DIR})

FetchContent_GetProperties(abseil-cpp_raw)
if(NOT abseil-cpp_POPULATED)
    FetchContent_Populate(abseil-cpp_raw)
endif()

add_subdirectory(${abseil-cpp_raw_SOURCE_DIR} ${abseil-cpp_raw_BINARY_DIR} EXCLUDE_FROM_ALL)
