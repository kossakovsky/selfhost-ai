#!/bin/bash
# =============================================================================
# 05_configure_services.sh - Service-specific configuration
# =============================================================================
# Collects additional configuration needed by selected services via whiptail
# prompts and writes settings to .env file.
#
# Prompts for:
#   - OpenAI API Key (optional, used by Supabase AI and Crawl4AI)
#   - n8n workflow import option (~300 ready-made workflows)
#   - Number of n8n workers to run
#   - Privileged fallback for the n8n Assistant sandbox runner when Sysbox
#     cannot be installed (n8n-sandbox profile)
#   - Cloudflare Tunnel token (if cloudflare-tunnel profile is active)
#
# Also handles:
#   - Generates n8n worker-runner pairs configuration
#   - Installs Sysbox (scripts/setup_sysbox.sh) and wires the n8n Assistant
#     sandbox and SearXNG web search into n8n
#   - Resolves service conflicts (e.g., removes Dify if Supabase is selected)
#
# Usage: bash scripts/05_configure_services.sh
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Ensure .env exists
ensure_file_exists "$ENV_FILE"

# Load COMPOSE_PROFILES early so is_profile_active works for all sections
COMPOSE_PROFILES_VALUE="$(read_env_var COMPOSE_PROFILES)"
COMPOSE_PROFILES="$COMPOSE_PROFILES_VALUE"

# ----------------------------------------------------------------
# Prompt for OpenAI API key (optional) using .env value as source of truth
# ----------------------------------------------------------------
log_subheader "OpenAI API Key"
EXISTING_OPENAI_API_KEY="$(read_env_var OPENAI_API_KEY)"
OPENAI_API_KEY=""
if [[ -z "$EXISTING_OPENAI_API_KEY" ]]; then
    require_whiptail
    OPENAI_API_KEY=$(wt_input "OpenAI API Key" "Optional: Used by Supabase AI (SQL assistance) and Crawl4AI. Leave empty to skip." "") || true
    if [[ -n "$OPENAI_API_KEY" ]]; then
        write_env_var "OPENAI_API_KEY" "$OPENAI_API_KEY"
    fi
else
    # Reuse existing value without prompting
    OPENAI_API_KEY="$EXISTING_OPENAI_API_KEY"
fi


# ----------------------------------------------------------------
# Logic for n8n workflow import (RUN_N8N_IMPORT)
# ----------------------------------------------------------------
if is_profile_active "n8n"; then
    log_subheader "n8n Workflow Import"
    final_run_n8n_import_decision="false"
    require_whiptail
    if wt_yesno "Import n8n Workflows" "Import ~300 ready-made n8n workflows now? This can take ~30 minutes." "no"; then
        final_run_n8n_import_decision="true"
    else
        final_run_n8n_import_decision="false"
    fi

    # Persist RUN_N8N_IMPORT to .env
    write_env_var "RUN_N8N_IMPORT" "$final_run_n8n_import_decision"
else
    write_env_var "RUN_N8N_IMPORT" "false"
fi


# ----------------------------------------------------------------
# Prompt for number of n8n workers
# ----------------------------------------------------------------
if is_profile_active "n8n"; then
    log_subheader "n8n Worker Configuration"
    EXISTING_N8N_WORKER_COUNT="$(read_env_var N8N_WORKER_COUNT)"
    require_whiptail
    if [[ -n "$EXISTING_N8N_WORKER_COUNT" ]]; then
        N8N_WORKER_COUNT_CURRENT="$EXISTING_N8N_WORKER_COUNT"
        N8N_WORKER_COUNT_INPUT_RAW=$(wt_input "n8n Workers (instances)" "Enter new number of n8n workers, or leave as current ($N8N_WORKER_COUNT_CURRENT)." "") || true
        if [[ -z "$N8N_WORKER_COUNT_INPUT_RAW" ]]; then
            N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
        else
            if [[ "$N8N_WORKER_COUNT_INPUT_RAW" =~ ^0*[1-9][0-9]*$ ]]; then
                N8N_WORKER_COUNT_TEMP="$((10#$N8N_WORKER_COUNT_INPUT_RAW))"
                if [[ "$N8N_WORKER_COUNT_TEMP" -ge 1 ]]; then
                    if wt_yesno "Confirm Workers" "Update n8n workers to $N8N_WORKER_COUNT_TEMP?" "yes"; then
                        N8N_WORKER_COUNT="$N8N_WORKER_COUNT_TEMP"
                    else
                        N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
                        log_info "Change declined. Keeping N8N_WORKER_COUNT at $N8N_WORKER_COUNT."
                    fi
                else
                    log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Number must be positive. Keeping $N8N_WORKER_COUNT_CURRENT."
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
                fi
            else
                log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Please enter a positive integer. Keeping $N8N_WORKER_COUNT_CURRENT."
                N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
            fi
        fi
    else
        while true; do
            N8N_WORKER_COUNT_INPUT_RAW=$(wt_input "n8n Workers" "Enter number of n8n workers to run (default 1)." "1") || true
            N8N_WORKER_COUNT_CANDIDATE="${N8N_WORKER_COUNT_INPUT_RAW:-1}"
            if [[ "$N8N_WORKER_COUNT_CANDIDATE" =~ ^0*[1-9][0-9]*$ ]]; then
                N8N_WORKER_COUNT_VALIDATED="$((10#$N8N_WORKER_COUNT_CANDIDATE))"
                if [[ "$N8N_WORKER_COUNT_VALIDATED" -ge 1 ]]; then
                    if wt_yesno "Confirm Workers" "Run $N8N_WORKER_COUNT_VALIDATED n8n worker(s)?" "yes"; then
                        N8N_WORKER_COUNT="$N8N_WORKER_COUNT_VALIDATED"
                        break
                    fi
                else
                    log_error "Number of workers must be a positive integer."
                fi
            else
                log_error "Invalid input '$N8N_WORKER_COUNT_CANDIDATE'. Please enter a positive integer (e.g., 1, 2)."
            fi
        done
    fi
    # Ensure N8N_WORKER_COUNT is definitely set (should be by logic above)
    N8N_WORKER_COUNT="${N8N_WORKER_COUNT:-1}"

    # Persist N8N_WORKER_COUNT to .env
    write_env_var "N8N_WORKER_COUNT" "$N8N_WORKER_COUNT"
