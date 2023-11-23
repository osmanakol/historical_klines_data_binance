#!/bin/bash

set -e


function display_help() {
    echo "Usage: $0 <parameter1> [parameter2] [parameter3]"
    echo "Options:"
    echo "  -h | --help     Display this help message"
    echo "  -s | --symbol   Enter a symbol"
    echo "  -i | --interval Enter an interval"
    echo "  -d | --start    Enter a start date"
    exit 1
}


while getopts ":h:s:i:d:-" option; do
    case $option in
        -)  [ $OPTIND -ge 1 ] && optind=$(expr $OPTIND - 1 ) || optind=$OPTIND
            eval OPTION="\$$optind"
            OPTARG=$(echo "$OPTION" | cut -d'=' -f2)
            OPTION=$(echo "$OPTION" | cut -d'=' -f1)
            case "${OPTION}" in
                --help)
                    display_help
                    ;;
                --symbol)
                    symbol=${OPTARG}
                    ;;
                --interval)
                    interval=${OPTARG}
                    ;;
                --start)
                    start_date=${OPTARG}
                    ;;
                *)
                    echo "Invalid option: --${OPTARG}"
                    display_help
                    ;;
            esac
            OPTIND=1
            shift
            ;;
        h) # display Help
            display_help
            ;;
        s) # Enter a symbol
            symbol=$OPTARG
            ;;
        i) # Enter an interval
            interval=$OPTARG;
            ;;
        d) # Enter a start date
            start_date=$OPTARG
            ;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

echo "symbol: $symbol"
echo "interval: $interval"
echo "start_date: $start_date"


function initialize() {
    if [ -d "./temp" ]; then
        rm -rf ./temp
    fi

    mkdir -p ./temp
}

function generate_url() {
    echo "https://data.binance.vision/data/spot/daily/klines/${symbol}/${interval}/${symbol}-${interval}-$1.zip"
}

function get_csv_file_name() {
    echo "${symbol}-${interval}-$1.csv"
}

function get_zip_file_name() {
    echo "${symbol}-${interval}-$1.zip"
}

function dowload_file() {
    if [ -f "./temp" ]; then
        echo "File already exists: $2"
        return
    fi

    if [ -f "./temp/$2" ]; then
        echo "File already exists: $2"
        return
    fi

    echo "Downloading file: $2"
    echo "$1"
    curl "$1" > ./temp/"$2"
}

function extract_file() {
    if ! [ -f "./temp/$1" ]; then
        echo "File does not exist : $1"
        exit 1
    fi

    csv_file_name=$(get_csv_file_name "$2")

    if [ -f "./temp/$csv_file_name" ]; then
        echo "File already exist : $csv_file_name"
        return
    fi

    unzip  "./temp/$1" -d "./temp"
    rm "./temp/$1"
}

function concat_multiple_csv_to_single() {
   

    csv_file_name=$(get_csv_file_name "$1")

    if ! [ -f "./temp/$csv_file_name" ]; then
        echo "File does not exists : $csv_file_name"
        exit 1
    fi

    cat "./temp/$csv_file_name" >> "./temp/test.csv"
    rm "./temp/$csv_file_name"
}

function finalize() {
    if ! [ -f "./temp/test.csv" ]; then
        echo "File does not exists : test.csv"
        exit 1
    fi

    mv "./temp/test.csv" "./$symbol-$interval-$start_date-$end_date.csv"
    rm -rf ./temp
}

#https://data.binance.vision/data/spot/daily/klines/BTCUSDT/15m/BTCUSDT-15m-2023-11-19.zip

initialize

end_date=$(date +"%Y-%m-%d")
echo "End date: $end_date"
temp_start_date="$start_date"

while [ "$temp_start_date" != "$end_date" ]
do
    echo "$temp_start_date"
    url=$(generate_url "$temp_start_date")
    zip_file_name=$(get_zip_file_name "$temp_start_date")
    
    dowload_file "$url" "$zip_file_name"&
    extract_file "$zip_file_name" "$temp_start_date"&

    if [[ "$OSTYPE" == "darwin"* ]]; then
        temp_start_date=$(date -j -v +1d -f "%Y-%m-%d" "$temp_start_date" +%Y-%m-%d)
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        temp_start_date=$(date -I -d "$temp_start_date + 1 day")
    else
        echo "Unsupported operating system: $OSTYPE"
        exit 1
    fi
done

wait


temp_start_date="$start_date"
while [ "$temp_start_date" != "$end_date" ]
do
    concat_multiple_csv_to_single "$temp_start_date"
    temp_start_date=$(date -j -v +1d -f "%Y-%m-%d" "$temp_start_date" +%Y-%m-%d)
done

finalize