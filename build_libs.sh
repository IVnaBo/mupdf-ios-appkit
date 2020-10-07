#!/bin/bash

set -eo pipefail

# Call this script from a "Run Script" target in the Xcode project to
# cross compile MuPDF and third party libraries using the regular Makefile.
# Also see "iOS" section in Makerules.

echo pwd: $(pwd)
MUPDF_PATH=$(dirname $0)/mupdfdk/mupdf

if [ ! -e ${MUPDF_PATH}/generated/resources/fonts/droid/DroidSansFallback.ttf.c ]
then
  echo 'ERROR: You are missing the generated files.'
  echo 'ERROR: Please run "make generate" from the mupdf directory.'
  exit 1
fi

OS=ios
build=$(echo $CONFIGURATION | tr 'A-Z ' 'a-z-')

FLAGS="-Wno-unused-function -Wno-empty-body -Wno-implicit-function-declaration"
for A in $ARCHS
do
  FLAGS="$FLAGS -arch $A"
done

FLAGS="$FLAGS -fembed-bitcode"

# These make it easy to navigate to the location of an error/warning in Xcode
FLAGS="$FLAGS -fdiagnostics-print-source-range-info"
FLAGS="$FLAGS -fdiagnostics-show-category=id"
FLAGS="$FLAGS -fdiagnostics-parseable-fixits"
FLAGS="$FLAGS -fdiagnostics-absolute-paths"

FLAGS="$FLAGS -DTOFU -DTOFU_CJK"

OUT=build/$build-$OS-$(echo $ARCHS | tr ' ' '-')

echo "Compiling libraries for $ARCHS as '$build'"
if [ "$build" = 'fortify-debug' ]; then
  build='memento'
fi
set +e
export build OS
make -j1 -C ${MUPDF_PATH} OUT=$OUT XCFLAGS="$FLAGS" XLDFLAGS="$FLAGS" third libs
retval=$?
set -e
if [ $retval -ne 0 ]; then
  echo "error: calling make for mupdf failed"
  exit 1
fi

echo Copying library to $BUILT_PRODUCTS_DIR/.
mkdir -p "$BUILT_PRODUCTS_DIR"
cp -f ${MUPDF_PATH}/$OUT/lib*.a "$BUILT_PRODUCTS_DIR"
ranlib "$BUILT_PRODUCTS_DIR"/lib*.a

if [ "${EXECUTABLE_NAME}" = "mupdfdk" ]; then
  echo "Building mupdfdk, skipping duplicate symbol check as there's no smartoffice library to check against"
  exit 0
fi

echo Checking for duplicate symbols

nm -g -U "$BUILT_PRODUCTS_DIR"/lib*.a | egrep ' [TS] ' | awk '{print $3}' | sort | uniq > mupdf-symbols.txt
nm -g -U ./sodk/smart-office-lib.a | grep ' [TS] ' | awk '{print $3}' | sort | uniq > smartoffice-symbols.txt
DUPLICATES=`cat smartoffice-symbols.txt mupdf-symbols.txt | sort | uniq -d`
for i in $DUPLICATES; do
  echo "error: duplicate symbol found in both mupdf and smartoffice: $i"
done
if [ -n "$DUPLICATES" ]; then
  echo "error: duplicate symbols found, aborting build"
  exit 1
fi

echo Done.
