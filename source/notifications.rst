============================
Redis Keyspace Notifications
============================

.. note:: 
   このドキュメントは `Redis Keyspace Notifications <http://redis.io/topics/notifications>`_ の翻訳です。
   誤訳を見つけたら `翻訳リポジトリ <https://github.com/mocobeta/redis-doc-ja>`_ に Issue 登録をお願いします。

.. **IMPORTANT** Keyspace notifications is a feature available since 2.8.0

**重要** keyspace notifications は 2.8.0 以上で提供される機能です。

.. Feature overview

機能概要
============

.. Keyspace notifications allows clients to subscribe to Pub/Sub channels in order
.. to receive events affecting the Redis data set in some way.

keyspace notifications は、Redis データセットに対するなんらかの変更イベントを、クライアントが Pub/Sub チャネルで受け取るための仕組みです。

.. Examples of the events that is possible to receive are the following:

以下は、受け取れるイベントの例です:

.. * All the commands affecting a given key.
.. * All the keys receiving an LPUSH operation.
.. * All the keys expiring in the database 0.

* あるキーに作用するすべてのコマンド
* LPUSH 操作を受けたすべてのキー
* database 0 の中で、expire されたすべてのキー

.. Events are delivered using the normal Pub/Sub layer of Redis, so clients
.. implementing Pub/Sub are able to use this feature without modifications.

イベントは、ノーマルな Redis の Pub/Sub レイヤを介して配信されます。そのため、Pub/Sub を実装しているクライアントであれば、修正を加えることなくこの機能が利用できます。

.. Because Redis Pub/Sub is *fire and forget* currently there is no way to use this
.. feature if you application demands **reliable notification** of events, that is,
.. if your Pub/Sub client disconnects, and reconnects later, all the events
.. delivered during the time the client was disconnected are lost.

Redis の Pub/Sub は現在のところ *fire and forget* であるため、 **信頼性のある通知** を必要とするアプリケーションで使うことはできません。つまり、Pub/Sub クライアントが接続を失って、後に再接続をしても、接続が途切れていた間に配信されたイベントの情報は失われます。

.. In the future there are plans to allow for more reliable delivering of
.. events, but probably this will be addressed at a more general level either
.. bringing reliability to Pub/Sub itself, or allowing Lua scripts to intercept
.. Pub/Sub messages to perform operations like pushing the events into a list.

将来的にはより信頼性のあるイベント配信の提供も検討されていますが、おそらくそれは Pub/Sub 自身の信頼性を上げていくか、または Lua スクリプトで Pub/Sub メッセージを捉えてリストにプッシュするなどの方法で、より上位のレベルで対応されることになるでしょう。

.. Type of events

イベントタイプ
=========================

.. Keyspace notifications are implemented sending two distinct type of events
.. for every operation affecting the Redis data space. For instance a `DEL`
.. operation targeting the key named `mykey` in database `0` will trigger
.. the delivering of two messages, exactly equivalent to the following two
.. `PUBLISH` commands:

keyspace notifications は、Redis データセットに作用する各操作に対し、2 つの異なるタイプのイベントを送信するように実装されています。たとえば database 0 の 'mykey' に対する `DEL <http://redis.io/commands/del>`_ 操作は 2 つのメッセージを配信します。メッセージは以下の 2 つの `PUBLISH <http://redis.io/commands/publish>`_ コマンドと等価です。

.. code-block:: none

    PUBLISH __keyspace@0__:mykey del
    PUBLISH __keyevent@0__:del mykey

.. It is easy to see how one channel allows to listen to all the events targeting
.. the key `mykey` and the other channel allows to obtain informations about
.. all the keys that are target of a `del` operation.

一方のチャネルで 'mykey' に対するすべてのイベントを検知でき、もう一方のチャネルからは 'del' 操作の対象となったすべてのキーに関する情報を取得できることが、簡単に推測できるでしょう。

.. The first kind of event, with `keyspace` prefix in the channel is called
.. a **Key-space notification**, while the second, with the `keyevent` prefix,
.. is called a **Key-event notification**.

'keyspace' から始まる、最初のイベントタイプは **Key-space notification** と呼ばれ、2 つめの 'keyevent' から始まるイベントタイプは **Key-event notification** と呼ばれます。

