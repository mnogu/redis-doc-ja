.. Transactions

====================
トランザクション
====================

.. note:: 
   このドキュメントは `Transactions <http://redis.io/topics/transactions>`_ の翻訳です。
   誤訳を見つけたら `翻訳リポジトリ <https://github.com/mocobeta/redis-doc-ja>`_ に Issue を登録してください。

.. `MULTI`, `EXEC`, `DISCARD` and `WATCH` are the foundation of
.. transactions in Redis.  They allow the execution of a group of commands
.. in a single step, with two important guarantees:

`MULTI <http://redis.io/commands/multi>`_, `EXEC <http://redis.io/commands/exec>`_, `DISCARD <http://redis.io/commands/discard>`_ および `WATCH <http://redis.io/commands/watch>`_ は Redis におけるトランザクションの基本です。これらは、複数のコマンドの実行をひとつのステップで行えるようにします。その際、2 つの重要な点が保証されます。

.. * All the commands in a transaction are serialized and executed
.. sequentially. It can never happen that a request issued by another
.. client is served **in the middle** of the execution of a Redis
.. transaction. This guarantees that the commands are executed as a single
.. isolated operation.

.. * Either all of the commands or none are processed, so a Redis
.. transaction is also atomic. The `EXEC` command
.. triggers the execution of all the commands in the transaction, so
.. if a client loses the connection to the server in the context of a
.. transaction before calling the `MULTI` command none of the operations
.. are performed, instead if the `EXEC` command is called, all the
.. operations are performed. When using the
.. [append-only file](/topics/persistence#append-only-file) Redis makes sure
.. to use a single write(2) syscall to write the transaction on disk.
.. However if the Redis server crashes or is killed by the system administrator
.. in some hard way it is possible that only a partial number of operations
.. are registered. Redis will detect this condition at restart, and will exit with an error. Using the `redis-check-aof` tool it is possible to fix the
.. append only file that will remove the partial transaction so that the
.. server can start again.

* トランザクション中のすべてのコマンドは直列化され、順に実行されます。他のクライアントにより発行されたリクエストが、Redis トランザクションの **途中に** 入り込むことはありません。このことは、コマンド群がひとつの隔離されたオペレーションとして実行されることを保証します。

* すべてのコマンドが実行されるか、ひとつも実行されないかのいずれかであり、すなわち Redis のトランザクションはアトミックです。 `EXEC <http://redis.io/commands/exec>`_ コマンドはトランザクション中の全コマンドの実行のトリガです。もし、クライアントがトランザクションの途中で、 `MULTI <http://redis.io/commands/multi>`_ [訳注: EXEC の間違い？] コマンド実行前にサーバーとの接続を失うと、いずれのオペレーションも実行されません。その反対に、 `EXEC <http://redis.io/commands/exec>`_ コマンドが呼び出されると、すべてのオペレーションが実行されます。もし `append only file <http://redis.io/topics/persistence#append-only-file>`_ を使用している場合、Redis はトランザクションの内容をディスクに書き込むために、ひとつの write(2) システムコールを呼び出します。しかしながら、Redis サーバーがクラッシュ、または管理者により困難な方法で kill された場合に、一部のオペレーションのみが記入されてしまうことはあり得ます。Redis は再起動時にこの状態を検知し、エラーを発生させて終了します。 'redis-check-aof' ツールを使って修復することで、サーバーを起動できるようになります。

.. Starting with version 2.2, Redis allows for an extra guarantee to the
.. above two, in the form of optimistic locking in a way very similar to a
.. check-and-set (CAS) operation.
.. This is documented [later](#cas) on this page.

バージョン 2.2 以降、Redis は上記 2 つの保証に加えて、check-and-set (CAS) 操作によく似た方法で楽観ロックの手段を提供しています。この話題については、このページで後ほど (:ref:`transactions_cas`) 触れます。

.. ## Usage

使用方法
===============

.. A Redis transaction is entered using the `MULTI` command. The command
.. always replies with `OK`. At this point the user can issue multiple
.. commands. Instead of executing these commands, Redis will queue
.. them. All the commands are executed once `EXEC` is called.

Redis トランザクションは `MULTI <http://redis.io/commands/multi>`_ により開始されます。このコマンドは常に OK を返します。この時点から、ユーザーは複数のコマンドを発行可能です。これらのコマンドを実行する代わりに、Redis はキューイングを行います。すべてのコマンドは、 `EXEC <http://redis.io/commands/exec>`_ コマンドがコールされた時点で実行されます。

.. Calling `DISCARD` instead will flush the transaction queue and will exit
.. the transaction.

代わりに `DISCARD <http://redis.io/commands/discard>`_ をコールすると、トランザクションキューの内容がフラッシュされて、トランザクションは終了します。

.. The following example increments keys `foo` and `bar` atomically.

以下の例では、'foo' と 'bar' の 2 つのキーをアトミックにインクリメントしています。

.. code-block:: none

    > MULTI
    OK
    > INCR foo
    QUEUED
    > INCR bar
    QUEUED
    > EXEC
    1) (integer) 1
    2) (integer) 1

