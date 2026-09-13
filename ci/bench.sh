#!/usr/bin/env bash
# ci/bench.sh runs the full build-and-test sequence and prints CIBENCH- sentinel
# lines consumed by an external log parser. See workload-contract.md for the
# full line-format and behavior contract.
set -uo pipefail

RUN_ID="${CIBENCH_RUN_ID:?CIBENCH_RUN_ID is required}"
DRY_RUN="${CIBENCH_DRY_RUN:-0}"
RESULT_URL="${CIBENCH_RESULT_URL:-}"
HEARTBEAT="${CIBENCH_HEARTBEAT:-2}"

LOG_FILE="$(mktemp -t bench-log.XXXXXX)"
HB_PID=""
FAILED=0
FIRST_EXIT=0

ts() {
  date -u +%Y-%m-%dT%H:%M:%S.%NZ
}

emit() {
  echo "$1"
}

fp() {
  emit "CIBENCH-FP ${RUN_ID} $1=$2"
}

start_heartbeat() {
  if [ "${HEARTBEAT}" = "0" ]; then
    return
  fi
  (
    while true; do
      echo "CIBENCH-HB ${RUN_ID} $(ts)"
      sleep "${HEARTBEAT}"
    done
  ) &
  HB_PID=$!
}

stop_heartbeat() {
  if [ -n "${HB_PID}" ]; then
    kill "${HB_PID}" >/dev/null 2>&1 || true
    wait "${HB_PID}" 2>/dev/null || true
    HB_PID=""
  fi
}

have() {
  command -v "$1" >/dev/null 2>&1
}

cpu_model() {
  local m
  m="$(awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null)"
  if [ -n "${m}" ]; then
    echo "${m}"
    return
  fi
  local implementer part
  implementer="$(awk -F': ' '/^CPU implementer/ {print $2; exit}' /proc/cpuinfo 2>/dev/null)"
  part="$(awk -F': ' '/^CPU part/ {print $2; exit}' /proc/cpuinfo 2>/dev/null)"
  if [ -n "${implementer}" ] || [ -n "${part}" ]; then
    echo "implementer=${implementer} part=${part}"
    return
  fi
  uname -m
}

read_steal_total() {
  # Prints "<steal> <total>" from the aggregate /proc/stat cpu line.
  awk '/^cpu / {
    steal=$9
    total=0
    for (i=2; i<=NF; i++) total += $i
    print steal, total
  }' /proc/stat
}

cgroup_cpu_max() {
  if [ -r /sys/fs/cgroup/cpu.max ]; then
    cat /sys/fs/cgroup/cpu.max
    return
  fi
  if [ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us ] && [ -r /sys/fs/cgroup/cpu/cpu.cfs_period_us ]; then
    echo "$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us) $(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)"
    return
  fi
  echo "unavailable"
}

cgroup_mem_max() {
  if [ -r /sys/fs/cgroup/memory.max ]; then
    cat /sys/fs/cgroup/memory.max
    return
  fi
  if [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    cat /sys/fs/cgroup/memory/memory.limit_in_bytes
    return
  fi
  echo "unavailable"
}

effective_vcpus() {
  local n quota period cap
  n=$(nproc)
  read -r quota period < <(cgroup_cpu_max)
  case "${quota}" in
    ''|max|unavailable) echo "${n}"; return ;;
  esac
  if [ "${quota}" = "-1" ] || [ -z "${period}" ]; then
    echo "${n}"
    return
  fi
  case "${quota}" in
    ''|*[!0-9]*) echo "${n}"; return ;;
  esac
  case "${period}" in
    ''|*[!0-9]*) echo "${n}"; return ;;
  esac
  if [ "${period}" -le 0 ]; then
    echo "${n}"
    return
  fi
  cap=$(( (quota + period - 1) / period ))
  if [ "${cap}" -lt "${n}" ]; then
    echo "${cap}"
  else
    echo "${n}"
  fi
}

# ---- fetch-toolchain -------------------------------------------------------

detect_arch() {
  case "$(uname -m)" in
    x86_64) echo "amd64" ;;
    aarch64) echo "arm64" ;;
    *) echo "$(uname -m)" ;;
  esac
}

detect_node_arch() {
  case "$(uname -m)" in
    x86_64) echo "x64" ;;
    aarch64) echo "arm64" ;;
    *) echo "$(uname -m)" ;;
  esac
}

go_version_on_path() {
  if have go; then
    go version 2>/dev/null | awk '{print $3}' | sed 's/^go//'
  fi
}

node_version_on_path() {
  if have node; then
    node --version 2>/dev/null | sed 's/^v//'
  fi
}