.. In the above example a `del` event was generated for the key `mykey`.
.. What happens is that:

上述の例では、'del' イベントが 'mykey' に対して発行されています。起こることは以下です:

.. * The Key-space channel receives as message the name of the event.
.. * The Key-event channel receives as message the name of the key.

* Key-space チャネルはイベント名を受信する
* Key-event チャネルはキー名を受信する

.. It is possible to enable only one kind of notification in order to deliver
.. just the subset of events we are interested in.

関心のあるイベントのサブセットだけを配信するため、どちらかの通知のみを有効にすることも可能です。

.. Configuration

設定
==========

.. By default keyspace events notifications are disabled because while not
.. very sensible the feature uses some CPU power. Notifications are enabled
.. using the `notify-keyspace-events` of redis.conf or via the **CONFIG SET**.

この機能は少なからず CPU パワーを使用するため、デフォルトではは無効になっています。通知は redis.conf の 'notify-keyspace-events' か **CONFIG SET** を通して有効にすることができます。

.. Setting the parameter to the empty string disables notifications.
.. In order to enable the feature a non-empty string is used, composed of multiple
.. characters, where every character has a special meaning according to the
.. following table:

パラメータに空文字列を設定すると、通知が無効になります。通知機能を有効にするためには、以下のテーブルに記載の、特別な意味をもつ文字の組合せから構成される文字列を設定します。

.. code-block:: none

    K     Keyspace events, published with __keyspace@<db>__ prefix.
    E     Keyevent events, published with __keyevent@<db>__ prefix.
    g     Generic commands (non-type specific) like DEL, EXPIRE, RENAME, ...
    $     String commands
    l     List commands
    s     Set commands
    h     Hash commands
    z     Sorted set commands
    x     Expired events (events generated every time a key expires)
    e     Evicted events (events generated when a key is evicted for maxmemory)
    A     Alias for g$lshzxe, so that the "AKE" string means all the events.

.. At least `K` or `E` should be present in the string, otherwise no event
.. will be delivered regardless of the rest of the string.

少なくとも、'K' または 'E' が指定される必要があります。そうでないと、残りの文字列にかかわらずいずれのイベントも配信されません。

.. For instance to enable just Key-space events for lists, the configuration
.. parameter must be set to `Kl`, and so forth.

たとえばリストに関する Key-space events の通知だけを有効にするには、パラメータは 'Kl' と設定します。その他も同様です。

.. The string `KEA` can be used to enable every possible event.

'KEA' という文字列を指定すると、発生しうるすべてのイベントに関する通知を有効にします。

.. Events generated by different commands

各コマンドにより生成されるイベント
=======================================

.. Different commands generate different kind of events according to the following list.

異なるコマンドは、異なるイベントを生成します。以下のリストに列挙します。

