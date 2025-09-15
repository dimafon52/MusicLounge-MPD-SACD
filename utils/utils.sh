
RETURN_VALUE=""
#
# 📂 👉 ⚠️ ✅ ❌ 🔵 🟢 🟡 📦 👤 ➡️  🧪
# 
### https://chatgpt.com/c/68989698-21b4-832e-857d-03eb9287eefc
## Command: read
# | Опция      | Что делает                                           | Пример                                    |
# | ---------- | ---------------------------------------------------- | ----------------------------------------- |
# | `-p "txt"` | Показать приглашение перед вводом                    | `read -p "Имя: " name`                    |
# | `-s`       | Скрытый ввод (для пароля)                            | `read -s -p "Пароль: " pass`              |
# | `-t N`     | Таймаут (N секунд), если не введено — ошибка         | `read -t 5 -p "Ввод (5 сек): " ans`       |
# | `-n N`     | Читать ровно N символов (без Enter)                  | `read -n 1 -p "Нажмите клавишу: " key`    |
# | `-r`       | Не интерпретировать `\` как escape (важно для путей) | `read -r -p "Введите путь: " path`        |
# | `-a arr`   | Сохранить ввод в массив (разделение по пробелам)     | `read -a words -p "Слова: "`              |
# | `-d X`     | Читать до символа `X` (по умолчанию Enter)           | `read -d : value`                         |
# | `-e`       | Ввод с редактированием (стрелки ← →, история)        | `read -e -p "Команда: " cmd`              |
# | `-i "txt"` | Значение по умолчанию (работает только с `-e`)       | `read -e -i "/mnt/music" -p "Путь: " dir` |
# read -s -t 10 -p "Пароль (10 сек): " pass
# read -e -i "/home/user" -p "Путь: " dir
# read -n 1 -p "Продолжить? [y/n]: " ans
###
# DEFAULT_IFACE=$(ip -o -4 route show to default | awk '{print $5}')
DEFAULT_IFACE=$(ip -o -4 route show to default)
# [musiclounge]$ echo $DEFAULT_IFACE 
# default via 192.168.0.1 dev enp0s3 proto dhcp src 192.168.0.107 metric 100
mpd_db_update(){
    sp="/-\|"
    i=0
    echo -n "   $ICON_BASH_NOTE Please wait... "
    while mpc status | grep -q "Updating DB"; do
         printf "\b${sp:i++%${#sp}:1}"
        sleep 0.5
    done
    echo
}

#### Font COLOR and STYLE
color_table() {
    local cols=16
    for (( i=0; i<256; i++ )); do
        tput setaf "$i"
        printf "[%03d] " "$i"
        (( (i+1) % cols == 0 )) && tput sgr0 && echo
    done
    tput sgr0
    echo
}
if command -v tput &>/dev/null && [ -t 1 ]; then
    if [ -z "${NO_COLOR:-}" ];then
        FONT_RED=$(tput setaf 196)
        FONT_GREEN=$(tput setaf 2)
        FONT_BLUE=$(tput setaf 45)
        FONT_YELLOW=$(tput setaf 185)
    fi
    FONT_BOLD=$(tput bold)
    FONT_RESET=$(tput sgr0)
fi
FONT_BOLD_BLUE="${FONT_BOLD}${FONT_BLUE}"
FONT_BOLD_YELLOW="${FONT_BOLD}${FONT_YELLOW}"


# replace_in_string_in_file TOKEN_STRING PATTERN_STRING REPLACE_STRING FILE
# Заменяет PATTERN_STRING на REPLACE_STRING только в строках, содержащих TOKEN_STRING 
replace_string_in_file() {
    local token_string="$1"
    local pattern_string="$2"
    local replace_string="$3"
    local file="$4"

    if [[ ! -f "$file" ]]; then
        # echo "⚠️ Файл $file не найден"
        echo "⚠️ File $file not found"
        return 1
    fi

    # Создаём бэкап
    local backup="${file}.$(date +%Y%m%d%H%M%S).backup"
    cp "$file" "$backup"

    # Замена только в строках с pattern_string
    sed -i "/${token_string}/s|${pattern_string}|${replace_string}|g" "$file"

    echo "✅ Заменено в $file, бэкап: $backup"
}

