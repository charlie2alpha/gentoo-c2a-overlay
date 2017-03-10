# Copyright 2016 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: rindeal.eclass
# @MAINTAINER:
# Jan Chren (rindeal) <dev.rindeal+gentoo-overlay@gmail.com>
# @BLURB: Base eclass that should be inheritted by all ebuilds.
# @DESCRIPTION:

if [ -z "${_RINDEAL_ECLASS}" ] ; then

case "${EAPI:-0}" in
    6) ;;
    *) die "Unsupported EAPI='${EAPI}' for '${ECLASS}'" ;;
esac


## "Command not found" handler
if [[ -z "$(type -t command_not_found_handle 2>/dev/null)" ]] ; then

	command_not_found_handle() {
		debug-print-function "${FUNCNAME}" "$@"
		local -r cmd="${1}"

		## do not die in a pipe
		[[ -t 1 ]] || return 127

		## do not die in a subshell
		read _pid _cmd _state _ppid _pgrp _session _tty_nr _tpgid _rest < /proc/self/stat
		(( $$ == _tpgid )) && return 127

		die "'${cmd}': command not found"
	}

else
	eqawarn "${ECLASS}: command_not_found_handle() already registered"
fi


if [[ -z "$(declare -p _RINDEAL_ECLASS_SWAPS 2>/dev/null)" ]] ; then
declare -gA _RINDEAL_ECLASS_SWAPS=(
	['flag-o-matic']='flag-o-matic-patched'
	['cmake-utils']='cmake-utils-patched'
)
fi

## inherit hook
if [[ -z "$(type -t __original_inherit 2>/dev/null)" ]] ; then

eval "__original_$(declare -f inherit)"
inherit() {
	local a args=()
	for a in "$@" ; do
		if [[ ${_RINDEAL_ECLASS_SWAPS["${a}"]+exists} ]] ; then
			args+=( "${_RINDEAL_ECLASS_SWAPS["${a}"]}" )
			unset "_RINDEAL_ECLASS_SWAPS[${a}]"
		else
			args+=( "${a}" )
		fi
	done

	__original_inherit "${args[@]}"
}
fi


epushd() {
	pushd "$@" >/dev/null || die
}

epopd() {
	popd "$@" >/dev/null || die
}


erm() {
	debug-print-function "${FUNCNAME}" "$@"
	local verbose="-v"
	if [[ -n "${RM_V}" && \
		( ! (( RM_V )) || "${RM_V}" == 'false' || "${RM_V}" == 'no' ) \
		]]
	then
		verbose=
	fi

	rm ${verbose} --interactive=never --preserve-root --one-file-system "$@" || die
}


ecp() {
	cp -v "${@}" || die
}

emv() {
	mv -v "${@}" || die
}

emkdir() {
	mkdir -p -v "${@}" || die
}


_RINDEAL_ECLASS=1
fi
