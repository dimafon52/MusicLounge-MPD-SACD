#!/usr/bin/env bash

# 14.09.25

ML_VERSION="1.0"

BASH_SCRIPTS=$PWD/utils
. $BASH_SCRIPTS/icons.sh
. $BASH_SCRIPTS/os.sh
. $BASH_SCRIPTS/utils.sh
. $BASH_SCRIPTS/samba.sh
# . $BASH_SCRIPTS/network.sh

APPS_HOST_INSTALL="smbclient docker arp-scan mpc"

# set -e

MUSICLOUNGE_ROOT_DEFAULT="/mnt/musiclonge"
FILE_BASHRC="$HOME/.bashrc"
FILE_FSTAB="/etc/fstab"
# FILE_FSTAB="$HOME/music_lounge_repo/test.sh"
FILE_SMB_CREDENTIALS="/etc/smb-credentials"
FSTAB_OPT_SMB_SRV_VER_DEFAULT="vers=3.0"
################################# !!! DON'T CHANGE !!! 
MARKER_START_BLOCK="########### MUSIC LOUNGE DEFINITIONS ###########"
MARKER_END_BLOCK="####### END OF MUSIC LOUNGE DEFINITIONS ########"
# MARKER_START_BLOCK и MARKER_END_BLOCK - должны быть ЕДИНСТВЕННЫЕ и не могут
# повторятся в пределах ОДНОГО файла!!!
#################################
ml_set() {
    local fname="$1"
    shift 1
    local content="$*"
    utils_text_block_replace "$MARKER_START_BLOCK" "$MARKER_END_BLOCK" "$fname" "$content"
}

ml_set_sudo() {
    sudo bash -c "
        $(declare -f ml_set)
        $(declare -f utils_text_block_replace)
        MARKER_START_BLOCK=\"$MARKER_START_BLOCK\"
        MARKER_END_BLOCK=\"$MARKER_END_BLOCK\"
        ml_set \"\$@\"
    " _ "$@"
}

# Readed value in RETURN_VALUE variable(see utils.sh) 
ml_get() {
    local fname=$1
    utils_text_block_read "$MARKER_START_BLOCK" "$MARKER_END_BLOCK" "$fname"
}

ml_delete() {
    local fname="$1"
    utils_text_block_delete "$MARKER_START_BLOCK" "$MARKER_END_BLOCK" "$fname"
}
ml_delete_sudo() {
    sudo bash -c "
        $(declare -f ml_delete)
        $(declare -f utils_text_block_delete)
        MARKER_START_BLOCK=\"$MARKER_START_BLOCK\"
        MARKER_END_BLOCK=\"$MARKER_END_BLOCK\"
        ml_delete \"\$@\"
    "  _ "$@"                 
}

