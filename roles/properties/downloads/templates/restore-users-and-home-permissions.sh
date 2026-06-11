#!/bin/bash

for i in `cat /local/systems/home/system-users.txt`; do
    useradd $i
    chown -R $i:$i /home/$i
done
