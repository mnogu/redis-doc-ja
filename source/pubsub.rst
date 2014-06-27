=============
Redis Pub/Sub
=============

.. note:: 
   このドキュメントは `Pub/Sub <http://redis.io/topics/pubsub>`_ の翻訳です。
   誤訳を見つけたら `翻訳リポジトリ <https://github.com/mocobeta/redis-doc-ja>`_ に Issue を登録してください。

Pub/Sub
=======

.. `SUBSCRIBE`, `UNSUBSCRIBE` and `PUBLISH` implement the [Publish/Subscribe messaging paradigm](http://en.wikipedia.org/wiki/Publish/subscribe) where (citing Wikipedia) senders (publishers) are not programmed to send their messages to specific receivers (subscribers). Rather, published messages are characterized into channels, without knowledge of what (if any) subscribers there may be. Subscribers express interest in one or more channels, and only receive messages that are of interest, without knowledge of what (if any) publishers there are. This decoupling of publishers and subscribers can allow for greater scalability and a more dynamic network topology.

`SUBSCRIBE <http://redis.io/commands/subscribe>`_, `UNSUBSCRIBE <http://redis.io/commands/unsubscribe>`_, および `PUBLISH <http://redis.io/commands/publish>`_ は、 `Publish/Subscribe messaging paradigm <http://en.wikipedia.org/wiki/Publish/subscribe>`_ を実装しています。送信者(パブリッシャー)はメッセージを特定の受信者(サブスクライバ)へ向けて送信するようにはプログラムされていません。代わりに、特定のチャネルにメッセージを配信します。(存在するとしたら)どのようなサブスクライバが存在するのかという知識はもっていません。サブスクライバは、関心のある一つもしくは複数のチャネルを購読し、そのチャネルからのみメッセージを受信します。(存在するとしたら)どのようなパブリッシャーが存在するのかという知識はもっていません。このような、パブリッシャーとサブスクライバの疎な関係は、スケーラビリティとダイナミックなネットワークトポロジーを可能にします。

.. For instance in order to subscribe to channels `foo` and `bar` the client issues a `SUBSCRIBE` providing the names of the channels:

たとえば、'foo', 'bar' という 2 つのチャネル購読するには、クライアントはチャネル名を指定して `SUBSCRIBE <http://redis.io/commands/subscribe>`_ コマンドを発行します:

.. code-block:: none

    SUBSCRIBE foo bar

.. Messages sent by other clients to these channels will be pushed by Redis to all the subscribed clients.

これらのチャネルに他のクライアントが送信したメッセージは、Redis により、購読しているすべてのクライアントへプッシュ配信されます。

.. A client subscribed to one or more channels should not issue commands,
.. although it can subscribe and unsubscribe to and from other channels.
.. The reply of the `SUBSCRIBE` and `UNSUBSCRIBE` operations are sent in
.. the form of messages, so that the client can just read a coherent stream
.. of messages where the first element indicates the type of message.

一つ、もしくは複数のチャネルを購読しているサブスクライバは、コマンドを発行するべきではありません(とはいえ、他のチャネルを購読したり購読停止したりすることはできます)。 `SUBSCRIBE <http://redis.io/commands/subscribe>`_, `UNSUBSCRIBE <http://redis.io/commands/unsubscribe>`_ 操作の戻り値は、メッセージ形式で返却され、クライアントは一貫したメッセージのストリームを読み取ることができるようになります。なお最初の要素はメッセージのタイプを示します。

.. ## Format of pushed messages

配信メッセージのフォーマット
-----------------------------

.. A message is a @array-reply with three elements.

ひとつのメッセージは、3 つの要素からなる `Array reply <http://redis.io/topics/protocol#array-reply>`_ です。

.. The first element is the kind of message:

最初の要素は、メッセージの種類です:

.. * `subscribe`: means that we successfully subscribed to the channel
.. given as the second element in the reply. The third argument represents
.. the number of channels we are currently subscribed to.

* 'subscribe' : チャネルの購読に成功したことを意味します。チャネル名は応答の 2 つめの要素で与えられます。3 つめの要素は現在購読中のチャネル数を表します。

.. * `unsubscribe`: means that we successfully unsubscribed from the
.. channel given as second element in the reply. The third argument
.. represents the number of channels we are currently subscribed to. When
.. the last argument is zero, we are no longer subscribed to any channel,
.. and the client can issue any kind of Redis command as we are outside the
.. Pub/Sub state.

* 'unsubscribe': チャネルの購読停止に成功したことを意味します。チャネル名は応答の 2 つめの要素で与えられます。3 つめの要素は現在購読中のチャネル数を表します。最後の要素が 0 なら、もういずれのチャネルも購読しておらず、Pub/Sub 状態を抜けているため、クライアントは任意の Redis コマンドを発行できます。

.. * `message`: it is a message received as result of a `PUBLISH` command
.. issued by another client. The second element is the name of the
.. originating channel, and the third argument is the actual message
.. payload.

* 'message': 他のクライアントが発行した `PUBLISH <http://redis.io/commands/publish>`_ コマンドにより生成されたメッセージを受信したことを意味します。2 つめの要素は受信元のチャネル名、3 つめの要素は実際のメッセージペイロードです。

.. ## Database & Scoping

データベースとスコープ
--------------------------

.. Pub/Sub has no relation to the key space.  It was made to not interfere with
.. it on any level, including database numbers.

Pub/Sub はいずれのキースペースとも関係していません。データベース番号を含むどのレベルとも干渉しません。

.. Publishing on db 10, will be heard on by a subscriber on db 1.

DB 10 で発行されたメッセージは、DB 1 のサブスクライバが購読できます。

.. If you need scoping of some kind, prefix the channels with the name of the
.. environment (test, staging, production, ...).

もし何らかのスコープが必要なら、チャネル名に環境に応じた prefix (test, staging, production, ...) を付与してください。

.. ## Wire protocol example

ワイヤープロトコル例
----------------------

.. code-block:: none

    SUBSCRIBE first second
    *3
    $9
    subscribe
    $5
    first
    :1
    *3
    $9
    subscribe
    $6
    second
    :2

.. At this point, from another client we issue a `PUBLISH` operation
.. against the channel named `second`:

ここで、他のクライアントから `PUBLISH <http://redis.io/commands/publish>`_ 操作を 'second' チャネルに対して発行します:

.. code-block:: none

    > PUBLISH second Hello

.. This is what the first client receives:

すると最初のクライアントは、以下のデータを受信します:

.. code-block:: none

    *3
    $7
    message
    $6
    second
    $5
    Hello

.. Now the client unsubscribes itself from all the channels using the
.. `UNSUBSCRIBE` command without additional arguments:

ここでクライアントが、 `UNSCRIBE <http://redis.io/commands/unsubscribe>`_ コマンドを引数なしで発行し、すべてのチャネルの購読を停止します:

.. code-block:: none

    UNSUBSCRIBE
    *3
    $11
    unsubscribe
    $6
    second
    :1
    *3
    $11
    unsubscribe
    $5
    first
    :0

.. ## Pattern-matching subscriptions

パターンマッチによる購読
----------------------------

.. The Redis Pub/Sub implementation supports pattern matching. Clients may
.. subscribe to glob-style patterns in order to receive all the messages
.. sent to channel names matching a given pattern.

Redis Pub/Sub の実装はパターンマッチをサポートします。クライアントは、glob スタイル のパターンを購読することで、指定したパターンにマッチするすべてのチャネルに送信されたメッセージをを受信できます。

.. For instance:

たとえば:

.. code-block:: none

    PSUBSCRIBE news.*

.. Will receive all the messages sent to the channel `news.art.figurative`,
.. `news.music.jazz`, etc.  All the glob-style patterns are valid, so
.. multiple wildcards are supported.

この場合、'news.arg.figurative', 'news.music.jazz', といったチャネルに送信されたすべてのメッセージを受信します。どのような glob スタイルのパターンも許可されるため、複数のワイルドカードもサポートされます。

.. code-block:: none

    PUNSUBSCRIBE news.*

.. Will then unsubscribe the client from that pattern.  No other subscriptions
.. will be affected by this call.

この場合、クライアントはこのパターンにマッチするチャネルの購読を停止します。その他の購読には影響を与えません。

.. Messages received as a result of pattern matching are sent in a
.. different format:

パターンマッチにより受信されるメッセージは、異なるフォーマットをもちます:

.. * The type of the message is `pmessage`: it is a message received
.. as result of a `PUBLISH` command issued by another client, matching
.. a pattern-matching subscription. The second element is the original
.. pattern matched, the third element is the name of the originating
.. channel, and the last element the actual message payload.

* メッセージタイプ 'pmessage': 他のクライアントが発行した `PUBLISH <http://redis.io/commands/publish>`_ コマンドにより生成されたメッセージを受信したことを意味します。2 つめの要素はマッチしたパターン、最後の要素は実際のメッセージペイロードです。

.. Similarly to `SUBSCRIBE` and `UNSUBSCRIBE`, `PSUBSCRIBE` and
.. `PUNSUBSCRIBE` commands are acknowledged by the system sending a message
.. of type `psubscribe` and `punsubscribe` using the same format as the
.. `subscribe` and `unsubscribe` message format.

`SUBSCRIBE <http://redis.io/commands/subscribe>`_, `UNSUBSCRIBE <http://redis.io/commands/unsubscribe>`_ と同様に、 `PSUBSCRIBE <http://redis.io/commands/psubscribe>`_, `PUNSUBSCRIBE <http://redis.io/commands/punsubscribe>`_ コマンドがシステムにより確認されると、'subscribe', 'unsubscribe' と同じフォーマット'psubscribe' および 'punsubscribe' メッセージタイプが送信されます。

.. ## Messages matching both a pattern and a channel subscription

パターンとチャネルの両方にマッチするメッセージについて
--------------------------------------------------------

.. A client may receive a single message multiple times if it's subscribed
.. to multiple patterns matching a published message, or if it is
.. subscribed to both patterns and channels matching the message. Like in
.. the following example:

クライアントが、複数のパターンを購読していたり、パターンとチャネルの両方を購読している場合、ひとつのメッセージを複数回受信する可能性があります。たとえば以下の例のように:

.. code-block:: none

    SUBSCRIBE foo
    PSUBSCRIBE f*

.. In the above example, if a message is sent to channel `foo`, the client
.. will receive two messages: one of type `message` and one of type
.. `pmessage`.

上記の例では、'foo' チャネルにメッセージが送信されると、クライアントは 2 つのメッセージを受信します: ひとつは 'message' タイプ、もうひとつは 'pmessage' タイプです。

.. ## The meaning of the subscription count with pattern matching

パターンマッチにおける購読数の意味
-----------------------------------------

.. In `subscribe`, `unsubscribe`, `psubscribe` and `punsubscribe`
.. message types, the last argument is the count of subscriptions still
.. active. This number is actually the total number of channels and
.. patterns the client is still subscribed to. So the client will exit
.. the Pub/Sub state only when this count drops to zero as a result of
.. unsubscription from all the channels and patterns.

'subscribe', 'unsubscribe', 'psubscribe', および 'psubscribe' メッセージタイプにおいて、最後の要素はアクティブな購読数を表します。この数は、実際には、クライアントがまだ受信を続けているチャネルとパターンの総数です。クライアントは、すべてのチャネルとパターンの購読が停止され、この数が 0 になった時にかぎり、Pub/Sub 状態から抜けます。

.. ## Programming example

プログラミング例
----------------------

.. Pieter Noordhuis provided a great example using EventMachine
.. and Redis to create [a multi user high performance web
.. chat](https://gist.github.com/348262).

Pieter Noordhuis は EventMachine と Redis を使って、素晴らしい `高性能なマルチユーザーWebチャット <https://gist.github.com/348262>`_ の例を公開しています。

.. ## Client library implementation hints

クライアントライブラリ実装のヒント
-------------------------------------

.. Because all the messages received contain the original subscription
.. causing the message delivery (the channel in the case of message type,
.. and the original pattern in the case of pmessage type) client libraries
.. may bind the original subscription to callbacks (that can be anonymous
.. functions, blocks, function pointers), using an hash table.

受信されるすべてのメッセージは、メッセージデリバリーの元になった購読情報('message'タイプの場合はチャネル名、'pmessage'タイプの場合はパターン)を含んでいるため、クライアントライブラリは、ハッシュテーブルを使って元の購読をコールバック(無名関数、ブロック、関数ポインタ、など)にバインドすることができます。

.. When a message is received an O(1) lookup can be done in order to
.. deliver the message to the registered callback.

あるメッセージが受信されたとき、そのメッセージをあらかじめ登録されたコールバックに届けるために、O(1) の計算量でルックアップができるでしょう。

