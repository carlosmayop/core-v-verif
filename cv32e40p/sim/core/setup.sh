if [ -n "$BASH_VERSION" ]; then
  SCRIPT_PATH="$BASH_SOURCE[0]"
elif [ -n "$ZSH_VERSION" ]; then
  SCRIPT_PATH="${(%):-%N}"
else
  echo "Error: Non recognized shell."
  return
fi

export ROOT_PROJECT=$(readlink -f $(dirname "${SCRIPT_PATH}")/../../..)
# Print the root project path
export DPI_DASM_SPIKE_REPO="$ROOT_PROJECT/tools/spike"
export CV_SW_TOOLCHAIN="$ROOT_PROJECT/tools/riscv-toolchain"
export CV_SW_PREFIX=riscv32-unknown-elf-
