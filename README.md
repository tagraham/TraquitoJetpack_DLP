# TraquitoJetpack DLP (Docker / Low Power)

WSPR (Weak Signal Propagation Reporter) tracker firmware for RP2040 (Raspberry Pi Pico).

This is a fork of [dmalnati's TraquitoJetpack](https://github.com/dmalnati/TraquitoJetpack) - a fantastic piece of work that makes high-altitude balloon tracking accessible to ham radio enthusiasts everywhere. Huge thanks to the original author for making this available to the community.

**What this fork adds:**
- Docker-based build system for easy Linux/macOS/Windows compilation
- GCC compatibility patches (original was built with MSVC on Windows)
- Experiments with lower solar angle operation (work in progress)

## Quick Start

```bash
# Build firmware (requires Docker)
docker build -t traquito-build .
docker run --rm -v "$(pwd):/project" traquito-build

# Flash to Pico: hold BOOTSEL, plug in, copy output/TraquitoJetpack.uf2
```

## About

This is the source code for the [Traquito Jetpack WSPR tracker](https://traquito.github.io/tracker/).

This project relies heavily on the [picoinf](https://github.com/dmalnati/picoinf) project.

### Features

- WSPR beacon transmission for high-altitude balloon tracking
- JavaScript-based configuration via JerryScript engine
- GPS integration for position reporting
- Telemetry encoding with extended WSPR messages
- Low power operation for solar-powered flights

## Building

### Option 1: Docker (Recommended)

Works on Linux, macOS, and Windows (with Docker Desktop).

```bash
# Build the Docker image (one-time)
docker build -t traquito-build .

# Compile the firmware
docker run --rm -v "$(pwd):/project" traquito-build
```

Output files in `output/`:
- `TraquitoJetpack.uf2` - Flash this to your Pico
- `TraquitoJetpack.elf` - For debugging
- `TraquitoJetpack.bin` - Raw binary

### Option 2: Native Build (Advanced)

Requirements:
- ARM GCC toolchain 11.3
- CMake 3.15+
- Pico SDK

See original project notes - this is a C++ program built with CMake, not Arduino.

## Flashing

1. Hold the **BOOTSEL** button while plugging in the Pico
2. It will mount as a USB drive (RPI-RP2)
3. Copy `output/TraquitoJetpack.uf2` to the drive
4. The Pico will automatically reboot with the new firmware

Alternative: Flash via SWD using [J-Link](https://www.segger.com/products/debug-probes/j-link/models/j-link-edu-mini/)

## Fork Changes

The original code was developed on Windows with MSVC. This fork includes patches for GCC/Linux compilation:

1. **Time.h wrapper** - Creates missing header bridging `TimeClass.h`
2. **Clock.cpp fix** - Moves forward declaration for GCC compatibility
3. **JerryScript config** - Overrides heap size to fit RP2040's 264KB RAM

These patches are applied automatically by `build.sh` during the Docker build.

## Hardware

See [traquito.github.io](https://traquito.github.io/) for:
- Hardware design files
- Assembly instructions
- Configuration guides

## Project Structure

```
TraquitoJetpack/
├── src/                    # Main application source
├── ext/picoinf/           # Platform abstraction layer
│   ├── src/               # picoinf source
│   └── ext/               # Dependencies (pico-sdk, jerryscript, FreeRTOS, etc.)
├── Dockerfile             # Build container definition
├── build.sh               # Build script (runs inside Docker)
└── output/                # Build outputs (generated)
```

## History

> I built this project not intending to make it visible to others.
> Then I decided to make it visible to others, that's why some things aren't quite perfect.
>
> I hope you find something useful or interesting here.
> Unfortunately no support is available for your use of this project.
> All code subject to change at any time, with no warning, including going private.
>
> -- Original Author

## License

See LICENSE file.

## Acknowledgments

This project would not exist without the incredible work of [dmalnati](https://github.com/dmalnati), who designed and built the entire Traquito ecosystem - hardware, firmware, and documentation. The amount of effort that went into making WSPR balloon tracking accessible to hobbyists is remarkable. Thank you for sharing this with the ham radio community.

- Original project: [dmalnati/TraquitoJetpack](https://github.com/dmalnati/TraquitoJetpack)
- Traquito website: https://traquito.github.io/
- Related project: [dmalnati/picoinf](https://github.com/dmalnati/picoinf)
