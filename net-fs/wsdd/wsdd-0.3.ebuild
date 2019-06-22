# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="7"
PYTHON_COMPAT=( python3_{3,4,5,6,7} )
inherit python-r1 systemd

DESCRIPTION="Wsdd is a Web Service Discovery host daemon, which enables (Samba) hosts to be found by WSD clients such as Windows"
HOMEPAGE="https://github.com/christgau/wsdd"
SRC_URI="https://github.com/christgau/wsdd/archive/v${PV}.tar.gz -> ${P}.tar.gz"
RESTRICT="nomirror"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"
RDEPEND="${PYTHON_DEPS}"


src_install() {
	python_foreach_impl python_newscript src/wsdd.py wsdd
	doinitd etc/openrc/wsdd
	systemd_dounit etc/systemd/wsdd.service
	einstalldocs
}
