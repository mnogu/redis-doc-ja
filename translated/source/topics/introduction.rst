Introduction to Redis
=====================

Redis is an open source, BSD licensed, advanced **key-value store**. It
is often referred to as a **data structure server** since keys can
contain `strings </topics/data-types#strings>`__,
`hashes </topics/data-types#hashes>`__,
`lists </topics/data-types#lists>`__, `sets </topics/data-types#sets>`__
and `sorted sets </topics/data-types#sorted-sets>`__.

You can run **atomic operations** on these types, like `appending to a
string </commands/append>`__; `incrementing the value in a
hash </commands/hincrby>`__; `pushing to a list </commands/lpush>`__;
`computing set intersection </commands/sinter>`__,
`union </commands/sunion>`__ and `difference </commands/sdiff>`__; or
`getting the member with highest ranking in a sorted
set </commands/zrangebyscore>`__.

In order to achieve its outstanding performance, Redis works with an
**in-memory dataset**. Depending on your use case, you can persist it
either by `dumping the dataset to
disk </topics/persistence#snapshotting>`__ every once in a while, or by
`appending each command to a
log </topics/persistence#append-only-file>`__.

Redis also supports trivial-to-setup `master-slave
replication </topics/replication>`__, with very fast non-blocking first
synchronization, auto-reconnection on net split and so forth.

Other features include `Transactions </topics/transactions>`__,
`Pub/Sub </topics/pubsub>`__, `Lua scripting </commands/eval>`__, `Keys
with a limited time-to-live </commands/expire>`__, and configuration
settings to make Redis behave like a cache.

You can use Redis from `most programming languages </clients>`__ out
there.

Redis is written in **ANSI C** and works in most POSIX systems like
Linux, \*BSD, OS X without external dependencies. Linux and OSX are the
two operating systems where Redis is developed and more tested, and we
**recommend using Linux for deploying**. Redis may work in
Solaris-derived systems like SmartOS, but the support is *best effort*.
There is no official support for Windows builds, but Microsoft develops
and maintains a `Win32-64 experimental version of
Redis <https://github.com/MSOpenTech/redis>`__.
