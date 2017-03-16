# Copyright 2016 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: jetbrains-intellij.eclass
# @MAINTAINER:
# Jan Chren (rindeal) <dev.rindeal+gentoo-overlay@gmail.com>
# @BLURB: Boilerplate for IntelliJ based IDEs
# @DESCRIPTION:

if [ -z "${_JETBRAINS_INTELLIJ_ECLASS}" ] ; then

case "${EAPI:-0}" in
	6) ;;
	*) die "Unsupported EAPI='${EAPI}' for '${ECLASS}'" ;;
esac


inherit rindeal
# functions: make_desktop_entry, newicon, eshopts_push
inherit eutils
# functions: get_version_component_range
inherit versionator
# EXPORT_FUNCTIONS: src_prepare, pkg_preinst, pkg_postinst, pkg_postrm
inherit xdg


declare -g -r _JBIJ_PN_BASE="${PN%"-community"}"

HOMEPAGE="https://www.jetbrains.com/${_JBIJ_PN_BASE}"
LICENSE="IDEA || ( IDEA_Academic IDEA_Classroom IDEA_OpenSource IDEA_Personal )"

SLOT="$(get_version_component_range 1-2)"
declare -g -r _JBIJ_PN_SLOTTED="${PN}${SLOT}"

# @ECLASS-VARIABLE: JBIJ_URI
# @DEFAULT:
# 	JBIJ_URI="${PN}/${P}"
# @DESCRIPTION:
# 	The part of SRC_URI between domain name and extension.
# 	This varies greatly among packages as the first part is usually an internal codename of the product.
: "${JBIJ_URI:="${PN}/${P}"}"

SRC_URI="https://download.jetbrains.com/${JBIJ_URI}.tar.gz"

KEYWORDS="~amd64 ~arm ~x86"
IUSE="system-jre"
RESTRICT+=" mirror strip test"

RDEPEND="system-jre? ( >=virtual/jre-1.8 )"


# @ECLASS-VARIABLE: JBIJ_TAR_EXCLUDE
# @DESCRIPTION:
# 	An array of paths relative to the ${S} dir, which will be excluded when unpacking the archive.
# 	Please put here only files/dirs with big size or many inodes.

# @ECLASS-VARIABLE: JBIJ_PN_PRETTY
# @DESCRIPTION:
# 	Prettified PN.
# 	This will be used in various user-facing places, eg. desktop menu entry.
: "${JBIJ_PN_PRETTY:="${PN^}"}"


EXPORT_FUNCTIONS src_unpack src_prepare src_compile pkg_preinst src_install pkg_postinst pkg_postrm


