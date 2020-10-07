#!/bin/sh
SCRIPT_DIR=$(dirname $0)

echo "Running: git submodule update --init --recursive ${EPAGE_GIT_SUBMODULE_PARAMS} -- $SCRIPT_DIR/mupdfdk/mupdf"
time git submodule update --init --recursive ${EPAGE_GIT_SUBMODULE_PARAMS} -- $SCRIPT_DIR/mupdfdk/mupdf

make -C $SCRIPT_DIR/mupdfdk/mupdf generate
