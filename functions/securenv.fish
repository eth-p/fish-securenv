# =============================================================================
# fish-securenv | Copyright (C) 2022 eth-p
#
# A function for storing secure and sensitive environment variables
# (e.g. GITHUB_TOKEN) and retrieving them only when necessary.
#
# Documentation: https://github.com/eth-p/fish-securenv/tree/master/docs
# Repository:    https://github.com/eth-p/fish-securenv
# Issues:        https://github.com/eth-p/fish-securenv/issues
# =============================================================================

function securenv --description="Secure environment variables for fish"
	argparse -i -s 'placeholdergoeshere' -- $argv || return $status

	# Default to the help command if no command was provided.
	set -l command $argv[1]
	if test -z "$command"
		set command 'help'
	end

	# Run the function for the specified subcommand.
	# This will be '__securenv_command_$command'.
	# Note:
	#	Non-fish commands can also be used, but they will not be listed in the help entry.
	if functions -q "__securenv_command_$command" || command -q "__securenv_command_$command"
		"__securenv_command_$command" $argv[2..]
		return $status
	else
		printf "securenv: unknown subcommand '%s'\n" "$command"
		return 3
	end
end


# =============================================================================
# Subcommands: Reading
# =============================================================================

function __securenv_command_read --description 'print out the value of a securely-stored environment variable'
	argparse 'placeholdergoeshere' -- $argv || return $status
	
	if test (count $argv) -ne 1
		echo "securenv: incorrect usage for 'read' subcommand"
		echo "usage:"
		printf "    securenv read \x1B[4mVARIABLE\x1B[24m\n"
		return 2
	end 1>&2

	# Get the name of the entry.
	set -l entry_name "$argv[1]"
	__securenv_helper_ident_assert "$entry_name" || begin
		printf "securenv: invalid variable name '%s'\n" "$entry_name"
		return 9
	end

	# Ensure that the entry exists in the storage.
	if not __securenv_storage --query "$entry_name"
		printf "securenv: cannot 'read' nonexistent entry '%s'\n" "$entry_name" 1>&2
		return 3
	end

	# Read the entry to stdout.
	__securenv_storage --read "$entry_name" || return 1
	return 0
end

function __securenv_command_list --description 'list the names of all the securely-stored variable entries'
	argparse 'porcelain' -- $argv || return $status
	
	if test (count $argv) -ne 0
		echo "securenv: incorrect usage for 'list' subcommand"
		echo "usage:"
		printf "    securenv list\n"
		return 2
	end 1>&2

	# Run the underlying storage '--list' command.
	__securenv_storage --list 2>/dev/null || return 1
	return 0
end


# =============================================================================
# Subcommands: Apply
# =============================================================================

function __securenv_command_apply --description 'apply an environment variable to the current fish instance'
	argparse 'as=' -- $argv || return $status
	
	if test (count $argv) -ne 1
		echo "securenv: incorrect usage for 'apply' subcommand"
		echo "usage:"
		printf "    securenv apply \x1B[4mVARIABLE\x1B[24m\n"
		printf "    securenv apply \x1B[4mVARIABLE\x1B[24m --as=\x1B[4mNAME\x1B[24m\n"
		return 2
	end 1>&2

	# Get the name of the entry.
	set -l entry_name "$argv[1]"
	__securenv_helper_ident_assert "$entry_name" || begin
		printf "securenv: invalid variable name '%s'\n" "$entry_name"
		return 9
	end
	
	# Get the name of the variable to export to.
	set -l variable "$_flag_as"
	if test -z "$variable"
		set variable "$entry_name"
	end

	# Ensure that the entry exists in the storage.
	if not __securenv_storage --query "$entry_name"
		printf "securenv: cannot 'apply' nonexistent entry '%s'\n" "$entry_name" 1>&2
		return 3
	end

	# Read the entry.
	set -l entry_value (__securenv_storage --read "$entry_name" || return 1)

	# Export the variable.
	set --global --export "$variable" "$entry_value" || return 10
	if not contains "$variable=$entry_name" $__securenv_applied_entries
		set --global --append __securenv_applied_entries "$variable=$entry_name"
	end

	# Create a function that will listen for the variable to be erased.
	function __securenv_listen_for_erase_for_applied__"$variable" \
		--on-event "securenv_erase" \
		--inherit-variable entry_value \
		--inherit-variable entry_name \
		--inherit-variable variable
		if test "$argv[1]" = "$entry_name"
			functions -e __securenv_listen_for_erase_for_applied__"$variable"
			if test (eval "echo \"\$$variable\"") = "$entry_value"
				set --erase --global "$variable"
			end
		end
	end

	return 0
