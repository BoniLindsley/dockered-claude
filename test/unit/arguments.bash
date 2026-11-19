# Tests of the launcher's argument parsing.
# test/run sources test/lib.bash first,
# which sets launcher and temporary_directory,
# and whose capture sets output, errors and status.
# shellcheck disable=SC2154

# shellcheck source=../../bin/dockered-claude
source -- "${launcher}" || return

# Declare, as globals of the test's subshell,
# the arrays that the launcher's main declares for parse_arguments.
reset_arguments() {
  set_launcher_paths
  declare -gA kwargs=()
  declare -ga args=() tools=() packages=() mounts=()
}

test_tools_accumulate_in_order() {
  reset_arguments
  capture parse_arguments --tool rclone -t uv
  assert_status 0
  assert_array tools rclone uv
  assert_equal 1 "${kwargs[tools_given]}"
}

test_no_tools_clears_the_tools_before_it() {
  reset_arguments
  capture parse_arguments --tool rclone --no-tools --tool uv
  assert_status 0
  assert_array tools uv
}

test_first_unknown_argument_starts_claude_arguments() {
  reset_arguments
  capture parse_arguments --tool uv -p 'fix it' --tool rclone
  assert_status 0
  assert_array tools uv
  assert_array args -p 'fix it' --tool rclone
}

test_double_dash_passes_the_rest_to_claude() {
  reset_arguments
  capture parse_arguments -- --help
  assert_status 0
  assert_array args --help
  assert_equal '' "${kwargs[help]:-}"
}

test_tool_requires_a_name() {
  reset_arguments
  capture parse_arguments --tool
  assert_status 1
  assert_contains "${errors}" '--tool requires a tool name'
}

test_invalid_tool_name_is_refused() {
  reset_arguments
  capture parse_arguments --tool ../escape
  assert_status 1
  assert_contains "${errors}" "invalid tool name '../escape'"
}

test_build_tool_sets_its_name() {
  reset_arguments
  capture parse_arguments --build-tool vcpkg
  assert_status 0
  assert_equal vcpkg "${kwargs[build_tool]}"
  assert_array tools
}

test_packages_accumulate() {
  reset_arguments
  capture parse_arguments --package libssl-dev --package g++
  assert_status 0
  assert_array packages libssl-dev g++
  assert_equal 1 "${kwargs[packages_given]}"
}

test_invalid_package_name_is_refused() {
  reset_arguments
  capture parse_arguments --package 'gcc;rm'
  assert_status 1
  assert_contains "${errors}" "invalid package name 'gcc;rm'"
}

test_mounts_keep_their_mode_suffix() {
  reset_arguments
  capture parse_arguments --mount ~/notes:rw -m ../library
  assert_status 0
  assert_array mounts ~/notes:rw ../library
}

test_mount_with_a_comma_is_refused() {
  reset_arguments
  capture parse_arguments --mount 'a,b'
  assert_status 1
  assert_contains "${errors}" "invalid mount 'a,b'"
}

test_no_mounts_clears_the_mounts_before_it() {
  reset_arguments
  capture parse_arguments --mount /srv --no-mounts
  assert_status 0
  assert_array mounts
  assert_equal 1 "${kwargs[mounts_given]}"
}

test_flags_are_set() {
  reset_arguments
  capture parse_arguments --build --no-save --list-tools -h
  assert_status 0
  assert_equal '1 1 1 1' \
    "${kwargs[build]} ${kwargs[no_save]} ${kwargs[list_tools]} ${kwargs[help]}"
}
