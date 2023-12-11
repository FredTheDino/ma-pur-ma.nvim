#!/usr/bin/env bash
pushd $(dirname $0) > /dev/null
NUM=$(find . -name "run.sh" | wc -l )
echo "Found $NUM tests"

PASS=1
for T in $(find . -name "run.sh");
do
  echo $(dirname $T)
  pushd $(dirname $T) > /dev/null
  bash run.sh
  S=$?
  if [[ $S == 0 ]]
  then
    echo "$(dirname $T) PASS"
  else
    echo "$(dirname $T) FAIL"
    PASS=0
  fi
  echo ""
  popd > /dev/null
done
if [[ $PASS ]]
then
  echo "All looks good!"
else
  echo "Tests failed"
  exit 1
fi
popd > /dev/null