# Универсальная замена строки в файле только в строках, содержащих определённый паттерн
# replace_in_string_in_file PATTERN_STRING TOKEN_STRING REPLACE_STRING FILE
replace_in_string_in_file2() {
    local pattern_string="$1"
    local token_string="$2"
    local replace_string="$3"
    local file="$4"

    # Проверяем существование файла
    if [[ ! -f "$file" ]]; then
        echo "⚠️ Файл $file не найден"
        return 1
    fi

    # Создаём бэкап с временной меткой
    local backup="${file}.$(date +%Y%m%d%H%M%S).backup"
    cp -- "$file" "$backup" || { echo "Ошибка создания бэкапа"; return 1; }

    # Используем perl для безопасной замены любых спецсимволов
    perl -i -pe '
        BEGIN { $pattern = quotemeta($ENV{PATTERN}); $token = quotemeta($ENV{TOKEN}); $replace = $ENV{REPLACE} }
        if (/$pattern/) { s/$token/$replace/g }
    ' PATTERN="$pattern_string" TOKEN="$token_string" REPLACE="$replace_string" "$file"

    echo "✅ Заменено в $file, бэкап: $backup"
}
# replace_in_string_in_file '"name":"Show Images"' "localhost" "192.168.0.107" "./mympd/var_lib_mympd/state/home_list"

utils_net(){
    local param=$1
    case "$param" in
        ip)      index=9  ;;
        iface)   index=5  ;;
        route)   index=3  ;;
        *)       return 1 ;;
    esac
    echo "$DEFAULT_IFACE" | awk -v var=$index '{print $var}'
}

utils_is_installed(){
    # command -v $1 >/dev/null 2>&1
    type $1 >/dev/null 2>&1
}
# utils_is_installed docker
# utils_is_installed "kuKu docker"

# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
utils_dialog_yn(){
    local prompt=$1

    if [ ! "$prompt" ];then
        prompt="  Continue? [y/n]: "
    fi

    read -rp "$prompt" answer
    if [ "$answer" == "n" ];then
        echo "return" 
    fi
}

utils_dialog_continue(){
    # read -n 1 -p "  Continue? [y/n]: " answer
    read -p "  Continue? [y/n]: " answer
    if [ "$answer" == "n" ];then
        echo "return" 
    fi
}
# $(utils_dialog_continue)
# echo "continue..."

utils_read_file(){
    while IFS= read -r line; do
        echo "$line"
    done < "$1"
}

# dir="${dir/#\~/$HOME}"
utils_bash_path(){
    local path="$1"
    if [[ "$path" == ~* ]]; then
        echo "${path/#\~/$HOME}" #use Bash parameter expansion for '~'
    else
        echo "$path"
    fi
}

# https://chatgpt.com/c/68989698-21b4-832e-857d-03eb9287eefc
utils_dir_is_empty() {
    # find /mnt/music -mindepth 1 -maxdepth 1
    local test_dir=$1
    if [ -z "$(ls -A "$test_dir")" ]; then
        #echo "Папка пуста — можно монтировать ✅"
        return 0
    else
        # echo "⚠️ Папка не пуста!"
        #ls -A "$MOUNTPOINT"
        return 1
    fi
}

utils_is_file(){
    local file=$(utils_bash_path "$1")
    if [ ! -f "$file" ]; then
        return 1
    fi
}
utils_is_file2(){
    local file=$(utils_bash_path "$1")
    local cmd=$2
    if [ ! "$cmd" ];then
        cmd="return 1"
    fi
    if [ ! -f $file ]; then
        echo "$cmd"
    fi
}
# $(utils_is_file2 "~/qqqqqqqqqq")
# $(utils_is_file2 "/qqqqqqqqqq" "exit 1")
# $(utils_is_file2 "/qqqqqqqqqq" "ls -la")

utils_is_dir(){
    local dir=$(utils_bash_path "$1")
    if [ ! -d $dir ]; then
        return 1
    fi
}
# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
utils_get_user_input() {
    local prompt="$1"
    local default="$2"
    local input=""
    local opt=""

    if [ -n "$default" ];then
        opt="-i$default"
    fi
    RETURN_VALUE=""
    echo " 👉 To skip press 'q'."
    while true; do
        read -e $opt -rp "$prompt: " input   # working with TAB
        if [ "$input" == 'q' ];then
            return 1
        fi
        # input="${input:-$default}"  # если пустой ввод, берём дефолт
        if [ "$input" ];then
           RETURN_VALUE=$input
           # echo $input
           return
        fi
    done
}


