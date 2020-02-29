#!/bin/bash

set -eux -o pipefail

TEST_TARGET_ARCH=${TEST_TARGET_ARCH:-x86_64}
COVERAGE_DIR=${COVERAGE_DIR:-.cov}
COVERAGE_MERGE=${COVERAGE_MERGE:-true}
DMD=${DMD:-dmd}

dub test -a=${TEST_TARGET_ARCH} --coverage --compiler=${DMD}
dub test :stmtest -a=${TEST_TARGET_ARCH} --coverage --compiler=${DMD}