.. As it is possible to see from the session above, `MULTI` returns an
.. array of replies, where every element is the reply of a single command
.. in the transaction, in the same order the commands were issued.

セッションの様子を見るとわかるとおり、 `MULTI <http://redis.io/commands/multi>`_ [訳注: EXEC の間違い？] は応答の配列を返します。配列の要素はそれぞれ、トランザクション中の個々のコマンドへの応答になっており、また順番はコマンドの発行順序と同じです。

.. When a Redis connection is in the context of a `MULTI` request,
.. all commands will reply with the string `QUEUED` (sent as a Status Reply
.. from the point of view of the Redis protocol). A queued command is
.. simply scheduled for execution when `EXEC` is called.

Redis コネクションが `MULTI <http://redis.io/commands/multi>`_ リクエストの途中にあるとき、すべてのコマンドは 'QUEUED' という応答を返します (Redis プロトコルの観点から、Status Reply として送られる)。キューイングされたコマンドは、 `EXEC <http://redis.io/commands/exec>`_ が呼び出され、実行されるまで、シンプルにスケジューリングされます。

.. ## Errors inside a transaction

トランザクション中のエラーについて
====================================

.. During a transaction it is possible to encounter two kind of command errors:

トランザクション中、2 種類のコマンドエラーが発生する可能性があります:

.. * A command may fail to be queued, so there may be an error before `EXEC` is called. For instance the command may be syntactically wrong (wrong number of arguments, wrong command name, ...), or there may be some critical condition like an out of memory condition (if the server is configured to have a memory limit using the `maxmemory` directive).
.. * A command may fail *after* `EXEC` is called, for instance since we performed an operation against a key with the wrong value (like calling a list operation against a string value).

* コマンドのキューイングに失敗すると、 `EXEC <http://redis.io/commands/exec>`_ コマンドが呼び出される前にエラーが発生します。たとえば、コマンドが文法的に誤っている場合 (引数の数が誤っている、不正なコマンド名、...)、または、out of memory ('maxmemory' ディレクティブによりサーバーにメモリ制限が設定されているとき) 等のなんらかのクリティカルな状態になった場合などです。
* `EXEC <http://redis.io/commands/exec>`_ が呼び出された *後に* コマンドが失敗することもあります。たとえば、誤った値をもったキーに対する操作を行った場合(文字列値に対して、リスト操作を実行する、というように)などです。

.. Clients used to sense the first kind of errors, happening before the `EXEC` call, by checking the return value of the queued command: if the command replies with QUEUED it was queued correctly, otherwise Redis returns an error. If there is an error while queueing a command, most clients will abort the transaction discarding it.

以前には、クライアントは、キューイングされたコマンドの戻り値をチェックし、ひとつめの種類のエラー (`EXEC <http://redis.io/commands/exec>`_ コールの前に発生する) を検知する必要がありました: もしコマンドが QUEUED と応答したら、正しくキューイングされており、そうでなければ Redis はエラーを返します。もしコマンドのキューイング中にエラーが発生したら、多くのクライアントはトランザクションを中止し、破棄するでしょう。

