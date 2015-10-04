#!/bin/bash

for i in "1" "5" "6" "7" "8" "9" "11" "13" "14" "16" "18" "19" "20" "21"; 
do 
	./Micro ./testcases/input/test$i.micro > ./outputs/test$1.out

	diff -b -B ./outputs/test$i.out ./testcases/output/test$i.out > /dev/null

done

echo "Done testing"
