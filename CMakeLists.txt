project(tensorflow)
cmake_minimum_required(VERSION 3.11)

set(TF_VERSION "2.2.0")

include(cmake/external_library.cmake)
include(cmake/fetch_tf.cmake)

find_program(Bazelisk bazelisk REQUIRED)
find_program(Bazel bazel REQUIRED)
find_program(Python python3 REQUIRED)
message("Found Python3: " ${Python})

option(ENABLE_TF_SIMD "enable tensorflow SIMD support" ON)
option(ENABLE_TF_XLA  "enable tensorflow xla support" ON)
option(ENABLE_TF_CUDA  "enable tensorflow cuda support" OFF)

# Libraries
option(ENABLE_TF_AWS  "enable tensorflow aws support" OFF)
option(ENABLE_TF_GCP  "enable tensorflow gcp support" OFF)
option(ENABLE_TF_HDFS  "enable tensorflow hdfs support" OFF)
option(ENABLE_TF_NCCL  "enable tensorflow nccl support" OFF)

set(CUSTOM_TF_CONFIG "--config=monolithic" "--config=v2")
if (NOT ${ENABLE_TF_AWS})
	list(APPEND CUSTOM_TF_CONFIG "--config=noaws")
endif()
if (NOT ${ENABLE_TF_GCP})
	list(APPEND CUSTOM_TF_CONFIG "--config=nogcp")
endif()
if (NOT ${ENABLE_TF_HDFS})
	list(APPEND CUSTOM_TF_CONFIG "--config=nohdfs")
endif()
if (NOT ${ENABLE_TF_NCCL})
	list(APPEND CUSTOM_TF_CONFIG "--config=nonccl")
endif()

if (ENABLE_TF_CUDA)
	set(TF_NEED_CUDA 1)
else()
	set(TF_NEED_CUDA 0)
endif()
set(TF_CUDA_CLANG 0) # Use nvcc for cuda
set(TF_DOWNLOAD_CLANG 0)
set(TF_TENSORRT_VERSION 0)
set(TF_NEED_ROCM 0)
set(TF_CONFIGURE_IOS 0)

if (ENABLE_TF_XLA)
	set(TF_ENABLE_XLA 1)
else()
	set(TF_ENABLE_XLA 0)
endif()

set(TF_NEED_OPENCL_SYCL 0)
set(TF_SET_ANDROID_WORKSPACE 0)

set(TF_SIMD_FLAGS "-mfpmath=both" "-mavx" "-mavx2" "-mfma" "-msse4.1" "-msse4.2")

if (ENABLE_TF_SIMD)
	set(CC_OPT_FLAGS "-march=native -Wno-sign-compare ${TF_SIMD_FLAGS}")
else()
	set(CC_OPT_FLAGS "-march=native -Wno-sign-compare")
endif()

execute_process(COMMAND ${Python} -c "import sys; print(sys.executable, )"
	OUTPUT_VARIABLE PYTHON_BIN_PATH
	WORKING_DIRECTORY /
	OUTPUT_STRIP_TRAILING_WHITESPACE)

execute_process(COMMAND ${Python} -c "from distutils.sysconfig import get_python_lib; print(get_python_lib(), )"
	WORKING_DIRECTORY /
	OUTPUT_VARIABLE PYTHON_LIB_PATH
	OUTPUT_STRIP_TRAILING_WHITESPACE)

execute_process(COMMAND ${Python} -c "try:\n\timport numpy as np; np.__path__; np.get_include()\n\tprint(0);\nexcept:\n\tprint(1)"
	OUTPUT_VARIABLE FOUND_NUMPY
	WORKING_DIRECTORY /
	OUTPUT_STRIP_TRAILING_WHITESPACE)

if (${FOUND_NUMPY} STREQUAL "1")
	message(FATAL_ERROR "Failed to find numpy")
endif()

add_custom_target(list_tf_targets
	USES_TERMINAL
	WORKING_DIRECTORY ${TENSORFLOW_DIR}
	COMMAND bazel query "attr(visibility, \"//visibility:public\", //tensorflow:*)")

set(_tf_targets "//tensorflow:tensorflow_cc" "//tensorflow:install_headers")


execute_process(COMMAND sh -c "cat tensorflow/tools/pip_package/setup.py | grep \"protobuf.*=\" | awk '{print $3}' | sed \"s/',//g\""
	OUTPUT_VARIABLE protobuf_version
	WORKING_DIRECTORY ${TENSORFLOW_DIR}
	OUTPUT_STRIP_TRAILING_WHITESPACE)
