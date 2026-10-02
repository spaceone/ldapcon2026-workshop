#!/usr/bin/env bash
cd /opt/symas/ldap-load-gen
./run-load-tests.sh 1 1 5 10 symas T "checkUser,-Dverify=false:addGroup:addUser:assignGroup,-Dname=R1H1-1:checkUser,-Dname=R1H1-1,-Dverify=true,-Dsize=500:modUser:delUser:delGroup"