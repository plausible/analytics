#!/bin/sh
fail=false
while read l
do
  echo "$l"
  if echo "$l" | grep -qP '\[(warning|error)\]'
  then 
    fail=true; 
  fi
done

if [ $fail = true ]
then
  echo
  echo "💀 The tests are logging, please capture logs. See:"
  echo "  - https://hexdocs.pm/ex_unit/1.12/ExUnit.CaptureLog.html"
  echo "  - https://hexdocs.pm/ex_unit/1.12/ExUnit.Case.html#module-known-tags"
  echo
  exit 1
fi