.. However starting with Redis 2.6.5, the server will remember that there was an error during the accumulation of commands, and will refuse to execute the transaction returning also an error during `EXEC`, and discarding the transcation automatically.

しかし Redis 2.6.5 以降、サーバーはコマンドの累積中にエラーが発生したことを覚えておき、 `EXEC <http://redis.io/commands/exec>`_ コール時にトランザクションの実行を拒否するとともにエラーを返し、トランザクションを自動的に破棄するようになりました。

.. Before Redis 2.6.5 the behavior was to execute the transaction with just the subset of commands queued successfully in case the client called `EXEC` regardless of previous errors. The new behavior makes it much more simple to mix transactions with pipelining, so that the whole transaction can be sent at once, reading all the replies later at once.

Redis 2.6.5 以前は、事前にエラーが発生したことに構わずクライアントが `EXEC <http://redis.io/commands/exec>`_ コマンドをコールした場合、キューイングに成功した一部のコマンドだけでトランザクションを実行する、という振る舞いをしていました。新しい振る舞いは、トランザクションとパイプライニングのミックスをよりシンプルにし、これにより、トランザクション全体は一度に送信され、またすべての応答は一度に読み込まれるようになっています。

.. Errors happening *after* `EXEC` instead are not handled in a special way: all the other commands will be executed even if some command fails during the transaction.

対して、 `EXEC <http://redis.io/commands/exec>`_ コマンドの後に起こるエラーには、特別なハンドリングは行われません: トランザクション中にいくつかのコマンドが失敗したとしても、その他のすべてのコマンドはそのまま実行されます。

.. This is more clear on the protocol level. In the following example one
.. command will fail when executed even if the syntax is right:

これはプロトコルレベルでよりクリアになります。以下の例では、ひとつのコマンドが文法上は正しいにも関わらず、実行時に失敗しています:

.. code-block:: none

    Trying 127.0.0.1...
    Connected to localhost.
    Escape character is '^]'.
    MULTI
    +OK
    SET a 3
    abc
    +QUEUED
    LPOP a
    +QUEUED
    EXEC
    *2
    +OK
    -ERR Operation against a key holding the wrong kind of value

.. `EXEC` returned two-element @bulk-string-reply where one is an `OK` code and
.. the other an `-ERR` reply. It's up to the client library to find a
.. sensible way to provide the error to the user.

`EXEC <http://redis.io/commands/exec>`_ は 2 つの要素からなる `bulk-string-reply <http://redis.io/topics/protocol#bulk-string-reply>`_ を返します。ひとつは 'OK' コード、そしてもうひとつは '-ERR' 応答です。ユーザーに対して、ふさわしいエラーを提示する方法は、クライアントライブラリに任されています。

.. It's important to note that **even when a command fails, all the other
.. commands in the queue are processed** – Redis will _not_ stop the
.. processing of commands.

**あるコマンドが失敗しても、その他のキューに入っているコマンドは処理される** 点に留意することは重要です。Redis は一連のコマンドの処理を *止めません* 。

.. Another example, again using the wire protocol with `telnet`, shows how
.. syntax errors are reported ASAP instead:

別の例として、'telnet' によるワイヤプロトコルを使って、文法エラーがすぐに報告されるケースを示します。

.. code-block:: none

    MULTI
    +OK
    INCR a b c
    -ERR wrong number of arguments for 'incr' command

.. This time due to the syntax error the bad `INCR` command is not queued
.. at all.

この場合、誤った `INCR <http://redis.io/commands/incr>`_ は、文法エラーのためキューイングされません。

.. ## Why Redis does not support roll backs?

なぜ Redis はロールバックをサポートしないのか？
====================================================

.. If you have a relational databases background, the fact that Redis commands
.. can fail during a transaction, but still Redis will execute the rest of the
.. transaction instead of rolling back, may look odd to you.

もしあなたにリレーショナル・データベースのバックグランドがあったら、トランザクション中に Redis コマンドが失敗しても、ロールバックの代わりに残りのコマンドが実行される、という事実は奇妙に感じられるかもしれません。

