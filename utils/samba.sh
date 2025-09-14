#!/usr/bin/env bash

# 22.08.25

# sudo pacman -S gnu-netcat arp-scan smbclient
# /etc/fstab path with spaces ' ' change to \040
# '//192.168.0.1/MyPassport/MusicLib/The\ Beatles' ->  '//192.168.0.1/MyPassport/MusicLib/The\040Beatles'
# //192.168.0.1/MyPassport/MusicLib/The\040Beatles /mnt/router_media cifs uid=1000,gid=1000,noperm,vers=2.0,credentials=/etc/smb-credentials 0 0

# global vars
RETURN_VALUE=""

# --- Поиск SMB-серверов ---
# https://chatgpt.com/c/68989698-21b4-832e-857d-03eb9287eefc
# ОЧЕНЬ медленно
# hosts=$(nmap -p445 --open -oG - "$NETWORK" 2>/dev/null | awk '/445\/open/ {print $2}')
#
# 📂 👉 ⚠️ ✅ ❌ 🔵 🟢 🟡 📦 👤 ➡️
# 

smb_detect_server_version(){
    # Определяет нужный vers= для mount.cifs
    local server="$1"
    if [[ -z "$server" ]]; then
        return 1
    fi

    # Получаем negotiated dialect из smbclient
    dialect=$(smbclient -L "$server" -N -d 4 2>&1 | grep -o 'negotiated dialect\[[^]]*\]' | sed -E 's/.*\[(.*)\]/\1/')
    if [[ -z "$dialect" ]]; then
        echo "❌ Can't detect SMB version for $server"
        return 2
    fi

    case "$dialect" in
        NT1)      vers="1.0" ;;
        SMB2_02)  vers="2.0" ;;
        SMB2_10)  vers="2.1" ;;
        SMB3_00)  vers="3.0" ;;
        SMB3_02)  vers="3.02" ;;
        SMB3_10)  vers="3.10" ;;
        SMB3_11)  vers="3.11" ;;
        *)        vers="unknown" ;;
    esac

    if [ "$vers" == "unknown" ];then
       return 3
    fi
       
    echo "vers=$vers"
}
# [dima@vb-arch-nogui music_lounge_repo]$ smb_detect_server_version //192.168.0.1
# vers=2.0
# [dima@vb-arch-nogui music_lounge_repo]$ smb_detect_server_version //192.168.0.110
# vers=3.11
# [dima@vb-arch-nogui music_lounge_repo]$ 

smb_detect_server_version_verbose(){
    #!/usr/bin/env bash
    # autodetect-smb-vers.sh
    # Определяет нужный vers= для mount.cifs

    SERVER="$1"

    if [[ -z "$SERVER" ]]; then
        echo "Использование: $0 //<server>/<share>"
        return 1
    fi

    # Получаем negotiated dialect из smbclient
    [dima@vb-arch-nogui music_lounge_repo]$ smbclient -L "$SERVER" -N -d 4 2>&1 | grep -o 'negotiated dialect\[[^]]*\]'
    negotiated dialect[SMB2_02]

    dialect=$(smbclient -L "$SERVER" -N -d 4 2>&1 | grep -o 'negotiated dialect\[[^]]*\]' | sed -E 's/.*\[(.*)\]/\1/')
    if [[ -z "$dialect" ]]; then
        echo "❌ Не удалось определить версию SMB для $SERVER"
        return 2
    fi

    # Сопоставляем
    case "$dialect" in
        NT1)      vers="1.0" ;;
        SMB2_02)  vers="2.0" ;;
        SMB2_10)  vers="2.1" ;;
        SMB3_00)  vers="3.0" ;;
        SMB3_02)  vers="3.02" ;;
        SMB3_10)  vers="3.10" ;;
        SMB3_11)  vers="3.11" ;;
        *)        vers="unknown" ;;
    esac

    echo "🖧 Сервер: $SERVER"
    echo "📡 smbclient negotiated dialect: $dialect"
    echo "✅ Для mount.cifs использовать: vers=$vers"
}