end

function __securenv_command_unapply --description 'unapply an environment variable from the current fish instance'
	argparse 'a/all' -- $argv || return $status
	
	if begin test (count $argv) -ne 1 && test -z "$_flag_all"; end \
		|| begin test (count $argv) -ne 0 && test -n "$_flag_all"; end
		echo "securenv: incorrect usage for 'unapply' subcommand"
		echo "usage:"
		printf "    securenv unapply \x1B[4mVARIABLE\x1B[24m\n"
		printf "    securenv unapply ---all\n"
		return 2
	end 1>&2

	# Get the name of the entry.
	set -l entry_name "$argv[1]"
	__securenv_helper_ident_assert "$entry_name" || begin
		printf "securenv: invalid variable name '%s'\n" "$entry_name"
		return 9
	end
	
	# Get the name of the variable to export to.
	set -l i 1
	set -l unapplied 0
	while test "$i" -le (count $__securenv_applied_entries)
		set applied "$__securenv_applied_entries[$i]"

		set info (string split '=' -- "$applied")
		set applied_as    "$info[1]"
		set applied_entry "$info[2]"

		if test "$entry_name" = "$applied_entry"
			emit securenv_erase "$entry_name"
			set unapplied (math "$unapplied" + 1)
			set -e "__securenv_applied_entries[$i]"
			set i (math "$i" - 1)
		end

		set i (math "$i" + 1)
	end

	if test "$unapplied" -eq 0
		printf "securenv: nothing to 'unapply'\n" 1>&2
		return 1
	end

	printf "securenv: successfully 'unapply' for %s variable(s)\n" "$unapplied" 1>&2
	return 0
end

function __securenv_command_list-applied --description 'list the names of all the applied variable entries'
	argparse 'porcelain' -- $argv || return $status
	
	if test (count $argv) -ne 0
		echo "securenv: incorrect usage for 'list-applied' subcommand"
		echo "usage:"
		printf "    securenv list-applied\n"
		printf "    securenv list-applied --porcelain\n"
		return 2
	end 1>&2

	if test -z "$_flag_porcelain"
		set_color green
		echo "Applied entries:"
	end

	for applied in $__securenv_applied_entries
		set info (string split '=' -- "$applied")
		set applied_as    "$info[1]"
		set applied_entry "$info[2]"

		if test -n "$_flag_porcelain"
			printf "%s:%s\n" "$applied_entry" "$applied_as"
		else
			set_color green
			printf "|  "
			set_color $fish_color_command
			printf "set "
			set_color $fish_color_param
			printf -- "-gx %s " "$applied_as"
			set_color $fish_color_operator
			printf "("
			set_color $fish_color_command
			printf "securenv "
			set_color $fish_color_param
			printf "read %s" "$applied_entry"
			set_color $fish_color_operator
			printf ")"
			set_color normal
			printf "\n"
		end
	end
	return 0
end


# =============================================================================
# Subcommands: Writing
# =============================================================================

