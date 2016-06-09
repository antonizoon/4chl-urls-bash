#!/bin/bash

echo -e "\n"
BASE_URL="http://a.4cdn.org"

CWD=`pwd`
BASE_DIR="$CWD/4chandata"
JSON_DIR="$BASE_DIR/json"

DELAY=0.25



if [[ ! -d $BASE_DIR ]]
    then
    mkdir $BASE_DIR
fi
rm -R $JSON_DIR/*
if [[ ! -d $JSON_DIR ]]
    then
    mkdir $JSON_DIR
fi

curl $BASE_URL/boards.json | jq . > $JSON_DIR/boards.json
BOARDS_KEYS=(`cat $JSON_DIR/boards.json | jq .boards | jq "keys" | sed "s/,/ /g" | sed "s/\[//g" | sed "s/\]//g" | sed "s/  //g" | sed "s/\n//g"`)
for BKEY in "${BOARDS_KEYS[@]}"
    do
    cat $JSON_DIR/boards.json | jq .boards[$BKEY].board | sed "s/\"//g"
    cat $JSON_DIR/boards.json | jq .boards[$BKEY].board | sed "s/\"//g" >> $BASE_DIR/boards.txt
done

BOARDS=`cat $BASE_DIR/boards.txt | sed "s/\n/ /g"`
BOARDS=(`echo $BOARDS`)
for BOARD in "${BOARDS[@]}"
    do
    if [[ ! -d $JSON_DIR/$BOARD ]]
        then
        mkdir $JSON_DIR/$BOARD
    fi
    curl $BASE_URL/$BOARD/threads.json | jq . > $JSON_DIR/$BOARD/threads.json
    sleep $DELAY
done

for BOARD in "${BOARDS[@]}"
    do
    PAGE_KEYS=(`cat $JSON_DIR/$BOARD/threads.json | jq "keys" | sed "s/,/ /g" | sed "s/\[//g" | sed "s/\]//g" | sed "s/  //g" | sed "s/\n//g"`)
    if [[ ! -d $JSON_DIR/$BOARD/threads ]]
            then
            mkdir $JSON_DIR/$BOARD/threads
    fi
    for PKEY in "${PAGE_KEYS[@]}"
        do
        cat $JSON_DIR/$BOARD/threads.json | jq .[$PKEY].threads | sed "s/\[//g" | sed "s/\]//g" >> $JSON_DIR/$BOARD/threads.txt
        
    done
    THREAD_KEYS=`cat $JSON_DIR/$BOARD/threads.txt | egrep -o "\"no\": [0-9]+," | egrep -o "[0-9]+"`
    echo $THREAD_KEYS
    THREAD_KEYS=(`echo $THREAD_KEYS | sed "s/\n/ /g"`)
    for THREAD in "${THREAD_KEYS[@]}"
        do
        echo $THREAD
        
        curl $BASE_URL/$BOARD/thread/$THREAD.json | jq . > $JSON_DIR/$BOARD/threads/$THREAD.json
    done
    sleep $DELAY
done

# regex extract links using url regex
REGEX="((([0-9a-z_-]+\.)+(aero|asia|biz|cat|com|coop|edu|gov|info|int|jobs|mil|mobi|museum|name|net|org|pro|tel|travel|ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cu|cv|cx|cy|cz|cz|de|dj|dk|dm|do|dz|ec|ee|eg|er|es|et|eu|fi|fj|fk|fm|fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mn|mn|mo|mp|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|nom|pa|pe|pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ra|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|si|sj|sj|sk|sl|sm|sn|so|sr|st|su|sv|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|yu|za|zm|zw|arpa)(:[0-9]+)?((\/([~0-9a-zA-Z\#\+\%@=\?\.\/\(\)_-]+))?((\/([~0-9a-zA-Z\#\+\%@=\?\.\(\)\/_-]+)+)?)?)))[ \"]"
cat $JSON_DIR/**/threads/*.json | egrep -o "$REGEX" >> ./urls.txt

# dedupe links and sort
sort -u urls.txt >> $BASE_DIR/urls.txt
sed 's/[\" ]//' $BASE_DIR/urls.txt | sed 's/\\//' > ./urls.txt
sort -u ./urls.txt > $BASE_DIR/urls.txt

# filter list
FILTERS=(`cat $BASE_DIR/ignores.txt | sed "s/\n/ /g"`)
for FILTER in "${FILTERS[@]}"
    do
    sed -i.bak "/$FILTER/d" $BASE_DIR/urls.txt
done
cp $BASE_DIR/urls.txt ./urls.txt

# check all links for status and split 404 links to another files
# (could be an error or could be useful to find as archive.org pages)
