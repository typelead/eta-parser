patch_source() {
  if [ $# -ne 3 ]; then
    >&2 echo "Usage: $0 <src> <target> <patch_file>"
    exit 1
  fi
  local target=$2
  mkdir -p $(dirname "$target")
  cp "$1" "$target"
  local patch_file=$3
  if [ -f "$patch_file" ]; then
    patch -s "$target" "$patch_file"
  fi
}
