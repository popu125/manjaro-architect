# !/bin/bash
#
# Architect Installation Framework (2016-2017)
#
# Written by Carl Duff and @mandog for Archlinux
# Heavily modified and re-written by @Chrysostomus to install Manjaro instead
# Contributors: @papajoker, @oberon and the Manjaro-Community.
#
# This program is free software, provided under the GNU General Public License
# as published by the Free Software Foundation. So feel free to copy, distribute,
# or modify it as you wish.

main_menu() {
    declare -i loopmenu=1
    while ((loopmenu)); do
        if [[ $HIGHLIGHT != 6 ]]; then
           HIGHLIGHT=$(( HIGHLIGHT + 1 ))
        fi

        DIALOG " $_MMTitle " --default-item ${HIGHLIGHT} \
          --menu "\n$_MMBody\n " 0 0 6 \
          "1" "$_PrepMenuTitle|>" \
          "2" "$_InstBsMenuTitle|>" \
          "3" "$_ConfBseMenuTitle|>" \
          "4" "$_SeeConfOptTitle" \
          "5" "$_InstAdvBase|>" \
          "6" "$_Done" 2>${ANSWER}
        HIGHLIGHT=$(cat ${ANSWER})

        case $(cat ${ANSWER}) in
            "1") prep_menu
                ;;
            "2") check_mount && install_base_menu
                ;;
            "3") check_base && config_base_menu
                ;;
            "4") check_base && {
                    type edit_configs &>/dev/null || import ${LIBDIR}/util-config.sh
                    edit_configs
                    }
                ;;
            "5") check_base && {
                    type advanced_menu &>/dev/null || import ${LIBDIR}/util-advanced.sh
                    advanced_menu
                    }
                ;;
             *) loopmenu=0
                exit_done
                ;;
        esac
    done
}

# Preparation
prep_menu() {
    local PARENT="$FUNCNAME"
    declare -i loopmenu=1
    while ((loopmenu)); do
        submenu 7
        DIALOG " $_PrepMenuTitle " --default-item ${HIGHLIGHT_SUB} --menu "\n$_PrepMenuBody\n " 0 0 7 \
          "1" "$_VCKeymapTitle" \
          "2" "$_DevShowOpt" \
          "3" "$_PrepPartDisk" \
          "4" "$_PrepLUKS" \
          "5" "$_PrepLVM $_PrepLVM2" \
          "6" "$_PrepMntPart" \
          "7" "$_Back" 2>${ANSWER}
        HIGHLIGHT_SUB=$(cat ${ANSWER})

        case $(cat ${ANSWER}) in
            "1") select_keymap
                 set_keymap
                 ;;
            "2") show_devices
                 ;;
            "3") umount_partitions
                 select_device && create_partitions
                 ;;
            "4") luks_menu
                 ;;
            "5") lvm_menu
                 ;;
            "6") mount_partitions
                 ;;
            *) loopmenu=0
                return 0
                 ;;
        esac
    done
}

# Base Installation
install_base_menu() {
    local PARENT="$FUNCNAME"
    declare -i loopmenu=1
    while ((loopmenu)); do
        submenu 6
        DIALOG " $_InstBsMenuTitle " --default-item ${HIGHLIGHT_SUB} --menu "\n$_InstBseMenuBody\n " 0 0 6 \
          "1" "$_PrepMirror|>" \
          "2" "$_PrepPacKey" \
          "3" "$_InstBse" \
          "4" "$_InstDEStable|>" \
          "5" "$_InstBootldr" \
          "6" "$_Back" 2>${ANSWER}
        HIGHLIGHT_SUB=$(cat ${ANSWER})

        case $(cat ${ANSWER}) in
            "1") configure_mirrorlist
                 ;;
            "2") clear
                 (
                    ctrlc(){
                      return 0
                    }
                    trap ctrlc SIGINT
                    trap ctrlc SIGTERM
                    pacman-key --init;pacman-key --populate archlinux manjaro;pacman-key --refresh-keys;
                    check_for_error 'refresh pacman-keys'
                  )
                 ;;
            "3") install_base
                 ;;
            "4") check_base && install_manjaro_de_wm_pkg
                    local err=$?
                    if [[ $err > 0 ]]; then
                        DIALOG " $_InstBseTitle " --msgbox "\n$_InstFail\n " 0 0;
                        if [[ $err == 255 ]]; then
                            cat /tmp/basestrap.log
                            read -n1 -s
                        fi
                    fi
                 ;;
            "5") install_bootloader
                 ;;
            *) loopmenu=0
                return 0
                 ;;
        esac
    done
}

# Base Configuration
config_base_menu() {
    local PARENT="$FUNCNAME"
    declare -i loopmenu=1
    while ((loopmenu)); do
        submenu 8
        DIALOG " $_ConfBseMenuTitle " --default-item ${HIGHLIGHT_SUB} --menu "\n$_ConfBseBody\n " 0 0 8 \
          "1" "$_ConfBseFstab" \
          "2" "$_ConfBseHost" \
          "3" "$_ConfBseSysLoc" \
          "4" "$_PrepKBLayout" \
          "5" "$_ConfBseTimeHC" \
          "6" "$_ConfUsrRoot" \
          "7" "$_ConfUsrNew" \
          "8" "$_Back" 2>${ANSWER}
        HIGHLIGHT_SUB=$(cat ${ANSWER})

        case $(cat ${ANSWER}) in
            "1") generate_fstab
                ;;
            "2") set_hostname
                ;;
            "3") set_locale
                ;;
            "4") set_xkbmap
                ;;
            "5") set_timezone && set_hw_clock
                ;;
            "6") set_root_password
                ;;
            "7") create_new_user
                ;;
            *) loopmenu=0
                return 0
                ;;
        esac
    done
}

install_drivers_menu() {
    HIGHLIGHT_SUB=1
    declare -i loopmenu=1
    while ((loopmenu)); do
        DIALOG " $_InstDrvTitle " --default-item ${HIGHLIGHT_SUB} --menu "\n " 0 0 3 \
          "1" "$_InstGrMenuTitle|>" \
          "2" "$_InstNWDrv" \
          "3" "$_Back" 2>${ANSWER}

        case $(cat ${ANSWER}) in
            "1") install_graphics_menu
                HIGHLIGHT_SUB=2
                ;;
            "2") setup_network_drivers || DIALOG " $_InstBseTitle " --infobox "\n$_InstFail\n " 0 0
                HIGHLIGHT_SUB=3
                ;;
            *) HIGHLIGHT_SUB=5
                loopmenu=0
                return 0
                ;;
        esac
    done
}

install_graphics_menu() {
    DIALOG " $_InstGrMenuDD " --menu "\n " 0 0 4 \
      "1" "$_InstFree" \
      "2" "$_InstProp" \
      "3" "$_SelDDrv" \
      "4" "$_InstAllDrv" 2>${ANSWER} || return 0

    case $(cat ${ANSWER}) in
        "1") clear
            arch_chroot "mhwd -a pci free 0300" 2>$ERR
            check_for_error "$_InstFree" $?
            touch /mnt/.video_installed
            ;;
        "2") clear
            arch_chroot "mhwd -a pci nonfree 0300" 2>$ERR
            check_for_error "$_InstProp" $?
            touch /mnt/.video_installed
            ;;
        "3") setup_graphics_card
            ;;
        "4") install_all_drivers
            check_for_error "$_InstAllDrv" $?
            touch /mnt/.video_installed
            ;;
    esac
}