.. However there are good opinions for this behavior:

しかし、この振る舞いについては、理に適う見解があります:

.. * Redis commands can fail only if called with a wrong syntax (and the problem is not detectable during the command queueing), or against keys holding the wrong data type: this means that in practical terms a failing command is the result of a programming errors, and a kind of error that is very likely to be detected during development, and not in production.
.. * Redis is internally simplified and faster because it does not need the ability to roll back.

* Redis のコマンドが失敗するのは、誤った文法で呼び出された(かつコマンドのキューイング時に問題が検知されなかった)場合か、間違ったデータ型をもつキーに対して実行された場合のいずれかしかありません: つまり、実際的な観点から言って、コマンドの失敗はプログラミングエラーによるものであり、プロダクション環境ではなく開発段階で検知可能な類のエラーです。
* Redis は、ロールバック機能を必要としないことで、内部的にシンプルかつ高速化されています。

.. An argument against Redis point of view is that bugs happen, however it should be noted that in general the roll back does not save you from programming errors. For instance if a query increments a key by 2 instead of 1, or increments the wrong key, there is no way for a rollback mechanism to help. Given that no one can save the programmer from his errors, and that the kind of errors required for a Redis command to fail are unlikely to enter in production, we selected the simpler and faster approach of not supporting roll backs on errors.

バグは起こり得る、という観点からの Redis への反論はありますが、しかし一般的に言って、ロールバック機能は、プログラミングエラーからあなたを救うことはありません。たとえば、あるキーを 1 ではなく 2 だけインクリメントしたり、または間違ったキーに対してインクリメントしたり、という誤りについて、ロールバック機構は助けになりません。プログラマを、自身のエラーから救い出すことは誰にもできないことで、また実行に失敗する Redis コマンドがプロダクション環境には入り込むことは起こりにくいでしょう。この点から、私たちはエラー時のロールバックをサポートするよりも、シンプルで高速なアプローチを選択しました。

.. ## Discarding the command queue

コマンドキューの破棄
==========================

.. `DISCARD` can be used in order to abort a transaction. In this case, no
.. commands are executed and the state of the connection is restored to
.. normal.

`DISCARD <http://redis.io/commands/discard>`_ はトランザクションを途中で打ち切るために使われます。このとき、いずれのコマンドも実行されることはなく、コネクションは通常の状態の戻されます。

.. code-block:: none

    > SET foo 1
    OK
    > MULTI
    OK
    > INCR foo
    QUEUED
    > DISCARD
    OK
    > GET foo
    "1"

.. <a name="cas"></a>

.. ## Optimistic locking using check-and-set

.. _transactions_cas:

check-and-set を使った楽観ロック
==========================================

.. `WATCH` is used to provide a check-and-set (CAS) behavior to Redis
.. transactions.

`WATCH <http://redis.io/commands/watch>`_ は check-and-set (CAS) の振る舞いを Redis トランザクションに提供します。

.. `WATCH`ed keys are monitored in order to detect changes against them. If
.. at least one watched key is modified before the `EXEC` command, the
.. whole transaction aborts, and `EXEC` returns a @nil-reply to notify that
.. the transaction failed.

'WATCH' されたキーは、それらに対する変更を検知するために監視されます。もし、watch されているキーが 1 つでも `EXEC <http://redis.io/commands/exec>`_ コマンドの実行前に変更されたら、トランザクション全体が中止され、またトランザクションが失敗したことを通知するために `EXEC <http://redis.io/commands/exec>`_ は `Null-reply <http://redis.io/topics/protocol#nil-reply>`_ を返します。

.. For example, imagine we have the need to atomically increment the value
.. of a key by 1 (let's suppose Redis doesn't have `INCR`).

たとえば、あるキーの値を 1 ずつ自動インクリメントすることを考えてください (Redis が `INCR <http://redis.io/commands/incr>`_ をサポートしていないとして)。

.. The first try may be the following:

最初の試行は次のようになります:

.. code-block:: none

    val = GET mykey
    val = val + 1
    SET mykey $val