function __securenv_command_set --description 'create or update a securely-stored environment variable'
	argparse 'f/force' -- $argv || return $status

	if test (count $argv) -lt 1 || test (count $argv) -gt 2
		echo "securenv: incorrect usage for 'set' subcommand"
		echo "usage:"
		printf "    securenv set \x1B[4mVARIABLE\x1B[24m\n"
		printf "    securenv set \x1B[4mVARIABLE\x1B[24m \x1B[4mVALUE\x1B[24m\n"
		return 2
	end 1>&2

	# Get the name of the entry.
	set -l entry_name "$argv[1]"
	__securenv_helper_ident_assert "$entry_name" || begin
		printf "securenv: invalid variable name '%s'\n" "$entry_name"
		return 9
	end

	# Get the value of the entry.
	set -l entry_value "$argv[2]"
	if test (count $argv) -lt 2
		if ! status --is-interactive
			echo "securenv: cannot 'set' entry without value from non-interactive shell" 1>&2
			return 5
		end

		echo "securenv: please provide a value for the variable" 1>&2
		read --function entry_value \
			--prompt-str (
				set_color $fish_color_param
				printf "%s" "$entry_name"
				set_color $fish_color_operator
				printf "="
				set_color normal
			)
	end

	# If the entry already exists, ask to overwrite it.
	if __securenv_storage --query "$entry_name" && test -z "$_flag_force"
		__securenv_helper_confirm --default="y" --prompt-str="Overwrite existing variable $entry_name? [y/N]"
		set -l ok ""
		switch $status
			case 0;     set ok "ok"
			case 1 2 4; echo "securenv: refusing to overwrite variable '$entry_name'"
			case 5;     echo "securenv: cannot 'set' existing entry from non-interactive shell without '--force' flag"
			case '*';   echo "securenv: an unknown error occurred when trying to confirm"
		end 1>&2

		if not test -n "$ok"
			return 5
		end
	end

	# Write the entry.
	__securenv_storage --write "$entry_name" "$entry_value"
	return $status
end

function __securenv_command_erase --description 'permanently erase a securely-stored variable entry'
	argparse 'f/force' 'keep-in-memory' -- $argv || return $status

	if test (count $argv) -ne 1
		echo "securenv: incorrect usage for 'erase' subcommand"
		echo "usage:"
		printf "    securenv erase \x1B[4mVARIABLE\x1B[24m\n"
		return 2
	end 1>&2

	# Get the name of the entry.
	set -l entry_name "$argv[1]"
	__securenv_helper_ident_assert "$entry_name" || begin
		printf "securenv: invalid variable name '%s'\n" "$entry_name"
		return 9
	end

	# Ensure that the entry exists in the storage.
	if not __securenv_storage --query "$entry_name"
		printf "securenv: cannot 'erase' nonexistent entry '%s'\n" "$entry_name" 1>&2
		return 3
	end
	
	# If the entry already exists, ask to overwrite it.
	if test -z "$_flag_force"
		__securenv_helper_confirm --default="y" --prompt-str="Erase variable $entry_name? [y/N]"
		set -l ok ""
		switch $status
			case 0;     set ok "ok"
			case 1 2 4; echo "securenv: refusing to erase variable '$entry_name'"
			case 5;     echo "securenv: cannot 'erase' entry from non-interactive shell without '--force' flag"
			case '*';   echo "securenv: an unknown error occurred when trying to confirm"
		end 1>&2

		if not test -n "$ok"
			return 5
		end
	end

	# Delete the entry.
	__securenv_storage --delete "$entry_name" || return 1

	# If '--keep-in-memory' is not set, emit an event to erase it.
	if test -z "$_flag_keep_in_memory"
		emit securenv_erase "$entry_name"
		set -U __securenv_erase_entry "$entry_name"
		set -U __securenv_erase_ipc (
			printf "%s:%s:%s" "$entry_name" "$fish_pid" (date "+%s")
		)
	end

	return 0
end

function __securenv_on_erase --on-variable __securenv_erase_ipc
	if test -n "$__securenv_erase_ipc"
		emit securenv_erase "$__securenv_erase_entry"
	end
end


# =============================================================================
# Subcommands: Help
# =============================================================================

