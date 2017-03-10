# Copyright 2016 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: git-hosting.eclass
# @MAINTAINER:
# Jan Chren (rindeal) <dev.rindeal+gentoo@gmail.com>
# @BLURB: Support eclass for packages hosted on online git hosting services like GitHub

if [ -z "${_GH_ECLASS}" ] ; then

case "${EAPI:-0}" in
	5|6) ;;
	*) die "Unsupported EAPI='${EAPI}' for '${ECLASS}'" ;;
esac

### BEGIN Functions

##
# @FUNCTION:	_git-hosting_parse_uri
# @PRIVATE
# @USAGE:		$0 "${uri}" provider user repo
# @DESCRIPTION: parses uri into its components
##
_git-hosting_parse_uri() {
	(( $# != 4 )) && die "${FUNCNAME}: Not enough arguments provided"

	local -r -- uri="$1" ; shift
	local -n -- _provider="$1" ; shift
	local -n -- _user="$1" ; shift
	local -n -- _repo="$1" ; shift

	# use an array to split the string to '/' delimited parts
	local -a uri_a=( ${uri//\// } )

	(( "${#uri_a[*]}" > 0 )) && \
		_provider="${uri_a[0]}"
	(( "${#uri_a[*]}" > 1 )) && \
		_user="${uri_a[1]}"
	(( "${#uri_a[*]}" > 2 )) && \
		_repo="${uri_a[2]}"

	return 0
}

##
# @FUNCTION:	_git-hosting_gen_base_uri
# @PRIVATE
# @USAGE:		$0 "${provider}" "${user}" "${repo}" base_uri
# @DESCRIPTION: Generate base URI of the repository. Can be used as a homepage.
##
_git-hosting_gen_base_uri() {
	(( $# != 4 )) && die "${FUNCNAME}: Note enough arguments provided"

	local -r -- provider="$1" ; shift
	local -r -- user="$1" ; shift
	local -r -- repo="$1" ; shift
	local -n -- _base_uri="$1" ; shift

	local domain=
	_git-hosting_get_domain "${provider}" domain
	readonly domain

	_base_uri="https://${domain}/${user}/${repo}"

	return 0
}

##
# @FUNCTION:	_git-hosting_get_domain
# @PRIVATE
# @USAGE:		$0 "${provider}" domain
# @DESCRIPTION: Outputs domain name of the hosting provider.
##
_git-hosting_get_domain() {
	(( $# != 2 )) && die "${FUNCNAME}: Note enough arguments provided"

	local -r -- provider="$1" ; shift
	# this var shadowed by the one in _git-hosting_gen_base_uri
	local -n -- _domain="$1" ; shift

	case "${provider}" in
	'bitbucket')
		_domain='bitbucket.org' ;;
	'github')
		_domain='github.com' ;;
	'gitlab')
		_domain='gitlab.com' ;;
	*) die "Unsupported provider '${provider}'" ;;
	esac
}

##
# @FUNCTION:	_git-hosting_parse_uri
# @USAGE:		$0 "${uri}" "${ref}" snapshot_uri snapshot_ext
# @DESCRIPTION: Generate snapshot URI
##
git-hosting_gen_snapshot_uri() {
	case $# in
	# interface mostly for extrenal use
	4)
		local -r -- uri="$1" ; shift

		local -- provider user repo
		_git-hosting_parse_uri "${uri}" provider user repo
		readonly provider user repo

		local -- base_uri
		_git-hosting_gen_base_uri "${provider}" "${user}" "${repo}" base_uri
		readonly base_uri
		;;

	# interface mostly for internal use
	5)
		local -r -- provider="$1" ; shift
		local -r -- base_uri="$1" ; shift
		;;

	*) die "${FUNCNAME}: Note enough arguments provided" ;;
	esac

	local -r -- ref="$1" ; shift
	local -n -- _snapshot_uri="$1" ; shift
	local -n -- _ext="$1" ; shift

	local -- uri_path

	case "${provider}" in
	'bitbucket' )
		_ext=".tar.bz2"
		uri_path="get/${ref}${_ext}"
		;;
	'github' )
		_ext=".tar.gz"
		uri_path="archive/${ref}${_ext}"
		;;
	'gitlab' )
		_ext=".tar.bz2"
		uri_path="repository/archive${_ext}?ref=${ref}"
		;;
	*) die "Unsupported provider '${provider}'" ;;
	esac

	_snapshot_uri="${base_uri}/${uri_path}"
}

