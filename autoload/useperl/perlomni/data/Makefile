PERL = perl

all: host.pod

host.pod :
	$(PERL) gen-host.pl > $@

cpan.pod :
	wget http://cpan.nctu.edu.tw/modules/02packages.details.txt.gz
	echo "=item Module" > $@
	cat 02packages.details.txt.gz | gzip -dc | grep -Ev '^[A-Za-z0-9-[]+: ' | cut -d" " -f1 >> $@

clean :
	-rm 02packages.details.txt.gz
