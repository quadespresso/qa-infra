#!/bin/bash

MKE_USER_DEFAULT='admin'
MKE_USER=$MKE_USER_DEFAULT
MKE_CONFIG_TOML_PATH_DEFAULT=/tmp/mke-config.toml
MKE_CONFIG_TOML_PATH=$MKE_CONFIG_TOML_PATH_DEFAULT

# Function to display script usage
show_usage() {
    cat <<EOF

Updates a MKE config value key to true/false.  Uses grep to find the key specified
so this utility is only reliable where the key name in config.toml is unique.

Usage:
  $0 [options]

Options:
  -h, --help                  Display this help message
  -v, --view                  Display key value
  -k, --key                   Key to update
  -b, --bool                  Boolean value to set (true/false)
  --mke-host                  MKE Manager host name (or LB name)
  --mke-user                  MKE admin user (default is $MKE_USER_DEFAULT)
  --mke-password              MKE user password
  --mke-config-toml-path      Specify where the config.toml file should be output (default is $MKE_CONFIG_TOML_PATH_DEFAULT)

EOF
}

# MKE Auth Token Function
get_mke_auth_token() {
    local MKE_USER="$1"
    local MKE_PASSWORD="$2"
    local MKE_HOST="$3"

    echo "Obtaining an auth token from MKE..." >&2
    
    local AUTHTOKEN
    AUTHTOKEN=$(curl -sk -d "{\"username\":\"$MKE_USER\",\"password\":\"$MKE_PASSWORD\"}" "https://$MKE_HOST/auth/login" | grep -oP '(?<="auth_token":")[^"]*')
    
    if [ -z "$AUTHTOKEN" ]; then
        echo "Error: Unable to obtain auth token from MKE." >&2
        return 1
    fi
    
    echo "Obtaining an auth token from MKE complete." >&2   
    echo "$AUTHTOKEN"
}

# MKE config TOML download
download_mke_config_toml() {
    local MKE_HOST="$1"
    local AUTHTOKEN="$2"
    local TOML_FILE_PATH="$3"

    echo "Downloading MKE configuration file to [$TOML_FILE_PATH]..." >&2

    local CONFIG_RESPONSE
    CONFIG_RESPONSE=$(curl --silent --insecure -X GET "https://$MKE_HOST/api/ucp/config-toml" -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN")

    if [ $? -ne 0 ]; then
        echo "Error: Unable to download MKE configuration file." >&2
        return 1
    fi

    if [ -z "$CONFIG_RESPONSE" ]; then
        echo "Error: MKE configuration file is empty." >&2
        return 1
    fi

    echo "$CONFIG_RESPONSE" > "$TOML_FILE_PATH"
    echo "Downloading MKE configuration file complete." >&2
}

# MKE config TOML upload
upload_mke_config_toml() {
    local MKE_HOST="$1"
    local AUTHTOKEN="$2"
    local TOML_FILE_PATH="$3"

    if [ ! -e "$TOML_FILE_PATH" ]; then
        echo "Error: TOML file does not exist at [$TOML_FILE_PATH]." >&2
        return 1
    fi

    echo "Uploading MKE configuration file [$TOML_FILE_PATH]..." >&2
    curl --silent --insecure -X PUT "https://$MKE_HOST/api/ucp/config-toml" -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN" --upload-file "$TOML_FILE_PATH"
    if [ $? -ne 0 ]; then
        echo "Error: Unable to upload MKE configuration file." >&2
        return 1
    fi
    echo "Uploading MKE configuration file complete." >&2
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mke-host)
            if [ -z "$2" ]; then
                printf "Error: The MKE host must be specified after --mke-host.\n"
                exit 1
            fi
            MKE_HOST="$2"
            shift 2
            ;;
        --mke-user)
            if [ -z "$2" ]; then
                printf "Error: The MKE user must be specified after --mke-user.\n"
                exit 1
            fi
            MKE_USER="$2"
            shift 2
            ;;
        --mke-password)
            if [ -z "$2" ]; then
                printf "Error: The MKE password must be specified after --mke-password.\n"
                exit 1
            fi
            MKE_PASSWORD="$2"
            shift 2
            ;;
        --mke-config-toml-path)
            if [ -z "$2" ]; then
                printf "Error: The config TOML path must be specified after --mke-config-toml-path.\n"
                exit 1
            fi
            MKE_CONFIG_TOML_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -k|--key)
            CONFIG_TOML_KEY_NAME="$2"
            shift 2
            ;;
        -b|--bool)
            if [[ "$2" != "true" && "$2" != "false" ]]; then
                echo "Invalid value for -b|--bool. Use 'true' or 'false'."
                exit 1
            fi
            CONFIG_TOML_KEY_VALUE="$2"
            shift 2
            ;;
        -v|--view)
            VIEW_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$MKE_HOST" ]; then
  read -p "Enter MKE manager host name: " MKE_HOST
