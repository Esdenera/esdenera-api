LUA=		luajit
LUA_ABI=	`pkg-config --variable abiver ${LUA}`
LUA_PREFIX=	`pkg-config --variable prefix ${LUA}`
NOMAN=		y

BINDIR=		/usr/local/bin
NAME=		en
SCRIPT=		cli.lua

realinstall:
	${INSTALL} -d -o ${BINOWN} -g ${BINGRP} -m 755 \
	    ${DESTDIR}${LUA_PREFIX}/share/lua/${LUA_ABI}
	${INSTALL} -c -o root -g wheel -m 644 ${.CURDIR}/tnos.lua \
	    /${DESTDIR}${LUA_PREFIX}/share/lua/${LUA_ABI}/
	${INSTALL} -c -o root -g wheel -m 755 ${.CURDIR}/${SCRIPT} \
	    /${DESTDIR}${BINDIR}/${NAME}

.include <bsd.prog.mk>
