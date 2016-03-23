# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="3"

inherit user eutils

MY_P="${PN}.v.${PV}"
DESCRIPTION="Dynamic DNS (DynDNS) Update daemon in C that supports multiple services"
HOMEPAGE="http://sourceforge.net/projects/inadyn-mt"
SRC_URI="mirror://sourceforge/${PN}/${PN}/${MY_P}/${MY_P}.tar.gz"

LICENSE="|| ( GPL-2 GPL-3 )"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND=""
DEPEND="${RDEPEND}"

S="${WORKDIR}"/${MY_P}

pkg_setup() {
	enewuser ${PN}
}

src_prepare() {
	rm -R bin || die

	# inadyn-mt comes with outdated inadyn man pages - see inadyn-mt bug 2445206
	rm man/inadyn.8
	rm man/inadyn.conf.5
}

src_configure() {
        econf --disable-sound \
	--enable-threads
}

src_install() {
	# dodir /usr/share || die
	emake DESTDIR="${D}" INSTALL_PREFIX="${D}"/usr/share install || die

	dodoc ChangeLog NEWS README NOTICE AUTHORS || die
	dohtml readme.html || die

	newinitd "${FILESDIR}"/${PN}.initd ${PN} || die
	insinto /etc
	doins "${FILESDIR}"/${PN}.conf || die
}

pkg_postinst() {
	elog "You will need to edit /etc/inadyn-mt.conf before running inadyn-mt"
	elog "for the first time. The format is basically the same as the"
	elog "command line options; see inadyn-mt and inadyn-mt.conf manpages."
}