function __securenv_command_help --description "show help for securenv"
	argparse 'placeholdergoeshere' -- $argv || return $status

	# Get the list of subcommands.
	set -l commands
	for command in (functions --all \
		| grep '^__securenv_command_' \
		| sed 's/^__securenv_command_//' \
		| sort -u)
		set -a commands (
			printf "%s\t%s" \
			"$command" \
			(functions --details --verbose "__securenv_command_$command" | awk 'NR == 5 { print $0 }')
		)
	end

	# Get the list of config options.
	set -l providers (string join ', ' -- (__securenv_storage --list-providers))
	set -l configs \
		"securenv_provider	the storage provider (available: $providers)"
	
	for provider in $providers
		function __securenv_help_get_provider_info --inherit-variable provider
			set -l _securenv_storage_action 'help:config'
			"__securenv_storage_provider_$provider" 2>/dev/null
		end
		set -a configs (__securenv_help_get_provider_info)
		functions -e __securenv_help_get_provider_info
	end
	
	# Print help.
	set -l pad_command 1
	for command in $commands
		set -l length (string length (string replace --regex '\t.*' '' -- "$command"))
		if test "$length" -gt "$pad_command"; set pad_command "$length"; end
	end

	set -l pad_configs 1
	for config in $configs
		set -l length (string length (string replace --regex '\t.*' '' -- "$config"))
		if test "$length" -gt "$pad_configs"; set pad_configs "$length"; end
	end

	begin
		echo "SUBCOMMANDS:"
		for command in $commands
			set -l info (string split (printf '\t') --max=2 -- "$command")
			printf "    securenv %-$pad_command""s    : %s\n" \
				"$info[1]" \
				"$info[2]"
		end

		echo ""
		echo "CONFIG:"
		for config in $configs
			set -l info (string split (printf '\t') --max=2 -- "$config")
			printf "    \$%-$pad_configs""s    : %s\n" \
				"$info[1]" \
				"$info[2]"
		end
	end 1>&2
end


# =============================================================================
# Command Wrapping:
# =============================================================================

function __securenv_command_wrap --description 'wrap a command to always use a securenv variable'	
	argparse 'as=' -- $argv || return $status
	
	if test (count $argv) -ne 2
		echo "securenv: incorrect usage for 'wrap' subcommand"
		echo "usage:"
		printf "    securenv wrap \x1B[4mCOMMAND\x1B[24m \x1B[4mVARIABLE\x1B[24m\n"
		printf "    securenv wrap \x1B[4mCOMMAND\x1B[24m \x1B[4mVARIABLE\x1B[24m --as=\x1B[4mNAME\x1B[24m\n"
		return 2
	end 1>&2

	# Get the name of the command.
	set -l command "$argv[1]"

	# Get the name of the entry.
	set -l entry_name "$argv[2]"
	__securenv_helper_ident_assert "$entry_name" || begin
		printf "securenv: invalid variable name '%s'\n" "$entry_name"
		return 9
	end
	
	# Get the name of the variable to export to.
	set -l variable "$_flag_as"
	if test -z "$variable"
		set variable "$entry_name"
	end

	__securenv_helper_ident_assert "$variable" || begin
		printf "securenv: invalid '--as' name '%s'\n" "$variable"
		return 9
	end

	# Ensure that the entry exists in the storage.
	if not __securenv_storage --query "$entry_name"
		printf "securenv: cannot 'wrap' using nonexistent entry '%s'\n" "$entry_name" 1>&2
		return 3
	end

	# Wrap a command.
	# (Create a simple passthrough wrapper and let the function wrap do all the work.)
	if command -vq "$command"
		begin
			printf "function %s --wraps=%s\n" (string escape -- "$command") (string escape -- "$command")
			printf "	command %s \$argv # <-- securenv wrap (command) \n" (string escape -- "$command")
			printf "	return \$status\n"
			printf "end\n"
		end | source
	end

	# Wrap a function.
	if functions -q "$command"
		set -l contents (functions "$command")
		set -l variable_escaped (string escape -- "$variable")
		set -l entry_escaped (string escape -- "$entry_name")
		set -l inject_line 1
		set -l inject_code "	set -x $variable_escaped (__securenv_storage --read $entry_escaped) # <-- securenv wrap"

		for line in (seq 1 (count $contents))
			if string match --regex '^\s*function\s+' -- "$contents[$line]" >/dev/null
				set inject_line "$line"
				break
			end
		end

		set contents $contents[1..$line] "$inject_code" $contents[(math $line + 1)..]
		printf "%s\n" $contents | source
	end
end