fi

# Generate the n8n worker-runner pairs and the Prometheus targets. Runs even when
# n8n is not selected: the generator then removes the stale targets file
bash "$SCRIPT_DIR/generate_n8n_workers.sh"

# ----------------------------------------------------------------
# n8n Assistant sandbox (n8n-sandbox profile)
# The Docker-in-Docker runner is isolated with sysbox-runc when Sysbox can be
# installed on this host; otherwise the user may accept a privileged runner
# (root-equivalent on the host) or the profile is dropped.
# ----------------------------------------------------------------
if is_profile_active "n8n-sandbox"; then
    log_subheader "n8n Assistant Sandbox"

    if [ "$EUID" -ne 0 ]; then
        # Sysbox and the kernel module need root. Stop here rather than start a
        # runner that cannot work; install.sh and apply_update.sh abort on this.
        log_error "Not running as root: cannot install Sysbox or load br_netfilter for the n8n sandbox. Run 'make update' (it uses sudo) or 'sudo bash scripts/05_configure_services.sh'."
        exit 1
    else
        # The sandbox egress policy relies on bridge netfilter in both isolation modes
        if ! lsmod | grep -q '^br_netfilter'; then
            modprobe br_netfilter || log_warning "Could not load the br_netfilter kernel module; the sandbox network policy will not apply."
        fi
        if [ ! -f /etc/modules-load.d/n8n-sandbox.conf ]; then
            install -d /etc/modules-load.d && echo "br_netfilter" > /etc/modules-load.d/n8n-sandbox.conf \
                || log_warning "Could not persist br_netfilter in /etc/modules-load.d; it will not load on reboot."
        fi

        # setup_sysbox.sh re-tests an installed Sysbox and exits 0 quickly when it
        # works, so it runs every time. Its output is shown live and kept, because
        # whiptail clears the screen and the failure reason has to be in the dialog
        # itself. tee appends: on Linux /dev/stderr re-opens the target, and without
        # -a a stderr redirected to a log file would be truncated.
        if SYSBOX_OUTPUT="$(bash "$SCRIPT_DIR/setup_sysbox.sh" 2>&1 | tee -a /dev/stderr; exit "${PIPESTATUS[0]}")"; then
            write_env_var "N8N_SANDBOX_RUNNER_RUNTIME" "sysbox-runc"
            write_env_var "N8N_SANDBOX_RUNNER_PRIVILEGED" "false"
        else
            SYSBOX_REASON="$(printf '%s\n' "$SYSBOX_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -o 'Sysbox: .*' | tail -n1 || true)"
            SYSBOX_REASON="${SYSBOX_REASON:-Sysbox could not be installed.}"
            require_whiptail
            # wt_yesno is capped at 12 rows, so the reason is cut to fit the box.
            if wt_yesno "n8n Assistant Sandbox" \
                "${SYSBOX_REASON:0:200}\n\nRun the sandbox runner PRIVILEGED (root-equivalent on this host)? No = remove the n8n-sandbox profile." \
                "no"; then
                write_env_var "N8N_SANDBOX_RUNNER_RUNTIME" "runc"
                write_env_var "N8N_SANDBOX_RUNNER_PRIVILEGED" "true"
                log_warning "$SYSBOX_REASON"
                log_warning "The n8n sandbox runner will run privileged. Re-run 'make update' after fixing the Sysbox prerequisites to switch to sysbox-runc."
            else
                COMPOSE_PROFILES_VALUE=$(remove_compose_profile "$COMPOSE_PROFILES_VALUE" "n8n-sandbox")
                COMPOSE_PROFILES="$COMPOSE_PROFILES_VALUE"
                update_compose_profiles "$COMPOSE_PROFILES_VALUE"
                write_env_var "N8N_SANDBOX_RUNNER_RUNTIME" "runc"
                write_env_var "N8N_SANDBOX_RUNNER_PRIVILEGED" "false"
                log_warning "$SYSBOX_REASON"
                log_warning "Removed 'n8n-sandbox' from COMPOSE_PROFILES: the sandbox runner would have to run privileged."
            fi
        fi
    fi