.. * `DEL` generates a `del` event for every deleted key.
.. * `RENAME` generates two events, a `rename_from` event for the source key, and a `rename_to` event for the destination key.
.. * `EXPIRE` generates an `expire` event when an expire is set to the key, or a `del` event every time setting an expire results into the key being deleted (see `EXPIRE` documentation for more info).
.. * `SORT` generates a `sortstore` event when `STORE` is used to set a new key. If the resulting list is empty, and the `STORE` option is used, and there was already an existing key with that name, the result is that the key is deleted, so a `del` event is generated in this condition.
.. * `SET` and all its variants (`SETEX`, `SETNX`,`GETSET`) generate `set` events. However `SETEX` will also generate an `expire` events.
.. * `MSET` generates a separated `set` event for every key.
.. * `SETRANGE` generates a `setrange` event.
.. * `INCR`, `DECR`, `INCRBY`, `DECRBY` commands all generate `incrby` events.
.. * `INCRBYFLOAT` generates an `incrbyfloat` events.
.. * `APPEND` generates an `append` event.
.. * `LPUSH` and `LPUSHX` generates a single `lpush` event, even in the variadic case.
.. * `RPUSH` and `RPUSHX` generates a single `rpush` event, even in the variadic case.
.. * `RPOP` generates an `rpop` event. Additionally a `del` event is generated if the key is removed because the last element from the list was popped.
.. * `LPOP` generates an `lpop` event. Additionally a `del` event is generated if the key is removed because the last element from the list was popped.
.. * `LINSERT` generates an `linsert` event.
.. * `LSET` generates an `lset` event.
.. * `LTRIM` generates an `ltrim` event, and additionally a `del` event if the resulting list is empty and the key is removed.
.. * `RPOPLPUSH` and `BRPOPLPUSH` generate an `rpop` event and an `lpush` event. In both cases the order is guaranteed (the `lpush` event will always be delivered after the `rpop` event). Additionally a `del` event will be generated if the resulting list is zero length and the key is removed.
.. * `HSET`, `HSETNX` and `HMSET` all generate a single `hset` event.
.. * `HINCRBY` generates an `hincrby` event.
.. * `HINCRBYFLOAT` generates an `hincrbyfloat` event.
.. * `HDEL` generates a single `hdel` event, and an additional `del` event if the resulting hash is empty and the key is removed.
.. * `SADD` generates a single `sadd` event, even in the variadic case.
.. * `SREM` generates a single `srem` event, and an additional `del` event if the resulting set is empty and the key is removed.
.. * `SMOVE` generates an `srem` event for the source key, and an `sadd` event for the destination key.
.. * `SPOP` generates an `spop` event, and an additional `del` event if the resulting set is empty and the key is removed.
.. * `SINTERSTORE`, `SUNIONSTORE`, `SDIFFSTORE` generate `sinterstore`, `sunionostore`, `sdiffstore` events respectively. In the speical case the resulting set is empty, and the key where the result is stored already exists, a `del` event is generated since the key is removed.
.. * `ZINCR` generates a `zincr` event.
.. * `ZADD` generates a single `zadd` event even when multiple elements are added.
.. * `ZREM` generates a single `zrem` event even when multiple elements are deleted. When the resulting sorted set is empty and the key is generated, an additional `del` event is generated.
.. * `ZREMBYSCORE` generates a single `zrembyscore` event. When the resulting sorted set is empty and the key is generated, an additional `del` event is generated.
.. * `ZREMBYRANK` generates a single `zrembyrank` event. When the resulting sorted set is empty and the key is generated, an additional `del` event is generated.
.. * `ZINTERSTORE` and `ZUNIONSTORE` respectively generate `zinterstore` and `zunionstore` events. In the speical case the resulting sorted set is empty, and the key where the result is stored already exists, a `del` event is generated since the key is removed.
.. * Every time a key with a time to live associated is removed from the data set because it expired, an `expired` event is generated.
.. * Every time a key is evicted from the data set in order to free memory as a result of the `maxmemory` policy, an `evicted` event is generated.