##
# @FUNCTION:	_git-hosting_parse_uri
# @USAGE:		$0 "${uri}" live_uri
# @DESCRIPTION: Generate URI for git
##
git-hosting_gen_live_uri() {
	(( $# != 2 )) && die "${FUNCNAME}: Note enough arguments provided"

	local -r -- uri="$1" ; shift
	local -n -- live_uri="$1" ; shift

	local -- provider user repo
	_git-hosting_parse_uri "${uri}" provider user repo
	readonly provider user repo

	local -- base_uri
	_git-hosting_gen_base_uri "${provider}" "${user}" "${repo}" base_uri
	readonly base_uri

	live_uri="${base_uri}.git"
}

##
# @FUNCTION:	git-hosting_unpack
##
git-hosting_unpack() {
	(( $# != 2 )) && die
	local -r -- unpack_from="${1}"
	# do not use '${S}' for 'unpack_to' as user might overwrite 'S' leading to a wrong behaviour
	local -r -- unpack_to="${2}"

	## extract snapshot to 'S'
	printf ">>> Unpacking '%s' to '%s'\n" "${unpack_from##*/}" "${unpack_to}"
	mkdir -p "${unpack_to}" || die "Failed to create S='${unpack_to}' directory"
	local tar=( tar --extract
		--strip-components=1
		--file="${unpack_from}" --directory="${unpack_to}" )
	"${tar[@]}" || die "Failed to extract '${unpack_from}' archive"

	## filter 'unpack_from' from 'A'
	local f new_a_a=()
	for f in ${A} ; do
		if [[ "${f}" != "${unpack_from##*/}" ]] ; then
			new_a_a+=( "${f}" )
		fi
	done
	A="${new_a_a[@]}"

	return 0
}
### END Functions

### BEGIN Variables

##
# @ECLASS-VARIABLE: GH_URI
# @DEFAULT_UNSET
# @DESCRIPTION:
# String in the format:
#
#      <provider>[/<user_name>[/<repository_name>]]
#
# Default <user_name> and <repository_name> is ${PN}.
##
[[ -z "${GH_URI}" ]] && die "GH_URI must be set to a non-empty value"

##
# @ECLASS-VARIABLE: GH_PROVIDER
# @READONLY
# @DEFAULT_UNSET
# @DESCRIPTION:
# Contains the first part of GH_URI - the git hosting provider.
# Currently one of 'github', 'gitlab', 'bitbucket'.
##
GH_PROVIDER=

##
# @ECLASS-VARIABLE: GH_USER
# @READONLY
# @DEFAULT: ${PN}
# @DESCRIPTION:
# Contains the second part of GH_URI - the username/orgname/groupname.
##
GH_USER="${PN}"

##
# @ECLASS-VARIABLE: GH_REPO
# @READONLY
# @DEFAULT: ${PN}
# @DESCRIPTION:
# Contains the third part of GH_URI - the repository name.
##
GH_REPO="${PN}"

_git-hosting_parse_uri "${GH_URI}" GH_PROVIDER GH_USER GH_REPO
declare -g -r -- GH_PROVIDER GH_USER GH_REPO

##
# @ECLASS-VARIABLE: GH_FETCH_TYPE
# @DEFAULT: 'snapshot', for versions containing '9999' defaults to 'live'
# @DESCRIPTION:
# Defines if fetched from git ("live") or archive ("snapshot") or eclass
# shouldn't handle fetching at all ("manual").
##
if [[ -z "${GH_FETCH_TYPE}" ]] ; then
	if [[ "${PV}" == *9999* ]] ; then
		GH_FETCH_TYPE='live'
	else
		GH_FETCH_TYPE='snapshot'
	fi
fi
declare -g -r -- GH_FETCH_TYPE

##
# @ECLASS-VARIABLE: GH_REF
# @DEFAULT: for 'snapshot', "${PV}"
# @DESCRIPTION:
# Tag/commit/git_ref (except branches) that is fetched from git hosting provider.
##
if [[ -z "${GH_REF}" ]] ; then
	case "${GH_FETCH_TYPE}" in
		'snapshot')
			# a research conducted on April 2016 among the first 700 repos with >10000 stars on GitHub shows:
			# - no tags: 158
			# - `v` prefix: 350
			# - no prefix: 192
			GH_REF="${PV}" ;;
		'live' | 'manual') : ;;
		*) die "Unsupported fetch type: '${GH_FETCH_TYPE}'" ;;
	esac
fi
declare -g -r -- GH_REF

##
# @ECLASS-VARIABLE: _GH_DOMAIN
# @PRIVATE
# @READONLY
# @DESCRIPTION:
# Domain name of the hosting provider.
##
_git-hosting_get_domain "${GH_PROVIDER}" _GH_DOMAIN
declare -g -r -- _GH_DOMAIN

##
# @ECLASS-VARIABLE: GH_BASE_URI
# @READONLY
# @DEFAULT: "https://${_GH_DOMAIN}/${GH_USER}/${GH_REPO}"
# @DESCRIPTION:
# Base uri of the repo
##
_git-hosting_gen_base_uri "${GH_PROVIDER}" "${GH_USER}" "${GH_REPO}" GH_BASE_URI
declare -g -r -- GH_BASE_URI

##
# @ECLASS-VARIABLE: GH_HOMEPAGE
# @READONLY
# @DEFAULT: "${GH_BASE_URI}"
# @DESCRIPTION:
# Homepage of the repository hosted by the git hosting provider/
##
declare -g -r -- GH_HOMEPAGE="${GH_BASE_URI}"

##
# @ECLASS-VARIABLE: GH_DISTFILE
# @DEFAULT: ${P}-${GH_PROVIDER}
# @DESCRIPTION:
# Name of the distfile (without any extensions).
##
: "${GH_DISTFILE:="${GH_USER}--${GH_REPO}--${GH_REF}--${GH_PROVIDER}"}"
declare -g -r -- GH_DISTFILE

case "${GH_FETCH_TYPE}" in
'snapshot' )
	git-hosting_gen_snapshot_uri "${GH_PROVIDER}" "${GH_BASE_URI}" "${GH_REF}" _GH_SNAPSHOT_SRC_URI _GH_DISTFILE_EXT
	declare -g -r -- _GH_SNAPSHOT_SRC_URI _GH_DISTFILE_EXT
	;;
