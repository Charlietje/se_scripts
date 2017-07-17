#!/bin/bash

function usage {
    cat << EOF
usage: counter -l logfile -d day -h hour [-g [grep|bot|grepbot|ip]] [-f] [-a]
  -l                         access/access.gz log file. Default access.log.
  -d                         day of examine (ex. 30/apr). Default is first entry of the log.
  -h                         hour/minute to examine (ex: -h 16 or -h 16:10). Use -h all for all day.
  -g "grep [string]" -f      will grep log entries of given day and hour. Without -f will only show numbers.
  -g "bot [name-of-bot]"     will show how many bots/crawlers/spiders are in the log file.
  -g "grepbot [name-of-bot]" will grep all bots/crawlers/spiders.
  -g "ip [ip]"               will show how many times an ip occurs in the log file.
                             IP is optional ex. -g ip "84.198.51.10|10.10.10.10".
                             whith option -f, it will show the top 10 IP's.
  -f                         will format the lines to width of terminal
  -a                         calculate all requests (including js|css|jpg|jpeg|gif|png|bmp|ico)
  -b                         size of bar (default 2)

example: counter.sh -l accesslog -d 11/May -h 14 -g grepbot -f
         counter.sh -l accesslog -d 11/May -h all -g "ip 10.10.10.10" -a
         counter.sh -l accesslog -d 11/May -h 14 -g "bot semrush"
         counter.sh -l accesslog -d 11/May -h 14 -g "grep 46.4.32.75"

EOF
exit 1
}




#draw bar
function BAR {
    div=${DIV:-2}
    if [ $div -ne 0 ];then
        if [ $# -eq 2 ]; then
            col=$(( $(( $1 + 1 )) / $div ))
            tot=$(( $(( $2 + 1 )) / $div ))
        else
            col=0
            tot=$(( $(( $1 + 1 )) / $div ))
        fi

        for bar in $(seq 1 $tot); do
            if [ $bar -lt $col ]; then
                echo -n "≡"
                # echo -n "█"
            else
                # echo -n "═"
                echo -n "="
            fi
        done
    fi
    echo

}

#function to count requests
function WCL {
    echo -ne "\e[1m$HOUR:$i\e[21m\t"
    # echo -ne "$(echo "$PARSE" | grep "$YEAR:$HOUR:$i" | wc -l)\t"
    CNT="$(echo "$PARSE" | grep -ac "$YEAR:$HOUR:$i")"
    printf "%03d\t" "$CNT"
    if [ "$IP" = "" ]; then
        BAR $CNT
    fi
}



#function to parse the log
function PARSE_LOG {
    if [ "$P" -eq 0 ]; then
        PARSE=$($CAT "$LOG" | grep -ai "$DAY/$YEAR:$HOUR" | egrep -v "js|css|jpg|jpeg|gif|png|bmp|ico|$IGNORE_IP")
    else
        PARSE=$($CAT "$LOG" | grep -ai "$DAY/$YEAR:$HOUR")
    fi


    for i in {00..59}; do
        case "$GREP" in
            "grep")
                WCL
                echo -ne "$IP: "
                GIP=$(echo "$PARSE" | grep -a "$YEAR:$HOUR:$i" | egrep -a -c -i "$IP")
                echo -ne "$GIP\t"
                BAR $GIP $CNT
                echo -ne "\e[0m"
                if [ "$F" == 10 ]; then
                    echo "$PARSE" | grep -a "$YEAR:$HOUR:$i" | egrep -a -i "$IP"
                fi
                #echo
                ;;

            "bot")
                if [[ "$IP" == "" ]]; then
                    IP="bot|crawler|spider"
                fi
                WCL
                echo -ne "bots:\t"
                GIP=$(echo "$PARSE" | grep -a "$YEAR:$HOUR:$i" | egrep -aci "$IP")
                printf "%03d\t" $GIP
                BAR $GIP $CNT
                ;;

            "grepbot")
                if [[ "$IP" == "" ]]; then
                    IP="bot|crawler|spider"
                fi
                WCL
                echo
                echo "$PARSE" | grep -a "$YEAR:$HOUR:$i" | egrep -ai "$IP" | $FORMAT
                echo
                ;;

            "ip")
                WCL
                x=$(echo "$PARSE" | grep -a "$YEAR:$HOUR:$i" | awk '{ print $1 }' | egrep -a "\b$IP\b" | sort | uniq -c | sort -t 1 -n -r  | head -n "$F")
                if [ "$IP" != "" ]; then
                    if [ "$x" == "" ]; then
                        echo -ne "0\t"
                        BAR $CNT
                    else
                        GIP=$(echo "$x" | awk -v OFS=' ' '{ print $1 }')
                        echo -ne "$GIP\t"
                        BAR $GIP $CNT
                    fi
                else
                    echo "$x"
                    echo
                fi
                ;;

            *)
                WCL
                # echo
                ;;
        esac

    done
}




#Check options
if [ $# -eq 0 ]; then
    usage
fi

CAT=$(which cat)
WIDTH=$(stty size | cut -d' ' -f2)
FORMAT="tee"
YEAR=$(date +%Y)
DAY=$(date +%d/%b)
LOG=access.log
HOUR=00
IP=""
IGNORE_IP="5.134.1.202"   # CloudStar monitoring
P=0           # Parse variable (all or filtered)
F=99          # Format variable



while getopts l:d:h:g:b:fa option; do
    case "${option}" in
        l) LOG=${OPTARG}
            if file "$LOG" | grep gzip &>/dev/null ; then
                CAT=$(which zcat)
                DAY=$($CAT "$LOG" | head -n1 | awk '{ print $4 }' | tr -d '[' | cut -c 1-6)
            else
                DAY=$(head -n1 "$LOG" | awk '{ print $4 }' | tr -d '[' | cut -c 1-6)
            fi ;;
        d) DAY=${OPTARG};;
        h) HOUR=${OPTARG};;
        g) ARRAY=($OPTARG); GREP=${ARRAY[0]}; IP=${ARRAY[1]};;
        f) FORMAT="cut -c1-$WIDTH"; F=10;;
        b) DIV=${OPTARG};;
        a) P=1;;
    esac
done


echo -ne "running: counter.sh -l $LOG -d $DAY -h $HOUR -g \"${ARRAY[*]}\" "
if [[ $P -eq 1 ]]; then echo -ne "-a "; fi
if [[ $F -eq 10 ]]; then echo -ne "-f "; fi
echo


if [ "$HOUR" == "all" ]; then
    HOURB="00"
    HOURE="23"
    $CAT "$LOG" | grep -ai "$DAY/$YEAR:" > /tmp/tmp.$$
    LOG=/tmp/tmp.$$
    CAT=$(which cat)
    for HOUR in $(seq -f "%02g" $HOURB $HOURE); do
        PARSE_LOG
    done
    rm $LOG
else
    re='^[0-9:]+$'
    if ! [[ $HOUR =~ $re ]] ; then
        echo "error: Hour is not a valid number" >&2; exit 1
    fi
    PARSE_LOG
fi



exit
