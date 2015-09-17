#!/bin/bash

for i in {1..21}; 
do 
	./build/Micro ./testcases/input/test$i.micro > ./outputs/test$i.out
	let "line_num = $?"
	diff -b -B ./outputs/test$i.out ./testcases/output/test$i.out > /dev/null
	if (($? != 0)); then
		echo "failed test: " $i " line #" $line_num
	fi  
done

echo "Done testing"
