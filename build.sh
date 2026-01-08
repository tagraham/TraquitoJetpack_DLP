#!/bin/bash
# Build script for TraquitoJetpack RP2040 firmware
set -e

PROJECT_DIR="/project"
BUILD_DIR="${PROJECT_DIR}/build"
OUTPUT_DIR="${PROJECT_DIR}/output"

echo "=========================================="
echo "TraquitoJetpack Build Script"
echo "=========================================="

# Check toolchain
echo "Checking ARM toolchain..."
arm-none-eabi-gcc --version | head -1

# Check CMake
echo "CMake version:"
cmake --version | head -1

# Create build directory
echo ""
echo "Creating build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Configure with CMake
echo ""
echo "Ensuring pico-sdk 2.0.0 (required for clock_handle_t support)..."
cd "${PROJECT_DIR}/ext/picoinf/ext/pico-sdk"
git checkout 2.0.0 2>/dev/null || echo "  Already at 2.0.0"
cd "${PROJECT_DIR}"

echo "Creating Time.h wrapper (workaround for picoinf header naming)..."
# The TraquitoJetpack code includes Time.h but picoinf provides TimeClass.h
# Create a wrapper to fix this
cat > "${PROJECT_DIR}/ext/picoinf/src/App/Service/Time.h" << 'EOF'
#pragma once
// Wrapper for TimeClass.h - the picoinf library uses TimeClass.h
// but TraquitoJetpack expects Time.h
#include "TimeClass.h"
EOF

echo "Patching Clock.cpp (fix forward declaration for GCC compatibility)..."
# The original code was compiled with MSVC which is lenient with incomplete types in STL containers.
# GCC requires complete types. Move the unordered_map declaration after PllConfig is defined.
CLOCK_CPP="${PROJECT_DIR}/ext/picoinf/src/App/Peripheral/Clock.cpp"

# Only apply patch if the forward declaration exists (idempotent)
if grep -q '^struct PllConfig;$' "${CLOCK_CPP}"; then
    echo "  Applying Clock.cpp patch..."
    # Remove the forward declaration and map declaration (lines 44-45)
    sed -i '/^struct PllConfig;$/d' "${CLOCK_CPP}"
    sed -i '/^static unordered_map<double, PllConfig> freq__data;$/d' "${CLOCK_CPP}"

    # Add the map declaration right after the PllConfig struct closing brace
    # Insert before the comment that follows the struct
    sed -i '/^\/\/ 15.3 MHz is the lowest you can go with a PLL$/i\
static unordered_map<double, PllConfig> freq__data;\
' "${CLOCK_CPP}"
else
    echo "  Clock.cpp already patched, skipping..."
fi

echo "Configuring with CMake..."
cd "${BUILD_DIR}"
cmake "${PROJECT_DIR}" \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DPICO_SDK_PATH="${PROJECT_DIR}/ext/picoinf/ext/pico-sdk" \
    -DJERRY_GLOBAL_HEAP_SIZE=24 \
    -DJERRY_STACK_LIMIT=8 \
    -DJERRY_LINE_INFO=ON \
    -DJERRY_ERROR_MESSAGES=ON \
    -DJERRY_LOGGING=ON \
    -DJERRY_VM_HALT=ON \
    -DJERRY_VM_THROW=ON \
    -DJERRY_MEM_STATS=ON

# Build only the main target (skip test applications that fail with ARM toolchain)
echo ""
echo "Building TraquitoJetpack target..."
make -j$(nproc) TraquitoJetpack

# Copy output files
echo ""
echo "Copying output files..."
if [ -f "${BUILD_DIR}/src/TraquitoJetpack.uf2" ]; then
    cp "${BUILD_DIR}/src/TraquitoJetpack.uf2" "${OUTPUT_DIR}/"
    echo "SUCCESS: TraquitoJetpack.uf2 created!"
    ls -la "${OUTPUT_DIR}/TraquitoJetpack.uf2"
else
    echo "ERROR: TraquitoJetpack.uf2 not found!"
    echo "Looking for .uf2 files..."
    find "${BUILD_DIR}" -name "*.uf2" -ls
    exit 1
fi

# Also copy other useful files if they exist
for ext in elf bin hex map; do
    if [ -f "${BUILD_DIR}/src/TraquitoJetpack.${ext}" ]; then
        cp "${BUILD_DIR}/src/TraquitoJetpack.${ext}" "${OUTPUT_DIR}/"
    fi
done

echo ""
echo "=========================================="
echo "Build complete! Output files in /project/output/"
echo "=========================================="
ls -la "${OUTPUT_DIR}/"
