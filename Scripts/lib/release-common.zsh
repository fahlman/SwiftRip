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

require_file() {
    local file_path="$1"
    local label="${2:-file}"

    if [[ ! -f "$file_path" ]]; then
        echo "ERROR: Missing $label: $file_path"
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

codesign_entitlements() {
    local target_path="$1"
    local output_path="$2"
    /usr/bin/codesign -d --entitlements - "$target_path" > "$output_path" 2>/dev/null
}

assert_no_debug_entitlement() {
    local entitlements_path="$1"
    if /usr/bin/grep -q "com.apple.security.get-task-allow" "$entitlements_path"; then
        echo "ERROR: Release app has the debug get-task-allow entitlement."
        echo "$entitlements_path"
        exit 1
    fi
}

assert_entitlement_present() {
    local entitlements_path="$1"
    local entitlement="$2"
    if ! /usr/bin/grep -q "$entitlement" "$entitlements_path"; then
        echo "ERROR: Missing expected entitlement: $entitlement"
        echo "$entitlements_path"
        exit 1
    fi
}

assert_entitlement_absent() {
    local entitlements_path="$1"
    local entitlement="$2"
    if /usr/bin/grep -q "$entitlement" "$entitlements_path"; then
        echo "ERROR: Found unwanted entitlement: $entitlement"
        echo "$entitlements_path"
        exit 1
    fi
}

signing_identity_available() {
    local signing_identity="$1"
    /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -Fq "$signing_identity"
}

json_escape() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

json_string() {
    local value="$1"

    printf '"%s"' "$(json_escape "$value")"
}

write_release_manifest() {
    local manifest_path="$1"
    local app_name="$2"
    local version="$3"
    local bundle_identifier="$4"
    local release_arch="$5"
    local sparkle_feed_url="$6"
    local app_path="$7"
    local dmg_path="$8"
    local notarized="$9"
    local dmg_name
    local dmg_sha256
    local generated_at

    dmg_name="$(basename "$dmg_path")"
    dmg_sha256="$(/usr/bin/shasum -a 256 "$dmg_path" | /usr/bin/awk '{print $1}')"
    generated_at="$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"

    cat > "$manifest_path" <<EOF
{
  "appName": $(json_string "$app_name"),
  "version": $(json_string "$version"),
  "bundleIdentifier": $(json_string "$bundle_identifier"),
  "architecture": $(json_string "$release_arch"),
  "sparkleFeedURL": $(json_string "$sparkle_feed_url"),
  "appPath": $(json_string "$app_path"),
  "dmgName": $(json_string "$dmg_name"),
  "dmgPath": $(json_string "$dmg_path"),
  "dmgSHA256": $(json_string "$dmg_sha256"),
  "notarized": $notarized,
  "generatedAt": $(json_string "$generated_at")
}
EOF
}
