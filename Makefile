
DESTDIR	 =
BINDIR	 = /usr/bin
MANDIR	 = /usr/share/man
ETCDIR	 = /etc/pkg-get
CACHEDIR = /var/cache/pkg-get

VERSION  = 0.1.2

#all: pkg-get pkg-get.8
all: pkg-get

%: %.in
	sed "s/#VERSION#/$(VERSION)/" $< > $@

.PHONY:	install dist clean

install: all
	install -D -m0755 pkg-get $(DESTDIR)$(BINDIR)/pkg-get
#	install -D -m0644 pkg-get.8 $(DESTDIR)$(MANDIR)/man8/pkg-get.8
	install -D -m0644 pkg-get.pub $(DESTDIR)$(ETCDIR)/pkg-get.pub
	install -D -m0644 mirrors $(DESTDIR)$(ETCDIR)/mirrors
	install -d $(DESTDIR)$(CACHEDIR)

dist: clean
	(cd .. && tar czvf pkg-get-$(VERSION).tar.gz pkg-get-$(VERSION))

clean:
	rm -f pkg-get pkg-get.8

# End of file
