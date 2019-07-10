#!/bin/bash
## -----------------------------------------------------------------------------
## Linux Scripts.
## Auto save database.
##
## @package ojullien\bash\bin
## @license MIT <https://github.com/ojullien/bash-autosavedb/blob/master/LICENSE>
## -----------------------------------------------------------------------------
#set -o errexit
set -o nounset
set -o pipefail

## -----------------------------------------------------------------------------
## Shell scripts directory, eg: /root/work/Shell/src/bin
## -----------------------------------------------------------------------------
readonly m_DIR_REALPATH="$(realpath "$(dirname "$0")")"

## -----------------------------------------------------------------------------
## Load constants
## -----------------------------------------------------------------------------
# shellcheck source=/dev/null
. "${m_DIR_REALPATH}/../sys/constant.sh"

## -----------------------------------------------------------------------------
## Includes sources & configuration
## -----------------------------------------------------------------------------
# shellcheck source=/dev/null
. "${m_DIR_SYS}/string.sh"
# shellcheck source=/dev/null
. "${m_DIR_SYS}/filesystem.sh"
# shellcheck source=/dev/null
. "${m_DIR_SYS}/option.sh"
# shellcheck source=/dev/null
. "${m_DIR_SYS}/config.sh"
# shellcheck source=/dev/null
. "${m_DIR_SYS}/ftp.sh"
# shellcheck source=/dev/null
. "${m_DIR_APP}/autosavedb/app.sh"
Config::load "autosavedb"
if ((m_AUTOSAVEDB_ISMARIADB)); then
    # shellcheck source=/dev/null
    . "${m_DIR_SYS}/db/mariadb.sh"
else
    # shellcheck source=/dev/null
    . "${m_DIR_SYS}/db/mysql.sh"
fi

## -----------------------------------------------------------------------------
## Help
## -----------------------------------------------------------------------------
((m_OPTION_SHOWHELP)) && Option::showHelp && exit 0

## -----------------------------------------------------------------------------
## Trace
## -----------------------------------------------------------------------------
Constant::trace
AutoSaveDB::trace

## -----------------------------------------------------------------------------
## Start
## -----------------------------------------------------------------------------
String::separateLine
String::notice "Today is: $(date -R)"
String::notice "The PID for $(basename "$0") process is: $$"
Console::waitUser

## -----------------------------------------------------------------------------
## Creates directories
## -----------------------------------------------------------------------------
String::separateLine
FileSystem::removeDirectory "${m_AUTOSAVEDB_DIR_CACHE}"
FileSystem::createDirectory "${m_AUTOSAVEDB_DIR_CACHE}/${m_DATE}"
FileSystem::createDirectory "${m_AUTOSAVEDB_DIR_UPLOAD}"
Console::waitUser

## -----------------------------------------------------------------------------
## Flush
## -----------------------------------------------------------------------------
String::separateLine
FileSystem::syncFile
DB::flush "${m_DB_USR}" "${m_DB_PWD}"
Console::waitUser

## -----------------------------------------------------------------------------
## For each databases
## -----------------------------------------------------------------------------
for sDatabase in "${m_AUTOSAVEDB_DATABASES[@]}"; do

    ## -----------------------------------------------------------------------------
    ## Check before saving
    ## -----------------------------------------------------------------------------
    String::separateLine
    FileSystem::syncFile
    DB::check "${m_DB_USR}" "${m_DB_PWD}" "${sDatabase}"
    Console::waitUser

    ## -----------------------------------------------------------------------------
    ## Save database
    ## -----------------------------------------------------------------------------
    String::separateLine
    DB::dump "${m_DB_USR}"\
    "${m_DB_PWD}" "${sDatabase}"\
    "${m_AUTOSAVEDB_DIR_CACHE}/${m_DATE}/${sDatabase}-${m_DATE}-error.log"\
    "${m_AUTOSAVEDB_DIR_CACHE}/${m_DATE}/${sDatabase}-${m_DATE}.sql"
    Console::waitUser

done

## -----------------------------------------------------------------------------
## Compressing
## -----------------------------------------------------------------------------
String::separateLine
String::notice "Compressing ..."
cd "${m_AUTOSAVEDB_DIR_CACHE}" || exit 18
FileSystem::compressFile "${m_AUTOSAVEDB_DIR_UPLOAD}/${m_DATE}-db" "${m_DATE}"
cd - || exit 18
Console::waitUser

## -----------------------------------------------------------------------------
## Upload
## -----------------------------------------------------------------------------
String::separateLine
declare -i iReturn=1
String::notice "Uploading ..."
if [[ -f "${m_AUTOSAVEDB_DIR_UPLOAD}/${m_DATE}-db.tar.bz2" ]]; then
    FTP::put "${m_FTP_SRV}" "${m_FTP_USR}" "${m_FTP_PWD}" "${m_DATE}-db.tar.bz2" "." "${m_AUTOSAVEDB_DIR_UPLOAD}"
    iReturn=$?
    String::notice -n "FTP ${m_DATE}-db.tar.bz2:"
    String::checkReturnValueForTruthiness ${iReturn}
else
    String::error "NOK code: nothing to send or FTP mode is OFF"
    iReturn=0
fi
Console::waitUser

## -----------------------------------------------------------------------------
## END
## -----------------------------------------------------------------------------
m_OPTION_LOG=0
if [[ -f ${m_LOGFILE} ]]; then
    mv "${m_LOGFILE}" "${m_AUTOSAVEDB_DIR_UPLOAD}"
fi

String::notice -n "Changing upload directory owner:"
chown -R "${m_AUTOSAVEDB_UPLOAD_DIRECTORY_OWNER}":"${m_AUTOSAVEDB_UPLOAD_DIRECTORY_OWNER}" "${m_AUTOSAVEDB_DIR_UPLOAD}"
iReturn=$?
String::checkReturnValueForTruthiness ${iReturn}

String::notice "Now is: $(date -R)"
exit ${iReturn}
