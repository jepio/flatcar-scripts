#!/bin/bash

# Copyright (c) 2009 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Load common constants.  This should be the first executable line.
# The path to common.sh should be relative to your script's location.
. "$(dirname "$0")/common.sh"

# Script must be run inside the chroot
restart_in_chroot_if_needed $*
get_default_board

# Flags
DEFINE_string build_root "$DEFAULT_BUILD_ROOT" \
  "Root of build output"
DEFINE_string board "$DEFAULT_BOARD" \
  "Target board of which tests were built"

# Parse command line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"

# Run tests
if [ -z "$FLAGS_board" ]; then
  echo Error: --board required
  exit 1
fi

TESTS_DIR="/build/${FLAGS_board}/tests"
LD_LIBRARY_PATH=/build/${FLAGS_board}/lib:/build/${FLAGS_board}/usr/lib:\
/build/${FLAGS_board}/usr/lib/gcc/i686-pc-linux-gnu/4.4.1/:\
/build/${FLAGS_board}/usr/lib/opengl/xorg-x11/lib

# Die on error; print commands
set -ex

# Change to a test directory to make it easier for tests to write
# to and clean up temporary files.
TEST_CWD=$(mktemp -d /tmp/run_tests.XXXX)
cd $TEST_CWD

function cleanup() {
  cd -
  rm -rf $TEST_CWD
  trap - 0
}

trap cleanup ERR 0

# NOTE: We currently skip cryptohome_tests (which happens to have a different
# suffix than the other tests), because it doesn't work.
# NOTE: Removed explicit use of the target board's ld-linux.so.2 so that this
# will work on hardened builds (with PIE on by default).  Tests pass on
# hardened and non-hardened builds without this explicit use, but we only
# disable this on hardened, since that is where the PIE conflict happens.
for i in ${TESTS_DIR}/*_{test,unittests}; do
  if [[ "`file -b $i`" = "POSIX shell script text executable" ]]; then
    if [[ -f /etc/hardened ]]; then
      LD_LIBRARY_PATH=$LD_LIBRARY_PATH /build/${FLAGS_board}/bin/bash $i
    else
      LD_LIBRARY_PATH=$LD_LIBRARY_PATH /build/${FLAGS_board}/lib/ld-linux.so.2 /build/${FLAGS_board}/bin/bash $i
    fi
  else
    if [[ -f /etc/hardened ]]; then
      LD_LIBRARY_PATH=$LD_LIBRARY_PATH $i
    else
      LD_LIBRARY_PATH=$LD_LIBRARY_PATH /build/${FLAGS_board}/lib/ld-linux.so.2 $i
    fi
  fi
done