step_fetch_toolchain() (
  set -e
  local go_want="1.26.1"
  local node_want="22.12.0"
  local goarch nodearch
  goarch="$(detect_arch)"
  nodearch="$(detect_node_arch)"

  # Pick up an already-installed .toolchain/ from a prior run of this checkout
  # (this subshell's PATH only; the parent's prepend_toolchain_path call after
  # this step returns is what matters for later steps).
  prepend_toolchain_path

  local go_have node_have
  go_have="$(go_version_on_path || true)"
  node_have="$(node_version_on_path || true)"

  mkdir -p .toolchain

  if [ "${go_have}" != "${go_want}" ]; then
    local go_url="https://go.dev/dl/go${go_want}.linux-${goarch}.tar.gz"
    curl -fsSL "${go_url}" -o .toolchain/go.tar.gz
    rm -rf .toolchain/go
    tar -C .toolchain -xzf .toolchain/go.tar.gz
    rm -f .toolchain/go.tar.gz
  fi

  if [ "${node_have}" != "${node_want}" ]; then
    # .tar.gz, not .tar.xz: the workload contract requires tar+gzip only, and images such as
    # buildpack-deps:noble-scm ship no xz.
    local node_url="https://nodejs.org/dist/v${node_want}/node-v${node_want}-linux-${nodearch}.tar.gz"
    curl -fsSL "${node_url}" -o .toolchain/node.tar.gz
    rm -rf .toolchain/node
    mkdir -p .toolchain/node
    tar -C .toolchain/node --strip-components=1 -xzf .toolchain/node.tar.gz
    rm -f .toolchain/node.tar.gz
  fi
)

# Exported so later steps (deps/build/test) run with the fetched toolchain on
# PATH, whether or not fetch-toolchain actually downloaded anything.
prepend_toolchain_path() {
  if [ -x ".toolchain/go/bin/go" ]; then
    PATH="${PWD}/.toolchain/go/bin:${PATH}"
    export PATH
  fi
  if [ -x ".toolchain/node/bin/node" ]; then
    PATH="${PWD}/.toolchain/node/bin:${PATH}"
    export PATH
  fi
}

# ---- deps / build / test ---------------------------------------------------

step_deps() (
  set -e
  (cd go && go mod download)
  (cd node && npm ci --no-audit --no-fund)
)

step_build() (
  set -e
  (cd go && go build ./...)
  (cd node && npm run build)
)

step_test() (
  set -e
  (cd go && go test ./...)
  (cd node && npm test)
)

step_docker_build() (
  set -e
  docker build -q -t "shelfkeeper:${RUN_ID}" .
)

# ---- micro measurements -----------------------------------------------------

micro_cpu() (
  set -e
  local size single_start single_end single_ns
  if [ "${DRY_RUN}" = "1" ]; then
    size=$((16 * 1024 * 1024))
  else
    size=$((256 * 1024 * 1024))
  fi

  single_start=$(date +%s%N)
  head -c "${size}" /dev/zero | sha256sum >/dev/null
  single_end=$(date +%s%N)
  single_ns=$((single_end - single_start))
  echo "CIBENCH-MICRO ${RUN_ID} cpu_single_ns=${single_ns}"

  local n multi_start multi_end multi_ns
  n=$(effective_vcpus)
  multi_start=$(date +%s%N)
  seq 1 "${n}" | xargs -P "${n}" -I{} bash -c "head -c ${size} /dev/zero | sha256sum >/dev/null"
  multi_end=$(date +%s%N)
  multi_ns=$((multi_end - multi_start))
  echo "CIBENCH-MICRO ${RUN_ID} cpu_multi_ns=${multi_ns}"
)

micro_disk() (
  set -e
  local count bs=4M
  if [ "${DRY_RUN}" = "1" ]; then
    count=16 # 64 MiB
  else
    count=256 # 1 GiB
  fi
  local total_bytes=$((4 * 1024 * 1024 * count))

  rm -f .bench-disk

  local direct_ok=1
  local write_start write_end write_ns write_err
  write_start=$(date +%s%N)
  if ! write_err=$(dd if=/dev/zero of=.bench-disk bs=${bs} count="${count}" oflag=direct conv=fsync status=none 2>&1); then
    direct_ok=0
  fi
  if [ "${direct_ok}" = "0" ]; then
    echo "CIBENCH-MICRO ${RUN_ID} disk_note=direct-io-unsupported"
    rm -f .bench-disk
    write_start=$(date +%s%N)
    dd if=/dev/zero of=.bench-disk bs=${bs} count="${count}" conv=fsync status=none
  fi
  write_end=$(date +%s%N)
  write_ns=$((write_end - write_start))
  local write_bps
  write_bps=$(awk -v b="${total_bytes}" -v ns="${write_ns}" 'BEGIN { printf "%.0f", b / (ns / 1000000000) }')
  echo "CIBENCH-MICRO ${RUN_ID} disk_write_bps=${write_bps}"

  local read_start read_end read_ns
  if [ "${direct_ok}" = "1" ]; then
    read_start=$(date +%s%N)
    dd if=.bench-disk of=/dev/null bs=${bs} iflag=direct status=none
    read_end=$(date +%s%N)
  else
    read_start=$(date +%s%N)
    dd if=.bench-disk of=/dev/null bs=${bs} status=none
    read_end=$(date +%s%N)
  fi
  read_ns=$((read_end - read_start))
  local read_bps
  read_bps=$(awk -v b="${total_bytes}" -v ns="${read_ns}" 'BEGIN { printf "%.0f", b / (ns / 1000000000) }')
  echo "CIBENCH-MICRO ${RUN_ID} disk_read_bps=${read_bps}"

  rm -f .bench-disk
)

