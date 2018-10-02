#!/bin/bash -e

mf=/tmp/inbound.$$.eml
trap "rm -f $mf" EXIT

cat >| $mf

# The $(echo ...) wrappers remove leading and trailing whitespace.
return_address="$(echo $(formail -c -x Reply-To: < $mf))"
if [ ! "$return_address" ]; then
    return_address="$(echo $(formail -c -x From: < $mf))"
fi
message_id="$(echo $(formail -c -x Message-Id: < $mf))"
subject="$(echo $(formail -c -x Subject: < $mf))"

(cat <<EOF; cat $mf) | /usr/sbin/sendmail -oi -t
From: $LOGNAME@$HOSTNAME
To: $return_address
Subject: Re: $subject
References: $message_id
In-Reply-To: $message_id

Your submission to misc.test.moderated has been received!

This is an automatic reply to your submission, which is included in
full below.

Note that misc.test.moderated does not have any human moderators, and
your message is not actually going to be posted to the newsgroup.

At this time, the only purpose of misc.test.moderated is to provide a
mechanism for people to test that their News server knows how to route
submissions properly to moderated newsgroups. If you post a message to
misc.test.moderated and receive this reply, that means your News
server did the right thing with your posting.

Please direct any questions about this to root@$HOSTNAME.

Over and out!

----- original submission follows -----

EOF
