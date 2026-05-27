require_command() {
    local command_name="$1"

    if [[ "$command_name" == /* ]]; then
        if [[ -x "$command_name" ]]; then
            return 0
        fi

        echo "ERROR: Missing required command: $command_name"
        exit 1
    fi

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "ERROR: Missing required command: $command_name"
        exit 1
    fi
}

require_executable() {
    local executable_path="$1"
    if [[ ! -x "$executable_path" ]]; then
        echo "ERROR: Missing executable: $executable_path"
        exit 1
    fi
}

require_value() {
    local name="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo "ERROR: Missing required value: $name"
        exit 1
    fi
}

refuse_unsafe_path() {
    local path_to_check="${1:A}"
    local label="$2"
    local unsafe_root="${3:-}"

    case "$path_to_check" in
        "/"|"$HOME")
            echo "ERROR: Refusing to use unsafe $label: $path_to_check"
            exit 1
            ;;
    esac

    if [[ -z "$unsafe_root" ]]; then
        return 0
    fi

    local unsafe_root_path="${unsafe_root:A}"
    case "$path_to_check" in
        "$unsafe_root_path"|"$unsafe_root_path"/*)
            echo "ERROR: Refusing to use unsafe $label: $path_to_check"
            exit 1
            ;;
    esac
}

verify_dmg() {
    local dmg_path="$1"

    for attempt in {1..5}; do
        if /usr/bin/hdiutil verify "$dmg_path"; then
            return 0
        fi

        if [[ "$attempt" -lt 5 ]]; then
            echo "DMG verification failed; retrying in 2 seconds..."
            /bin/sleep 2
        fi
    done

    return 1
}