.. This will work reliably only if we have a single client performing the
.. operation in a given time. If multiple clients try to increment the key
.. at about the same time there will be a race condition. For instance,
.. client A and B will read the old value, for instance, 10. The value will
.. be incremented to 11 by both the clients, and finally `SET` as the value
.. of the key. So the final value will be 11 instead of 12.

このコードは、一度にひとつのクライアントのみから実行される場合に限り、安全に動作するでしょう。もし複数のクライアントが該当のキーを同時にインクリメントしようとすると、競合が発生します。たとえば、クライアント A とクライアント B が古い値、10 を読み取ったとしましょう。両方のクライアントにより、値は 11 にインクリメントされ、 `SET <http://redis.io/commands/set>`_ されます。結果的に値は、12 ではなく 11 となります。

.. Thanks to `WATCH` we are able to model the problem very well:

`WATCH <http://redis.io/commands/watch>`_ のおかげで、私たちはプログラムがうまく働くように作ることができます:

.. code-block:: none

    WATCH mykey
    val = GET mykey
    val = val + 1
    MULTI
    SET mykey $val
    EXEC

.. Using the above code, if there are race conditions and another client
.. modifies the result of `val` in the time between our call to `WATCH` and
.. our call to `EXEC`, the transaction will fail.

上記のコードを使うと、競合が発生し `WATCH <http://redis.io/commands/watch>`_ と `EXEC <http://redis.io/commands/exec>`_ の呼び出しの間で他のクライアントが 'val' の結果を変更した場合、トランザクションは失敗します。

.. We just have to repeat the operation hoping this time we'll not get a
.. new race. This form of locking is called _optimistic locking_ and is
.. a very powerful form of locking. In many use cases, multiple clients
.. will be accessing different keys, so collisions are unlikely – usually
.. there's no need to repeat the operation.

私たちは、次は競合が発生しないことを願いながら単純にオペレーションを繰り返します。この形式のロックは、 *楽観ロック* と呼ばれ、非常に強力なロックの方法です。多くのユースケースでは、複数のクライアントは異なるキーにアクセスするため、衝突は起こりにくいでしょう。通常は、オペレーションをやり直す必要はありません。

.. ## `WATCH` explained

`WATCH <http://redis.io/commands/watch>`_ の説明
====================================================

