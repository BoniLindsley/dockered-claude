# Tests of what each command does, with Docker and builds replaced.
# test/run sources test/lib.bash first,
# which sets launcher and temporary_directory,
# and whose capture sets output, errors and status.
# shellcheck disable=SC2154

# shellcheck source=../../bin/dockered-claude
source -- "${launcher}" || return

# Declare, as globals of the test's subshell,
# the arrays that the launcher's main declares,
# with the launcher's directory and HOME in temporary_directory,
# and calls set to a file where replaced functions record their calls.
reset_commands() {
  set_launcher_paths
  declare -gA kwargs=()
  declare -ga args=() tools=() packages=() mounts=()
  project_directory="${temporary_directory}/launcher"
  HOME="${temporary_directory}/home"
  calls="${temporary_directory}/calls"
  mkdir -p -- "${project_directory}" "${HOME}"
  : >"${calls}"
  cd -- "${HOME}" || return
}

# Record a call to the function that calls this, with its arguments.
record_call() {
  printf '%s\n' "${FUNCNAME[1]}${*:+ $*}" >>"${calls}"
}

test_tool_list_shows_which_tools_are_built() {
  reset_commands
  mkdir -p -- "${project_directory}"/tools/{built,missing,empty}
  : >"${project_directory}/tools/built/Dockerfile"
  : >"${project_directory}/tools/missing/Dockerfile"
  # shellcheck disable=SC2329 # Called by list_tools.
  docker() {
    [[ "$*" == 'volume inspect dockered-claude-tool-built' ]]
  }
  parse_arguments tool list
  capture run
  assert_status 0
  assert_equal $'built\nmissing (not built)' "${output}"
}

test_tool_build_builds_each_tool_without_the_cache() {
  reset_commands
  # shellcheck disable=SC2329 # Called by run.
  ensure_image() { record_call; }
  # shellcheck disable=SC2329 # Called by run.
  build_tool_volume() { record_call "$@"; }
  parse_arguments tool build vcpkg uv
  capture run
  assert_status 0
  assert_file "${calls}" $'ensure_image\nbuild_tool_volume vcpkg refresh\nbuild_tool_volume uv refresh'
}

test_build_rebuilds_the_image_and_the_saved_packages() {
  reset_commands
  mkdir -p -- "${HOME}/project/.meta/dockered-claude"
  printf '%s\n' 'packages = gdb libssl-dev' \
    >"${HOME}/project/.meta/dockered-claude/config"
  cd -- "${HOME}/project" || return
  # shellcheck disable=SC2329 # Called by build_images.
  build_image() { record_call; }
  # shellcheck disable=SC2329 # Called by build_images.
  ensure_packages_image() { record_call "${packages[@]}"; }
  parse_arguments build
  capture run
  assert_status 0
  assert_file "${calls}" $'build_image\nensure_packages_image gdb libssl-dev'
}

# Answer the docker calls of ensure_packages_image
# as if the packages image was built from the current base image.
docker_with_current_packages_image() {
  case "$*" in
  'image inspect --format {{.Id}} '*) printf 'sha256:base\n' ;;
  'image inspect --format {{index .Config.Labels '*) printf 'sha256:base\n' ;;
  build\ *) printf 'docker build\n' >>"${calls}" ;;
  *) return 1 ;;
  esac
}

test_running_keeps_a_current_packages_image() {
  reset_commands
  image=dockered-claude:latest
  packages=(gdb)
  kwargs[command]=run
  # shellcheck disable=SC2329 # Called by ensure_packages_image.
  docker() { docker_with_current_packages_image "$@"; }
  capture ensure_packages_image
  assert_status 0
  assert_file "${calls}" ''
  assert_contains "${container_image}" 'dockered-claude:packages-'
}

test_build_rebuilds_a_current_packages_image() {
  reset_commands
  image=dockered-claude:latest
  packages=(gdb)
  kwargs[command]=build
  # shellcheck disable=SC2329 # Called by ensure_packages_image.
  docker() { docker_with_current_packages_image "$@"; }
  capture ensure_packages_image
  assert_status 0
  assert_file "${calls}" 'docker build'
}
