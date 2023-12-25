#!/bin/bash

export LANG=C

[[ $EUID != 0 ]] && echo -e "\nThis script must be run with root privileges\n" && exit 1

usage() {
    echo
    echo "usage: $(basename $0)"
    echo "       -ws [path]    sign files "
    echo "       -u            update packages "
    echo "       -h            displays this message "
    echo
    exit 1
}

while [ -n "$1" ]; do # while loop starts
    case "$1" in
    -ws)
        SIGN_PATH="$2"
        shift
        ;;
    -u)
        UPDATE="yes"
        shift
        ;;
    -h) usage
        ;;
    --)
        shift # The double dash makes them parameters
        break
        ;;
     *) usage
        ;;
    esac
    shift
done


IRRADIUM_VERSION="3.7"
IRRADIUM_URL="https://dl.irradium.org/irradium/packages/aarch64/${IRRADIUM_VERSION}"
IRRADIUM_CACHE="/var/cache/pkg-get"
PORTS="/usr/bin/ports"
DOWNLOAD="/usr/bin/curl"
SIGNIFY="/usr/bin/signify"
SIGNIFY_PATH="/home/dev/build/crux-dev/pkg-get"
SIGNIFY_NAME="pkg-get"
COMPRESSION="gz"
PORT_SUFFIX=".pkg.tar.${COMPRESSION}"

WORK_DIR=$(mktemp -d)


trap 'cleaning' INT
trap 'cleaning' SIGINT
trap 'cleaning' TERM


message() {
    # parametr 1 - text message
    MESSAGE="$1"
    printf '|\e[1;33mwarn\x1B[0m| \e[0;32m%-12s\x1B[0m %s\n' "$ACTION" "$MESSAGE"
}

check_for_updates() {
    $PORTS -d | sed -n '2,$p' > $WORK_DIR/ports.diff
}

verify_sign() {
    local port="$1"
    local pkg="$2"

    if [[ -e "${IRRADIUM_CACHE}/${port}/${pkg}.sig" ]]; then
        if [[ ! $($SIGNIFY -p ${SIGNIFY_NAME}.pub -V -x "${IRRADIUM_CACHE}/${port}/${pkg}.sig" -m "${IRRADIUM_CACHE}/${port}/${pkg}" 2>&1 > /dev/null) ]]; then
            echo "Port: ${port}    signature package: ${pkg}    : OK"
        else
            echo "Port: ${port}    signature package: ${pkg}    : ERROR"
        fi
    else
        echo "Port: ${port}    signature missing: ${pkg}.sig"
    fi
}

sign_files() {
    local path="$1"

    find $path -iname "*${PORT_SUFFIX}" -exec $SIGNIFY -s ${SIGNIFY_NAME}.sec -S -m "{}" -x "{}.sig" \;

#    if [[ ! -e ${file}.sig ]]; then
#        $SIGNIFY -s ${SIGNIFY_NAME}.sec -S -x "${IRRADIUM_CACHE}/${port}/${pkg}.sig" -m "${IRRADIUM_CACHE}/${port}/${pkg}"
#    fi
}

downloads() {
    local port="$1"
    local name="$2"
    local version="$3"
    local url=${IRRADIUM_URL}/${port}/${name}'%23'${version}${PORT_SUFFIX}
    local pkg=${name}'#'${version}${PORT_SUFFIX}

    if [[ ! -d "${IRRADIUM_CACHE}/${port}" ]]; then
        mkdir -p "${IRRADIUM_CACHE}/${port}"
    fi

    if [[ -e "${IRRADIUM_CACHE}/${port}/${pkg}" ]]; then
        echo "Port: ${port}    package in cache: ${pkg}"
    else
        if [[ $($DOWNLOAD -o /dev/null -k --silent -Iw '%{http_code}' $url) == "200" ]]; then
            # download package
            $DOWNLOAD -k -e robots=off --no-clobber $url \
                      -o ${IRRADIUM_CACHE}/${port}/${name}'#'${version}${PORT_SUFFIX}
        else
            echo "Port: ${port}    remote file missing: ${pkg}"
        fi
    fi

    if [[ -e "${IRRADIUM_CACHE}/${port}/${pkg}.sig" ]]; then
        echo "Port: ${port}    signature in cache: ${pkg}.sig"
    else
        if [[ $($DOWNLOAD -o /dev/null -k --silent -Iw '%{http_code}' $url) == "200" ]]; then
            # download package
            $DOWNLOAD -k -e robots=off --no-clobber $url \
                      -o ${IRRADIUM_CACHE}/${port}/${name}'#'${version}${PORT_SUFFIX}
        else
            echo "Port: ${port}    remote file missing: ${pkg}.sig"
        fi
    fi
}

prepare_ports() {
    local type="$1"

    while read -r line; do
        port=$(echo $line | cut -d ' ' -f1)
        name=$(echo $line | cut -d ' ' -f2)
        version=$(echo $line | cut -d ' ' -f4)
        if [[ $type == "download" ]]; then
            downloads ${port##*-} $name $version
        elif [[ $type == "verify" ]]; then
            verify_sign ${port##*-} ${name}'#'${version}${PORT_SUFFIX}
        fi
    done < $WORK_DIR/ports.diff
}

cleaning() {
    # clean work directory
    if [[ -d ${WORK_DIR} ]]; then
        rm -rf ${WORK_DIR}
    fi
    exit 0
}

if [[ ! -z $SIGN_PATH && -d $SIGN_PATH ]]; then
    sign_files $SIGN_PATH
fi

if [[ ! -z $UPDATE ]]; then
    check_for_updates
    prepare_ports "download"
    prepare_ports "verify"
fi

cleaning


