#!/usr/bin/env bash
# Verify ADR-015 — Adopt Docker as the Image Format.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -f Dockerfile ]; then
	check_pass "Dockerfile present"
else
	check_fail "Dockerfile present" "missing"
	report_and_exit "ADR-015 — Docker"
fi

if [ -f .dockerignore ]; then
	check_pass ".dockerignore present"
else
	check_fail ".dockerignore present" "missing"
fi

# Multi-stage: at least two FROM ... AS stages.
stages="$(grep -cE '^FROM[[:space:]]+.*[[:space:]]+AS[[:space:]]+' Dockerfile)"
if [ "${stages:-0}" -ge 2 ]; then
	check_pass "Dockerfile is multi-stage (≥2 FROM ... AS)" "stages: $stages"
else
	check_fail "Dockerfile is multi-stage (≥2 FROM ... AS)" "stages: $stages"
fi

# Non-root: USER directive present and not 'root'.
user_line="$(grep -E '^USER[[:space:]]+' Dockerfile | tail -1)"
if [ -z "$user_line" ]; then
	check_fail "non-root USER set" "no USER directive"
else
	user_name="$(echo "$user_line" | awk '{print $2}')"
	case "$user_name" in
	root | 0 | 0:0) check_fail "non-root USER set" "USER $user_name" ;;
	*) check_pass "non-root USER set" "USER $user_name" ;;
	esac
fi

# Every base image (FROM) must be pinned by digest @sha256: OR a specific tag
# (X.Y or X.Y.Z) OR an ARG-substituted tag whose ARG default is pinned —
# never a floating tag like 'latest' or no tag at all.
bad=""
while IFS= read -r line; do
	[ -z "$line" ] && continue
	ref="$(echo "$line" | awk '{print $2}')"
	base="${ref%% AS *}"
	if echo "$base" | grep -q '@sha256:'; then
		continue
	fi
	# ARG-substituted tag (e.g. python:${PYTHON_TAG}) — accept if the ARG has
	# an exact-version default declared in the Dockerfile (ARG NAME=X.Y.Z).
	if echo "$base" | grep -qE '\$\{?[A-Z_][A-Z0-9_]*\}?'; then
		var="$(echo "$base" | sed -E 's/.*\$\{?([A-Z_][A-Z0-9_]*)\}?.*/\1/')"
		default="$(grep -E "^ARG[[:space:]]+${var}=" Dockerfile | head -1 | sed -E 's/^[^=]*=//' | tr -d '"')"
		if echo "$default" | grep -Eq '^[0-9]+\.[0-9]+(\.[0-9]+)?(-[A-Za-z0-9.]+)?$'; then
			continue
		fi
		bad="${bad:+$bad, }$base (ARG $var default: ${default:-<unset>})"
		continue
	fi
	case "$base" in
	*:latest | *:) bad="${bad:+$bad, }$base" ;;
	*:*[0-9]*) ;; # has a tag with at least one digit
	*) bad="${bad:+$bad, }$base (no tag)" ;;
	esac
done <<EOF
$(grep -iE '^FROM[[:space:]]' Dockerfile)
EOF
if [ -z "$bad" ]; then
	check_pass "every FROM pinned by digest or specific tag"
else
	check_fail "every FROM pinned by digest or specific tag" "$bad"
fi

# No secret-looking ENV / ARG (cheap heuristic per docker rule on secrets).
secret_hits="$(grep -iE '^(ENV|ARG)[[:space:]]+[A-Z_]*(SECRET|TOKEN|PASSWORD|KEY)' Dockerfile)"
if [ -z "$secret_hits" ]; then
	check_pass "no secret-shaped ENV / ARG in Dockerfile"
else
	check_fail "no secret-shaped ENV / ARG in Dockerfile" \
		"$(echo "$secret_hits" | head -3 | tr '\n' ' | ')"
fi

# HEALTHCHECK strongly recommended for the runtime stage.
if grep -qE '^HEALTHCHECK ' Dockerfile; then
	check_pass "HEALTHCHECK declared"
else
	check_fail "HEALTHCHECK declared" "no HEALTHCHECK in Dockerfile"
fi

report_and_exit "ADR-015 — Docker"
