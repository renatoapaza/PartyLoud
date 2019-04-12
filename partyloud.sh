#!/usr/bin/env bash

# Globals
readonly BW="$(cat badwords)"
readonly BW_S="$(wc -l < badwords)"

# UI FUNCTION
logo() {
cat << 'EOF'

  ___          _        _                _
 | _ \__ _ _ _| |_ _  _| |   ___ _  _ __| |
 |  _/ _` | '_|  _| || | |__/ _ \ || / _` |
 |_| \__,_|_|  \__|\_, |____\___/\_,_\__,_|
                   |__/        Coded by THO


A simple tool to do several http request and
simulate navigation

17/03/2019

EOF
}

DisplayHelp() {
    cat << 'EOF'
==================[ HELP ]==================

  do not overthink, just run it this way :

       ./partyloud.sh [# of threads]

      # of threads must be 0 < x < 25
EOF
}

center() {
    columns=80
    printf "%*s" "$(( (${#1} - columns) / 2))"
    echo -ne "$1"
}

clearLines() {
    for ((x=1; x<="$1"; x++)); do
        if [ "$x" != "$1" ]
        then
            echo -ne "\e[1A"
        fi
        echo -ne "\033[2K\r"
    done
}

progress() {
    clearLines 1
    if [ $# == 2 ]
    then
        echo -ne "$1 [$2]"
    else
        echo -ne "$1"
    fi
}

generateUserAgent() {
    local -r WIN=( "10.0"  # Win10
                   "6.3"   # Win 8.1
                   "6.2"   # Win 8
                   "6.1" ) # Win 7

    local -r MAC=( "10_14" "10_14_1" "10_14_2" "10_14_3"
                   "10_14_4" "10_14_5" "10_14_6"         # Mojave
                   "10_13" "10_13_1" "10_13_2" "10_13_3"
                   "10_13_4" "10_13_5" "10_13_6"         # High Sierra
                   "10_12" "10_12_1" "10_12_2" "10_12_3"
                   "10_12_4" "10_12_5" "10_12_6"         # Sierra
                   "10_11" "10_11_1" "10_11_2" "10_11_3"
                   "10_11_4" "10_11_5" "10_11_6")        # El Capitan

    local UserAgent="Mozilla/5.0 "

    local OS="$(( RANDOM % 3 + 1 ))"
    local -r bit="$(( RANDOM % 2 ))"

    if [ "${OS}" == 1 ]
    then
        # Windows
        OS="${WIN[$(( RANDOM % ${#WIN[@]} ))]}"
        if [ "${bit}" == 0 ]
        then
            # 32bit
            UserAgent+="(Windows NT $OS"
        else
            # 64bit
            UserAgent+="(Windows NT $OS; Win64; x64"
        fi
    elif [ "${OS}" == 2 ]
    then
        # MacOS
        OS="${MAC[$(( RANDOM % ${#MAC[@]} ))]}"
        UserAgent+="(Macintosh; Intel Mac OS X $OS"
    else
        # Linux
        if [ "${bit}" == 0 ]
        then
            # 32bit
            UserAgent+="(X11; Linux i686"
        else
            # 64bit
            UserAgent+="(X11; Linux x86_64"
        fi
    fi

    local -r Browser="$(( RANDOM % 2 ))"
    local VER=""

    if [ "${Browser}" == 1 ]
    then
        # Firefox
        readonly FF=( "50.0" "50.0.1" "50.0.2" "50.1.0"
                      "51.0" "51.0.1" "51.0.2" "51.0.3"
                      "52.0" "52.0.1" "52.0.2"
                      "53.0" "53.0.1" "53.0.2" "53.0.3"
                      "54.0" "54.0.1"
                      "55.0" "55.0.1" "55.0.2" "55.0.3"
                      "56.0" "56.0.1" "56.0.2"
                      "57.0" "57.0.1" "57.0.2" "57.0.3" "57.0.4"
                      "58.0" "58.0.1" "58.0.2"
                      "59.0" "59.0.1" "59.0.2" "59.0.3"
                      "60.0" "60.0.1" "60.0.2"
                      "61.0" "61.0.1" "61.0.2"
                      "62.0" "62.0.1" "62.0.2" "62.0.3"
                      "63.0" "63.0.1" "63.0.2" "63.0.3"
                      "64.0" "64.0.1" "64.0.2"
                      "65.0" "65.0.1" "65.0.2"
                      "66.0" )
        VER="${FF[$(( RANDOM % ${#FF[@]} ))]}"
        UserAgent+="; rv:${VER}) Gecko/20100101 Firefox/${VER}"
    else
        # Chrome
        readonly CH=( "56.0.2924" "57.0.2987" "58.0.3029"
                      "59.0.3071" "60.0.3112" "61.0.3163"
                      "62.0.3202" "63.0.3239" "64.0.3282"
                      "65.0.3325" "66.0.3359" "67.0.3396"
                      "68.0.3440" "69.0.3497" "70.0.3538"
                      "71.0.3578" "72.0.3626" "73.0.3683" )
        VER="${CH[$(( RANDOM % ${#CH[@]} ))]}"
        UserAgent+=") AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${VER} Safari/537.36"
    fi

    echo "${UserAgent}"
}

getLock() {
    while ! mkdir /tmp/partyloud.lock 2>/dev/null
    do
        sleep 0.2
    done
}

freeLock() {
    rm -fr /tmp/partyloud.lock
}


stop() {
    for PID in ${PIDS[@]};
    do
        progress "[+] Terminating HTTP Engines ..." "pid: ${PID}"
        kill -9 "$PID"
        wait "$PID" 2>/dev/null
    done
}

filter() {
    local URLS="${1}"
    if [[ "${URLS}" != "" ]]
    then
        for FILTER in ${BW[@]};
        do
            URLS="$(grep -iv "${FILTER}" <<< "${URLS}")"
        done
    fi
    echo "${URLS}"
}

SWCheck() {
    local -r SW=( "echo"
                  "curl"
                  "grep"
                  "sed"
                  "awk"
                  "wc"
                  "sort"
                  "uniq"
                  "kill"
                  "wait"
                  "rm"
                  "mkdir"
                  "printf"
                )
    for COMMAND in ${SW[@]};
    do
        if [ $TEST == true ]
        then
            if [[ $(command -v "$COMMAND") ]]
            then
                tput bold
                echo "[+] $COMMAND Found!"
                tput sgr0
            else
                tput bold
                tput setaf 1
                echo "[!] $COMMAND not Found!!"
                tput sgr0
                TEST=false
            fi
        fi
    done
}

Engine() {
    local URL="${1}"
    local ALT="${3}"
    local RES=""
    local SIZE=0
    local -r URL_REGEX='(https|http)://[A-Za-z0-9_|.]*(/([^\.\"?:;,#\<\>=% ]*(.html)?)*)'
    while true; do
        getLock
        cmd=("curl" "-L" "-A" "${2}" "-w" "'%{http_code}'" "${URL}")
        op=$("${cmd[@]}" 2>&1)
        if [[ -n $op ]]; then
            RES="$op"
        else
            RES=""
        fi
        freeLock
        echo -ne "[*] ${URL:0:60}"
        if [[ "${#URL}" -gt 60 ]]
        then
            echo -ne "... "
            tput cuf 6
        else
            tput cuf "$(( 70 - ${#URL} ))"
        fi

        echo " ${RES:(-5)}"
        if [[ "${RES}" != "" ]] && [[ "${RES:(-5)}" == "'200'" ]]
        then
            RES="$(awk -F '"' '{print $2}' <<< ${RES})"
            RES="$(grep -Eo "${URL_REGEX}" <<< "${RES}" | sort | uniq)"
            RES="$(filter "${RES}")"
            SIZE="$(wc -l <<< "${RES}")"
            if [[ "${SIZE}" -gt 3 ]]
            then
                ALT="${URL}"
                NUM="$(( RANDOM % $(( ${SIZE} - 1 )) + 1 ))"
                URL="$(sed "${NUM}q;d" <<< ${RES})" # Random Link
            else
                URL="${ALT}"
                ALT="${3}"
            fi
        else
            URL="${ALT}"
            ALT="${3}"
        fi
        sleep 2
    done
}

main() {
    local TEST=true
    export TEST
    SWCheck
    if [ "$TEST" = true ]
    then
        echo -ne "\n"
        echo -ne "[+] Testing Internet Connection ..."
        if ping -q -c 3 8.8.8.8 &>/dev/null
        then
            clearLines 1
            echo -ne "[+] Internet Connection Available!\n\n"
            declare -a PIDS

            export PIDS

            trap stop SIGINT
            trap stop SIGTERM
            trap stop EXIT

            local -r L_LEN="$(( $(wc -l < partyloud.conf) - 1 ))"
            local CURR_URL=""
            local ALT_URL="https://www.hdblog.it"

            getLock

            for CURR_URL in $(cat partyloud.conf); do
                progress "[+] Starting HTTP Engine ($CURR_URL) ... "
                Engine "${CURR_URL}" "$(generateUserAgent)" "${ALT_URL}" "${i}" &
                PIDS+=("$!")
                sleep 0.4
                ALT_URL="${CURR_URL}"
            done

            freeLock

            clearLines 1
            tput bold
            echo -ne "[+] HTTP Engines Started!\n"
            tput sgr0

            local RESPONSE=""
            echo -ne "\n\n"

            tput bold
            center "[ PRESS ENTER TO STOP ]"
            tput sgr0

            echo -ne "\n\n\n"
            read -r RESPONSE

            stop

            clearLines 1
            tput bold
            echo -ne "[+] HTTP Engines Stopped!\n\n"
            tput sgr0

        else
            clearLines 1
            tput bold
            tput setaf 1
            echo "[!] Unable to Connect to Network!"
            tput sgr0
        fi
    fi
}

clear
logo

rm -fr /tmp/partyloud.lock

if [[ "${#}" == 1 ]]
then
    if [[ "${1}" -gt 0 ]] && [[ "${1}" -lt 25 ]]
    then
        main "${1}"
    else
        DisplayHelp
    fi
elif [ "${#}" == 0 ]
then
    main 7
else
    DisplayHelp
fi

exit 0
