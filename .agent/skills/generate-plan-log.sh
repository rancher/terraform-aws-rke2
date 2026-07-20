#!/usr/bin/env bash
set -euo pipefail

# This skill script extracts the "Purpose" and execution dates of all plans
# in the plans directory (excluding README.md), sorts them, and filters them
# by year or year and month, then outputs them as a Plan Log.

readonly PLANS_DIR="${PLANS_DIR:-.agent/plans}"

# Default options
SORT_ORDER="desc" # Default to newest first
FILTER_YEAR=""
FILTER_MONTH=""
FILTER_PATTERN=""

show_usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  -s, --sort <asc|desc>    Sort plans by executed date (default: desc)."
    echo "  -y, --year <YYYY>        Filter plans by year (e.g., 2026)."
    echo "  -m, --month <MM>         Filter plans by month (e.g., 07)."
    echo "  -f, --filter <YYYY[-MM]> Filter plans by year or year-month (e.g., 2026 or 2026-07)."
    echo "  -h, --help               Show this help message."
    echo ""
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--sort)
            if [[ -n "${2:-}" && ( "$2" == "asc" || "$2" == "desc" ) ]]; then
                SORT_ORDER="$2"
                shift 2
            else
                echo "Error: --sort requires 'asc' or 'desc'" >&2
                show_usage
                exit 1
            fi
            ;;
        -y|--year)
            if [[ -n "${2:-}" && "$2" =~ ^[0-9]{4}$ ]]; then
                FILTER_YEAR="$2"
                shift 2
            else
                echo "Error: --year requires a 4-digit year (e.g., 2026)" >&2
                show_usage
                exit 1
            fi
            ;;
        -m|--month)
            if [[ -n "${2:-}" && "$2" =~ ^[0-9]{2}$ ]]; then
                FILTER_MONTH="$2"
                shift 2
            else
                echo "Error: --month requires a 2-digit month (e.g., 07)" >&2
                show_usage
                exit 1
            fi
            ;;
        -f|--filter)
            if [[ -n "${2:-}" && "$2" =~ ^[0-9]{4}(-[0-9]{2})?$ ]]; then
                FILTER_PATTERN="$2"
                shift 2
            else
                echo "Error: --filter requires YYYY or YYYY-MM (e.g., 2026 or 2026-07)" >&2
                show_usage
                exit 1
            fi
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            show_usage
            exit 1
            ;;
    esac
done

# If FILTER_PATTERN is set, extract year and month
if [[ -n "${FILTER_PATTERN}" ]]; then
    if [[ "${FILTER_PATTERN}" =~ ^([0-9]{4})-([0-9]{2})$ ]]; then
        FILTER_YEAR="${BASH_REMATCH[1]}"
        FILTER_MONTH="${BASH_REMATCH[2]}"
    elif [[ "${FILTER_PATTERN}" =~ ^([0-9]{4})$ ]]; then
        FILTER_YEAR="${BASH_REMATCH[1]}"
    fi
fi

extract_date() {
    local file="$1"
    local date_val
    
    date_val=$(awk 'tolower($0) ~ /^\**date completed:\**/ || tolower($0) ~ /^\**executed date:\**/ { sub(/^\**([Dd]ate [Cc]ompleted|[Ee]xecuted [Dd]ate):\**[ \t]*/, ""); print; exit }' "${file}")
    
    if [[ -z "${date_val}" ]]; then
        echo "Not specified"
    else
        echo "${date_val}"
    fi
}

extract_purpose() {
    local file="$1"
    local purpose_val
    
    purpose_val=$(awk 'tolower($0) ~ /^\**purpose:\**/ { sub(/^\**[Pp]urpose:\**[ \t]*/, ""); print; exit }' "${file}")
    
    if [[ -z "${purpose_val}" ]]; then
        echo "Not specified"
    else
        echo "${purpose_val}"
    fi
}

get_sort_key() {
    local date_val="$1"
    local lower_date
    lower_date=$(echo "${date_val}" | tr '[:upper:]' '[:lower:]')
    
    if [[ "${lower_date}" == "pending" ]]; then
        echo "9999-12-31"
    elif [[ "${date_val}" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
        echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
    elif [[ "${date_val}" =~ ^([0-9]{4})-([0-9]{2}) ]]; then
        echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-00"
    elif [[ "${date_val}" =~ ^([0-9]{4}) ]]; then
        echo "${BASH_REMATCH[1]}-00-00"
    else
        echo "0000-00-00"
    fi
}

generate_plan_log() {
    local plans_data=()
    local has_plans=false
    
    # Check if there are any markdown files
    # Use nullglob to avoid literal *.md if no files match
    shopt -s nullglob
    local files=("${PLANS_DIR}"/*.md)
    shopt -u nullglob
    
    for file in "${files[@]}"; do
        local filename
        filename=$(basename "${file}")
        
        # Skip README.md
        if [[ "${filename}" == "README.md" ]]; then
            continue
        fi
        
        has_plans=true
        local plan_name="${filename%.md}"
        local date_val
        local purpose_val
        
        date_val=$(extract_date "${file}")
        purpose_val=$(extract_purpose "${file}")
        
        # Extract year and month for filtering
        local plan_year=""
        local plan_month=""
        if [[ "${date_val}" =~ ^([0-9]{4})-([0-9]{2}) ]]; then
            plan_year="${BASH_REMATCH[1]}"
            plan_month="${BASH_REMATCH[2]}"
        elif [[ "${date_val}" =~ ^([0-9]{4}) ]]; then
            plan_year="${BASH_REMATCH[1]}"
        fi
        
        # Apply filters
        if [[ -n "${FILTER_YEAR}" ]]; then
            if [[ "${plan_year}" != "${FILTER_YEAR}" ]]; then
                continue
            fi
        fi
        
        if [[ -n "${FILTER_MONTH}" ]]; then
            if [[ "${plan_month}" != "${FILTER_MONTH}" ]]; then
                continue
            fi
        fi
        
        local sort_key
        sort_key=$(get_sort_key "${date_val}")
        
        # Store as standard delimited line: sort_key|plan_name|date_val|purpose_val
        plans_data+=("${sort_key}|${plan_name}|${date_val}|${purpose_val}")
    done
    
    if [[ "${has_plans}" == false ]]; then
        echo "No plans found in ${PLANS_DIR}."
        return
    fi
    
    if [[ ${#plans_data[@]} -eq 0 ]]; then
        echo "# Plan Log"
        echo ""
        echo "No plans found matching the filter criteria."
        return
    fi
    
    echo "# Plan Log"
    echo ""
    
    # Sort options
    local sort_flag=""
    if [[ "${SORT_ORDER}" == "desc" ]]; then
        sort_flag="r"
    fi
    
    # Sort by sort_key (field 1) according to SORT_ORDER, and secondary sort by plan_name (field 2) ascending
    while IFS='|' read -r sort_key plan_name date_val purpose_val; do
        # Ignore empty lines
        if [[ -z "${plan_name}" ]]; then
            continue
        fi
        echo "## ${plan_name}"
        echo "- **Date:** ${date_val}"
        echo "- **Purpose:** ${purpose_val}"
        echo ""
    done < <(printf "%s\n" "${plans_data[@]}" | sort -t '|' -k 1,1${sort_flag} -k 2,2)
}

main() {
    if [[ ! -d "${PLANS_DIR}" ]]; then
        echo "Error: Directory ${PLANS_DIR} does not exist." >&2
        exit 1
    fi
    
    generate_plan_log
}

main "$@"
