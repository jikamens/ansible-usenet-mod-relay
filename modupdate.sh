#!/bin/bash -ex

tf=/tmp/modupdate.$$
list_host=lists.eyrie.org
target=$HOME/aliases/aliases
now=$(date +%Y%m%d%H%M%S)
old=$HOME/aliases/old/aliases.$now
new=$target.$now
check_ip=true

while [ -n "$1" ]; do
    case "$1" in
        --permissive) shift; check_ip=false ;;
        *) echo "Unrecognized argument \"$1\"" 1>&2; exit 1 ;;
    esac
done

trap "rm -f $tf" EXIT
rm -f $tf
cat > $tf

if $check_ip; then
    received=$(formail -x Received -c < $tf | head -1)
    if [ ! "$received" ]; then
        echo "Could not find Received line in message" 1>&2
        exit 1
    fi

    remote_ip=$(echo "$received" | sed -n -E \
                -e 's/.*\[([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\].*/\1/p' \
                -e 's/.*\[IPv6:([0-9a-f:]+)\].*/\1/p')
    if [ ! "$remote_ip" ]; then
        echo "Could not find remote IP in first Received line" 1>&2
        exit 1
    fi

    matching=$(host $list_host | awk '$NF == "'$remote_ip'" {print}')
    if [ ! "$matching" ]; then
        echo "Remote IP $remote_ip does not appear to match $list_host" 1>&2
        exit 1
    fi
fi

sed -n '/Beginning of list of aliases/,/End of list of aliases/p' < $tf > $new
if [ ! -s $new ]; then
    echo "Empty after sed" 1>&2
    exit 1
fi

dos2unix $new

lines=$(wc -l < $new)
goodlines=$(grep -E -c '^#|.*:.*(@|/dev/null)' $new)
if [ $lines != $goodlines ]; then
    echo "Line count mismatch: $lines total vs. $goodlines good" 1>&2
    echo "Bad lines:" 1>&2
    grep -E -v '^#|.*:.*@' $new
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
chmod a+r $target.new $new.db
mv -f $target.new $target
mv -f $new.db $target.db
rm -f $new
diff -u $old $target | mail -s 'Installed aliases update' root
