#!/bin/bash -ex

target=$HOME/aliases/aliases
now=$(date +%Y%m%d%H%M%S)
old=$HOME/aliases/old/aliases.$now
new=$target.$now

sed -n '/Beginning of list of aliases/,/End of list of aliases/p' > $new
if [ ! -s $new ]; then
    echo "Empty after sed" 1>&2
    exit 1
fi

dos2unix $new

lines=$(wc -l < $new)
goodlines=$(egrep -c '^#|.*:.*(@|/dev/null)' $new)
if [ $lines != $goodlines ]; then
    echo "Line count mismatch: $lines total vs. $goodlines good" 1>&2
    echo "Bad lines:" 1>&2
    egrep -v '^#|.*:.*@' $new
    exit 1
fi

if ! grep -q -s '^misc-taxes-moderated:	mtm@asktax\.org$' $new; then
    echo "misc-taxes-moderated line is missing" 1>&2
    exit 1
fi

ln -f $new $target.new
mkdir -p "$(dirname $old)"
ln $target $old
/usr/sbin/postalias $new
mv -f $target.new $target
mv -f $new.db $target.db
rm -f $new
chmod a+r $target $target.db
diff -u $old $target | mail -s 'Installed aliases update' root
