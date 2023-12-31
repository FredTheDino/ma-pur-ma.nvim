#!/usr/bin/env bash
pushd $(dirname $0) > /dev/null
NUM=$(find . -name "run.sh" | wc -l )
echo "Found $NUM tests"

PASS=1
for T in $(find . -name "test.nvim");
do
  echo $(dirname $T)
  pushd $(dirname $T) > /dev/null
  nvim src.purs --headless -S test.nvim -c "saveas! gen.purs" -c "q"
  echo ""
  diff --color out.purs gen.purs
  S=$?
  if [[ $S == 0 ]]
  then
    rm -f gen.purs
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