# =============================================================================
# Confirmation Helper Function:
# Synopsis:
#   __securenv_helper_confirm --prompt-str="continue?"
# Returns:
#   0  -- Explicit yes.
#   1  -- Explicit no.
#   2  -- Attempts failed.
#   4  -- Prompt cancelled.
#   5  -- Non-interactive shell.
# =============================================================================

function __securenv_helper_confirm
	argparse 'prompt-str=' 'attempts' 'default=' -- $argv || return 10
	if test -z "$_flag_attempts"; set _flag_attempts 3; end

	# If not interactive, the prompt cannot be answered.
	if ! status --is-interactive
		return 5
	end

	# Prompt the user for either "Y" or "N".
	set -l answer ""
	for __attempt in (seq 1 $_flag_attempts)
		read --nchars=1 answer \
			--prompt-str (
				set_color green
				printf "%s " "$_flag_prompt_str"
				set_color normal
			) \
			|| return 4

		switch "$answer"
		case "y" "Y"; break
		case "n" "N"; break
		case ""
			set answer "$_flag_default"
			if test -n "$answer"; break; end
		end
	end

	# Return.
	switch "$answer"
		case "y" "Y"; return 0
		case "n" "N"; return 1
		case "*";     return 2
	end
end


# =============================================================================
# Variable Name Assertion Helper Function:
# Synopsis:
#   __securenv_helper_ident_assert NAME
# Returns:
#   0  -- Valid
#   1  -- Invalid
# =============================================================================

function __securenv_helper_ident_assert
	argparse 'thisdoesnotexist' -- $argv || return 10
	echo "$argv" | string match --regex '^[A-Za-z_]+$' >/dev/null || return 1
	return 0
end


# =============================================================================
# Storage Provider Wrapper Function:
# Synopsis:
#   __securenv_storage --list
#   __securenv_storage --list-providers
#   __securenv_storage --query [entry]
#   __securenv_storage --read [entry]
#   __securenv_storage --write [entry] [value]
#   __securenv_storage --delete [entry]
# =============================================================================

function __securenv_storage
	argparse -x 'read,write,list,delete,query,help,list-providers' \
		'read' 'write' 'list' 'delete' 'query' 'help=' 'list-providers' \
		-- $argv || return $status

	# Handle '--list-providers' flag.
	if test -n "$_flag_list_providers"
		functions --all \
			| grep '^__securenv_storage_provider_' \
			| sed 's/^__securenv_storage_provider_//' \
			| cut -d'_' -f1 \
			| sort -u
		return 0
	end
	
	# Set the $_securenv_storage_action variable.
	# This variable tells the storage provider what to do.
	set -l _securenv_storage_action \
		(string replace --regex "^-*" "" -- "$_flag_read$_flag_write$_flag_list$_flag_delete$_flag_query")

	if test -n "$_flag_help"
		set _securenv_storage_action "help:$_flag_help"
	end
	
	# Set the $_securenv_storage_entry variable.
	# This is the entry that should be loaded.
	set -l securenv_storage_entry ""	
	switch "$_securenv_storage_action"
		case "read" "write" "delete" "query"
			set _securenv_storage_entry $argv[1]
	end
	
	# Set the $_securenv_storage_value variable.
	# This is the value that should be written to the key.
	set -l securenv_storage_value ""	
	switch "$_securenv_storage_action"
		case "write"
			set _securenv_storage_value $argv[2]
	end

	# Run the storage provider function.
	set _error ''
	"__securenv_storage_provider_$securenv_provider"
	set -l result $status

	# If '--query' return 1 if not found and 0 if found.
	if test -n "$_flag_query"
		test "$result" -eq 0 && return 0
		return 1
	end

	# If the return was not zero, print a message and return an error.
	if test "$result" -ne 0
		if test -z "$_error"
			set _error "$result"
		end

		printf "storage provider %s encountered an error: %s\n" \
			"$securenv_provider" \
			"$_error" \
			1>&2

		return 2
	end
end


# =============================================================================
# Defaults:
# =============================================================================

if not set -q securenv_provider; set -g securenv_provider "gpg"; end

