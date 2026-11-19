# Tests of the docker run arguments of Claude Code's container.
# test/run sources test/lib.bash first,
# which sets launcher and temporary_directory,
# and whose capture sets output, errors and status.
# shellcheck disable=SC2154

# shellcheck source=../../bin/dockered-claude
source -- "${launcher}" || return

# Declare, as globals of the test's subshell,
# the state that run_container's steps read and set,
# with the tools rclone and uv in a launcher directory
# in temporary_directory, uv with an env file,
# and docker answering only for the image's PATH.
reset_container() {
  set_launcher_paths
  declare -ga tools=() docker_args=() path_entries=()
  project_directory="${temporary_directory}/launcher"
  container_image=dockered-claude-default:latest
  mkdir -p -- "${project_directory}"/tools/{rclone,uv}
  : >"${project_directory}/tools/rclone/Dockerfile"
  : >"${project_directory}/tools/uv/Dockerfile"
  printf '%s\n' 'UV_CACHE_DIR=/tmp/uv' >"${project_directory}/tools/uv/env"
  # shellcheck disable=SC2329 # Called by add_path_argument.
  docker() {
    [[ "$1 $2" == 'image inspect' ]] || return 1
    printf '%s\n' 'HOME=/home/claude' 'PATH=/usr/local/bin:/usr/bin'
  }
}

test_tools_go_in_front_of_the_image_path_in_order() {
  reset_container
  tools=(uv rclone)
  capture add_tool_arguments
  assert_status 0
  capture add_path_argument
  assert_status 0
  assert_array docker_args \
    --mount type=volume,src=dockered-claude-tool-uv,dst=/opt/tools/uv,readonly \
    --mount type=volume,src=dockered-claude-tool-rclone,dst=/opt/tools/rclone,readonly \
    --env-file "${project_directory}/tools/uv/env" \
    --env PATH=/opt/tools/uv/bin:/opt/tools/rclone/bin:/usr/local/bin:/usr/bin
}

test_without_path_entries_the_image_path_is_kept() {
  reset_container
  capture add_path_argument
  assert_status 0
  assert_array docker_args
}

test_profile_variables_are_passed_and_its_path_follows_the_tools() {
  reset_container
  tools=(uv)
  declare -ga profile_variables=(SDK_HOME) profile_path_entries=(/opt/sdk/bin)
  capture add_tool_arguments
  assert_status 0
  capture add_profile_arguments
  assert_status 0
  capture add_path_argument
  assert_status 0
  assert_array docker_args \
    --mount type=volume,src=dockered-claude-tool-uv,dst=/opt/tools/uv,readonly \
    --env-file "${project_directory}/tools/uv/env" \
    --env SDK_HOME \
    --env PATH=/opt/tools/uv/bin:/opt/sdk/bin:/usr/local/bin:/usr/bin
}
