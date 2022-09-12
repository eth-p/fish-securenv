# =============================================================================
# fish-securenv | Copyright (C) 2022 eth-p
#
# A storage provider for fish-securenv that uses GPG to encrypt the variables.
#
# Documentation: https://github.com/eth-p/fish-securenv/tree/master/docs
# Repository:    https://github.com/eth-p/fish-securenv
# Issues:        https://github.com/eth-p/fish-securenv/issues
# =============================================================================

function __securenv_storage_provider_gpg --no-scope-shadowing
	test -d "$securenv_gpg_store" || mkdir -p "$securenv_gpg_store" || return 1
	set -l storefile "$securenv_gpg_store/$_securenv_storage_entry"

	# Get the user email address.
	set -l securenv_gpg_user "$securenv_gpg_user"
	if test "$securenv_gpg_user" = "auto"
		set securenv_gpg_user (
			gpg --list-keys --with-colons \
			| cut -d':' -f1,10 \
			| grep '^uid:' \
			| sed 's/^uid://; s/^.*<//; s/>.*$//' \
			| head -n1
		)
	end

	# Run the actions.
	switch "$_securenv_storage_action"
		case "list"
			set -l varfile
			for varfile in "$securenv_gpg_store"/*
				echo "$varfile"
			end | sed 's/.*\/\(.*\)$/\1/'

		case "read"
			gpg --quiet --skip-verify --batch --yes --trust-model always \
				--decrypt --armor "$storefile" \
				2>/dev/null

			# If decryption fails, try again but without stderr suppressed.
			if test "$status" -ne 0
				gpg --quiet --skip-verify --batch --yes --trust-model always \
					--decrypt --armor "$storefile" \
					|| return $status
			end

		case "write"
			printf "%s" "$_securenv_storage_value" \
				| gpg --batch --yes --trust-model always \
				  --encrypt --armor --hidden-recipient "$securenv_gpg_user" \
				> "$storefile" \
				|| return $status

		case "delete"
			rm "$storefile" || return $status

		case "query"
			test -f "$storefile" && return 0
			return 1

		case "help:config"
			printf "%s\t%s\n" "securenv_gpg_user"  "the email to use for encrypting entries"
			printf "%s\t%s\n" "securenv_gpg_store" "the directory where securenv entries are stored"

		case "*"
			set _error "unsupported action: $_securenv_storage_action"
			return 1
	end
end


# =============================================================================
# Defaults:
# =============================================================================

if not set -q securenv_gpg_user; set -g securenv_gpg_user "auto"; end
if not set -q securenv_gpg_store
	set -g securenv_gpg_store (printf "%s/%s" \
		(begin set -q XDG_DATA_HOME && echo "$XDG_DATA_HOME"; end || echo "$HOME/.local/share") \
		"securenv/data" \
	)
end