# Функция для интерактивного запроса существующей директории
utils_get_dir() {
    local prompt="$1"
    local default="$2"
    local dir=""

    # utils_bash_path $default #expand path with '~/'
    default=${default/#\~/$HOME} #expand path with '~/'

    if [[ -n "$default" && ! -d "$default" ]]; then
        echo "  ❌ Default directory '$default' does not exist or not directory."
        return 1
    fi

    opt=""
    if [ -n "$default" ];then
        opt="-i$default"
    fi
    RETURN_VALUE=""
    echo " 👉 To skip press 'q'."
    while true; do
        # read -e $opt -rp "$prompt [$default]: " dir   # working with TAB
        read -e $opt -rp "$prompt: " dir   # working with TAB
        if [ "$dir" == 'q' ];then
            return 1
        fi

        dir="${dir:-$default}"  # если пустой ввод, берём дефолт
        dir=${dir/#\~/$HOME} #expand path with '~/'

        if [ -d "$dir" ]; then
            echo "$dir"
            RETURN_VALUE=$dir
            return
        else
            # echo "Директория '$dir' не существует. Попробуйте снова."
            echo " ⚠️  Directory '$dir' does not exist or not directory. Try again."
        fi
    done
}

################################# TEXT BLOCK #################################
# https://chatgpt.com/c/68990991-5184-832f-803e-ba098a8b4881
utils_text_block_delete() {
    local marker_start="$1"
    local marker_end="$2"
    local file="$3"
    sed -i "/^${marker_start}/,/^${marker_end}/d" "$file"
}

# Replace text block between marker_start & marker_end
# If text block not exists, then add text block 
utils_text_block_replace() {
    local marker_start="$1"
    local marker_end="$2"
    local file="$3"
    shift 3
    local new_content="$*"
    
    if grep -Eq "^${marker_start}" "$file"; then
        # Блок есть — заменяем
        sed -i._backup_ "/^${marker_start}/,/^${marker_end}/c \
            ${marker_start}\
            \n${new_content} \
            \n${marker_end}" "$file"
    else
        # Блока нет — добавляем в конец файла
        {
            echo "$marker_start"
            echo -e "$@"
            echo "$marker_end"
        } >> "$file"
    fi
}

utils_text_block_read() {
    local marker_start="$1"
    local marker_end="$2"
    local file="$3"
    RETURN_VALUE=()
    IFS=$'\n' RETURN_VALUE=($(sed -n "/$marker_start/,/$marker_end/p" $file))
    unset IFS
    # for v in "${RETURN_VALUE[@]}"; do
    #     echo -e "$v"
    # done
}
# ####### EXAMPLES HOW TO USE ########
# ################################# DON'T CHANGE !!! 
# FILE_TXT="./test_file.txt"
# MARKER_START_BLOCK="########### MUSIC LOUNGE DEFINITIONS ###########"
# MARKER_END_BLOCK="####### END OF MUSIC LOUNGE DEFINITIONS ########"
# # MARKER_START_BLOCK и MARKER_END_BLOK - должны быть ЕДИНСТВЕННЫЕ и не могут
# # повторятся в пределах ОДНОГО файла!!!
# #################################
# ml_replace_block() {
#     local fname="$1"
#     shift 1
#     local content="$*"
#     utils_text_block_replace "$MARKER_START_BLOCK" "$MARKER_END_BLOCK" "$fname" "$content"
# }
# ml_delete_block() {
#     local fname="$1"
#     utils_text_block_delete "$MARKER_START_BLOCK" "$MARKER_END_BLOCK" "$fname"
# }
# ml_replace_block "$FILE_TXT" \
#                   "1. New Data" \
#                   "\n2. New Data" \
#                   "\n3. New Data" \
#                   "\n5. New Data"
#
# ml_read_block(){
#     local fname="$1"
#     utils_text_block_read "$MARKER_START_BLOCK" "$MARKER_END_BLOCK" "$fname"
# }
# ml_read_block "$FILE_TXT"
# echo ${RETURN_VALUE[0]}
# echo ${RETURN_VALUE[1]}
#
# ml_delete_block "$FILE_TXT"


######## Misc examples
# rege(){
#     input="//192.168.0.1/MyPassport/MusicLib /mnt/music/remote_music cifs uid=1000,gid=1000"
#     if [[ $input =~ [^[:space:]]+[[:space:]]+([^[:space:]]+) ]]; then
#         echo ${BASH_REMATCH[1]}
#     fi
#     input="/home/Passport/MusicLib /mnt/music/local_music cifs uid=1000,gid=1000"
#     if [[ $input =~ [^[:space:]]+[[:space:]]+([^[:space:]]+) ]]; then
#         echo ${BASH_REMATCH[1]}
#     fi
# }
# rege2() {
#     input="//192.168.0.1/MyPassport/MusicLib /mnt/music/remote_music cifs uid=1000,gid=1000,iocharset=utf8,vers=2.0,nofail,x-systemd.automount,_netdev,credentials=/etc/smb-credentials 0 0"
#     read -r source mount_point other <<< "$input"
#     echo "$source"
#     echo "$mount_point"
#     echo "$other"
# }
# rege(){
#     input="US/Central - 10:26 PM (CST)"
#     [[ $input =~ ([0-9]+:[0-9]+) ]]
#     echo ${BASH_REMATCH[1]}
# }
