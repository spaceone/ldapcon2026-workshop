#!/bin/bash

# This bash script executes load-load-gen jmeter tests.
# example invocation:
# H1:
#./run-load-tests.sh 1 1 5 20 symas T "addGroup:addUser:assignGroup,-Dname=load01-R1H1-1:checkUser,-Dname=load01-R1H1-1,-Dverify=true,-Dbind=true,-Dreverselookup=true:delUser:delGroup"
# H2:
#./run-load-tests.sh 2 1 5 20 symas T "addGroup:addUser:assignGroup,-Dname=load01-R1H2-1:checkUser,-Dname=load01-R1H2-1,-Dverify=true,-Dbind=true,-Dreverselookup=false:delUser:delGroup"
# Here, it repeats the set of operations 20 times ($4), using qualifier host#1 ($1) starting at 1 ($2) and ending at 5 ($2 + $3).
# qualifiers: hostname-R1H1-nnn, hostname-R1H2-nnn, hostname-R1H3-nnn, hostname-R1H4-nnn, hostname-R1H5-nnn
# It perform ops ($7) addGroup,addUser,assignGroup,... Some operations have extra args, e.g. -Dname=load01-R1H2-1
# PKG arg ($5) symas or openldap, correspond with the location of the ldap-load-gen package.

# Global constants:
HOSTNUM=$1
START=$2
COUNT=$3
REPEAT=$4
PKG=$5
CLEAN=$6
OPS=$7

get_jmeter_ops () {
  #Split the string based on the delimiter, :
  readarray -d : -t opsarr <<< "$OPS"
  numops="${#opsarr[*]}"
  #echo "numopts=$numopts"
}

get_jmeter_args () {
  opt="${opsarr[j]}"
  #echo "opt$j=$opt"
  # The jmeter arguments are comma separated
  readarray -d , -t argarr <<< "$opt"
  #op="${argarr[0]:0:1}"
  op="${argarr[0]}"
  numargs="${#argarr[*]}"
  #echo "op=$op numargs=$numargs"
  # The jmeter arguments for the specified test, e.g. -Dduplicate:
  for (( k=1; k < $numargs; k++))
  do
    arg="${argarr[k]}"
    if [ -n "$arg" ]
    then
      args+="$arg "
    fi
  done
}

if [ "$PKG" != 'symas' ]; then
  cd /usr/local/ldap-load-gen
  echo "cd /usr/local/ldap-load-gen"
else
  cd /opt/symas/ldap-load-gen
  echo "cd /opt/symas/ldap-load-gen"
fi

echo "*** PERFORM run-load-tests.sh HOSTNUM:$HOSTNUM START:$START COUNT:$COUNT REPEAT:$REPEAT PKG:$PKG CLEAN:$CLEAN OPS:$OPS"
start=$(date +%s)
let "END = ( $START + $COUNT ) - 1"

if [ "$CLEAN" == 'T' ]; then
  echo "Do a clean..."
  mvn clean
fi

# Main control loop:
echo "*** PERFORM $OPS $REPEAT times..."
for (( i=0; i<"$REPEAT"; i++ ))
do
mvn clean -Pload -DskipTests package
  echo "*** OUTER LOOP i:$i ***"
  get_jmeter_ops
  # Iterate over the operations passed in, A, U, D, etc ...
  for (( j=0; j < $numops; j++))
  do
    args=''
    type=''
    get_jmeter_args
    echo "args=$args"
    echo "*** INNER LOOP j:${j} op:$op"
    echo "*** HOST $HOSTNUM Do $COUNT $type..."
    # Do the operation, e.g. A, multiple times
    for (( k=$START; k<="$END"; k++ ))
    do
      end=$(date +%s)
      echo "*** LOOP outer: $i, inner: $k, elapsed time: $(($end-$start)) seconds ***"
      echo "*** mvn -Pload -Dtype=${op} -Dqualifier=R${k}H${HOSTNUM} $args"
      mvn verify -Pload -Dtype=${op} -Dqualifier=R${k}H${HOSTNUM} $args
    done
  done
done

echo "host$HOSTNUM: finish"