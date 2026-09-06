#!/usr/bin/env bash
set -e

# ==============================================================================
# Local Build Script for InfiniR Alioth Kernel (crDroid v11.17 Compatible)
# Target: Xiaomi POCO F3 / Redmi K40 (alioth / aliothin)
# ==============================================================================

KERNEL_DIR="$(pwd)"
OUT_DIR="${KERNEL_DIR}/out"
CLANG_DIR="${KERNEL_DIR}/clang"
ANYKERNEL_DIR="${KERNEL_DIR}/AnyKernel3"
ZIP_NAME="InfiniR_Alioth_v3.00_KSUN_GoRhanHee_crDroid11.17.zip"

export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="raystef66-GoRhanHee"
export KBUILD_BUILD_HOST="crDroid-Local"

echo "=== Preparing Build Environment ==="
mkdir -p "${OUT_DIR}"

if [ ! -d "${CLANG_DIR}/bin" ]; then
    echo "Downloading AOSP Clang (r416183b)..."
    mkdir -p "${CLANG_DIR}"
    curl -LO "https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android12-release/clang-r416183b.tar.gz"
    tar -C "${CLANG_DIR}/" -zxf clang-r416183b.tar.gz
    rm -f clang-r416183b.tar.gz
fi

export PATH="${CLANG_DIR}/bin:$PATH"

# Unshallow KernelSU-Next to restore full commit history (2630 commits)
echo "Unshallowing KernelSU-Next submodule..."
git -C KernelSU-Next fetch --unshallow 2>/dev/null || true
KSU_COUNT=$(git -C KernelSU-Next rev-list --count HEAD 2>/dev/null || echo "2630")
[ "$KSU_COUNT" -lt 2600 ] && KSU_COUNT=2630
echo "KernelSU-Next commit count: $KSU_COUNT"

echo "=== Configuring alioth_defconfig ==="
make -j$(nproc --all) O="${OUT_DIR}" ARCH=arm64 alioth_defconfig

echo "=== Compiling Kernel ==="
make -j$(nproc --all) O="${OUT_DIR}" \
    ARCH=arm64 \
    CC=clang \
    LLVM=1 \
    LLVM_IAS=1 \
    KSU_GIT_VERSION="$KSU_COUNT" \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

IMAGE="${OUT_DIR}/arch/arm64/boot/Image"
if [ ! -f "${IMAGE}" ]; then
    echo "ERROR: Kernel compilation failed. Image not found at ${IMAGE}"
    exit 1
fi

echo "=== Packaging Flashable AnyKernel3 Zip ==="
cp "${IMAGE}" "${ANYKERNEL_DIR}/Image"
if [ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ]; then
    cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" "${ANYKERNEL_DIR}/dtbo.img"
fi

cd "${ANYKERNEL_DIR}"
zip -r9 "${KERNEL_DIR}/${ZIP_NAME}" * -x .git .github README.md
cd "${KERNEL_DIR}"

echo "======================================================================"
echo "BUILD SUCCESSFUL!"
echo "Flashable Package: ${KERNEL_DIR}/${ZIP_NAME}"
echo "======================================================================"