jetbrains-intellij_src_unpack() {
	debug-print-function ${FUNCNAME}

	local _A=( $A )
	(( ${#_A[@]} == 1 )) || die "Your SRC_URI contains too many archives"
	local arch="${DISTDIR}/${_A[0]}"

	mkdir -p "${S}" || die
	local tar=(
		tar --extract

		--no-same-owner --no-same-permissions
		--strip-components=1 # otherwise we'd have to specify excludes as `${P}/path`

		--file="${arch}"
		--directory="${S}"
	)

	local excludes=(
		'license'
		# This plugins has several QA violations, eg. https://github.com/rindeal/gentoo-overlay/issues/67.
		# If someone needs it, it can be installed separately from JetBrains plugin repo.
		'plugins/tfsIntegration'
	)
	use system-jre	 && excludes+=( 'jre' )
	use amd64	|| excludes+=( bin/{fsnotifier64,libbreakgen64.so,libyjpagent-linux64.so,LLDBFrontend} )
	use arm		|| excludes+=( bin/fsnotifier-arm )
	use x86		|| excludes+=( bin/{fsnotifier,libbreakgen.so,libyjpagent-linux.so} )

	excludes+=( "${JBIJ_TAR_EXCLUDE[@]}" )
	# mark as readonly to prevent the user from mistakenly editing it in other phases
	readonly JBIJ_TAR_EXCLUDE

	einfo "Unpacking '${arch}' to '${S}'"

	einfo "Excluding: $(printf "'%s' " "${excludes[@]}")"
	tar+=( "${excludes[@]/#/--exclude=}" )

	debug-print "${ECLASS}: ${FUNCNAME}: Running: '${tar[@]}'"
	"${tar[@]}" || die
}


jetbrains-intellij_src_prepare() {
	debug-print-function "${FUNCNAME}"
	xdg_src_prepare
}


jetbrains-intellij_src_compile() { : ; }


# @ECLASS-VARIABLE: JBIJ_DESKTOP_CATEGORIES=()
# @DEFAULT_UNSET
# @DESCRIPTION:
# 	An array of additional desktop menu entry categories.
# 	Defaults are 'Development;IDE;Java', which cannot be unset.

# @ECLASS-VARIABLE: JBIJ_DESKTOP_EXTRAS=()
# @DEFAULT_UNSET
# @DESCRIPTION:
# 	An array of lines which will be appended to the generated '.desktop' file.

# @ECLASS-VARIABLE: JBIJ_INSTALL_DIR
# @DESCRIPTION:
# 	Readonly variable pointing to the directory under which everything will be installed.
# 	The path is without EPREFIX.
declare -g -r JBIJ_INSTALL_DIR="/opt/jetbrains/${_JBIJ_PN_SLOTTED}"

# @ECLASS-VARIABLE: JBIJ_STARTUP_SCRIPT_NAME
# @DESCRIPTION:
# 	Filename of the startup script.
# 	This file must be located in the 'bin/' dir and ends with '.sh'.
: "${JBIJ_STARTUP_SCRIPT_NAME:="${_JBIJ_PN_BASE}.sh"}"


jetbrains-intellij_src_install() {
	debug-print-function ${FUNCNAME}

	## install icon
	# nullglob is required as BASH would think '*' is a filename otherwise
	eshopts_push -s nullglob
	# first find any '*.svg' and '*.png' images in the 'bin/' dir
	local svg=( bin/*.svg ) png=( bin/*.png )

	# prefer SVG icons if any were found
	if (( ${#svg[@]} )) ; then
		newicon -s scalable "${svg[0]}" "${_JBIJ_PN_SLOTTED}.svg"

	# PNG otherwise
	elif (( ${#png[@]} )) ; then
		# icons size is sometimes 128 and sometimes 256
		newicon -s 128 "${png[0]}" "${_JBIJ_PN_SLOTTED}.png"

	# throw ebuild QA warning if nothing was found
	else
		equawarn "No icon found"
	fi
	eshopts_pop

	[[ -n "${JBIJ_INSTALL_DIR}" ]] || die "JBIJ_INSTALL_DIR='${JBIJ_INSTALL_DIR}' not defined"

	## first let's copy everything to the image dir
	insinto "${JBIJ_INSTALL_DIR}"
	doins -r ./*

	## now let's push into the image dir and change few things in there
	pushd "${ED}/${JBIJ_INSTALL_DIR}" >/dev/null || die "JBIJ_INSTALL_DIR='${JBIJ_INSTALL_DIR}'"
	{
		## first check the directory has a structure that we expect it to have
		[[ -f "bin/${JBIJ_STARTUP_SCRIPT_NAME}" ]] || die "'bin/${JBIJ_STARTUP_SCRIPT_NAME}' not found"

		## fix permissions
		chmod -v a+x bin/${JBIJ_STARTUP_SCRIPT_NAME} || die
		chmod -v a+x bin/fsnotifier* || die
		use system-jre || { chmod -v a+x jre/jre/bin/* || die ; }
	}
	popd >/dev/null || die

    ## install symlink
	dosym "${JBIJ_INSTALL_DIR}/bin/${JBIJ_STARTUP_SCRIPT_NAME}" "/usr/bin/${_JBIJ_PN_SLOTTED}"

	## generate and install .desktop menu file
	local make_desktop_entry_args=(
		# start the script directly
		"${EPREFIX}${JBIJ_INSTALL_DIR}/bin/${JBIJ_STARTUP_SCRIPT_NAME} %U"	# exec
		"${JBIJ_PN_PRETTY} ${SLOT}"	# name
		"${_JBIJ_PN_SLOTTED}"		# icon
		"Development;IDE;Java;$(IFS=';'; echo "${JBIJ_DESKTOP_CATEGORIES[*]}")"	# categories
	)
	local make_desktop_entry_extras=(
		"StartupWMClass=jetbrains-${PN}"
		"${JBIJ_DESKTOP_EXTRAS[@]}"
	)
	make_desktop_entry "${make_desktop_entry_args[@]}" \
		"$( printf '%s\n' "${make_desktop_entry_extras[@]}" )"

	# recommended by: https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit
	mkdir -p "${D}"/etc/sysctl.d || die
	echo "fs.inotify.max_user_watches = 524288" \
		>"${D}"/etc/sysctl.d/30-idea-inotify-watches.conf || die
}


jetbrains-intellij_pkg_preinst() {
	debug-print-function "${FUNCNAME}"
	xdg_pkg_preinst
}


jetbrains-intellij_pkg_postinst() {
	debug-print-function "${FUNCNAME}"
	xdg_pkg_postinst
}


jetbrains-intellij_pkg_postrm() {
	debug-print-function "${FUNCNAME}"
	xdg_pkg_postrm
}


_JETBRAINS_INTELLIJ_ECLASS=1
fi