# ---- step runner ------------------------------------------------------------

# run_step NAME requires_tool skip_reason_if_dry_run
run_step() {
  local name="$1"
  local require_tool="${2:-}"
  local dry_run_skips="${3:-0}"

  if [ "${FAILED}" = "1" ]; then
    emit "CIBENCH-SKIP ${RUN_ID} ${name} previous-step-failed"
    return
  fi

  if [ -n "${require_tool}" ] && ! have "${require_tool}"; then
    emit "CIBENCH-SKIP ${RUN_ID} ${name} requires:${require_tool}"
    return
  fi

  if [ "${dry_run_skips}" = "1" ] && [ "${DRY_RUN}" = "1" ]; then
    emit "CIBENCH-SKIP ${RUN_ID} ${name} dry-run"
    return
  fi

  emit "CIBENCH-STEP-START ${RUN_ID} ${name} $(ts)"
  "step_fn_${name//-/_}"
  local rc=$?
  emit "CIBENCH-STEP-END ${RUN_ID} ${name} ${rc} $(ts)"

  if [ "${rc}" != "0" ]; then
    FAILED=1
    FIRST_EXIT="${rc}"
  fi
}

step_fn_fetch_toolchain() { step_fetch_toolchain; local rc=$?; prepend_toolchain_path; return "${rc}"; }
step_fn_deps() { step_deps; }
step_fn_build() { step_build; }
step_fn_test() { step_test; }
step_fn_docker_build() { step_docker_build; }
step_fn_micro_cpu() { micro_cpu; }
step_fn_micro_disk() { micro_disk; }

# ---- main -------------------------------------------------------------------

main() {
  exec > >(tee -a "${LOG_FILE}") 2>&1

  local sha
  sha="$(git rev-parse HEAD 2>/dev/null || echo "0000000000000000000000000000000000000000")"
  emit "CIBENCH-BEGIN ${RUN_ID} $(ts) std-v1@${sha}"

  fp "arch" "$(detect_arch)"
  fp "cpu_model" "$(cpu_model)"
  fp "vcpus" "$(effective_vcpus)"
  fp "host_vcpus" "$(nproc)"
  fp "cgroup_cpu_max" "$(cgroup_cpu_max)"
  fp "cgroup_mem_max" "$(cgroup_mem_max)"
  fp "mem_bytes" "$(awk '/^MemTotal:/ {print $2 * 1024}' /proc/meminfo)"
  fp "kernel" "$(uname -r)"
  fp "os_image" "$( { [ -f /etc/os-release ] && awk -F= '/^PRETTY_NAME=/ {gsub(/"/, "", $2); print $2}' /etc/os-release; } || uname -s)"
  if have systemd-detect-virt; then
    fp "virtualization" "$(systemd-detect-virt 2>/dev/null || echo none)"
  fi
  if have go; then
    fp "toolchain.go" "$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')"
  fi
  if have node; then
    fp "toolchain.node" "$(node --version 2>/dev/null | sed 's/^v//')"
  fi
  if have npm; then
    fp "toolchain.npm" "$(npm --version 2>/dev/null)"
  fi
  if have docker; then
    fp "toolchain.docker" "$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,$//')"
  fi
  if have git; then
    fp "toolchain.git" "$(git --version 2>/dev/null | awk '{print $3}')"
  fi

  read -r begin_steal begin_total < <(read_steal_total)

  start_heartbeat

  run_step "fetch-toolchain" "" "1"
  prepend_toolchain_path
  run_step "deps" "" "1"
  run_step "build" "" "1"
  run_step "test" "" "1"
  run_step "docker-build" "docker" "1"
  run_step "micro-cpu" "" "0"
  run_step "micro-disk" "" "0"

  stop_heartbeat

  read -r end_steal end_total < <(read_steal_total)
  local steal_pct
  steal_pct=$(awk -v s0="${begin_steal}" -v t0="${begin_total}" -v s1="${end_steal}" -v t1="${end_total}" \
    'BEGIN {
       dt = t1 - t0
       ds = s1 - s0
       if (dt <= 0) { printf "0.00"; exit }
       printf "%.2f", (ds / dt) * 100
     }')
  fp "steal_pct" "${steal_pct}"

  local final_exit=0
  if [ "${FAILED}" = "1" ]; then
    final_exit="${FIRST_EXIT}"
  fi

  if [ -n "${RESULT_URL}" ]; then
    if ! curl -fsS --connect-timeout 5 --max-time 15 -X PUT --data-binary "@${LOG_FILE}" "${RESULT_URL}" >/dev/null 2>&1; then
      echo "warning: failed to PUT result log to CIBENCH_RESULT_URL" >&2
    fi
  fi

  emit "CIBENCH-DONE ${RUN_ID} ${final_exit} $(ts)"

  rm -f "${LOG_FILE}"
  exit "${final_exit}"
}

trap stop_heartbeat EXIT

main