fi

if is_profile_active "n8n-sandbox"; then
    write_env_var "N8N_INSTANCE_AI_SANDBOX_ENABLED" "true"
else
    write_env_var "N8N_INSTANCE_AI_SANDBOX_ENABLED" "false"
fi

# Open Terminal: only the full image ("latest" or a release tag such as 0.12.5)
# honours OPEN_TERMINAL_MULTI_USER and the package lists; the slim / alpine /
# openshift variants ("slim", "latest-slim", "0.12.5-alpine", ...) ignore them.
# Refuse the combination instead of letting every user silently share one shell.
if is_profile_active "open-terminal"; then
    OT_VERSION="$(read_env_var OPEN_TERMINAL_VERSION)"
    case "$OT_VERSION" in
        slim|alpine|openshift|*-slim|*-alpine|*-openshift)
            if [ "$(read_env_var OPEN_TERMINAL_MULTI_USER)" = "true" ]; then
                log_error "OPEN_TERMINAL_VERSION=$OT_VERSION does not support OPEN_TERMINAL_MULTI_USER=true - all users would share one shell. Use the full image (latest or a release tag) or set OPEN_TERMINAL_MULTI_USER=false."
                exit 1
            fi
            for v in OPEN_TERMINAL_PACKAGES OPEN_TERMINAL_PIP_PACKAGES OPEN_TERMINAL_NPM_PACKAGES; do
                [ -z "$(read_env_var "$v")" ] || log_warning "$v is ignored by the '$OT_VERSION' image (no runtime installs)."
            done
            ;;
    esac
fi

# Web search for the n8n Assistant: point n8n at the bundled SearXNG while that
# profile is active, and clear the value again when it is not. A custom URL is
# left alone in both directions.
SEARXNG_INTERNAL_URL="http://searxng:8080"
CURRENT_SEARXNG_URL="$(read_env_var N8N_INSTANCE_AI_SEARXNG_URL)"
if is_profile_active "searxng"; then
    if [ -z "$CURRENT_SEARXNG_URL" ]; then
        write_env_var "N8N_INSTANCE_AI_SEARXNG_URL" "$SEARXNG_INTERNAL_URL"
    fi
elif [ "$CURRENT_SEARXNG_URL" = "$SEARXNG_INTERNAL_URL" ]; then
    write_env_var "N8N_INSTANCE_AI_SEARXNG_URL" ""
fi

