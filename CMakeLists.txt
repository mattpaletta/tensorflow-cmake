project(tensorflow)
cmake_minimum_required(VERSION 3.11)

include(cmake/external_library.cmake)
include(cmake/fetch_tf.cmake)

find_program(Bazelisk bazelisk REQUIRED)
find_program(Bazel bazel REQUIRED)
find_program(Python python3 REQUIRED)
message("Found Python3: " ${Python})

add_custom_target(configure_bazel
	COMMAND ${Bazelisk}
	USES_TERMINAL
	WORKING_DIRECTORY ${TENSORFLOW_DIR})

set(TF_SIMD_FLAGS " --copt=-mfpmath=both --copt=-mavx --copt=-mavx2 --copt=-mfma --copt=-msse4.1 --copt=-msse4.2")
set(CUSTOM_TF_CONFIG "--config=monolithic --config=v2 --config=noaws --config=nogcp --config=nohdfs --config=nonccl")
set(TF_NEED_CUDA 0)
set(TF_CUDA_CLANG 0) # Use nvcc for cuda
set(TF_DOWNLOAD_CLANG 0)
set(TF_TENSORRT_VERSION 0)
set(TF_NEED_ROCM 0)
set(TF_CONFIGURE_IOS 0)
set(TF_ENABLE_XLA 1)
set(TF_NEED_OPENCL_SYCL 0)
set(TF_SET_ANDROID_WORKSPACE 0)
set(CC_OPT_FLAGS "-march=native -Wno-sign-compare ${CUSTOM_TF_CONFIG} ${TF_SIMD_FLAGS}")

execute_process(COMMAND ${Python} -c "import sys; print(sys.executable, )"
	OUTPUT_VARIABLE PYTHON_BIN_PATH
	WORKING_DIRECTORY /
	OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND ${Python} -c "from distutils.sysconfig import get_python_lib; print(get_python_lib(), )"
	WORKING_DIRECTORY /
	OUTPUT_VARIABLE PYTHON_LIB_PATH
	OUTPUT_STRIP_TRAILING_WHITESPACE)

message("Python Bin Path: " ${PYTHON_BIN_PATH})
message("Python Lib Path: " ${PYTHON_LIB_PATH})
set(TF_BIN_DIR ${tensorflow_raw_BINARY_DIR})

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

add_external_library(TARGET tensorflow
	# Build tensorflow into the CMAKE Binary_DIR
	#                                                               build with 'opt' flags
	COMMAND export TEST_TMPDIR="${TF_BIN_DIR}" && ${Bazelisk} build -c opt //tensorflow:tensorflow_cc
	WORKING_DIRECTORY "${TENSORFLOW_DIR}"
	INCLUDE_DIRS
		"${TF_BIN_DIR}/bazel-tensorflow;" # Standard Headers
		"${TENSORFLOW_DIR}/;" # Standard Headers
		"${TF_BIN_DIR}/bazel-bin/;" # Generated Protobuf
		"${TF_BIN_DIR}/bazel-tensorflow/external/eigen_archive/;" # Patch for Eigen
		"${TENSORFLOW_DIR}/../abseil-cpp" # Missing absl library
	OUTPUT
		"${TENSORFLOW_DIR}/bazel-bin/tensorflow/libtensorflow_cc.so"
		"${TENSORFLOW_DIR}/bazel-bin/" # Generated Protobuf
	DEPENDS configure_tf)
add_dependencies(tensorflow configure_tf)

