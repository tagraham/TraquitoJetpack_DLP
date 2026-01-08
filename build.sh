#!/bin/bash
# Build script for TraquitoJetpack RP2040 firmware
set -e

PROJECT_DIR="/project"
BUILD_DIR="${PROJECT_DIR}/build"
OUTPUT_DIR="${PROJECT_DIR}/output"

# =============================================================================
# BUILD CONFIGURATION
# =============================================================================
# LOW_POWER_MODE: Set to 1 for single clock output (reduced power for low solar)
#                 Set to 0 for dual clock output (maximum power, default)
#
# Can also be set via environment variable:
#   LOW_POWER_MODE=1 docker run --rm -v "$(pwd):/project" traquito-build
# =============================================================================
LOW_POWER_MODE=${LOW_POWER_MODE:-0}

echo "=========================================="
echo "TraquitoJetpack Build Script"
echo "=========================================="
echo ""
if [ "$LOW_POWER_MODE" = "1" ]; then
    echo "*** LOW POWER MODE: Single clock output (CLK0 only) ***"
else
    echo "*** STANDARD MODE: Dual clock output (CLK0 + CLK1) ***"
fi

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

echo "Patching WSPRMessageTransmitter.h (add LOW_POWER_SINGLE_CLOCK option)..."
# Add compile-time option to use single clock output for reduced power consumption.
# When LOW_POWER_SINGLE_CLOCK is defined, only CLK0 is used (no CLK1 with 180-degree phase shift).
WSPR_TX_H="${PROJECT_DIR}/ext/picoinf/src/WSPR/WSPRMessageTransmitter.h"

# Only apply patch if not already patched (idempotent)
if ! grep -q 'LOW_POWER_SINGLE_CLOCK' "${WSPR_TX_H}"; then
    echo "  Applying WSPRMessageTransmitter.h patch..."

    # Add documentation comment after the includes
    sed -i '/#include "WSPREncoder.h"/a\
\
// LOW_POWER_SINGLE_CLOCK: When defined, uses only CLK0 (single output)\
// for reduced power consumption at lower solar angles.\
// When not defined (default), uses CLK0 + CLK1 with 180-degree phase shift\
// for maximum output power (dual phase output).\
//\
// To enable low power mode, add to CMake: -DLOW_POWER_SINGLE_CLOCK=ON\
// or uncomment the line below:\
// #define LOW_POWER_SINGLE_CLOCK' "${WSPR_TX_H}"

    # Wrap CLK1 setup in RadioOn() with #ifndef
    sed -i '/Fan out and invert the first clock signal/i\
#ifndef LOW_POWER_SINGLE_CLOCK' "${WSPR_TX_H}"
    sed -i 's|// 180-degree phase shift on second clock|// 180-degree phase shift on second clock (dual phase output for more power)|' "${WSPR_TX_H}"
    sed -i '/output_enable(SI5351_CLK1, 1);/a\
#endif' "${WSPR_TX_H}"

    # Wrap CLK1 disable in RadioOff() with #ifndef
    sed -i '/output_enable(SI5351_CLK1, 0);/i\
#ifndef LOW_POWER_SINGLE_CLOCK' "${WSPR_TX_H}"
    sed -i '/set_clock_pwr(SI5351_CLK1, 0);/a\
#endif' "${WSPR_TX_H}"

    # Wrap CLK1 drive strength in SetDrive() with #ifndef
    sed -i '/drive_strength(SI5351_CLK1, pwr);/i\
#ifndef LOW_POWER_SINGLE_CLOCK' "${WSPR_TX_H}"
    sed -i '/drive_strength(SI5351_CLK1, pwr);/a\
#endif' "${WSPR_TX_H}"
else
    echo "  WSPRMessageTransmitter.h already patched, skipping..."
fi

echo "Configuring with CMake..."
cd "${BUILD_DIR}"

# Generate build timestamp for SW version display (YYYY-MM-DD HH:MM:SS)
BUILD_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "Build timestamp: ${BUILD_TIMESTAMP}"

# Build CMake options
CMAKE_OPTS="-DCMAKE_BUILD_TYPE=MinSizeRel"
CMAKE_OPTS="${CMAKE_OPTS} -DAPP_BUILD_VERSION=\"${BUILD_TIMESTAMP}\""
CMAKE_OPTS="${CMAKE_OPTS} -DPICO_SDK_PATH=${PROJECT_DIR}/ext/picoinf/ext/pico-sdk"
CMAKE_OPTS="${CMAKE_OPTS} -DJERRY_GLOBAL_HEAP_SIZE=24"
CMAKE_OPTS="${CMAKE_OPTS} -DJERRY_STACK_LIMIT=8"
CMAKE_OPTS="${CMAKE_OPTS} -DJERRY_LINE_INFO=ON"
CMAKE_OPTS="${CMAKE_OPTS} -DJERRY_ERROR_MESSAGES=ON"
CMAKE_OPTS="${CMAKE_OPTS} -DJERRY_LOGGING=ON"
CMAKE_OPTS="${CMAKE_OPTS} -DJERRY_VM_HALT=ON"
CMAKE_OPTS="${CMAKE_OPTS} -DJERRY_VM_THROW=ON"
CMAKE_OPTS="${CMAKE_OPTS} -DJERRY_MEM_STATS=ON"

# Add low power mode flag if enabled (using compile definitions to avoid overwriting flags)
if [ "$LOW_POWER_MODE" = "1" ]; then
    CMAKE_OPTS="${CMAKE_OPTS} -DLOW_POWER_SINGLE_CLOCK=ON"
fi

cmake "${PROJECT_DIR}" ${CMAKE_OPTS}

# Build only the main target (skip test applications that fail with ARM toolchain)
echo ""
echo "Building TraquitoJetpack target..."
make -j$(nproc) TraquitoJetpack

# Copy output files with appropriate naming
echo ""
echo "Copying output files..."

# Generate timestamp for filename (YYYYMMDD-HHMM)
TIMESTAMP=$(date +"%Y%m%d-%H%M")

# Set output filename suffix based on build mode
if [ "$LOW_POWER_MODE" = "1" ]; then
    OUTPUT_SUFFIX="_LowPower_SingleClock_${TIMESTAMP}"
else
    OUTPUT_SUFFIX="_${TIMESTAMP}"
fi

if [ -f "${BUILD_DIR}/src/TraquitoJetpack.uf2" ]; then
    cp "${BUILD_DIR}/src/TraquitoJetpack.uf2" "${OUTPUT_DIR}/TraquitoJetpack${OUTPUT_SUFFIX}.uf2"
    echo "SUCCESS: TraquitoJetpack${OUTPUT_SUFFIX}.uf2 created!"
    ls -la "${OUTPUT_DIR}/TraquitoJetpack${OUTPUT_SUFFIX}.uf2"
else
    echo "ERROR: TraquitoJetpack.uf2 not found!"
    echo "Looking for .uf2 files..."
    find "${BUILD_DIR}" -name "*.uf2" -ls
    exit 1
fi

# Also copy other useful files if they exist
for ext in elf bin hex map; do
    if [ -f "${BUILD_DIR}/src/TraquitoJetpack.${ext}" ]; then
        cp "${BUILD_DIR}/src/TraquitoJetpack.${ext}" "${OUTPUT_DIR}/TraquitoJetpack${OUTPUT_SUFFIX}.${ext}"
    fi
done

echo ""
echo "=========================================="
echo "Build complete! Output files in /project/output/"
echo "=========================================="
ls -la "${OUTPUT_DIR}/"