# ----------------------------------------------------------------
# Prompt for number of Ollama instances (multi-GPU hosts)
# ----------------------------------------------------------------
if is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
    log_subheader "Ollama Instances"
    EXISTING_OLLAMA_INSTANCE_COUNT="$(read_env_var OLLAMA_INSTANCE_COUNT)"
    OLLAMA_INSTANCE_COUNT_CURRENT="${EXISTING_OLLAMA_INSTANCE_COUNT:-1}"
    # Validate the value already in .env, not just new input. A hand-edited
    # "two" or a stray trailing space would otherwise be written straight back
    # and then abort the whole update in generate_ollama_instances.sh.
    if ! [[ "$OLLAMA_INSTANCE_COUNT_CURRENT" =~ ^0*[1-9][0-9]*$ ]] \
       || [ "$((10#$OLLAMA_INSTANCE_COUNT_CURRENT))" -gt "$OLLAMA_MAX_INSTANCES" ]; then
        log_warning "OLLAMA_INSTANCE_COUNT in .env is '$OLLAMA_INSTANCE_COUNT_CURRENT', which is not an integer between 1 and $OLLAMA_MAX_INSTANCES. Falling back to 1."
        OLLAMA_INSTANCE_COUNT_CURRENT=1
    fi
    require_whiptail
    OLLAMA_INSTANCE_COUNT_INPUT_RAW=$(wt_input "Ollama Instances" \
      "Number of Ollama containers (1-$OLLAMA_MAX_INSTANCES). Use 2 or more only on a multi-GPU host, to dedicate a GPU per model and avoid model swapping. Extra instances are internal only (http://ollama2:11434) and share one model store. Leave empty to keep the current value ($OLLAMA_INSTANCE_COUNT_CURRENT)." \
      "") || true
    if [[ -z "$OLLAMA_INSTANCE_COUNT_INPUT_RAW" ]]; then
        OLLAMA_INSTANCE_COUNT="$OLLAMA_INSTANCE_COUNT_CURRENT"
    elif [[ "$OLLAMA_INSTANCE_COUNT_INPUT_RAW" =~ ^0*[1-9][0-9]*$ ]] \
         && [ "$((10#$OLLAMA_INSTANCE_COUNT_INPUT_RAW))" -le "$OLLAMA_MAX_INSTANCES" ]; then
        OLLAMA_INSTANCE_COUNT="$((10#$OLLAMA_INSTANCE_COUNT_INPUT_RAW))"
    else
        log_warning "Invalid input '$OLLAMA_INSTANCE_COUNT_INPUT_RAW'. Enter an integer between 1 and $OLLAMA_MAX_INSTANCES. Keeping $OLLAMA_INSTANCE_COUNT_CURRENT."
        OLLAMA_INSTANCE_COUNT="$OLLAMA_INSTANCE_COUNT_CURRENT"
    fi
    write_env_var "OLLAMA_INSTANCE_COUNT" "$OLLAMA_INSTANCE_COUNT"

    if [ "$OLLAMA_INSTANCE_COUNT" -gt 1 ] && is_profile_active "gpu-nvidia" \
       && [ -z "$(read_env_var OLLAMA_GPU_DEVICES)" ]; then
        log_warning "Running $OLLAMA_INSTANCE_COUNT Ollama instances but OLLAMA_GPU_DEVICES is empty: the first instance is not GPU-pinned and may land on a GPU already assigned to ollama2. Set OLLAMA_GPU_DEVICES in .env (e.g. 0)."
    fi
fi

# Always run, even when Ollama is not selected: this also removes a stale
# generated file after a hardware-profile switch or after Ollama is deselected.
bash "$SCRIPT_DIR/generate_ollama_instances.sh"


# ----------------------------------------------------------------
# Cloudflare Tunnel Token (if cloudflare-tunnel profile is active)
# ----------------------------------------------------------------
if is_profile_active "cloudflare-tunnel"; then
    log_subheader "Cloudflare Tunnel"
    existing_cf_token="$(read_env_var CLOUDFLARE_TUNNEL_TOKEN)"

    if [ -n "$existing_cf_token" ]; then
        log_info "Cloudflare Tunnel token found in .env; reusing it."
        # Do not prompt; keep existing token as-is
    else
        require_whiptail
        input_cf_token=$(wt_input "Cloudflare Tunnel Token" "Enter your Cloudflare Tunnel token (leave empty to skip)." "") || true

        # Update the .env with the token (may be empty if user skipped)
        write_env_var "CLOUDFLARE_TUNNEL_TOKEN" "$input_cf_token"

        if [ -n "$input_cf_token" ]; then
            log_success "Cloudflare Tunnel token saved to .env."
            log_info "After confirming the tunnel works, consider closing ports 80, 443, and 7687 in your firewall."
        else
            log_warning "Cloudflare Tunnel token was left empty. You can set it later in .env."
        fi
    fi
fi


# ----------------------------------------------------------------
# Safety: If Supabase is present, remove Dify from COMPOSE_PROFILES (no prompts)
# ----------------------------------------------------------------
if is_profile_active "supabase"; then
  COMPOSE_PROFILES_VALUE_UPDATED=$(remove_compose_profile "$COMPOSE_PROFILES_VALUE" "dify")
  if [[ "$COMPOSE_PROFILES_VALUE_UPDATED" != "${COMPOSE_PROFILES_VALUE// /}" ]]; then
    write_env_var "COMPOSE_PROFILES" "$COMPOSE_PROFILES_VALUE_UPDATED"
    log_info "Supabase present: removed 'dify' from COMPOSE_PROFILES due to conflict with Supabase."
    COMPOSE_PROFILES_VALUE="$COMPOSE_PROFILES_VALUE_UPDATED"
  fi
fi

# ----------------------------------------------------------------
# Ensure Supabase Analytics targets the correct Postgres service name used by Supabase docker compose
# ----------------------------------------------------------------
write_env_var "POSTGRES_HOST" "db"
# ----------------------------------------------------------------

log_success "Service configuration complete. .env updated at $ENV_FILE"

# Cleanup any .bak files
cleanup_bak_files "$PROJECT_ROOT"

exit 0
