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

add_custom_target(configure_bazel
	COMMAND ${Bazelisk}
	USES_TERMINAL
	WORKING_DIRECTORY ${TENSORFLOW_DIR})


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
	DEPENDS configure_bazel
	WORKING_DIRECTORY ${TENSORFLOW_DIR}
	COMMAND bazel query "attr(visibility, \"//visibility:public\", //tensorflow:*)")

add_custom_target(configure_tf
	USES_TERMINAL
	DEPENDS configure_bazel
	WORKING_DIRECTORY ${TENSORFLOW_DIR}
	COMMAND export PYTHONPATH="${Python}"
			PYTHON_BIN_PATH="${PYTHON_BIN_PATH}"
			PYTHON_LIB_PATH="${PYTHON_LIB_PATH}"
			TF_NEED_CUDA="${TF_NEED_CUDA}"
			TF_CUDA_CLANG="${TF_CUDA_CLANG}"
			TF_DOWNLOAD_CLANG="${TF_DOWNLOAD_CLANG}"
			TF_TENSORRT_VERSION="${TF_TENSORRT_VERSION}"
			TF_NEED_ROCM="${TF_NEED_ROCM}"
			TF_CONFIGURE_IOS="${TF_CONFIGURE_IOS}"
			TF_ENABLE_XLA="${TF_ENABLE_XLA}"
			TF_NEED_OPENCL_SYCL="${TF_NEED_OPENCL_SYCL}"
			TF_SET_ANDROID_WORKSPACE="${TF_SET_ANDROID_WORKSPACE}"
			CC_OPT_FLAGS="${CC_OPT_FLAGS}"
			TEST_TMPDIR="${TF_BIN_DIR}" # Specify bazel output location
			&& ./configure)

add_external_library(TARGET tensorflow_cc
	# Build tensorflow into the CMAKE Binary_DIR
	#                                                               build with 'opt' flags
	COMMAND export TEST_TMPDIR="${TF_BIN_DIR}" && ${Bazelisk} build -c opt ${CUSTOM_TF_CONFIG} //tensorflow:tensorflow_cc
	USES_TERMINAL
	WORKING_DIRECTORY "${TENSORFLOW_DIR}"
	INCLUDE_DIRS
		"${TENSORFLOW_DIR}/;" # Standard Headers
		"${TENSORFLOW_DIR}/bazel-bin/;" # Generated Protobuf
		"${TENSORFLOW_DIR}/bazel-tensorflow_raw-src/external/eigen_archive/;" # Patch for Eigen
		"${TENSORFLOW_DIR}/../abseil-cpp" # Missing absl library
	OUTPUT "${TENSORFLOW_DIR}/bazel-bin/tensorflow/libtensorflow_cc.so.${TF_VERSION}"
	DEPENDS configure_tf)
add_external_library(TARGET tensorflow_framework
	COMMAND touch hello.txt
	WORKING_DIRECTORY "${TENSORFLOW_DIR}"
	INCLUDE_DIRS "${TENSORFLOW_DIR}/;" # Standard Headers
	OUTPUT "${TENSORFLOW_DIR}/bazel-bin/tensorflow/libtensorflow_framework.so"
	DEPENDS tensorflow_cc)
# add_dependencies(tensorflow_target configure_tf)
set(protobuf_BUILD_TESTS OFF)
add_subdirectory(${TENSORFLOW_DIR}/bazel-tensorflow_raw-src/external/com_google_protobuf/cmake/ ${TF_BIN_DIR} EXCLUDE_FROM_ALL)

add_custom_target(tensorflow_cc_copy
	USES_TERMINAL
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${TENSORFLOW_DIR}/bazel-bin/tensorflow/libtensorflow_cc.so.2 ${CMAKE_BINARY_DIR}/libtensorflow_cc.so.2
	WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
	DEPENDS tensorflow_cc)

add_custom_target(tensorflow_framework_copy
	USES_TERMINAL
	COMMAND ${CMAKE_COMMAND} -E copy_if_different ${TENSORFLOW_DIR}/bazel-bin/tensorflow/libtensorflow_framework.so ${CMAKE_BINARY_DIR}/libtensorflow_framework.so.2
	WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
	DEPENDS tensorflow_cc)

add_library(tensorflow INTERFACE)
target_link_libraries(tensorflow INTERFACE tensorflow_cc tensorflow_framework absl::strings protobuf::libprotobuf)
target_include_directories(tensorflow PUBLIC ${tensorflow_cc_INCLUDE_DIRS})
add_dependencies(tensorflow tensorflow_cc_copy tensorflow_framework_copy tensorflow_cc_target tensorflow_cc_framework)