message("Using Protobuf version: " ${protobuf_version})

execute_process(COMMAND ${Bazelisk}
		WORKING_DIRECTORY ${TENSORFLOW_DIR}
		OUTPUT_QUIET)
execute_process(COMMAND export PYTHONPATH="${Python}" 
		COMMAND export PYTHON_BIN_PATH="${PYTHON_BIN_PATH}" PYTHON_LIB_PATH="${PYTHON_LIB_PATH}" TF_NEED_CUDA="${TF_NEED_CUDA}" TF_CUDA_CLANG="${TF_CUDA_CLANG}" TF_DOWNLOAD_CLANG="${TF_DOWNLOAD_CLANG}" TF_TENSORRT_VERSION="${TF_TENSORRT_VERSION}" TF_NEED_ROCM="${TF_NEED_ROCM}" TF_CONFIGURE_IOS="${TF_CONFIGURE_IOS}" TF_ENABLE_XLA="${TF_ENABLE_XLA}" TF_NEED_OPENCL_SYCL="${TF_NEED_OPENCL_SYCL}" TF_SET_ANDROID_WORKSPACE="${TF_SET_ANDROID_WORKSPACE}" CC_OPT_FLAGS="${CC_OPT_FLAGS}" TEST_TMPDIR="${TF_BIN_DIR}" && ./configure
			WORKING_DIRECTORY ${TENSORFLOW_DIR}
			OUTPUT_FILE .tf_configure.bazelrc)

set(tf_cc_build_dir ${TENSORFLOW_DIR}/bazel-out/k8-opt/bin)
set(tf_cc_dir ${tf_cc_build_dir}/tensorflow)
set(tf_cc_path ${tf_cc_dir}/libtensorflow_cc.so.${TF_VERSION})

add_custom_target(tensorflow_cc
	COMMAND export TEST_TMPDIR="${TF_BIN_DIR}" && ${Bazelisk} build -c opt ${CUSTOM_TF_CONFIG} //tensorflow:tensorflow_cc
	DEPENDS ${TENSORFLOW_DIR}/.tf_configure.bazelrc
	WORKING_DIRECTORY "${TENSORFLOW_DIR}"
	BYPRODUCTS ${tf_cc_path})	

add_custom_target(tensorflow_headers
	COMMAND export TEST_TMPDIR="${TF_BIN_DIR}" && ${Bazelisk} build -c opt ${CUSTOM_TF_CONFIG} //tensorflow:install_headers //third_party/eigen3:install_eigen_headers
	DEPENDS ${TENSORFLOW_DIR}/.tf_configure.bazelrc
	WORKING_DIRECTORY "${TENSORFLOW_DIR}"
	BYPRODUCTS ${tf_cc_dir}/libtensorflow_framework.so)	

set(protobuf_BUILD_TESTS OFF)
add_subdirectory(${TENSORFLOW_DIR}/bazel-tensorflow_raw-src/external/com_google_protobuf/cmake/ ${TF_BIN_DIR} EXCLUDE_FROM_ALL)

add_custom_target(tensorflow_cc_copy
	USES_TERMINAL
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${tf_cc_path} ${CMAKE_BINARY_DIR}/libtensorflow_cc.so.2
	WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
	DEPENDS tensorflow_cc)

# We know we're grabbing the same onw as tensorflow always
FetchContent_Declare(protobuf 
	GIT_REPOSITORY https://github.com/protocolbuffers/protobuf.git 
	GIT_TAG v${protobuf_version})
FetchContent_GetProperties(protobuf)
if (NOT protobuf_POPULATED)
	FetchContent_Populate(protobuf)
endif()
add_subdirectory(${protobuf_SOURCE_DIR}/cmake ${protobuf_BINARY_DIR} EXCLUDE_FROM_ALL)


add_library(tensorflow STATIC IMPORTED GLOBAL)
target_include_directories(tensorflow INTERFACE ${TENSORFLOW_DIR})
set_target_properties(tensorflow PROPERTIES
	IMPORTED_LOCATION ${tf_cc_path}
	INTERFACE_INCLUDE_DIRECTORIES "${TENSORFLOW_DIR};${tf_cc_build_dir}/tensorflow/include")
target_link_libraries(tensorflow INTERFACE absl::strings protobuf::libprotobuf)
add_dependencies(tensorflow INTERFACE tensorflow_cc_copy tensorflow_headers)
