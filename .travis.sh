#!/bin/bash

set -eux -o pipefail

TEST_TARGET_ARCH=${TEST_TARGET_ARCH:-x86_64}
echo "--coverage_dir=${COVERAGE_DIR:-.cov}">.coverageopt
echo "--coverage_merge=${COVERAGE_MERGE:-true}">>.coverageopt
DMD=${DMD:-dmd}

dub test -a=${TEST_TARGET_ARCH} -b=unittest-cov -c=ut --compiler=${DMD}
dub test :stmtest -a=${TEST_TARGET_ARCH} -b=unittest-cov --compiler=${DMD}
