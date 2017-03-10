# Copyright 2016 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: portage-patches.eclass
# @MAINTAINER:
# Jan Chren (rindeal) <dev.rindeal+gentoo-overlay@gmail.com>
# @BLURB: Set of portage functions overrides intended to be used anywhere
# @DESCRIPTION:

case "${EAPI:-0}" in
    5|6) ;;
    *) die "Unsupported EAPI='${EAPI}' for '${ECLASS}'" ;;
esac


## Origin: portage - bin/isolated-functions.sh
## PR: https://github.com/gentoo/portage/pull/26
has() {
	local needle=$'\a'"$1"$'\a'
	shift
	local IFS=$'\a'
	local haystack=$'\a'"$@"$'\a'

	[[ "${haystack}" == *"${needle}"* ]]
}
