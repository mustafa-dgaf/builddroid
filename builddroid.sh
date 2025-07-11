#!/bin/bash
version=v2.4.1
source config.ini || { echo "Error occurred while parsing config.ini"; exit 1; }

time_all="$(date +%s)"
Reset='\033[0m'
Black='\033[0;30m'
Red='\033[1;31m'
Yellow='\033[0;33m'
Green='\033[1;32m'
Orange='\e[38;5;214m'
Blue='\033[0;34m'
Purple='\033[0;35m'
Cyan='\033[1;36m'
White='\033[0;37m'

buildstatus="${Cyan}Warming up ${Reset}| Running BuildDroid ${Blue}${version}${Reset}"
directory="out/target/product/$codename"

# --------------------
#       Prepare
# --------------------

print() {
    if [ "$console" = true ]; then
        echo -e "$*"
    fi
    if [ "$telegram" = true ]; then
        local clean_message=$(echo -e "$*" | sed -r "s/\x1B\[[0-9;]*[mK]//g")
        local cleaner_message=$(echo -e "$clean_message" | sed -r "s/│  ├─ //g" | sed -r "s/│  ╰─ //g" | sed -r "s/╰─ //g" | sed -r "s/╭─ //g")
        echo $cleaner_message > status
    fi
}

telegram() {
    if [ "$telegram" = true ]; then
        curl -s "https://api.telegram.org/bot$telegramtoken/sendMessage" \
             -d "chat_id=$chat_id" \
             -d "text=$1" \
             -d "parse_mode=HTML" > /dev/null
    fi
}

rm -rf pid1 pid2 pid3
rm -rf build.log
echo $$ > pid1

# --------------------
#   Check integrity
# --------------------

if [ -e "builddroid" ]; then
    rm -rf builddroid
fi

if [ -e "builddroid.sh" ]; then
    echo -e "\nDetected older version of BuildDroid. Overwriting...\n\n"