smb_scan_for_shares() {
    local iface=$1 # for example wlan0
    local i=0
    RETURN_VALUE=""

    if [[ ! "$iface" ]]; then
        iface=$(ip -o -4 route show to default | awk '{print $5}')
    fi
    if [[ -z "$iface" ]]; then
        # echo "Не удалось определить сетевой интерфейс"
        # RETURN_VALUE="Failed to determine network interface. Check network connectivity."
        echo " $ICON_BASH_ERROR Failed to determine network interface. Check network connectivity."
        return 1
    fi
    if ! err=$(ip -o link show $iface 2>&1) ;then
        # RETURN_VALUE=$err
        echo " $ICON_BASH_ERROR  $err"
        return 1
    fi

    echo " 👉 Scanning network for SMB servers... using interface: $iface"
    hosts=$(sudo arp-scan --interface="$iface" --localnet 2>/dev/null | \
                awk '/^[0-9]+\./ {print $1}')

    if [[ -z "$hosts" ]]; then
        echo "  $ICON_BASH_ERROR  No found any host on the network"
        echo "    Check if arp-scan is installed"
        return 1
    fi

    # 2. Для каждого хоста пробуем получить список шар
    for host in $hosts; do
        shares=$(smbclient -L "//$host" -N -g 2>/dev/null | awk -F'|' '/Disk/ {print $2}')
        for share in $shares; do
            ((i++))
            MENU[$i]="//$host/$share"
            echo "[$i] ${MENU[$i]}"
        done
    done

    if (( i == 0 )); then
        echo "  $ICON_BASH_WARN  SMB shares was not found."
        return 1
    fi

    while true; do
        echo
        read -p " 👉 Choose SMB share by number: " choice

        if [[ -n "${MENU[$choice]}" ]]; then
            RETURN_VALUE=${MENU[$choice]}
            return 0  
        else
            echo "Incorrect number"
        fi
    done
}
# if ! smb_scan_for_share wlan0 ; then
# if ! smb_scan_for_share; then
# if ! smb_scan_for_share; then
#     echo " =!= ERROR: $RETURN_VALUE"
# else
#     echo "RETURN_VALUE: '$RETURN_VALUE'" 
# fi
# exit 0

smb_check_path() {
    local full_path="$1"   # полный путь SMB, например //192.168.0.1/MyPassport/MusicLib/Subfolder
    local user="$2"        # имя пользователя (может быть пустым)
    local pass="$3"        # пароль (может быть пустым)
    local smb_share=""
    
    # Выделяем шару (//server/share)
    smb_share=$(echo "$full_path" | cut -d/ -f1-4)

    # Выделяем подкаталог (всё, что после //server/share/)
    local subdir
    subdir=$(echo "$full_path" | cut -d/ -f5-)

    # if subdir empty, need for -c ls command on SMB server
    if [[ ! "$subdir" ]]; then
       subdir='*'
    fi
    # Опция подключения для guest или с логином
    local auth_args=()

    # Функция для попытки подключения и проверки
    try_smb() {
        smbclient "$smb_share" "${auth_args[@]}" -c "ls \"$subdir\"" >/dev/null 2>&1
        #smbclient "$smb_share" "${auth_args[@]}" -c "ls \"$subdir\""  2>&1
    }
    # Если  заданы user/pass — пробуем с ними
    # Если гостевой доступ разрешён — проверить корректность username/password нельзя.
    # Надо настроить сервер, чтобы он требовал аутентификацию.
    #  если сервер сконфигурирован как guest ok = yes или map to guest = Bad User, то он примет любые данные и "превратит" их в гостя;
    #  клиент (например smbclient) никак не отличит «правильный пароль» от «игнорированного пароля».
    if [[ -n "$user" && -n "$pass" ]]; then
        auth_args=(-U "${user}%${pass}")
        echo " --> ${auth_args[@]}"
        if try_smb; then
            echo " => Test SMB share: login as '$user'"
            return 0
        fi
    else
        # guest (без логина)
        auth_args=(-N)
        if try_smb; then
            echo " => Test SMB share: login as anonymous"
            return 0
        fi
    fi
    # Если не получилось — возвращаем ошибку
    echo " ❌ '$full_path' - no login"
    return 1
}
#check for remote smb path
#smb_check_path "$USER_REMOTE_SMB_MOUNT_DIR" "$SMB_USERNAME" "$SMB_PASSWORD"
#smb_check_path "//192.168.0.1/MyPassport"
#smb_check_path "//192.168.0.1/MyPassport/MusicLiba/*"
# smb_check_path "//192.168.0.1/MyPassport/MusicLib/BENSONHURST BLUES/*" 'admin' 'admin'
#smb_list_dirs "//192.168.0.1/MyPassport"
# exit 0

