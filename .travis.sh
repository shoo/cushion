#!/bin/bash

function if_error_exit() {
    exit 1
}

dub test --arch=$ARCH || if_error_exit
dub test :stmtest --arch=$ARCH || if_error_exit