fi
git clone https://github.com/wojtekojtek/builddroid builddroid
mv builddroid/* .

if [ "$codename" == "" ]; then
    print "╰─ ${Red}Error${Reset} | Device codename is empty"
    telegram "Error | Device codename is empty"
    exit 1
fi
if [ "$trees" == "" ] && [ "$manifest" == "" ]; then
    print "╰─ ${Red}Error${Reset} | No trees to clone"
    telegram "Error | No trees to clone"
fi
if [ "$lunch" == "" ]; then
    print "╰─ ${Red}Error${Reset} | Lunch is empty"
    telegram "Error | Lunch is empty"
    exit 1
fi
if [ "$ota" == "true" ]; then
    if [ "$githubota" == "" ] || [ "$gituser" == "" ] ||[ "$gitemail" == "" ] || [ "$gitbranch" == "" ] || [ "$jsonversion" == "" ] || [ "$jsonromtype" == ""] || [ "$githubota" == "" ] || [ "$url" == "" ]; then
        print "╰─ ${Red}Error${Reset} | Required variables for OTA are empty, check config file"
        telegram "Error | Required variables for OTA are empty, check config file"
        exit 1
    fi
fi
if [ "$ota" == "true" ] && [ "$server" == "" ] && [ "$downloadurl" == "" ]; then
    print "╰─ ${Red}Error${Reset} | No link to download OTA"
    telegram "Error | No link to download OTA"
    exit 1
fi
if [ "$telegramtoken" == "" ]; then
    if [ "$telegram" == true ]; then
        print "╰─ ${Red}Error${Reset} | Telegram token is empty"
        telegram "Error | Telegram token is empty"
        exit 1
    fi
    if [ "$chat_id" == "" ]; then
        if [ "$telegram" == true ]; then
            print "╰─ ${Red}Error${Reset} | Chat ID is empty"
            telegram "Error | Chat ID is empty"
            exit 1
        fi
    fi
    if [ "$user_id" == "" ]; then
        if [ "$telegram" == true ]; then
            print "╰─ ${Red}Error${Reset} | User ID is empty"
            telegram "Error | User ID is empty"
            exit 1
        fi
    fi
fi
if [ "$sign" == "true" ]; then
    if [ "$keys" == "" ]; then
        print "╰─ ${Red}Error${Reset} | Keys path is empty"
        telegram "Error | Keys path is empty"
        exit 1
    fi
fi
if [ "$server" == "SourceForge" ]; then
    if [ "$sfproject" == "" ] || [ "$sfdir" == "" ] || [ "$sfuser" == "" ] ||  [ "$ssh" == "" ]; then
        print "╰─ ${Red}Error${Reset} | Variables - sfdir, sfuser, sfproject or ssh are empty"
        telegram "Error | Variables - sfdir, sfuser, sfproject or ssh are empty"
        exit 1
    fi
fi
if [ "$server" == "PixelDrain" ]; then
    if [ "$pixeldraintoken" == "" ]; then
        print "╰─ ${Red}Error${Reset} | PixelDrain token is empty"
        telegram "Error | PixelDrain token is empty"
        exit 1
    fi
fi
if [ "$server" == "BashUpload" ] && [ "$private_chat_id" == "" ]; then
    print "╰─ ${Red}Error${Reset} | Private TG ChatID is empty"
    telegram "Error | Private TG ChatID is empty"
    exit 1
fi
if [ "$quiet" == "true" ]; then
    quiet="> /dev/null"
else
    quiet=""
fi
if [ "$console" = "" ]; then
    console=true
fi
if [ "$lunch" == "" ]; then
    lunch="eng"
fi
if ! [ -e "tgsrv.sh" ] || ! [ -e "config.ini" ] || ! [ -e "status.sh" ]; then
    print "╰─ ${Red}Error${Reset} | Corrupted installation"
    exit 1
fi
if ! [ -e "packages" ] || ! [ -e "vendor" ] || ! [ -e "build" ]; then
    print "╰─ ${Red}Error${Reset} | Not inside ROM sources"
    exit 1
fi
if [ $cleanbuild == "" ]; then
    cleanbuild=false
fi
if [ "$telegram" == true ]; then
    ./tgsrv.sh &
fi
print "╭─ $buildstatus"


# --------------------
#   Unsupported ROM
# --------------------

if [ "$unsupported" != "" ]; then
    if [[ "$unsupported" == repo\ init* ]]; then
        time_rom_sync="$(date +%s)"
        declare -A rom_names=(
            ["DerpFest"]="DerpFest-AOSP"
            ["LineageOS"]="LineageOS"
            ["PixelExperience"]="PixelExperience"
            ["AOSiP"]="AOSiP"
            ["EvolutionX"]="Evolution-X"
            ["CrDroid"]="crdroidandroid"
            ["HavocOS"]="Havoc-OS"
            ["ArrowOS"]="ArrowOS"
            ["ResurrectionRemix"]="ResurrectionRemix"
            ["BlissROM"]="BlissRoms"
            ["ParanoidAndroid"]="AOSPA"
            ["SyberiaOS"]="SyberiaProject"
            ["LegionOS"]="LegionOS"
            ["dotOS"]="dotOS"
            ["PixysOS"]="PixysOS"
            ["Xtended"]="Xtended"
            ["NitrogenOS"]="Nitrogen-Project"
            ["OctaviOS"]="Octavi-OS"
            ["YAAP"]="yaap"
            ["StyxProject"]="StyxProject"
            ["ElixirOS"]="Project-Elixir"
            ["ProjectSakura"]="ProjectSakura"
            ["SuperiorOS"]="SuperiorOS"
            ["InfinityX"]="ProjectInfinity-X"
            ["Nameless"]="NamelessRom"
            ["PixelOS"]="PixelOS-AOSP"
        )
        rom=""
        repo_url=$(echo "$unsupported" | grep -oP '(?<=-u )[^ ]+')
        for rom_name in "${!rom_names[@]}"; do
            if [[ "$repo_url" == *"${rom_names[$rom_name]}"* ]]; then
                rom="$rom_name"
                break
            fi
        done
        unset repo_url
        if [ "$rom" != "" ]; then
            buildstatus="${Cyan}Downloading unsupported ROM${Reset} | ${Cyan}${rom}${Reset}"
        else
            buildstatus="${Cyan}Downloading unsupported ROM${Reset}"
        fi
        print "├─ $buildstatus"
        $unsupported $quiet
        status_rom="unsupported"
        /opt/crave/resync.sh $quiet
        time_rom_sync="$(($(date +%s) - time_rom_sync))"
        time_rom_sync="$((time_rom_sync / 3600))h $(((time_rom_sync % 3600) / 60))min $((time_rom_sync % 60))s"
        time_rom_sync="$(echo $time_rom_sync | sed 's/^0h //; s/ 0min//; s/^0min //')"
    fi
fi

# Define ROMs in priority order (highest first)
ROM_PRIORITY=(
    "DerpFest:vendor/derp"
    "PixelExperience:pe.mk"
    "AOSiP:vendor/aosip"
    "EvolutionX:vendor/evolution"
    "crDroid:vendor/crdroid"
    "HavocOS:vendor/havoc"
    "ArrowOS:vendor/arrow"
    "ResurrectionRemix:vendor/resurrection"
    "BlissROM:vendor/bliss"
    "ParanoidAndroid:vendor/pa"
    "SyberiaOS:vendor/syberia"
    "LegionOS:vendor/legion"
    "dotOS:vendor/dotos"
    "PixysOS:vendor/pixys"
    "Xtended:vendor/xtended"
    "NitrogenOS:vendor/nitrogen"
    "OctaviOS:vendor/octavi"
    "YAAP:vendor/yaap"
    "StyxProject:vendor/styx"
    "ElixirOS:vendor/elixir"
    "ProjectSakura:vendor/sakura"
    "SuperiorOS:vendor/superior"
    "Nameless:vendor/nameless"
    "InfinityX:vendor/infinity"
    "PixelOS:vendor/pixelos"
    "LineageOS:build/soong/Android.bp"
    "AOSP:build/make/core/envsetup.mk"
)
ROM_DETECTED=""
for ENTRY in "${ROM_PRIORITY[@]}"; do
    ROM="${ENTRY%%:*}"
    FILE="${ENTRY#*:}"

    if [[ -e "$FILE" ]]; then
        ROM_DETECTED="$ROM"
        break
    fi
done
if [[ "$ROM_DETECTED" == "false" ]]; then
    ROM=""
    if ! [ "$rom" == "" ]; then
        ROM=$rom
    fi
else
    if [ "$status_rom" == "unsupported" ]; then
        if ! [ "$rom" == "$ROM" ]; then
            print "├─ ${Orange}WARNING: ROM mismatch detected!\n${Reset}│    ${Orange}Expected ROM: ${Reset}${rom}${Orange}\n${Reset}│${Orange}    Detected ROM: ${Reset}${ROM}\n│ \n│    ${Orange}Continuing anyway...${Reset}"
            telegram "ROM mismatch detected!
Expected: <b>${rom}</b>
Detected: <b>${ROM}</b>"
        fi
    fi
fi
if [ "$rom" == "" ]; then
    rom="$ROM"
fi
if [ "$cleanbuild" == true ]; then
    print "├─ ${Cyan}Cleaning build directory${Reset}"
    rm -rf out
fi

# --------------------
#  Signing and trees
# --------------------

if [ "$sign" == "true" ]; then
    if [ -e "$keys" ]; then
        if [ -e "${keys}/bluetooth.x509.pem" ] && [ -e "${keys}/bluetooth.pk8" ] && [ -e "${keys}/media.x509.pem" ] && [ -e "${keys}/media.pk8" ] && [ -e "${keys}/networkstack.x509.pem" ] && [ -e "${keys}/networkstack.pk8" ] && [ -e "${keys}/nfc.x509.pem" ] && [ -e "${keys}/nfc.pk8" ] && [ -e "${keys}/otakey.x509.pem" ] && [ -e "${keys}/otakey.pk8" ] && [ -e "${keys}/platform.x509.pem" ] && [ -e "${keys}/platform.pk8" ] && [ -e "${keys}/releasekey.x509.pem" ] && [ -e "${keys}/releasekey.pk8" ] && [ -e "${keys}/sdk_sandbox.x509.pem" ] && [ -e "${keys}/sdk_sandbox.pk8" ] && [ -e "${keys}/shared.x509.pem" ] && [ -e "${keys}/shared.pk8" ] && [ -e "${keys}/testkey.x509.pem" ] && [ -e "${keys}/testkey.pk8" ] && [ -e "${keys}/verity.x509.pem" ] && [ -e "${keys}/verity.pk8" ]; then
            sign=true
        else
            missing_keys="$(for key in bluetooth media networkstack nfc otakey platform releasekey sdk_sandbox shared testkey verity; do if [ ! -e "${keys}/${key}.x509.pem" ] || [ ! -e "${keys}/${key}.pk8" ]; then echo $key; fi; done)"
            sign=false
            missing_keys=$(echo $missing_keys | tr '\n' ' ')
            print "├─ ${Red}Error${Reset} | Missing key files: ${missing_keys}"
            telegram "Error | Missing key files: ${missing_keys}. Build won't be signed."
        fi
    fi
fi
if [ "$sign" == "true" ]; then # to be done: support for other ROMs
    if [ -e "vendor/derp/signing/keys" ]; then
        cp -af "${keys}"/* "vendor/derp/signing/keys"
    else
        telegram "Build <u>won't be signed</u>, ROM is not supported. If you know how to support it, open a pull request on github."
    fi
fi
if [ "$manifest" != "" ]; then
    if [[ "$manifest" == *github.com* ]]; then
        buildstatus="${Cyan}Downloading manifest from GitHub${Reset}"
        print "├─ $buildstatus"
        $manifest .repo/local_manifests/roomservice.xml $quiet
    else
        if command -v wget &> /dev/null; then
            buildstatus="${Cyan}Downloading manifest using wget${Reset}"
            print "├─ $buildstatus"
            wget $manifest -O .repo/local_manifests/roomservice.xml $quiet
        elif command -v curl &> /dev/null; then
            buildstatus="${Cyan}Downloading manifest using curl${Reset}"
            print "├─ $buildstatus"
            curl -o .repo/local_manifests/roomservice.xml $manifest $quiet
        else
            print "├─ ${Red}Error${Reset} | Neither wget nor curl found, no method to download manifest"
            telegram "Error | Neither wget nor curl found, no method to download manifest"
        fi
    fi
    if [ -e ".repo/local_manifests/roomservice.xml" ]; then
        time_trees="$(date +%s)"
        /opt/crave/resync.sh $quiet
        time_trees="$(($(date +%s) - time_trees))"
        time_trees="$((time_trees / 3600))h $(((time_trees % 3600) / 60))min $((time_trees % 60))s"
        time_trees="$(echo $time_trees | sed 's/^0h //; s/ 0min//; s/^0min //')"
    fi
fi
if [ "$trees" != "" ]; then
    if ! [ -e ".repo/local_manifests/roomservice.xml" ]; then
        time_trees="$(date +%s)"
        buildstatus="${Cyan}Downloading trees${Reset}"
        print "├─ $buildstatus"
        echo "$trees" | while IFS= read -r line; do
            if [ -z "$line" ]; then
                continue
            fi
            dir=$(echo "$line" | awk '{print $(NF-2)}')
            if [ -d "$dir" ]; then
                print "│  ├─ ${Cyan}Removing directory: ${Reset}$dir"
                if [[ $dir == "hardware/samsung" ]]; then
                    if [ -e "hardware/samsung/nfc" ]; then
                        # print "│  │  ├─ ${Cyan}Backing up NFC${Reset}"
                        mkdir hardware/tmp
                        mv hardware/samsung/nfc hardware/tmp
                        rm -rf hardware/samsung/nfc
                        nfcfix=true
                        print "│     ├─ ${Cyan}Cloning trees${Reset}"
                    fi
                fi
                rm -rf "$dir"
            fi
        done
        if [[ $trees == *"hardware/samsung"* ]]; then
            if [ -e "hardware/samsung/nfc" ]; then
                print "│     ├─ ${Cyan}Cloning trees${Reset}"
            fi
        else
            print "│  ╰─ ${Cyan}Cloning trees${Reset}"
        fi
        echo "$trees" | while read -r line; do
            $line $quiet
        done
        if [ -e "hardware/tmp/nfc" ]; then
            print "│     ╰─ ${Cyan}Restoring NFC${Reset}"
            mv hardware/tmp/nfc hardware/samsung/nfc
            rm -rf hardware/tmp
        fi
    fi
fi

# --------------------
#       OTA setup
# --------------------

if [ "$ota" == "true" ]; then
    print "├─ ${Cyan}Setting up OTA${Reset}"
    file_path="packages/apps/Updater/app/src/main/res/values/strings.xml"
    if [[ ! -f "$file_path" ]]; then
        print "│  ╰─ ${Red}Error${Reset} | Looks like the strings.xml file is missing, please check $file_path"
        telegram "Looks like the strings.xml file is missing, please check logs"
        status_ota=fail
    else
        print "│  ├─ ${Cyan}Replacing Updater Server URL${Reset}"
        sed -i -E "s|(<string name=\"updater_server_url\" translatable=\"false\">).*?(</string>)|\1$url/{device}.json\2|g" "$file_path"
        print "│  ├─ ${Cyan}Updater Server URL replaced${Reset}"

        print "│  ├─ ${Cyan}Replacing Changelog URL${Reset}"
        sed -i -E "s|(<string name=\"menu_changelog_url\" translatable=\"false\">).*?(</string>)|\1$url/changelog_<xliff:g id=\"device_name\">%1\\\$s</xliff:g>.txt\2|g" "$file_path"
        print "│  ╰─ ${Cyan}Changelog URL replaced${Reset}"
        status_ota=success
    fi
    unset file_path
fi
if [ "$ROM" == "DerpFest" ]; then
    if [ -e "hardware/samsung/dap" || -e "hardware/samsung/doze" ]; then
        print "├─ ${Cyan}Applying fix for DerpFest 14${Reset}"
        cd vendor/support/res/values
        rm -rf attrs.xml
        curl https://pastebin.com/raw/aCi9YAvL --output attrs.xml $quiet
        cd ../../../..
        cd hardware/samsung
        print "│  ╰─ ${Cyan}Fixing conflicting files in ${Reset}hardware/samsung"
        rm -rf doze dap
        cd ../..
    else
        print "│  ╰─ ${Cyan}Applying fix for DerpFest 14${Reset}"
        cd vendor/support/res/values
        rm -rf attrs.xml
        curl https://pastebin.com/raw/aCi9YAvL --output attrs.xml $quiet
        cd ../../../..
    fi
elif [ "$ROM" == "InfinityX" ]; then
    if [ -e "hardware/samsung/dap" || -e "hardware/samsung/doze"  || -e "hardware/samsung/AdvancedDisplay" ]; then
        print "│  ╰─ ${Cyan}Applying fix for Infinity X${Reset}"
        cd hardware/samsung
        print "│  ╰─ ${Cyan}Fixing conflicting files in ${Reset}hardware/samsung"
        rm -rf doze dap AdvancedDisplay
        cd ../..
    fi
fi

# --------------------
#     Build ROM
# --------------------

time_build="$(date +%s)"
source build/envsetup.sh $quiet
mka installclean
./status.sh &
case "$rom" in
    "DerpFest")
        print "├─ ${Cyan}Building DerpFest${Reset}"
        lunch derp_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka derp -j$(nproc --all) | tee build.log
        else
            mka derp -j$(nproc --all)
        fi
        ;;
    "LineageOS")
        print "├─ ${Cyan}Building LineageOS${Reset}"
        lunch lineage_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "PixelExperience")
        print "├─ ${Cyan}Building PixelExperience${Reset}"
        lunch aosp_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "AOSiP")
        print "├─ ${Cyan}Building AOSiP${Reset}"
        lunch aosip_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka kronic -j$(nproc --all) | tee build.log
        else
            mka kronic -j$(nproc --all)
        fi
        ;;
    "EvolutionX")
        print "├─ ${Cyan}Building EvolutionX${Reset}"
        lunch evolution_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka evolution -j$(nproc --all) | tee build.log
        else
            mka evolution -j$(nproc --all)
        fi
        ;;
    "crDroid")
        print "├─ ${Cyan}Building crDroid${Reset}"
        lunch lineage_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "HavocOS")
        print "├─ ${Cyan}Building HavocOS${Reset}"
        lunch havoc_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka havoc -j$(nproc --all) | tee build.log
        else
            mka havoc -j$(nproc --all)
        fi
        ;;
    "ArrowOS")
        print "├─ ${Cyan}Building ArrowOS${Reset}"
        lunch arrow_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "ResurrectionRemix")
        print "├─ ${Cyan}Building ResurrectionRemix${Reset}"
        lunch resurrection_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "BlissROM")
        print "├─ ${Cyan}Building BlissROM${Reset}"
        lunch bliss_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka blissify -j$(nproc --all) | tee build.log
        else
            mka blissify -j$(nproc --all)
        fi
        ;;
    "ParanoidAndroid")
        print "├─ ${Cyan}Building ParanoidAndroid${Reset}"
        lunch aosp_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "SyberiaOS")
        print "├─ ${Cyan}Building SyberiaOS${Reset}"
        lunch syberia_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "LegionOS")
        print "├─ ${Cyan}Building LegionOS${Reset}"
        lunch legion_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "dotOS")
        print "├─ ${Cyan}Building dotOS${Reset}"
        lunch dot_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "PixysOS")
        print "├─ ${Cyan}Building PixysOS${Reset}"
        lunch pixys_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka pixys -j$(nproc --all) | tee build.log
        else
            mka pixys -j$(nproc --all)
        fi
        ;;
    "Xtended")
        print "├─ ${Cyan}Building Xtended${Reset}"
        lunch xtended_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka xtended -j$(nproc --all) | tee build.log
        else
            mka xtended -j$(nproc --all)
        fi
        ;;
    "NitrogenOS")
        print "├─ ${Cyan}Building NitrogenOS${Reset}"
        lunch nitrogen_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "OctaviOS")
        print "├─ ${Cyan}Building OctaviOS${Reset}"
        lunch octavi_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "YAAP")
        print "├─ ${Cyan}Building YAAP${Reset}"
        lunch yaap_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "StyxProject")
        print "├─ ${Cyan}Building StyxProject${Reset}"
        lunch styx_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "ElixirOS")
        print "├─ ${Cyan}Building ElixirOS${Reset}"
        lunch elixir_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "ProjectSakura")
        print "├─ ${Cyan}Building ProjectSakura${Reset}"
        lunch sakura_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "SuperiorOS")
        print "├─ ${Cyan}Building SuperiorOS${Reset}"
        lunch superior_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "Nameless")
        print "├─ ${Cyan}Building Nameless ROM${Reset}"
        lunch nameless_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "PixelOS")
        print "├─ ${Cyan}Building PixelOS${Reset}"
        lunch pixelos_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "InfinityX")
        print "├─ ${Cyan}Building Infinity X${Reset}"
        lunch infinity_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    "AOSP")
        print "├─ ${Cyan}Building AOSP${Reset}"
        lunch aosp_${codename}-${lunch} $quiet
        if [ "$telegram" == "true" ]; then
            mka bacon -j$(nproc --all) | tee build.log
        else
            mka bacon -j$(nproc --all)
        fi
        ;;
    *)
        print "╰─ ${Red}Error:${Reset} Unknown ROM ${Reset}'${rom}'${Reset}"
        exit 1
        ;;
esac
time_build="$(($(date +%s) - time_build))"
time_build="$((time_build / 3600))h $(((time_build % 3600) / 60))min $((time_build % 60))s"
time_build="$(echo $time_build | sed 's/^0h //; s/ 0min//; s/^0min //')"
if [ -e "pid2" ]; then
    pid2=$(cat pid2)
    kill -9 $pid2
    rm -rf pid2
fi

# --------------------
#       Upload
# --------------------

if [[ -d "$directory" ]]; then
        rom_zip=$(find "$directory" -type f -name "*.zip" -size +1G)
        if [[ -n "$rom_zip" ]]; then
            status_build="success"
        else
            status_build="fail"
            print "├─ ${Red}Error: Unknown ROM ${Reset}'${rom}'"
        fi
    else
        print "├─ ${Orange}Directory ${Reset}${directory}${Orange} does not exist${Reset}"
        status_build="fail"
fi
if [ "$server" == BashUpload ]; then
    if ! [ "status_build" == "fail" ]; then
        time_upload="$(date +%s)"
        print "├─ ${Cyan}Uploading to${Reset} BashUpload"
        chmod +r "$rom_zip"
        curl bashupload.com -T "$rom_zip" > downloadlog.txt
        print "│  ╰─ ${Cyan}Upload finished!${Reset}"
        curl -s -X POST https://api.telegram.org/bot$telegramtoken/sendMessage -d chat_id=$private_chat_id -d text="$(cat downloadlog.txt)" > /dev/null 2>&1
        rm -rf downloadlog.txt
        time_upload="$(($(date +%s) - time_upload))"
        time_upload="$((time_upload / 3600))h $(((time_upload % 3600) / 60))min $((time_upload % 60))s"
        time_upload="$(echo $time_upload | sed 's/^0h //; s/ 0min//; s/^0min //')"
    fi
fi
if [ "$server" == SourceForge ]; then
    if [ -e "$ssh" ] && ! [ "$sfproject" == "" ] && ! [ "$sfdir" == "" ] && ! [ "$sfuser" == "" ]; then
        time_upload="$(date +%s)"
        chmod 600 "$ssh"
        chown $(whoami):$(whoami) "$ssh"
        DESTINATION="${sfuser}@frs.sourceforge.net:/home/frs/project/$sfproject/$sfdir/"
        MESSAGE="Starting upload of $FILE to SourceForge project $PROJECT, directory $DIRECTORY..."
        RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$telegramtoken/sendMessage" \
            -d chat_id="$chat_id" \
            -d text="$MESSAGE")
        MESSAGE_ID=$(echo "$RESPONSE" | grep -o '"message_id":[0-9]*' | cut -d: -f2)
        PROGRESS_FILE="./rsync_progress"
        {
            rsync --progress -e "ssh -i $ssh -o StrictHostKeyChecking=no" "$rom_zip" "$DESTINATION" | while IFS= read -r line; do
                if [[ "$line" =~ ([0-9]+)% ]]; then
                    PROGRESS="${BASH_REMATCH[1]}%"
                    echo "$PROGRESS" > "$PROGRESS_FILE"
                fi
            done
        } &
        while kill -0 $! 2>/dev/null; do
            if [[ -f "$PROGRESS_FILE" ]]; then
                PROGRESS=$(cat "$PROGRESS_FILE")
                EDIT_MESSAGE="Uploading $jsonfilename to SourceForge project $PROJECT, directory $DIRECTORY... Progress: $PROGRESS"
                curl -s -X POST "https://api.telegram.org/bot$telegramtoken/editMessageText" \
                    -d chat_id="$chat_id" \
                    -d message_id="$MESSAGE_ID" \
                    -d text="$EDIT_MESSAGE" >/dev/null
            fi
            sleep 2
        done
        if wait $!; then
            FINAL_MESSAGE="Upload of $jsonfilename to SourceForge project $PROJECT, directory $DIRECTORY completed successfully!"
            curl -s -X POST "https://api.telegram.org/bot$telegramtoken/editMessageText" \
                -d chat_id="$chat_id" \
                -d message_id="$MESSAGE_ID" \
                -d text="$FINAL_MESSAGE" >/dev/null
            rm -f "$PROGRESS_FILE"
        else
            ERROR_MESSAGE="Upload of $jsonfilename to SourceForge project $PROJECT, directory $DIRECTORY failed. Please check logs."
            curl -s -X POST "https://api.telegram.org/bot$telegramtoken/editMessageText" \
                -d chat_id="$chat_id" \
                -d message_id="$MESSAGE_ID" \
                -d text="$ERROR_MESSAGE" >/dev/null
        fi
        unset MESSAGE RESPONSE MESSAGE_ID PROGRESS_FILE PROGRESS EDIT_MESSAGE FINAL_MESSAGE ERROR_MESSAGE
        time_upload="$(($(date +%s) - time_upload))"
        time_upload="$((time_upload / 3600))h $(((time_upload % 3600) / 60))min $((time_upload % 60))s"
        time_upload="$(echo $time_upload | sed 's/^0h //; s/ 0min//; s/^0min //')"
    fi
fi
if [ "$server" == PixelDrain ]; then
    time_upload="$(date +%s)"
    response=$(curl -s -T "$rom_zip" -u :${pixeldraintoken} https://pixeldrain.com/api/file)
    status_upload=$(echo "$response" | jq -r '.success')
    if [ "$status_upload" == "true" ]; then
        status_upload="success"
        downloadurl=$(echo "$response" | jq -r '.url')
    else
        status_upload="fail"
        status_upload_error=$(echo "$response" | jq -r '.message')
    fi
    time_upload="$(($(date +%s) - time_upload))"
    time_upload="$((time_upload / 3600))h $(((time_upload % 3600) / 60))min $((time_upload % 60))s"
    time_upload="$(echo $time_upload | sed 's/^0h //; s/ 0min//; s/^0min //')"
fi

# --------------------
#     Update JSON
# --------------------

if [ "$ota" == "true" ]; then
    if [ "$status_build" == "success" ]; then
        print "├─ ${Cyan}Generating OTA JSON${Reset}"
        jsondatetime=$(date +%s)
        jsonsize=$(stat -c%s "$rom_zip")
        jsonfilename=$(basename "$rom_zip")
        jsonid=$(sha256sum "$rom_zip" | awk '{print $1}')
        if [ "$downloadurl" == "" ]; then
            if [ "$server" == "SourceForge" ]; then
                downloadurl="https://sourceforge.net/projects/$sfproject/files/$sfdir/$jsonfilename/download"
                status_ota="success"
            elif [ "$server" == "PixelDrain" ]; then
                downloadurl="$downloadlink"
                status_ota="success"
            else
                telegram "Error | Download URL is empty"
                print "│  ╰─ ${Red}Error${Reset} | Download URL is empty"
                status_ota="fail"
            fi
        fi
        if [ "$status_ota" == "success" ]; then
            cat <<EOF > "${codename}.json"
{
  "response": [
    {
      "datetime": $jsondatetime,
      "filename": "$jsonfilename",
      "id": "$jsonid",
      "romtype": "$jsonromtype",
      "size": $jsonsize,
      "url": "$downloadurl",
      "version": "$jsonversion"
    }
  ]
}
EOF
        fi
        if [ -e "${codename}.json" ]; then
            status_ota="success"
        else
            status_ota="fail"
        fi
    fi
fi
if [ "$ota" == "true" ]; then
    if [ "$status_ota" == "success" ]; then
        print "│  ╰─ ${Cyan}Uploading JSON${Reset}"
        gitrepouser=$(echo $githubota | cut -d'/' -f1)
        gitreponame=$(echo $githubota | cut -d'/' -f2)
        if ! [ "$gitbranch" == "" ]; then
            gitbranchb="-b $gitbranch"
        fi
        git clone https://github.com/${githubota} $gitbranchb
        if [ -e "changelog_${codename}.txt" ]; then
            echo -e "${Cyan}AB${Reset}: Changelog for $codename found, adding to repo..."
            mv changelog_${codename}.txt $gitreponame
        else
            echo -e "${Orange}WARN${Reset}: Changelog for $codename not found."
        fi
        mv ${codename}.json $gitreponame
        cd $gitreponame
        git config --global user.name "${githubuser}"
        git config --global user.email "${githubemail}"
        git add .
        git commit -m "New OTA build for ${codename}"
        git push https://${githubuser}:${githubtoken}@github.com/${githubota}.git $gitbranch
        cd ..
    fi
fi
time_all="$(($(date +%s) - time_all))"
time_all="$((time_all / 3600))h $(((time_all % 3600) / 60))min $((time_all % 60))s"
time_all="$(echo $time_all | sed 's/^0h //; s/ 0min//; s/^0min //')"
if [ -e "pid3" ]; then
    pid3=$(cat pid3)
    kill -9 $pid3
    rm -rf pid3
fi

# --------------------
#       Info
# --------------------

if [ "$status_build" == "success" ]; then
    print "╰─ ${Green}Build completed${Reset} | Time taken: ${time_all}"
else
    print "╰─ ${Red}Build failed${Reset} | Time taken: ${time_all}"
fi
if [ "$status_build" == "success" ]; then
    build1="<b>Build <u>success</u></b> | Time taken: ${time_all}"
    build5="Download: <a href=\"${downloadurl}\">${server}</a>"
else
    build1="<b>Build <u>failed</u></b> | Time taken: ${time_all}"
    build5=""
fi
build2="Built <b>${ROM}</b> for <b>${codename}</b>, <b>${lunch}</b>"
build3="<b>Time statistics:</b> ROM sync: <b>${time_rom_sync}</b>, Trees: <b>${time_trees}</b>, Build: <b>${time_build}</b>, Upload: <b>${time_upload}</b>"
build4=""
if [ "$status_build" == "fail" ]; then
    if ! [ -e "./out/error.log" ]; then
        build5="No error log found"
    fi
fi
buildinfo=$(echo -e "${build1}\n${build2}\n${build3}\n${build4}\n${build5}")
telegram "${buildinfo}"
if [ $status_build == "fail" ]; then
    if [ -e "./out/error.log" ]; then
        errorlog="./out/error.log"
        curl -v -F "chat_id=${chat_id}" -F document=@${errorlog} https://api.telegram.org/bot${telegramtoken}/sendDocument > /dev/null 2>&1
        unset errorlog
    fi
fi
if [ "$status_build" == "success" ]; then
    exit 0
else
    exit 1
fi
