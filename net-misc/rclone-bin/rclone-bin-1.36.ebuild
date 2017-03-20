# Copyright 2016-2017 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit rindeal

# functions: systemd_douserunit
inherit systemd

DESCRIPTION='Sync files to and from Google Drive, S3, Swift, Cloudfiles, Dropbox, ...'
HOMEPAGE='http://rclone.org/ https://github.com/ncw/rclone'
LICENSE='MIT'

PN_NB="${PN%-bin}"
SLOT='0'
src_uri_base="http://downloads.rclone.org/${PN_NB}-v${PV}-linux"
SRC_URI="
	amd64?	( ${src_uri_base}-amd64.zip )
	arm?	( ${src_uri_base}-arm.zip )
	arm64?	( ${src_uri_base}-arm64.zip )
"

KEYWORDS='-* ~amd64 ~arm ~arm64'

RDEPEND="!!${CATEGORY}/${PN_NB}"

RESTRICT+=" mirror"

src_unpack() {
	default
	cd "${WORKDIR}"/${PN_NB}-*/ || die
	S="${PWD}"
}

inst_d="/opt/${PN_NB}"
QA_PRESTRIPPED="${inst_d#/}/bin/${PN_NB}"

src_install() {
	into "${inst_d}"
	dobin "${PN_NB}"
	dosym "${inst_d}/bin/${PN_NB}" "/usr/bin/${PN_NB}"

	doman "${PN_NB}.1"
	dodoc README.*

	systemd_douserunit "${FILESDIR}/rclone-mount.service"
}
