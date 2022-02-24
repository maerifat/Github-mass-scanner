#!/bin/bash
QUERY="something"
URLFILE=${QUERY}_allurls.txt
USERSFILE=${QUERY}_users.txt
rm $URLFILE
TOTALCOUNT=`curl "https://github.com/search/count?q=$QUERY&type=code" -Ls \
-H "Cookie: user_session=9M328YcwZT-JNLrIkgRpIOxOvk7jrwtERf__5RwaMQkjKbCO"\
|egrep -o ">[0-9KMB]+"| tr -d "><" | sed 's/K/000/' |\
sed 's/M/000000/' | sed 's/B/000000000/'`
echo "$TOTALCOUNT total results found"
#payloads
RANGE=10000
FROMSIZE=0
LIMITSIZE=400000
#echo "$TOSIZE this is to size" 
FILESCOMPILED=0
#running Loop for filter
while [[ $TOTALCOUNT -gt $FILESCOMPILED && $TOSIZE -lt $LIMITSIZE ]]
do
TOSIZE=$(($FROMSIZE + $RANGE))
FILTER="size:$FROMSIZE..$TOSIZE"
declare -a payload_array
payload_array[0]="q=$QUERY+$FILTER&type=code&o=desc&s=indexed"
#payload_array[0]="q=$QUERY&type=code&l=html"
#payload_array[1]="q=$QUERY&o=desc&s=committer-date&type=Commits"
#running loop for payloads
for PAYLOAD in "${payload_array[@]}";
do
#echo "$PAYLOAD is being used"
#running script
COUNT=`curl "https://github.com/search/count?$PAYLOAD" -Ls \
-H "Cookie: user_session=9M328YcwZT-JNLrIkgRpIOxOvk7jrwtERf__5RwaMQkjKbCO"\
|egrep -o ">[0-9KMB]+"| tr -d "><" | sed 's/K/000/' |\
sed 's/M/000000/' | sed 's/B/000000000/'`
echo "$COUNT results found for payload $PAYLOAD"
PER_PAGE=10
if (($COUNT > 1000))
        then 
        PAGES=100
    elif ((COUNT % 10==0))
        then 
        PAGES=$(($COUNT / $PER_PAGE))
    else  
        PAGES=$(($COUNT / $PER_PAGE+1))
    fi
PAGE=0
while (($PAGE<$PAGES)) 
do
((PAGE++))
echo "Trying to fetch data for page no. $PAGE"
URLS=$(curl -s "https://github.com/search?p=$PAGE&$PAYLOAD" -H\
 "Cookie: user_session=9M328YcwZT-JNLrIkgRpIOxOvk7jrwtERf__5RwaMQkjKbCO" |\
egrep -oi "https://github[0-9A-Za-z/\._%-]+" | egrep "blob|commit"| sed 's/\/blob\//\/raw\//'|sort -u|\
awk '{if ($0 ~ /\/commit\//) sub(/$/,".patch"); print }' |\
tee -a $URLFILE )
TOFIND='github'
if grep "$TOFIND" <<< "$URLS"
then 
echo "yes it is there"
FAILED=0
else
echo "no, it is not there"
((PAGE--))
((FAILED++))
echo "It has failed $FAILED times, so sleeping"
for i in {10..0}; do echo -ne "$i\033[0K\r"; sleep 1; done; echo 
    if (($FAILED>10))
    then
    echo "exiting as it has failed too many times" 
    exit
    else
    echo ""
    fi
fi
done #ending pages loop
#echo "Task Finished for $PAYLOAD payload."
FILESCOMPILED=$(($FILESCOMPILED + $COUNT))
echo "$FILESCOMPILED files compiled out of $TOTALCOUNT."
echo " "
done #ending payload loop
FROMSIZE=$(($FROMSIZE + $RANGE))
done #ending size loop
echo " JOB DONE.. Good Bye.."
echo " "
### GATHERING USERS ###
echo "We are gathering the userlist."
echo "##############"
cat $URLFILE|cut -d "/" -f4 | tee -a $USERSFILE
sort -u -o $USERSFILE $USERSFILE
### SCANNING FILES ####
echo " "
echo " We are scanning your files."
echo "############### "
SCANNEDFILES=0
REPORTFILE=${QUERY}_${RANDOM}_dailyreport.txt
TOTALCOUNT=`wc -l $URLFILE| awk '{print $1}'`
for url in `cat $URLFILE`;
do
((SCANNEDFILES++))
echo -n "$SCANNEDFILES/$TOTALCOUNT "| tee -a $REPORTFILE
RESULT=`python3 SecretFinder.py -i $url -o cli |tee -a $REPORTFILE`
echo -n "$RESULT"
echo " "
done