* `DEL <http://redis.io/commands/del>`_ は削除された各キーに対し 'del' イベントを生成します。
* `RENAME <http://redis.io/commands/rename>`_ は 2 つのイベントを生成します。ひとつは変更元キーに対する 'rename_from' イベント、もうひとつは 変更先キーに対する 'rename_to' イベントです。
* `EXPIRE <http://redis.io/commands/expire>`_ はキーに対し expire が設定されたときに 'expires' イベントを、expire によりキーが削除されたときに 'del' イベントを生成します(詳しくは `EXPIRE <http://redis.io/commands/expire>`_ のドキュメントを参照)。
* `SORT <http://redis.io/commands/sort>`_ は、新しいキーをセットするため `STORE` が指定されたときに 'sortstore' イベントを生成します。結果のリストが空で、 `STORE` が指定され、かつ同名のキーが存在した場合はそのキーが削除されるため、 'del' イベントが生成されます。
* `SET <http://redis.io/commands/set>`_ およびその異型(`SETEX <http://redis.io/commands/setex>`_, `SETNX <http://redis.io/commands/setnx>`_, `GETSET <http://redis.io/commands/getset>`_) は 'set' イベントを生成します。なお `SETEX <http://redis.io/commands/setex>`_ は同時に 'expire' イベントも生成します。
* `MSET <http://redis.io/commands/mset>`_ は各キーごとに別々の 'set' イベントを生成します。
* `SETRANGE <http://redis.io/commands/setrange>`_ は 'setrange' イベントを生成します。
* `INCR <http://redis.io/commands/incr>`_, `DECR <http://redis.io/commands/decr>`_, `INCRBY <http://redis.io/commands/incrby>`_, `DECRBY <http://redis.io/commands/decrby>`_ コマンドはすべて、'incrby' イベントを生成します。
* `INCRBYFLOAT <http://redis.io/commands/incrbyfloat>`_ は 'incrbyfloat' イベントを生成します。
* `APPEND <http://redis.io/commands/append>`_ は 'append' イベントを生成します。
* `LPUSH <http://redis.io/commands/lpush>`_ と `LPUSHX <http://redis.io/commands/lpushx>`_ は、可変個の引数をとりますが、ひとつの 'lpush' イベントを生成します。
* `RPUSH <http://redis.io/commands/rpush>`_ と `RPUSHX <http://redis.io/commands/rpushx>`_ は、可変この引数をとりますが、ひとつの 'rpush' イベントを生成します。
* `RPOP <http://redis.io/commands/rpop>`_ は 'rpop' イベントを生成します。最後の要素がリストから pop されてキーが削除された場合は、加えて 'del' イベントが生成されます。
* `LPOP <http://redis.io/commands/lpop>`_ は 'lpop' イベントを生成します。最後の要素がリストから pop されてキーが削除された場合は、加えて 'del' イベントが生成されます。
* `LINSERT <http://redis.io/commands/linsert>`_ は 'linsert' イベントを生成します。
* `LSET <http://redis.io/commands/lset>`_ は 'lset' イベントを生成します。
* `LTRIM <http://redis.io/commands/ltrim>`_ は 'ltrim' イベントを生成します。結果としてリストが空になり、キーが削除された場合は、加えて 'del' イベントが生成されます。
* `RPOPLPUSH <http://redis.io/commands/rpoplpush>`_  と `BRPOPLPUSH <http://redis.io/commands/brpoplpush>`_ は ひとつの 'rpop' イベントとひとつの 'lpush' イベントを生成します。両方のケースにおいて、順序は保証されます('lpush' イベントは常に 'rpop' イベントの後に配信される)。結果としてリスト長がゼロになり、キーが削除された場合は 'del' イベントも生成されます。
* `HSET <http://redis.io/commands/hset>`_, `HSETNX <http://redis.io/commands/hsetnx>`_, および `HMSET <http://redis.io/commands/hmset>`_ はすべて、ひとつの 'hset' イベントを生成します。
* `HINCRBY <http://redis.io/commands/hincrby>`_ は 'hincrby' イベントを生成します。
* `HINCRBYFLOAT <http://redis.io/commands/hincrbyfloat>`_ は 'hincrbyfloat' イベントを生成します。
* `HDEL <http://redis.io/commands/hdel>`_ は 'hdel' イベントを生成します。結果として Hash が空になりキーが削除された場合は、加えて 'del' イベントも生成されます。
* `SADD <http://redis.io/commands/sadd>`_ は可変個の引数をとりますが、ひとつの 'sadd' イベントを生成します。
* `SREM <http://redis.io/commands/srem>`_ は 'srem' イベントを生成します。結果として Set が空になりキーが削除された場合は、加えて 'del' イベントも生成されます。
* `SMOVE <http://redis.io/commands/smove>`_ は移動元キーに対して 'srem' イベントを、移動先キーに対して 'sadd' イベントを生成します。
* `SPOP <http://redis.io/commands/spop>`_ は 'spop' イベントを生成します。結果として set が空になりキーが削除された場合は加えて 'spop' イベントも生成されます。
* `SINTERSTORE <http://redis.io/commands/sinterstore>`_, `SUNIONSTORE <http://redis.io/commands/sunionstore>`_, `SDIFFSTORE <http://redis.io/commands/sdiffstore>`_ はそれぞれ 'sinterstore', 'sunionostore', 'sdiffstore' イベントを生成します。特殊なケースとして、結果セットが空で、かつ格納先のキーがすでに存在した場合は、キーが削除されるため 'del' イベントも生成されます。
* `ZINCRBY <http://redis.io/commands/zincrby>`_ は 'zincr' イベントを生成します。
* `ZADD <http://redis.io/commands/zadd>`_ は、複数の要素が追加される場合でも、ひとつの 'zadd' イベントを生成します。
* `ZREM <http://redis.io/commands/zrem>`_ は、複数の要素が削除される場合でも、ひとつの 'zrem' イベントを生成します。結果のソート済み集合が空になり、キーが削除された場合は、加えて 'del' イベントも生成されます。
* `ZREMRANGEBYSCORE <http://redis.io/commands/zremrangebyscore>`_ は、'zrembyscore' イベントを生成します。結果のソート済み集合が空になり、キーが削除された場合は、加えて 'del' イベントも生成されます。
* `ZREMRANGEBYRANK <http://redis.io/commands/zremrangebyrank>`_ は、'zrembyrank' イベントを生成します。結果のソート済み集合が空になり、キーが削除された場合は、加えて 'del' イベントも生成されます。
* `ZINTERSTORE <http://redis.io/commands/zinterstore>`_ と `ZUNIONSTORE <http://redis.io/commands/zunionstore>`_ はそれぞれ 'zinterstore' イベントと 'zunionstore' イベントを生成します。特殊なケースとして、結果のソート済み集合が空で、かつ格納先のキーがすでに存在した場合は、キーが削除されるため 'del' イベントも生成されます。
* time to live をもつキーが expire されてデータセットから削除される都度、'expired' イベントが生成されます。
* フリーメモリ領域の確保のため 'maxmemory' ポリシーによってキーがデータセットから除去される都度、'evicted' イベントが生成されます。