smb_browse_share() {
    local smb_share="$1"          # //192.168.0.1/MyPassport
    local current_path=""         # пусто = корень шары
    RETURN_VALUE=""

    if ! smb_check_path $smb_share; then
        return 1
    fi

    while true; do
        echo
        echo "📂 Текущая директория: /${current_path}"
        echo "Доступные папки:"

        # Формируем команду для smbclient
        local smb_cmd
        if [[ -z "$current_path" ]]; then
            smb_cmd="ls"
        else
            smb_cmd="cd \"$current_path\" ; ls"
        fi

        dirs=()
        while IFS= read -r line; do
            # ищем строки, где есть 'D' во втором столбце
            if [[ "$line" =~ ^[[:space:]]*(.+)[[:space:]]D[[:space:]] ]]; then
                name="${BASH_REMATCH[1]}"
                name=$(echo "$name" | sed 's/ *$//')   # убираем пробелы справа
                [[ "$name" != "." && "$name" != ".." ]] && dirs+=("$name")
            fi
        done < <(smbclient -N "$smb_share" -c "$smb_cmd" 2>/dev/null)

        # Меню select
        PS3="#? "
        local choice
        if ((${#dirs[@]} == 0)); then
            select choice in ".." "✅ Готово"; do
                if [[ "$REPLY" == "" ]]; then continue; fi
                if [[ "$choice" == "✅ Готово" ]]; then
                    RETURN_VALUE="$smb_share"
                    echo "👉 Итоговый путь: $RETURN_VALUE"
                    return 0
                elif [[ "$choice" == ".." ]]; then
                    # подняться вверх
                    if [[ -z "$current_path" ]]; then
                        : # уже в корне
                    elif [[ "$current_path" == */* ]]; then
                        current_path="${current_path%/*}"
                    else
                        current_path=""
                    fi
                    break
                else
                    echo "⚠️ Неверный выбор"; break
                fi
            done
        else
            select choice in ".." "${dirs[@]}" "✅ Готово"; do
                if [[ "$REPLY" == "" ]]; then continue; fi
                if [[ "$choice" == "✅ Готово" ]]; then
                    if [[ -z "$current_path" ]]; then
                        RETURN_VALUE="$smb_share"
                    else
                        RETURN_VALUE="$smb_share/$current_path"
                    fi
                    echo "👉 Итоговый путь: $RETURN_VALUE"
                    return 0
                elif [[ "$choice" == ".." ]]; then
                    if [[ -z "$current_path" ]]; then
                        : # уже в корне
                    elif [[ "$current_path" == */* ]]; then
                        current_path="${current_path%/*}"
                    else
                        current_path=""
                    fi
                    break
                elif [[ -n "$choice" ]]; then
                    # Спуск в выбранную поддиректорию
                    if [[ -z "$current_path" ]]; then
                        current_path="$choice"
                    else
                        current_path="$current_path/$choice"
                    fi
                    break
                else
                    echo "⚠️ Неверный выбор"; break
                fi
            done
        fi
    done
}


smb_list_dirs() {
    local smb_path="$1"

    # Проверка: указан ли путь
    if [[ -z "$smb_path" ]]; then
        echo "Использование: list_smb_dirs //<host>/<share>"
        return 1
    fi

    # Получаем список директорий (фильтрация по типу 'D')
    smbclient -N "$smb_path" -c "ls" 2>/dev/null \
        | awk -v path=$smb_path '$2 ~ /D/ {print path"/" $1}' \
        | sed 's/[[:space:]]*$//' \
        | grep -vE '\.\.?$'
}

# 🔹 Функция: «браузер» по директориям внутри шары. НЕ РАБОТАЕТ с пробелами!
smb_browse_share_2() {
    local smb_share=$1
    current_path=" "
    RETURN_VALUE="None"
    
    while true; do

        read -p "CURRENT_PATH: $current_path"
        
        if [[ "$current_path" == " " ]]; then
            smb_cmd="ls"
        else
            smb_cmd="ls \"$current_path\*\""
        fi

        echo
        echo "📂 Текущая директория: $current_path"
        echo "Доступные папки:"
        
        # Получаем список папок внутри текущей директории
        # dirs=$(smbclient -N "$smb_share" -c "ls \"$smb_cmd\"" 2>/dev/null \
        #            | awk '/D[[:space:]]/ {print $1}' | grep -v '^\.\.$' | grep -v '^\.$')
        dirs=$(smbclient -g -N "$smb_share" -c "$smb_cmd" 2>/dev/null \
                   | awk '/D[[:space:]]/ {print $1}' | grep -v '^\.\.$' | grep -v '^\.$')
        
        
        if [[ -z "$dirs" ]]; then
            echo "⚠️ Нет поддиректорий"
        else
            select dir in ".." $dirs "✅ Готово"; do
                if [[ "$dir" == "✅ Готово" ]]; then
                    FINAL_PATH="$smb_share/$current_path"
                    RETURN_VALUE=$FINAL_PATH
                    echo "👉 Итоговый путь: $FINAL_PATH"
                    return
                elif [[ "$dir" == ".." ]]; then
                    # подняться вверх
                    current_path=$(dirname "$current_path")
                    [[ "$current_path" == "." ]] && current_path="/"
                    break
                elif [[ -n "$dir" ]]; then
                    # уйти в поддиректорию
                    read -p "DIR: $dir"
                    if [[ "$current_path" == " " ]]; then
                        current_path="$dir"
                    else
                        current_path="$current_path/$dir"
                    fi
                    # current_path=$current_path"/"
                    break
                else
                    echo "⚠️ Неверный выбор"
                fi
            done
        fi
    done
}
