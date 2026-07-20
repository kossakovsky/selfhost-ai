#!/bin/bash
# =============================================================================
# 03_generate_secrets.sh - Secret and configuration generator
# =============================================================================
# Generates secure passwords, JWT secrets, API keys, and encryption keys for
# all services. Creates the .env file from .env.example template.
#
# Features:
#   - Generates cryptographically secure random values (passwords, secrets, keys)
#   - Creates bcrypt hashes for Caddy basic auth using `caddy hash-password`
#   - Preserves existing user-provided values in .env on re-run
#   - Supports --update flag to add new variables without regenerating existing
#   - Prompts for domain name and Let's Encrypt email
#
# Secret types: password (alphanum), secret (base64), hex, api_key, jwt
#
# Usage: bash scripts/03_generate_secrets.sh [--update]
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Source telemetry functions
source "$SCRIPT_DIR/telemetry.sh"

# Setup cleanup for temporary files
TEMP_FILES=()
cleanup_temp_files() {
    for f in "${TEMP_FILES[@]}"; do
        rm -f "$f" 2>/dev/null
    done
}
trap cleanup_temp_files EXIT

# Check for openssl
require_command "openssl" "Please ensure openssl is installed and available in your PATH."

# --- Configuration ---
TEMPLATE_FILE="$PROJECT_ROOT/.env.example"
OUTPUT_FILE="$PROJECT_ROOT/.env"

# Variables that get assigned the user's email address
EMAIL_VARS=(
    "COMFYUI_USERNAME"
    "DASHBOARD_USERNAME"
    "DOCLING_USERNAME"
    "INVOKEAI_USERNAME"
    "LANGFUSE_INIT_USER_EMAIL"
    "LETSENCRYPT_EMAIL"
    "LIGHTRAG_USERNAME"
    "LT_USERNAME"
    "PADDLEOCR_USERNAME"
    "PROMETHEUS_USERNAME"
    "RAGAPP_USERNAME"
    "SEARXNG_USERNAME"
    "TEMPORAL_UI_USERNAME"
    "WAHA_DASHBOARD_USERNAME"
    "WEAVIATE_USERNAME"
    "WELCOME_USERNAME"
    "WHATSAPP_SWAGGER_USERNAME"
)

# All user input variables (EMAIL_VARS plus non-email vars)
USER_INPUT_VARS=(
    "${EMAIL_VARS[@]}"
    "N8N_WORKER_COUNT"
    "NEO4J_AUTH_USERNAME"
    "OPENAI_API_KEY"
    "RUN_N8N_IMPORT"
)