.. **IMPORTANT** all the commands generate events only if the target key is really modified. For instance an `SREM` deleting a non-existing element from a Set will not actually change the value of the key, so no event will be generated.

**重要** すべてのコマンドは、対象とするキーを実際に変更した場合にのみ、イベントを生成します。たとえば、Set に存在しない要素を 'SREM' で削除しようとした場合、実際にはキーの値を変更しないため、どのようなイベントも生成されません。

.. If in doubt about how events are generated for a given command, the simplest
.. thing to do is to watch yourself:

あるコマンドがどのようなイベントを生成するか疑問に思ったら、実際に確認してみるのが近道です:

.. code-block:: bash

    $ redis-cli config set notify-keyspace-events KEA
    $ redis-cli --csv psubscribe '__key*__:*'
    Reading messages... (press Ctrl-C to quit)
    "psubscribe","__key*__:*",1

.. At this point use `redis-cli` in another terminal to send commands to the
.. Redis server and watch the events generated:

ここで、別のターミナルから 'redis-cli' を使って Redis サーバーにコマンドを送り、生成されるイベントを監視します:

.. code-block:: bash

    "pmessage","__key*__:*","__keyspace@0__:foo","set"
    "pmessage","__key*__:*","__keyevent@0__:set","foo"
    ...

.. Timing of expired events

expired イベントの発生タイミング
==================================

.. Keys with a time to live associated are expired by Redis in two ways:

time to live が関連づけられたキーは、Redis により 2 つの方法で expire されます。

.. * When the key is accessed by a command and is found to be expired.
.. * Via a background system that looks for expired keys in background, incrementally, in order to be able to also collect keys that are never accessed.

* あるコマンドでキーがアクセスされ、すでに expire されていることに気づいたとき
* 一切アクセスされなくなったキーを集めるため、expire されたキーをひとつずつ探すバックグラウンドシステムを介して。

.. The `expired` events are generated when a key is accessed and is found to be expired by one of the above systems, as a result there are no guarantees that the Redis server will be able to generate the `expired` event at the time the key time to live reaches the value of zero.

'expired' イベントは、上記いずれかのシステムによりキーがアクセスされた時に生成されます。したがって、キーの time to live の値がゼロに達したタイミングで Redis サーバーが 'expired' イベントを生成するという保証はありません。

.. If no command targets the key constantly, and there are many keys with a TTL associated, there can be a significant delay between the time the key time to live drops to zero, and the time the `expired` event is generated.

対象のキーに対してコンスタントにコマンドが実行されず、また TTL が関連づけられたキーが多く存在する場合、time to live がゼロに達したタイミングと 'expired' イベントが生成されるタイミングの間には、大きな遅延が発生する可能性があります。

.. Basically `expired` events **are generated when the Redis server deletes the key** and not when the time to live theorically reaches the value of zero.

基本的に、'expired' イベントは **Redis サーバーがキーを削除したときに生成され** 、理論上において time to live の値がゼロに達したときに生成されるものではありません。