fi

if [ -z "$MKE_PASSWORD" ]; then
  read -s -p "Enter MKE password for user [$MKE_USER]: " MKE_PASSWORD
fi

AUTHTOKEN=$(get_mke_auth_token "$MKE_USER" "$MKE_PASSWORD" "$MKE_HOST")
if [ $? -ne 0 ]; then
    exit 1
fi
download_mke_config_toml "$MKE_HOST" "$AUTHTOKEN" "$MKE_CONFIG_TOML_PATH"
if [ $? -ne 0 ]; then
    exit 1
fi

match_count=$(grep -c "^[[:space:]]*$CONFIG_TOML_KEY_NAME[[:space:]]*=[[:space:]]*[^\s]*" "$MKE_CONFIG_TOML_PATH")
if [ "$match_count" -gt 1 ]; then
  printf "Error: Multiple instances of MKE parameter [$CONFIG_TOML_KEY_NAME] found in [$MKE_CONFIG_TOML_PATH].  Script only targets unique keys.\n"
  exit 1
fi

CONFIG_TOML_KEY_VALUE_SETTING=$(awk -F= -v key="$CONFIG_TOML_KEY_NAME" '{gsub(/^[ \t]+|[ \t]+$/, "", $1); if ($1 == key) {gsub(/"/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}}' "$MKE_CONFIG_TOML_PATH")
if [ -z "$CONFIG_TOML_KEY_VALUE_SETTING" ]; then
  printf "A value for MKE parameter [$CONFIG_TOML_KEY_NAME] was not found.\n"
  exit 1
else
  printf "Current MKE parameter [$CONFIG_TOML_KEY_NAME] value is [$CONFIG_TOML_KEY_VALUE_SETTING].\n"
fi
if [ "$VIEW_ONLY" = true ]; then       
    exit 0
fi
if [ "$CONFIG_TOML_KEY_VALUE_SETTING" == "$CONFIG_TOML_KEY_VALUE" ]; then
    printf "The MKE [$CONFIG_TOML_KEY_NAME] value already matches the desired value - no update performed.\n"
    exit 0
fi
if [ -z "$CONFIG_TOML_KEY_VALUE" ]; then
    printf "Error: No value provded for [$CONFIG_TOML_KEY_NAME].\n"
    exit 1
fi
printf "Updating MKE [$CONFIG_TOML_KEY_NAME] parameter to [$CONFIG_TOML_KEY_VALUE]...\n"
sed -i -e "/$CONFIG_TOML_KEY_NAME =/ s/= .*/= $CONFIG_TOML_KEY_VALUE/" "$MKE_CONFIG_TOML_PATH"
printf "Updating MKE [$CONFIG_TOML_KEY_NAME] parameter complete.\n"
upload_mke_config_toml "$MKE_HOST" "$AUTHTOKEN" "$MKE_CONFIG_TOML_PATH"
if [ $? -ne 0 ]; then
    exit 1
fi
printf "Updating MKE setting complete.\n"