# Variables to generate: varName="type:length"
# Types: password (alphanum), secret (base64), hex, base64, alphanum
declare -A VARS_TO_GENERATE=(
    ["APPSMITH_ENCRYPTION_PASSWORD"]="password:32"
    ["APPSMITH_ENCRYPTION_SALT"]="password:32"
    ["CLICKHOUSE_PASSWORD"]="password:32"
    ["COMFYUI_PASSWORD"]="password:32" # Added ComfyUI basic auth password
    ["CRAWL4AI_API_TOKEN"]="secret:48" # Bearer token; Crawl4AI 0.9+ binds loopback only without it
    ["DASHBOARD_PASSWORD"]="password:32" # Supabase Dashboard
    ["DIFY_SECRET_KEY"]="secret:64" # Dify application secret key (maps to SECRET_KEY in Dify)
    ["DOCLING_PASSWORD"]="password:32"
    ["ENCRYPTION_KEY"]="hex:64" # Langfuse Encryption Key (32 bytes -> 64 hex chars)
    ["GOST_PASSWORD"]="password:32"
    ["GOST_USERNAME"]="fixed:gost"
    ["GRAFANA_ADMIN_PASSWORD"]="password:32"
    ["INVOKEAI_PASSWORD"]="password:32" # InvokeAI Caddy basic auth password
    ["JWT_SECRET"]="base64:64" # 48 bytes -> 64 chars
    ["LANGFUSE_INIT_PROJECT_PUBLIC_KEY"]="langfuse_pk:32"
    ["LANGFUSE_INIT_PROJECT_SECRET_KEY"]="langfuse_sk:32"
    ["LANGFUSE_INIT_USER_PASSWORD"]="password:32"
    ["LANGFUSE_SALT"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["LETTA_SERVER_PASSWORD"]="password:32" # Added Letta server password
    ["LIGHTRAG_API_KEY"]="secret:48"
    ["LIGHTRAG_PASSWORD"]="password:32"
    ["LIGHTRAG_TOKEN_SECRET"]="secret:64" # JWT signing secret (required when AUTH_ACCOUNTS is set)
    ["LOGFLARE_PRIVATE_ACCESS_TOKEN"]="fixed:not-in-use" # For supabase-vector, can't be empty
    ["LOGFLARE_PUBLIC_ACCESS_TOKEN"]="fixed:not-in-use" # For supabase-vector, can't be empty
    ["LT_PASSWORD"]="password:32" # Added LibreTranslate basic auth password
    ["MINIO_ROOT_PASSWORD"]="password:32"
    ["N8N_ENCRYPTION_KEY"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["N8N_RUNNERS_AUTH_TOKEN"]="secret:64" # Task runner auth token for n8n v2.0
    ["N8N_USER_MANAGEMENT_JWT_SECRET"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["NEO4J_AUTH_PASSWORD"]="password:32" # Added Neo4j password
    ["NEO4J_AUTH_USERNAME"]="fixed:neo4j" # Added Neo4j username
    ["NEXTAUTH_SECRET"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["NOCODB_JWT_SECRET"]="secret:64" # NocoDB authentication JWT secret
    ["OLLAMA_CADDY_API_TOKEN"]="secret:48" # Bearer token for exposing Ollama API via Caddy
    ["PADDLEOCR_PASSWORD"]="password:32" # Added PaddleOCR basic auth password
    ["PG_META_CRYPTO_KEY"]="alphanum:32"
    ["POSTGRES_NON_ROOT_PASSWORD"]="password:32"
    ["POSTGRES_PASSWORD"]="password:32"
    ["PROMETHEUS_PASSWORD"]="password:32" # Added Prometheus password
    ["QDRANT_API_KEY"]="secret:48" # API Key for Qdrant service
    ["RAGAPP_PASSWORD"]="password:32" # Added RAGApp basic auth password
    ["RAGFLOW_ELASTICSEARCH_PASSWORD"]="password:32"
    ["RAGFLOW_MINIO_ROOT_PASSWORD"]="password:32"
    ["RAGFLOW_MYSQL_ROOT_PASSWORD"]="password:32"
    ["RAGFLOW_REDIS_PASSWORD"]="password:32"
    ["S3_PROTOCOL_ACCESS_KEY_ID"]="hex:32"
    ["S3_PROTOCOL_ACCESS_KEY_SECRET"]="hex:64"
    ["SEARXNG_PASSWORD"]="password:32" # Added SearXNG admin password
    ["SECRET_KEY_BASE"]="base64:64" # 48 bytes -> 64 chars
    ["TEMPORAL_UI_PASSWORD"]="password:32" # Temporal UI basic auth password
    ["VAULT_ENC_KEY"]="alphanum:32"
    ["WAHA_DASHBOARD_PASSWORD"]="password:32"
    ["WEAVIATE_API_KEY"]="secret:48" # API Key for Weaviate service (36 bytes -> 48 chars base64)
    ["WELCOME_PASSWORD"]="password:32" # Welcome page basic auth password
    ["WHATSAPP_SWAGGER_PASSWORD"]="password:32"
)

# Initialize existing_env_vars and attempt to read .env if it exists
log_info "Initializing environment configuration..."
declare -A existing_env_vars
declare -A generated_values

if [ -f "$OUTPUT_FILE" ]; then
    log_info "Found existing $OUTPUT_FILE. Reading its values to use as defaults and preserve current settings."
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -n "$line" && ! "$line" =~ ^\s*# && "$line" == *"="* ]]; then
            varName=$(echo "$line" | cut -d'=' -f1 | xargs)
            varValue=$(echo "$line" | cut -d'=' -f2-)
            # Repeatedly unquote "value" or 'value' to get the bare value
            _tempVal="$varValue"
            while true; do
                if [[ "$_tempVal" =~ ^\"(.*)\"$ ]]; then # Check double quotes
                    _tempVal="${BASH_REMATCH[1]}"
                    continue
                fi
                if [[ "$_tempVal" =~ ^\'(.*)\'$ ]]; then # Check single quotes
                    _tempVal="${BASH_REMATCH[1]}"
                    continue
                fi
                break # No more surrounding quotes of these types
            done
            varValue="$_tempVal"
            existing_env_vars["$varName"]="$varValue"
        fi
    done < "$OUTPUT_FILE"
fi

# Install Caddy
log_subheader "Installing Caddy"
log_info "Adding Caddy repository and installing..."
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt install -y caddy

# Check for caddy
require_command "caddy" "Caddy installation failed. Please check the installation logs above."

require_whiptail

# Prompt for the domain name
log_subheader "Domain Configuration"
DOMAIN="" # Initialize DOMAIN variable

# Try to get domain from existing .env file first
# Check if USER_DOMAIN_NAME is set in existing_env_vars and is not empty
if [[ ${existing_env_vars[USER_DOMAIN_NAME]+_} && -n "${existing_env_vars[USER_DOMAIN_NAME]}" ]]; then
    DOMAIN="${existing_env_vars[USER_DOMAIN_NAME]}"
    # Ensure this value is carried over to generated_values for writing and template processing
    # If it came from existing_env_vars, it might already be there, but this ensures it.
    generated_values["USER_DOMAIN_NAME"]="$DOMAIN"
else
    while true; do
        DOMAIN_INPUT=$(wt_input "Primary Domain" "Enter the primary domain name for your services (e.g., example.com)." "") || true

        DOMAIN_TO_USE="$DOMAIN_INPUT" # Direct assignment, no default fallback

        # Validate domain input
        if [[ -z "$DOMAIN_TO_USE" ]]; then
            wt_msg "Validation" "Domain name cannot be empty."
            continue
        fi

        # Basic check for likely invalid domain characters (very permissive)
        if [[ "$DOMAIN_TO_USE" =~ [^a-zA-Z0-9.-] ]]; then
            wt_msg "Validation" "Warning: Domain contains potentially invalid characters: '$DOMAIN_TO_USE'"
        fi
        if wt_yesno "Confirm Domain" "Use '$DOMAIN_TO_USE' as the primary domain?" "yes"; then
            DOMAIN="$DOMAIN_TO_USE" # Set the final DOMAIN variable
            generated_values["USER_DOMAIN_NAME"]="$DOMAIN" # Using USER_DOMAIN_NAME
            log_info "Domain set to '$DOMAIN'. It will be saved in .env."
            break # Confirmed, exit loop
        fi
    done
fi

# Prompt for user email
log_subheader "Email Configuration"
if [[ -z "${existing_env_vars[LETSENCRYPT_EMAIL]}" ]]; then
    wt_msg "Email Required" "Please enter your email address. It will be used for logins and Let's Encrypt SSL."
fi

if [[ -n "${existing_env_vars[LETSENCRYPT_EMAIL]}" ]]; then
    USER_EMAIL="${existing_env_vars[LETSENCRYPT_EMAIL]}"
else
    while true; do
        USER_EMAIL=$(wt_input "Email" "Enter your email address." "") || true

        # Validate email input
        if [[ -z "$USER_EMAIL" ]]; then
            wt_msg "Validation" "Email cannot be empty."
            continue
        fi

        # Basic email format validation
        if [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            wt_msg "Validation" "Warning: Email format appears to be invalid: '$USER_EMAIL'"
        fi
        if wt_yesno "Confirm Email" "Use '$USER_EMAIL' as your email?" "yes"; then
            break # Confirmed, exit loop
        fi
    done
fi



log_subheader "Secret Generation"
log_info "Generating secrets and creating .env file..."

# --- Helper Functions ---
# Note: gen_random, gen_password, gen_hex, gen_base64 are now in utils.sh

# Function to update or add a variable to the .env file
# Usage: _update_or_add_env_var "VAR_NAME" "var_value"
_update_or_add_env_var() {
    local var_name="$1"
    local var_value="$2"
    local tmp_env_file

    tmp_env_file=$(mktemp)
    # Ensure temp file is cleaned up if this function exits unexpectedly (though trap in main script should also cover)
    # trap 'rm -f "$tmp_env_file"' EXIT

    if [[ -f "$OUTPUT_FILE" ]]; then
        grep -v -E "^${var_name}=" "$OUTPUT_FILE" > "$tmp_env_file" || true # Allow grep to not find anything
    else
        touch "$tmp_env_file" # Create empty temp if output file doesn't exist yet
    fi

    if [[ -n "$var_value" ]]; then
        # Use single quotes for values containing $ (like bcrypt hashes) to prevent variable expansion
        # Use double quotes for everything else
        if [[ "$var_value" == *'$'* ]]; then
            echo "${var_name}='$var_value'" >> "$tmp_env_file"
        else
            echo "${var_name}=\"$var_value\"" >> "$tmp_env_file"
        fi
    fi
    mv "$tmp_env_file" "$OUTPUT_FILE"
    # trap - EXIT # Remove specific trap for this temp file if desired, or let main script's trap handle it.
}

# Note: generate_bcrypt_hash() is now in utils.sh

# --- Main Logic ---

if [ ! -f "$TEMPLATE_FILE" ]; then
    log_error "Template file not found at $TEMPLATE_FILE"
    exit 1
fi

# Pre-populate generated_values with non-empty values from existing_env_vars
for key_from_existing in "${!existing_env_vars[@]}"; do
    if [[ -n "${existing_env_vars[$key_from_existing]}" ]]; then
        generated_values["$key_from_existing"]="${existing_env_vars[$key_from_existing]}"
    fi
done

# Store user input values (potentially overwriting if user was re-prompted and gave new input)
# Assign user email to all EMAIL_VARS
for var in "${EMAIL_VARS[@]}"; do
    generated_values["$var"]="$USER_EMAIL"
done

# Database names for backward compatibility
# New installations: use service-specific databases (postiz, waha, lightrag)
# Upgrades: use 'postgres' to preserve existing data
DB_MIGRATION_VARS=("POSTIZ_DB_NAME" "WAHA_DB_NAME" "LIGHTRAG_DB_NAME")

for var in "${DB_MIGRATION_VARS[@]}"; do
    if [[ -z "${existing_env_vars[$var]}" ]]; then
        # Variable not in existing .env
        if [[ ${#existing_env_vars[@]} -gt 0 ]]; then
            # This is an upgrade - .env exists but var is missing
            # Use 'postgres' for backward compatibility
            generated_values["$var"]="postgres"
        else
            # New installation - use service name
            case "$var" in
                "POSTIZ_DB_NAME")  generated_values["$var"]="postiz" ;;
                "WAHA_DB_NAME")    generated_values["$var"]="waha" ;;
                "LIGHTRAG_DB_NAME") generated_values["$var"]="lightrag" ;;
            esac
        fi
    fi
done

# Create a temporary file for processing
TMP_ENV_FILE=$(mktemp)
TEMP_FILES+=("$TMP_ENV_FILE")

# Track whether our custom variables were found in the template
declare -A found_vars
for var in "${USER_INPUT_VARS[@]}"; do
    found_vars["$var"]=0
done

# Read template, substitute domain, generate initial values
while IFS= read -r line || [[ -n "$line" ]]; do
    # Substitute domain placeholder
    processed_line=$(echo "$line" | sed "s/$DOMAIN_PLACEHOLDER/$DOMAIN/g")

    # Check if it's a variable assignment line (non-empty, not comment, contains '=')
    if [[ -n "$processed_line" && ! "$processed_line" =~ ^\s*# && "$processed_line" == *"="* ]]; then
        varName=$(echo "$processed_line" | cut -d'=' -f1 | xargs) # Trim whitespace
        currentValue=$(echo "$processed_line" | cut -d'=' -f2-)

        # If already have a non-empty value from existing .env or prior generation/user input, use it
        if [[ -n "${generated_values[$varName]}" ]]; then
            processed_line="${varName}=\"${generated_values[$varName]}\""
        # Check if this is one of our user-input derived variables that might not have a value yet
        # (e.g. OPENAI_API_KEY if user left it blank). These are handled by `found_vars` later if needed.
        # Or, if variable needs generation AND is not already populated (or is empty) in generated_values
        elif [[ ${VARS_TO_GENERATE[$varName]+_} && -z "${generated_values[$varName]}" ]]; then
            IFS=':' read -r type length <<< "${VARS_TO_GENERATE[$varName]}"
            newValue=""
            case "$type" in
                password|alphanum) newValue=$(gen_password "$length") ;;
                secret|base64) newValue=$(gen_base64 "$length") ;;
                hex) newValue=$(gen_hex "$length") ;;
                langfuse_pk) newValue="pk-lf-$(gen_hex "$length")" ;;
                langfuse_sk) newValue="sk-lf-$(gen_hex "$length")" ;;
                fixed) newValue="$length" ;; # Handle fixed type
                *) log_warning "Unknown generation type '$type' for $varName" ;;
            esac

            if [[ -n "$newValue" ]]; then
                processed_line="${varName}=\"${newValue}\"" # Quote generated values
                generated_values["$varName"]="$newValue"    # Store newly generated
            else
                # Keep original line structure but ensure value is empty if generation failed
                # but it was in VARS_TO_GENERATE
                processed_line="${varName}=\""
                generated_values["$varName"]="" # Explicitly mark as empty in generated_values
            fi
        # For variables from the template that are not in VARS_TO_GENERATE and not already in generated_values
        # store their template value if it's a direct assignment (not a ${...} substitution)
        # This allows them to be used in later ${VAR} substitutions if they are referenced.
        else
            # This 'else' block is for lines from template not covered by existing values or VARS_TO_GENERATE.
            # Check if it is one of the user input vars - these are handled by found_vars later if not in template.
            is_user_input_var=0 # Reset for each line
            for uivar in "${USER_INPUT_VARS[@]}"; do
                if [[ "$varName" == "$uivar" ]]; then
                    is_user_input_var=1
                    # Mark as found if it's in template, value taken from generated_values if already set or blank
                    found_vars["$varName"]=1 
                    if [[ ${generated_values[$varName]+_} ]]; then # if it was set (even to empty by user)
                        processed_line="${varName}=\"${generated_values[$varName]}\""
                    else # Not set in generated_values, keep template's default if any, or make it empty
                        if [[ "$currentValue" =~ ^\$\{.*\} || -z "$currentValue" ]]; then # if template is ${VAR} or empty
                            processed_line="${varName}=\"\""
                        else # template has a default simple value
                            processed_line="${varName}=\"$currentValue\"" # Use template's default, and quote it
                        fi
                    fi
                    break
                fi
            done

            if [[ $is_user_input_var -eq 0 ]]; then # Not a user input var, not in VARS_TO_GENERATE, not in existing
                trimmed_value=$(echo "$currentValue" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'//")
                if [[ -n "$varName" && -n "$trimmed_value" && "$trimmed_value" != "\${INSTANCE_DOMAIN}" && "$trimmed_value" != "\${SUBDOMAIN_WILDCARD_CERT}" && ! "$trimmed_value" =~ ^\\$\\{ ]]; then # Check for other placeholders
                    # Only store if not already in generated_values and not a placeholder reference
                    if [[ -z "${generated_values[$varName]}" ]]; then
                        generated_values["$varName"]="$trimmed_value"
                    fi
                fi
                # processed_line remains as is (from template, after domain sub) for these cases
            fi
        fi
    fi
    echo "$processed_line" >> "$TMP_ENV_FILE"
done < "$TEMPLATE_FILE"

# Generate placeholder Supabase keys (always generate these)

# Function to create a JWT token
create_jwt() {
    local role=$1
    local jwt_secret=$2
    local now=$(date +%s)
    local exp=$((now + 315360000)) # 10 years from now (seconds)
    
    # Create header (alg=HS256, typ=JWT)
    local header='{"alg":"HS256","typ":"JWT"}'
    # Create payload with role, issued at time, and expiry
    local payload="{\"role\":\"$role\",\"iss\":\"supabase\",\"iat\":$now,\"exp\":$exp}"
    
    # Base64url encode header and payload
    local b64_header=$(echo -n "$header" | base64 -w 0 | tr '/+' '_-' | tr -d '=')
    local b64_payload=$(echo -n "$payload" | base64 -w 0 | tr '/+' '_-' | tr -d '=')
    
    # Create signature
    local signature_input="$b64_header.$b64_payload"
    local signature=$(echo -n "$signature_input" | openssl dgst -sha256 -hmac "$jwt_secret" -binary | base64 -w 0 | tr '/+' '_-' | tr -d '=')
    
    # Combine to form JWT
    echo -n "$b64_header.$b64_payload.$signature" # Use echo -n to avoid trailing newline
}

# Get JWT secret from previously generated values
JWT_SECRET_TO_USE="${generated_values["JWT_SECRET"]}"

if [[ -z "$JWT_SECRET_TO_USE" ]]; then
    # This should ideally have been generated by VARS_TO_GENERATE if it was missing
    # and JWT_SECRET is in VARS_TO_GENERATE. For safety, generate if truly empty.
    log_warning "JWT_SECRET was empty, attempting to generate it now."
    # Assuming JWT_SECRET definition is 'base64:64'
    JWT_SECRET_TO_USE=$(gen_base64 64)
    generated_values["JWT_SECRET"]="$JWT_SECRET_TO_USE"
fi

# Generate the actual JWT tokens using the JWT_SECRET_TO_USE, if not already set
if [[ -z "${generated_values[ANON_KEY]}" ]]; then
    generated_values["ANON_KEY"]=$(create_jwt "anon" "$JWT_SECRET_TO_USE")
fi

if [[ -z "${generated_values[SERVICE_ROLE_KEY]}" ]]; then
    generated_values["SERVICE_ROLE_KEY"]=$(create_jwt "service_role" "$JWT_SECRET_TO_USE")
fi

# Add any custom variables that weren't found in the template
for var in "${USER_INPUT_VARS[@]}"; do
    if [[ ${found_vars["$var"]} -eq 0 && ${generated_values[$var]+_} ]]; then
        # Before appending, check if it's already in TMP_ENV_FILE to avoid duplicates
        if ! grep -q -E "^${var}=" "$TMP_ENV_FILE"; then
            echo "${var}=\"${generated_values[$var]}\"" >> "$TMP_ENV_FILE" # Ensure quoting
        fi
    fi
done

# --- WAHA API KEY (sha512) --- (moved after .env write to avoid overwrite)

# Second pass: Substitute generated values referenced like ${VAR}
# We'll process the substitutions line by line to avoid escaping issues

# Copy the temporary file to the output
cp "$TMP_ENV_FILE" "$OUTPUT_FILE"

log_info "Applying variable substitutions..."

# Process each generated value
for key in "${!generated_values[@]}"; do
    value="${generated_values[$key]}"
    
    # Create a temporary file for this value to avoid escaping issues
    value_file=$(mktemp)
    echo -n "$value" > "$value_file"
    
    # Create a new temporary file for the output
    new_output=$(mktemp)
    
    # Process each line in the file
    while IFS= read -r line; do
        # Replace ${KEY} format
        if [[ "$line" == *"\${$key}"* ]]; then
            placeholder="\${$key}"
            replacement=$(cat "$value_file")
            line="${line//$placeholder/$replacement}"
        fi
        
        # Replace $KEY format
        if [[ "$line" == *"$"$key* ]]; then
            placeholder="$"$key
            replacement=$(cat "$value_file")
            line="${line//$placeholder/$replacement}"
        fi
        
        # Handle specific cases
        if [[ "$key" == "ANON_KEY" && "$line" == "ANON_KEY="* ]]; then
            line="ANON_KEY=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "SERVICE_ROLE_KEY" && "$line" == "SERVICE_ROLE_KEY="* ]]; then
            line="SERVICE_ROLE_KEY=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "ANON_KEY" && "$line" == "SUPABASE_ANON_KEY="* ]]; then
            line="SUPABASE_ANON_KEY=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "SERVICE_ROLE_KEY" && "$line" == "SUPABASE_SERVICE_ROLE_KEY="* ]]; then
            line="SUPABASE_SERVICE_ROLE_KEY=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "JWT_SECRET" && "$line" == "SUPABASE_JWT_SECRET="* ]]; then
            line="SUPABASE_JWT_SECRET=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "POSTGRES_PASSWORD" && "$line" == "SUPABASE_POSTGRES_PASSWORD="* ]]; then
            line="SUPABASE_POSTGRES_PASSWORD=\"$(cat "$value_file")\""
        fi
        
        # Write the processed line to the new file
        echo "$line" >> "$new_output"
    done < "$OUTPUT_FILE"
    
    # Replace the output file with the new version
    mv "$new_output" "$OUTPUT_FILE"
    
    # Clean up
    rm -f "$value_file"
done

# --- WAHA API KEY (sha512) --- ensure after .env write/substitutions ---
# Generate plaintext API key if missing, then compute sha512:HEX and store in WAHA_API_KEY
if [[ -z "${generated_values[WAHA_API_KEY_PLAIN]}" ]]; then
    generated_values[WAHA_API_KEY_PLAIN]="$(gen_base64 48 | tr -d '\n' | tr '/+' 'AZ')"
fi

PLAINTEXT_KEY="${generated_values[WAHA_API_KEY_PLAIN]}"
if [[ -n "$PLAINTEXT_KEY" ]]; then
    SHA_HEX="$(printf "%s" "$PLAINTEXT_KEY" | openssl dgst -sha512 | awk '{print $2}')"
    if [[ -n "$SHA_HEX" ]]; then
        generated_values[WAHA_API_KEY]="sha512:${SHA_HEX}"
    fi
fi

_update_or_add_env_var "WAHA_API_KEY_PLAIN" "${generated_values[WAHA_API_KEY_PLAIN]}"
_update_or_add_env_var "WAHA_API_KEY" "${generated_values[WAHA_API_KEY]}"

# Generate GOST_PROXY_URL if gost profile is active
if is_profile_active "gost"; then
    if [[ -n "${generated_values[GOST_PASSWORD]}" && -n "${generated_values[GOST_USERNAME]}" ]]; then
        generated_values["GOST_PROXY_URL"]="http://${generated_values[GOST_USERNAME]}:${generated_values[GOST_PASSWORD]}@gost:8080"
        _update_or_add_env_var "GOST_PROXY_URL" "${generated_values[GOST_PROXY_URL]}"
    fi
else
    # Clear proxy URL if gost is not active
    _update_or_add_env_var "GOST_PROXY_URL" ""
fi

# Update GOST_NO_PROXY from template to ensure all internal services are included
# This overwrites user's value to guarantee new services added in updates are included
template_no_proxy=$(grep -E "^GOST_NO_PROXY=" "$TEMPLATE_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "")
if [[ -n "$template_no_proxy" ]]; then
    _update_or_add_env_var "GOST_NO_PROXY" "$template_no_proxy"
fi

# Hash passwords using caddy with bcrypt (consolidated loop)
SERVICES_NEEDING_HASH=("PROMETHEUS" "SEARXNG" "COMFYUI" "PADDLEOCR" "RAGAPP" "LT" "DOCLING" "TEMPORAL_UI" "WELCOME" "INVOKEAI")

for service in "${SERVICES_NEEDING_HASH[@]}"; do
    password_var="${service}_PASSWORD"
    hash_var="${service}_PASSWORD_HASH"

    plain_pass="${generated_values[$password_var]}"
    existing_hash="${generated_values[$hash_var]}"

    # If no hash exists but we have a plain password, generate new hash
    if [[ -z "$existing_hash" && -n "$plain_pass" ]]; then
        new_hash=$(generate_bcrypt_hash "$plain_pass")
        if [[ -n "$new_hash" ]]; then
            existing_hash="$new_hash"
            generated_values["$hash_var"]="$new_hash"
        else
            # An empty hash would either break Caddy config parsing (username
            # without hash) or silently lock the service behind a deny-all
            log_error "Failed to generate bcrypt hash for ${service} - Caddy basic auth would be broken."
            exit 1
        fi
    fi

    _update_or_add_env_var "$hash_var" "$existing_hash"
done

log_success ".env file generated successfully in the project root ($OUTPUT_FILE)."

# Save installation ID for telemetry correlation
save_installation_id "$OUTPUT_FILE"

# Uninstall caddy
apt remove -y caddy

# Cleanup any .bak files
cleanup_bak_files "$PROJECT_ROOT"

exit 0
