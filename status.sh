#!/bin/bash
# Status update service.
# Part of BuildDroid.
# https://github.com/wojtekojtek/builddroid

echo $$ > pid2
while true; do
    cat build.log | grep "\[ [0-9].*" | tail -n 1 > status
    sleep 0.1
done
