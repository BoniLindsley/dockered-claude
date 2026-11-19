# Tests of choosing a profile and naming its images.
# test/run sources test/lib.bash first,
# which sets launcher and temporary_directory,
# and whose capture sets output, errors and status.
# shellcheck disable=SC2154

# shellcheck source=../../bin/dockered-claude
source -- "${launcher}" || return

# Declare, as globals of the test's subshell,
# the state that select_profile reads,
# with the profiles default and minimal in a launcher directory
# in temporary_directory, and DOCKERED_CLAUDE_PROFILE unset.
reset_profiles() {
  set_launcher_paths
  declare -gA kwargs=() project_options=()
  project_directory="${temporary_directory}/launcher"
  mkdir -p -- "${project_directory}"/profiles/{default,minimal}
  : >"${project_directory}/profiles/default/Dockerfile"
  : >"${project_directory}/profiles/minimal/Dockerfile"
  unset DOCKERED_CLAUDE_PROFILE
}

test_selecting_defaults_to_the_default_profile() {
  reset_profiles
  capture select_profile
  assert_status 0
  assert_equal default "${profile}"
  assert_equal dockered-claude-default:latest "${image}"
  assert_equal "${image}" "${container_image}"
}

test_selecting_takes_the_environment_over_the_default() {
  reset_profiles
  DOCKERED_CLAUDE_PROFILE=minimal
  capture select_profile
  assert_status 0
  assert_equal dockered-claude-minimal:latest "${image}"
}

test_selecting_takes_the_configuration_over_the_environment() {
  reset_profiles
  DOCKERED_CLAUDE_PROFILE=default
  project_options[profile]=minimal
  capture select_profile
  assert_status 0
  assert_equal minimal "${profile}"
}

test_selecting_takes_the_option_over_the_configuration() {
  reset_profiles
  project_options[profile]=default
  kwargs[profile]=minimal
  capture select_profile
  assert_status 0
  assert_equal minimal "${profile}"
}

test_selecting_refuses_a_profile_without_a_dockerfile() {
  reset_profiles
  kwargs[profile]=missing
  capture select_profile
  assert_status 1
  assert_contains "${errors}" "no profile 'missing'"
}

test_selecting_refuses_an_invalid_name_from_the_environment() {
  reset_profiles
  DOCKERED_CLAUDE_PROFILE=../default
  capture select_profile
  assert_status 1
  assert_contains "${errors}" "invalid profile name '../default'"
}