.. So what is `WATCH` really about? It is a command that will
.. make the `EXEC` conditional: we are asking Redis to perform
.. the transaction only if no other client modified any of the
.. `WATCH`ed keys. Otherwise the transaction is not entered at
.. all. (Note that if you `WATCH` a volatile key and Redis expires
.. the key after you `WATCH`ed it, `EXEC` will still work. [More on
.. this](http://code.google.com/p/redis/issues/detail?id=270).)

実際のところ、 `WATCH <http://redis.io/commands/watch>`_ とは何でしょう？これは、 `EXEC <http://redis.io/commands/exec>`_ を条件つきにします: 'watch' しているキーが、他のクライアントによって変更されていない場合に限り、トランザクションを実行するように Redis に要請します。そうでなければ、トランザクションはまったく実行されません。(もし、有効期限つきのキーを `WATCH <http://redis.io/commands/watch>`_ していて、watch 中に Redis がそのキーを expire した場合は、 `EXEC <http://redis.io/commands/exec>`_ は機能することに注意してください。 `詳細についてはこちら <http://code.google.com/p/redis/issues/detail?id=270>`_ )

.. `WATCH` can be called multiple times. Simply all the `WATCH` calls will
.. have the effects to watch for changes starting from the call, up to
.. the moment `EXEC` is called. You can also send any number of keys to a
.. single `WATCH` call.

`WATCH <http://redis.io/commands/watch>`_ は複数回呼ぶことができます。単純に、すべての `WATCH <http://redis.io/commands/watch>`_ 呼び出しは、開始から `EXEC <http://redis.io/commands/exec>`_ 呼び出しまでの間の変更を watch するのみです。1 回の `WATCH <http://redis.io/commands/watch>`_ 呼び出しで、キーはいくつでも指定できます。

.. When `EXEC` is called, all keys are `UNWATCH`ed, regardless of whether
.. the transaction was aborted or not.  Also when a client connection is
.. closed, everything gets `UNWATCH`ed.

`EXEC <http://redis.io/commands/exec>`_ が呼ばれると、トランザクションが中止されたかどうかに関わらず、すべてのキーは 'unwatch' されます。また、クライアントの接続が閉じられた場合も、すべて 'unwatch' されます。

.. It is also possible to use the `UNWATCH` command (without arguments)
.. in order to flush all the watched keys. Sometimes this is useful as we
.. optimistically lock a few keys, since possibly we need to perform a
.. transaction to alter those keys, but after reading the current content
.. of the keys we don't want to proceed.  When this happens we just call
.. `UNWATCH` so that the connection can already be used freely for new
.. transactions.

すべての watch 中のキーをフラッシュするため、(引数なしの) `UNWATCH <http://redis.io/commands/unwatch>`_ コマンドが使えます。いくつかのキーを更新するために楽観ロックをかけ、その現在の値を読み取った後で処理を中断したくなったときに、しばしば有用です。この場合、単に `UNWATCH <http://redis.io/commands/unwatch>`_ を呼ぶだけで良く、そうすると新しいトランザクションのために接続が使える状態になります。

.. ### Using `WATCH` to implement ZPOP

ZPOP を実装するために `WATCH <http://redis.io/commands/watch>`_ を使う
================================================================================

.. A good example to illustrate how `WATCH` can be used to create new
.. atomic operations otherwise not supported by Redis is to implement ZPOP,
.. that is a command that pops the element with the lower score from a
.. sorted set in an atomic way. This is the simplest implementation:

新しいアトミックな操作を定義するのに、 `WATCH <http://redis.io/commands/watch>`_ がどのように使えるか、を示す良い例が ZPOP の実装です。これは sorted set から、最も低いスコアをもつ要素をアトミックなやり方で pop する、というコマンドです。以下は、もっともシンプルな実装です:

.. code-block:: none

    WATCH zset
    element = ZRANGE zset 0 0
    MULTI
    ZREM zset element
    EXEC

.. If `EXEC` fails (i.e. returns a @nil-reply) we just repeat the operation.

もし `EXEC <http://redis.io/commands/exec>`_ が失敗したら(つまり、`Null reply <http://redis.io/topics/protocol#nil-reply>`_ が返却されたら)、私たちは単純に操作を繰り返します。

.. ## Redis scripting and transactions

Redis スクリプティングとトランザクション
==============================================

.. A [Redis script](/commands/eval) is transactional by definition, so everything
.. you can do with a Redis transaction, you can also do with a script, and
.. usually the script will be both simpler and faster.

`Redis script <http://redis.io/commands/eval>`_ はその定義からいってトランザクショナルです。そのため、Redis トランザクションで可能なことはすべてスクリプトで実現できます。また、大抵の場合、スクリプトはよりシンプルで高速です。

.. This duplication is due to the fact that scripting was introduced in Redis 2.6
.. while transactions already existed long before. However we are unlikely to
.. remove the support for transactions in the short time because it seems
.. semantically opportune that even without resorting to Redis scripting it is
.. still possible to avoid race conditions, especially since the implementation
.. complexity of Redis transactions is minimal.

この重複は、スクリプティングは Redis 2.6 から導入されたけれども、一方でトランザクションはそれよりもずっと以前から存在していた、という事実からきています。しかし、私たちは直近のうちにトランザクションのサポートを排除するつもりはありません。Redis スクリプティングへの大がかりな移行をしなくても、競合を避けることが可能で、また Redis トランザクションの実装の複雑さは最小限なものであるためです。

.. However it is not impossible that in a non immediate future we'll see that the
.. whole user base is just using scripts. If this happens we may deprecate and
.. finally remove transactions.

しかし、今すぐではない将来、ユーザーベース全体がスクリプトを使うようになったと判断できれば、移行は不可能ではないでしょう。その際には、トランザクションを非推奨とし、最終的には機能を削除するかもしれません。