'live' | 'manual' ) : ;;
*) die "Unsupported fetch type: '${GH_FETCH_TYPE}'" ;;
esac

### END Variables

### BEGIN Inherits

case "${GH_FETCH_TYPE}" in
	'live' )
		[[ -z "${EGIT_REPO_URI}" ]] && \
			EGIT_REPO_URI="${GH_BASE_URI}.git"
		[[ -n "${GH_REF}" && -z "${EGIT_COMMIT}" ]] && \
			EGIT_COMMIT="${GH_REF}"
		[[ -z "${EGIT_CLONE_TYPE}" ]] && \
			EGIT_CLONE_TYPE="shallow"

		inherit git-r3
		;;
	'snapshot' | 'manual' ) : ;;
	*) die "Unsupported fetch type: '${GH_FETCH_TYPE}'" ;;
esac

### END Inherits

### BEGIN Portage variables

# set SRC_URI only for 'snapshot' GH_FETCH_TYPE
case "${GH_FETCH_TYPE}" in
'snapshot' ) SRC_URI="${_GH_SNAPSHOT_SRC_URI} -> ${GH_DISTFILE}${_GH_DISTFILE_EXT}" ;;
'live' | 'manual' ) : ;;
*) die "Unsupported fetch type: '${GH_FETCH_TYPE}'" ;;
esac

: "${HOMEPAGE:="${GH_HOMEPAGE}"}"

# prefer their CDN over Gentoo mirrors
RESTRICT="${RESTRICT} primaryuri"

### END Portage variables

# debug-print summary
if [[ -n "${EBUILD_PHASE_FUNC}" && "${EBUILD_PHASE_FUNC}" == 'pkg_setup' ]] ; then
	debug-print "${ECLASS}: -- vardump --"
	for _v in $(compgen -A variable) ; do
		if [[ "${_v}" == "GH_"* || "${_v}" == "EGIT_"* ]] ; then
			debug-print "${ECLASS}: ${_v}='${!_v}'"
		fi
	done
	debug-print "${ECLASS}: ----"
	unset _v
fi

### BEGIN Exported functions

EXPORT_FUNCTIONS src_unpack

##
# @FUNCTION: git-hosting_src_unpack
# @DESCRIPTION:
# Handles unpacking of special source files, like git snapshots, live git repos, ...
#
# Please note that if GH_FETCH_TYPE=~(live|snapshot) this function won't unpack files from SRC_URI
# other than those it added itself, additionally, upon execution it filters them out of '${A}' variable, so
# that you can than loop through '${A}' safely and unpack the rest yourself or just call default().
##
git-hosting_src_unpack() {
	debug-print-function "${FUNCNAME}"

	case "${GH_FETCH_TYPE}" in
		'live') git-r3_src_unpack ;;
		'snapshot')
			git-hosting_unpack "${DISTDIR}/${GH_DISTFILE}${_GH_DISTFILE_EXT}" "${WORKDIR}/${P}"
			;;
		'manual') default ;;
		*) die ;;
	esac
}

### END Exported functions

_GH_ECLASS=1
fi