musiclounge_cfg_get(){
    ml_get $FILE_FSTAB
    if ((${#RETURN_VALUE[@]} != 0)); then
        for line in "${RETURN_VALUE[@]}"; do
            # echo $line
            read -r source mount_point other <<< "$line"
            if [ "$mount_point" == "$MUSICLOUNGE_LOCAL" ];then
                USER_LOCAL_MUSIC_DIR="$source"
            elif [ "$mount_point" == "$MUSICLOUNGE_REMOTE" ];then
                USER_REMOTE_SMB_DIR="$source"
            fi
        done
    fi
}

musiclounge_cfg_set(){
    local fstab_content=""
    if [[ ! "$USER_LOCAL_MUSIC_DIR" && ! "$USER_REMOTE_SMB_DIR" ]] ; then
        echo " $ICON_BASH_WARN  There are no music directories to mount."
        return 1
    fi

    if [[ "$USER_LOCAL_MUSIC_DIR" ]]; then
        # FSTAB_CMD_MOUNT_LOCAL="$USER_LOCAL_MUSIC_DIR $MUSICLOUNGE_LOCAL $FSTAB_OPT_LOCAL"
        fstab_content="$USER_LOCAL_MUSIC_DIR $MUSICLOUNGE_LOCAL $FSTAB_OPT_LOCAL\n"
    fi
    if [[ "$USER_REMOTE_SMB_DIR" ]]; then
        # FSTAB_CMD_MOUNT_SMB="$USER_REMOTE_SMB_DIR $MUSICLOUNGE_REMOTE $FSTAB_OPT_SMB"
        # echo " ==> FSTAB_CMD_MOUNT_SMB: $FSTAB_CMD_MOUNT_SMB"
        fstab_content+="$USER_REMOTE_SMB_DIR $MUSICLOUNGE_REMOTE $FSTAB_OPT_SMB"
    fi

    mkdir -p $MUSICLOUNGE_LOCAL    
    mkdir -p $MUSICLOUNGE_REMOTE
        
    echo "  $ICON_BASH_NOTE  Change Docker service configuration."
    echo "    Please wait for SMB share and local dir to mount..."
    ### https://chatgpt.com/c/68990991-5184-832f-803e-ba098a8b4881
    ## https://chatgpt.com/share/68a0d775-84b4-8013-a1a1-ef186993a29f
    sudo mkdir -p /etc/systemd/system/docker.service.d
    echo -e "[Unit]
    RequiresMountsFor=$MUSICLOUNGE_REMOTE
    RequiresMountsFor=$MUSICLOUNGE_LOCAL
    After=remote-fs.target local-fs.target
    " | sudo tee /etc/systemd/system/docker.service.d/override.conf 

    echo -e "$fstab_content"
    ml_set_sudo "$FILE_FSTAB" "$fstab_content"

    sudo mount -a

    # sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl restart docker
}

ml_create_smb_credentials(){
    local smb_username=""
    local smb_password=""

    echo " $ICON_BASH_NOTE  Create the credentials file $FILE_SMB_CREDENTIALS for the SMB share."
    if ! utils_get_user_input "  Please enter user name" "admin"; then
        return 1
    fi
    smb_username=$RETURN_VALUE

    if ! utils_get_user_input "  Please enter password" "admin"; then
        return 1
    fi
    smb_password=$RETURN_VALUE

    sudo /bin/sh -c "echo 'username=$smb_username' >  $FILE_SMB_CREDENTIALS"
    sudo /bin/sh -c "echo 'password=$smb_password' >> $FILE_SMB_CREDENTIALS"
    sudo chmod 600 $FILE_SMB_CREDENTIALS
    $(utils_is_file2 $FILE_SMB_CREDENTIALS)
    echo " $ICON_BASH_DONE  Credentials file "$FILE_SMB_CREDENTIALS" successfully created!"
    # ls $CREDENTIALS
    # sudo cat $CREDENTIALS
}

musiclounge_set_smb_share() {
    local smb_share=""
    local smb_srv_ver=""

    echo " $ICON_BASH_NOTE  Set SMB share details for mount remote music"
    $(utils_dialog_continue) # return - if user type 'n'+Enter

    # if [ -n "$USER_REMOTE_SMB_DIR" ];then
    #     echo "  $ICON_BASH_NOTE  Remote SMB: $USER_REMOTE_SMB_DIR"
    #     $(utils_dialog_yn "   You want to change [y/n]") # return - if user type 'n'+Enter
    # fi
    
    if ! smb_scan_for_shares ;then
        # Errors or no avaivable smb shares 
        return 1
    fi
    smb_share=$RETURN_VALUE
    echo " ==> SMB share: $smb_share"
    if ! smb_browse_share $smb_share ; then
        return 2
    fi
    if ! smb_check_path "$RETURN_VALUE" ; then
        return 3
    fi
    USER_REMOTE_SMB_DIR="$RETURN_VALUE"
    # For fstab need:
    if smb_srv_ver=$(smb_detect_server_version $smb_share); then
        echo " ==> smb_srv_ver: $smb_srv_ver"
                                              # sed -E "s|vers=[0-9]\.[0-9]{1,2}|$smb_srv_ver|"
        FSTAB_OPT_SMB=$(echo "$FSTAB_OPT_SMB" | sed -E "s|vers=[^,]{1,4}|$smb_srv_ver|")
    fi

    if utils_is_file $FILE_SMB_CREDENTIALS;then
        echo " $ICON_BASH_NOTE  $FILE_SMB_CREDENTIALS is exists."
        read -rp "  Do you want to change it? [y/n]: " answer
        if [ "$answer" != "n" ];then
            if ! ml_create_smb_credentials; then
                return
            fi
        fi
    else
        if ! ml_create_smb_credentials; then
            return
        fi
    fi
}

musiclounge_set_local_path() {
    USER_LOCAL_MUSIC_DIR=""
    if ! utils_get_dir "    Enter your music location" "$USER_LOCAL_MUSIC_DIR"; then
        return
    fi
    USER_LOCAL_MUSIC_DIR=$RETURN_VALUE
}

musiclounge_set_root_path() {
    # echo "  * MusicLounge set main path"
    if ! printenv MUSICLOUNGE_ROOT >/dev/null 2>&1; then
        read -e -p "    $ICON_BASH_NOTE Enter MusicLounge root, default value [$MUSICLOUNGE_ROOT_DEFAULT]: " input

        # Take default if the user has not entered anything
        MUSICLOUNGE_ROOT="${input:-$MUSICLOUNGE_ROOT_DEFAULT}"
        # Set env variable MUSICLOUNGE_ROOT
        export MUSICLOUNGE_ROOT
        ml_set "$FILE_BASHRC" "export MUSICLOUNGE_ROOT=$MUSICLOUNGE_ROOT"
    else
        current=$(printenv MUSICLOUNGE_ROOT)
        echo "    👉 MUSICLOUNGE_ROOT is already set as '$current'."
        # read -n 1 -p "    Do you want to change MUSICLOUNGE_ROOT? [y/n]: " input 
        $(utils_dialog_continue) # return if user type 'n'+Enter
        read -e -i $current -p "    Enter new MusicLounge root: " input
        if [ "$current" == "${input}"];then
            return
        fi
        # sed -i "s|^export MUSIC_LOUNGE_DIR_GLOBAL=.*|export MUSIC_LOUNGE_DIR_GLOBAL='$NEW_MUSIC_LOUNGE_DIR_GLOBAL'|" ~/.bashrc
        MUSICLOUNGE_ROOT=$input
        export MUSICLOUNGE_ROOT
        ml_set "$FILE_BASHRC" "export MUSICLOUNGE_ROOT=$input"
    fi
    MUSICLOUNGE_LOCAL="$MUSICLOUNGE_ROOT/local"
    MUSICLOUNGE_REMOTE="$MUSICLOUNGE_ROOT/remote"
}

host_apps_install(){
    local not_installed_pkgs=$(os_missing_pkgs $APPS_HOST_INSTALL)

    if [ -z "$not_installed_pkgs" ];then
        return
    fi
           
    $OS_CMD_UPDATE
    echo " 👉 This apps [$not_installed_pkgs] will be installed on the host."
    # read -p " To continue press Enter, to exit 'q'" input
    read -n 1 -p "  Continue? [y/n]: " answer
    if [ "$answer" == "n" ];then
        echo
        exit 0
    fi
    $OS_CMD_INSTALL $not_installed_pkgs
}

musiclounge_docker_install(){
    local host_ip=$(utils_net ip)
    echo " $ICON_BASH_NOTE  Docker containers installation..."
    cd ${PWD}/musiclounge
    mkdir -p ./mympd/var_lib_mympd
    mkdir -p ./mympd/var_cache_mympd
    cp -rf ./mympd/mympd_config/* ./mympd/var_lib_mympd
    file=./mympd/var_lib_mympd/state/home_list
    sed -i._backup_ "/\"name\":\"Show Images\"/s|localhost|http://$host_ip|" "$file"
    docker compose up -d
}

musiclounge_uninstall(){
    local docker_images=($(docker images | grep -E "^musiclounge-|dperson/torproxy" | awk '{print $1}'))
    # if [ -z $docker_images ];then
    #     echo " $ICON_BASH_NOTE  MusicLounge does not installed"
    #     return
    # fi
    
    echo "  $ICON_BASH_WARN  MusicLounge will be UNINSTALLED!"
    $(utils_dialog_continue)

    if ! printenv MUSICLOUNGE_ROOT;then
        echo " $ICON_BASH_WARN  A reboot is required to continue."
        $(utils_dialog_continue)
        sudo reboot
    fi

    
    
    ### Docker
    echo " 1. Stop and remove containers"
    # docker compose -f musiclounge/docker-compose.yml stop #> /dev/null 2>&1
    # docker compose -f musiclounge/docker-compose.yml rm
    docker compose -f musiclounge/docker-compose.yml down
    
    echo " 3. Remove docker images"
    for img in "${docker_images[@]}";do
        echo "  -- Remove $img"
        docker image rm $img -f
    done
    docker image prune -f > /dev/null 2>&1

    ### Unmount used dirs
    # echo "$MUSICLOUNGE_LOCAL"
    # echo "$MUSICLOUNGE_REMOTE"
    # # if systemd automount - reboot only! sudo umount - not work; see your options in /etc/fstab 
    # sudo umount $MUSICLOUNGE_LOCAL
    # sudo umount $MUSICLOUNGE_REMOTE
    
    # Delete configuration of MusicLounge
    ml_delete $FILE_BASHRC
    ml_delete_sudo $FILE_FSTAB
    
    # ### Packages
    # pkgs=($APPS_HOST_INSTALL)
    # for pkg in "${pkgs[@]}";do
    #     echo "  Uninstall package: $pkg"
    # done
    echo " $ICON_BASH_DONE  MusicLounge has been removed."
    echo " $ICON_BASH_NOTE  The system will reboot to complete the uninstall."
    $(utils_dialog_continue)
    sudo reboot
}

musiclounge_install() {
    echo "${FONT_BOLD}"
    echo " 📦 MusicLounge Installation${FONT_RESET}"
    $(utils_dialog_continue)
    echo " ➡️  ${FONT_BOLD}1. Install apps on host${FONT_RESET}"
    host_apps_install
    echo " ➡️  ${FONT_BOLD}2. Define MusicLounge root directory ${FONT_RESET}"
    musiclounge_set_root_path
    echo " ➡️  ${FONT_BOLD}4. Specify your local music directory${FONT_RESET}"
    musiclounge_set_local_path
    echo " ➡️  ${FONT_BOLD}4. Specify your remote music SMB share directory${FONT_RESET}"
    musiclounge_set_smb_share
    if ! musiclounge_cfg_set; then
        return 1
    fi
    musiclounge_docker_install
    mpc update
    sleep 2
    host_ip=$(utils_net ip)
    echo "${FONT_BOLD_YELLOW}"
    echo " $ICON_BASH_DONE The Music Lounge structure has been created successfully! $ICON_BASH_SMILE ${FONT_RESET}"
    echo " $ICON_BASH_DONE  Connecting to the web client using a web browser: '$host_ip'"
    echo "     Connecting to the MCIS(music content image show) using a web browser: '$host_ip:5000'"
    echo " $ICON_BASH_NOTE It is recommended to reboot the system."
    $(utils_dialog_continue)
    sudo reboot
    # echo " 2. Get local $USER directory"
    # musiclounge_set_local_path
    # ml_get "$HOME/.bashrc"
    # echo "${RETURN_VALUE[1]}"
    # echo "MUSICLOUNGE_ROOT: $MUSICLOUNGE_ROOT"
}

if ! os_detect; then
    exit 1
fi
# echo " OS:          $OS"
# echo " PKG_MANAGER: $OS_PKG_MANAGER"
# echo " SUDO_USER:   $OS_SUDO_USER"
# echo " CMD_UPDATE:  $OS_CMD_UPDATE"
# echo " CMD_INSTALL: $OS_CMD_INSTALL"

while :; do
    # clear # Очистка экрана
    USER_REMOTE_SMB_DIR=""
    USER_LOCAL_MUSIC_DIR=""
    MUSICLOUNGE_ROOT=$(printenv MUSICLOUNGE_ROOT)
    MUSICLOUNGE_LOCAL="$MUSICLOUNGE_ROOT/local"
    MUSICLOUNGE_REMOTE="$MUSICLOUNGE_ROOT/remote"
    FSTAB_OPT_SMB="cifs uid=1000,gid=1000,iocharset=utf8,${FSTAB_OPT_SMB_SRV_VER_DEFAULT},nofail,x-systemd.automount,_netdev,credentials=${FILE_SMB_CREDENTIALS} 0 0"
    FSTAB_OPT_LOCAL="none  bind,x-systemd.automount  0 0"
    # FSTAB_CMD_MOUNT_LOCAL=""
    # FSTAB_CMD_MOUNT_SMB=""
    musiclounge_cfg_get
    echo
    # echo "====================="
    echo "  $ICON_BASH_SPEAKER$FONT_BOLD_BLUE Music Lounge Menu $FONT_RESET$FONT_BLUE ver:$ML_VERSION $FONT_RESET"
    # echo "====================="
    echo " 1. Install MusicLounge"
    echo " 2. Uninstall MusicLounge"
    # echo "2. Change remote music location (SMB share)"
    # echo "3. Change local music location"
    # echo "4. Change MusicLounge main path"
    echo " 3. Exit"
    # echo "====================="
    echo 
    read -p " $ICON_BASH_NOTE Please choose action: " choice

    case $choice in
        1)
            if ! musiclounge_install; then
                echo "    Installation stoped."
            fi        
            ;;
        2)
            musiclounge_uninstall
            ;;
        # 3)
        #     musiclounge_set_local_path
        #     ;;
        # 4)
        #     musiclounge_set_root_path
        #     ;;
        3)
            break 2
            ;;
        *)
            echo "Invalid input. Please try again."
            ;;
    esac

    # if [ $MUSICLOUNGE_ROOT_CHANGED ] ;then
    #     read -p "MUSICLOUNGE_ROOT_CHANGED"
    # fi
    # echo " ==> USER_REMOTE_SMB_DIR:  '$USER_REMOTE_SMB_DIR'"
    # echo " ==> USER_LOCAL_MUSIC_DIR: '$USER_LOCAL_MUSIC_DIR'"
done

exit 0



# PS3="Пожалуйста, выберите опцию: "
# options=(
#     "Change remote music location (SMB share)" 
#     "Change local music location" 
#     "Change MusicLounge path" 
#     "Install MusicLounge"
#     "About"
#     "Exit"
# )

# select opt in "${options[@]}" 
# do
#     # case $opt in
#     case $REPLY in
#         1)
#             date
#             ;;
#         2)
#             uname -a
#             ;;
#         3)
#             ls -l
#             ;;
#         4)
#             echo "TBD"
#             ;;
#         5)
#             echo "About TBD"
#             ;;

#         6)
#             break
#             ;;
#         *) echo "Неверная опция $REPLY";;
#     esac
# done
# read -p "Selected option: $REPLY"
# #exit 0
