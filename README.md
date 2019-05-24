Ansible playbook for Usenet moderator relay server
==================================================

This directory contains an Ansible playbook and ancillary files
necessary for building out a server intended to be one of the MX
servers for moderators.isc.org, i.e., to route Usenet postings to
newsgroup moderators via email.

In particular:

* README.md -- this file

* mod-relay.yml -- the playbook

* modupdate.sh -- the script that processes updates to the aliases
  list when they are sent out by the maintainers of the list

* mtm.sh -- the auto-reply script for misc.test.moderated (this is
  only actually used at any given time on one of the relay servers,
  but there's no harm in installing it on all of htem)

Prerequisites
-------------

Before using the files in this directory, you need:

* a Debian-based host to serve as the relay server

* a static host name and IP addresses and PTR records for all of the
  host's public addresses (both IPv4 and IPv6, if any) pointing at its
  host name

* if using IPv6, a dedicated /64 for the host, to avoid getting
  labeled a spammer because of other hosts in your /64 sending spam
  (the spam blocklists only distinguish IPv6 addresses to /64
  granularity, so it's not good enough to have a single dedicated IPv6
  address)

* clearance through your network firewall (if any) for ingress traffic
  to the host on ports 22, 25, and maybe 2222 (see below) and egress
  traffic on port 25

* a copy of the current aliases file, which you can obtain from
  [moderators-request@isc.org](mailto:moderators-request@isc.org) when
  you email them to let them know you're setting up a relay, saved
  with the name "aliases" in this directory

* an inventory file which lists your relay host name in the group
  "mod\_relays" 

* enough network bandwidth (as a rough estimate, all of the relay
  servers together currently receive about 96MB per week and send
  about 27MB; this traffic is divided approximately evenly across all
  of the servers, so the more servers there are, the less bandwidth
  each uses)

* SSH login access to the root account on your host (i.e., put your
  public key in /root/.ssh/authorized_keys)

Assumptions
-----------

This documentation assumes that you are sufficiently familiar with
Ansible and system administration that you can read the playbook and
scripts and understand what they do (and you should do that before
running it!) so the details don't all need to be spelled out here.

This playbook has been tested on Ubuntu 18.04.1, but I assume that
it'll work just fine on any recent Debian-based distribution.

The playbook assumes that you are running the relay on a dedicated
host or VM, not a shared host, so it has free rein to configure
everything on the host for this specific purpose. If you want to run
the relay on a host that does other stuff, you're probably going to
have to pick and choose bits and pieces of the playbook and do other
stuff by hand that the playbook would do automatically on a dedicated
host. If this is the case, then the first paragraph of this section
applies even more so.

Configuration
-------------

The playbook uses the following configuration settings which should be
set as desired in your inventory:

* List your relay host in the "mod\_relays" group in your inventory.

* If you want to automatically run a daily script to check if your
  host is listed in any DNS blocklists (as discussed below), also add
  your relay host to the group "dnsbl\_check\_hosts" in your inventory.

* inventory\_hostname -- The playbook uses this standard Ansible to
  configure various settings on the host, *including changing its host
  name as needed to match this variable*.

* snitch\_url -- I use a
  [Coal Mine](https://github.com/quantopian/coal-mine/) server to
  monitor the health of the relay I maintain. You can also use
  something like [Dead Man's Snitch](https://deadmanssnitch.com/).
  Basically, if you set this variable, then the relay server will call
  GET on whatever URL you specify once per hour as long as it thinks
  it is healthy.

* root\_email\_address -- When defined, the playbook will alias `root`
  to the specified email address in `/etc/aliases`.

* relay\_ssh\_port -- If you set this variable to a port number, then
  the playbook will reconfigure `sshd` on the host to accept
  connections on that port *replacing any previous port setting,
  including the default*. I do this on my relay server for two
  reasons: (a) it reduces the amount of script kiddie spam from people
  trying to hack into port 22, and (b) my home ISP doesn't allow
  outbound SSH on port 22 :-(. Note that if you set this, then the
  port number the host's SSH daemon is running on will change in the
  middle of the playbook run, so `ansible-playbook` *may* fail in the
  middle when it stops being able to connect to the host, but it won't
  if it keeps a cached connection open. After the `ansible-playbook`
  reconfigures the SSH port you will want to edit your `~/.ssh/config`
  to specify the new port there for the host.

* disable\_sshd\_password_authentication -- Set to true if you want the
  playbook to disable sshd password authentication, i.e., only allow
  public key authentication. This is *strongly encouraged* for good
  security hygiene. Make sure you have public key ssh access
  configured before you do this!

Initial setup
-------------

1. Read and understand the playbook.

2. Make sure you've satisfied all of the prerequisites listed above.

3. Let [moderators-request@isc.org](mailto:moderators-request@isc.org)
   know that you are setting up a new relay server, ask them for a
   copy of the current aliases file, and save it as `aliases` in this
   directory.

4. Set the configuration variables described above as desired in your
   Ansible inventory file.

5. Run the playbook.

6. Send email to misc-test-moderated@_your-host-name_ and confirm that
   you get back either a reply from mtm@mod-relay-1.kamens.us, or a
   bounce telling you that mtm-submission@mtm.sf-bay.org doesn't
   exist. Either of these confirms that your host is correctly parsing
   the moderator aliases file and routing messages through the aliases
   in it.

7. Send email to root@_your-host-name_ and confirm that it is
   forwarded to the email address specified in the
   `root_email_address` variable, if you set it.

8. Ask [moderators-request@isc.org](mailto:moderators-request@isc.org)
   to add modupdate@_your-host-name_ to the mailing list for alias
   updates and send out a test update. Check
   `/home/modupdate/procmail.log` and
   `/home/modupdate/aliases/aliases` to confirm that it was processed
   correctly.

9. Ask [moderators-request@isc.org](mailto:moderators-request@isc.org)
   to add your host name as one of the MX records for
   moderators.isc.org.

Note that as of when this README file was written (2018-10-02),
there's a bug in the Ansible `user` module which will cause the
playbook to report `changed` for tasks that use it every time it is
run, even though nothing in those tasks is changing after the first
time.

Ongoing maintenance
-------------------

You need to check the spam DNSBLs on a regular basis to make sure you
haven't gotten listed on one, and if you do, try to figure out why and
get delisted. You can use the script included here to do this, by
adding your host to the "dnsbl\_check\_hosts" group in your Ansible
inventory before running the playbook. Alternatively, there are
various web sites that will do this for you, e.g.,
[https://www.dnsbl.info/](https://www.dnsbl.info/),
[https://mxtoolbox.com/blacklists.aspx](https://mxtoolbox.com/blacklists.aspx),
[http://www.anti-abuse.org/multi-rbl-check/](http://www.anti-abuse.org/multi-rbl-check/),
[http://dnsbllookup.com/](http://dnsbllookup.com/). Some of them may
even allow you to configure them to do it automatically on a regular
basis and email you the results.

You should quickly review the daily logwatch email and deal with
anything that looks crazy.

The most likely problem for you to run into is your disk filling up
because some idiot sends many GB of submissions to a moderated
newsgroup that doesn't actually exist anymore, from a bogus email
address, so the bounce emails are queuing up for days on your server
before being bounced (yeah, it's happened once or twice). You'll know
this happens when logwatch says your disk is full! If so, then you'll
have to clean up the mail queue and email moderators-request@isc.org
asking them to disable the offending newsgroup in the aliases file so
submissions to it will bounce instead of queuing up.

You should install OS patches promptly, or at least the ones that look
like they actually matter, so you aren't running with known security
holes. Note that the playbook configures your host to email you when
patches are available.

You should upgrade your OS version when it is end-of-lifed so that you
don't stop getting security updates. If you're using a VM, it might be
easier to just create a new VM from scratch with the new OS version,
rather than upgrading the existing VM. If you do decide to do an
upgrade, then rerun the whole playbook on the host after the upgrade
to fix anything the upgrade broke.

Credits
-------

This playbook and documentation were written and are maintained by
Jonathan Kamens &lt;[jik@kamens.us](mailto:jik@kamens.us)&gt;. I
welcome your feedback.

Copyright
---------

Everything in this directory is in the public domain. Feel free to do
whatever you want with it.
