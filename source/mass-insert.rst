====================
Redis Mass Insertion
====================

.. note:: 
   このドキュメントは `Redis Mass Insertion <http://redis.io/topics/mass-insert>`_ の翻訳です。
   誤訳を見つけたら `翻訳リポジトリ <https://github.com/mocobeta/redis-doc-ja>`_ に Issue 登録をお願いします。

.. Sometimes Redis instances needs to be loaded with big amount of preexisting
.. or user generated data in a short amount of time, so that millions of keys
.. will be created as fast as possible.

しばしば Redis インスタンスは、数百万のキーをできるだけ高速に作成するため、既存の、またはユーザーが生成する大量のデータを、短時間でロードする必要があります。

.. This is called a *mass insertion*, and the goal of this document is to
.. provide information about how to feed Redis with data as fast as possible.

これは *mass insertion* と呼ばれます。このドキュメントでは、Redis にできるだけ高速にデータを投入する方法について、情報を提供することを目的とします。

.. Use the protocol, Luke

プロトコルを使うんだ, Luke
===========================

.. Using a normal Redis client to perform mass insertion is not a good idea
.. for a few reasons: the naive approach of sending one command after the other
.. is slow because you have to pay for the round trip time for every command.
.. It is possible to use pipelining, but for mass insertion of many records
.. you need to write new commands while you read replies at the same time to
.. make sure you are inserting as fast as possible.

大量データの投入に、標準の Redis クライアントを使うことは、いくつかの理由により良い方針ではありません: コマンドをひとつひとつ送信するナイーブなアプローチは、毎回のコマンドの度にラウンドトリップが発生するため低速です。パイプライニングを使うことも可能ですが、大量のレコードを追加するためには、書き込みコマンドを発行する一方で、同時にできるだけ高速に応答を読み込まなければいけません。

.. Only a small percentage of clients support non-blocking I/O, and not all the
.. clients are able to parse the replies in an efficient way in order to maximize
.. throughput. For all this reasons the preferred way to mass import data into
.. Redis is to generate a text file containing the Redis protocol, in raw format,
.. in order to call the commands needed to insert the required data.

ごく少数のクライアントしかノンブロッキングI/Oをサポートしていません。また、すべてのクライアントが、スループット最大化のための効率的な応答のパースを実現できているわけではありません。こうした理由により、Redis に大量のデータをインポートする際に望ましい方法は、生の Redis プロトコルが書かれたテキスト・ファイルを生成し、データ追加に必要なコマンドを呼び出すことです。

.. For instance if I need to generate a large data set where there are billions
.. of keys in the form: `keyN -> ValueN' I will create a file containing the
.. following commands in the Redis protocol format:

たとえば、私が 'KeyN -> ValueN' というフォーマットのキーを数十億個含むような、大きなデータ・セットを生成する必要がある場合、以下のような Redis プロトコル形式のファイルを作成します:

.. code-block:: none

    SET Key0 Value0
    SET Key1 Value1
    ...
    SET KeyN ValueN

.. Once this file is created, the remaining action is to feed it to Redis
.. as fast as possible. In the past the way to do this was to use the
.. `netcat` with the following command:

ファイルを作成したら、残りの仕事は、 Redis へファイルの内容をできるだけ高速に送り込むことです。以前のやり方は、以下のように 'netcat' を使うことでした。

.. code-block:: none

    (cat data.txt; sleep 10) | nc localhost 6379 > /dev/null

.. However this is not a very reliable way to perform mass import because netcat
.. does not really know when all the data was transferred and can't check for
.. errors. In the unstable branch of Redis at github the `redis-cli` utility
.. supports a new mode called **pipe mode** that was designed in order to perform
.. mass insertion.

しかしこの方法は、大量のデータをインポートするときに信頼できるやり方とは言えません。netcat はすべてのデータが転送されたか実際のところを知らず、またエラー検知もできないためです。github の Redis の unstable branch [訳注: 2014/6 時点では stable version の 2.8 にマージ済み] に含まれる 'redis-cli' ユーティリティでは、mass insertion のため **pipe mode** をサポートするようになりました。

.. Using the pipe mode the command to run looks like the following:

pipe モードを使うには、以下のようにコマンドを実行します:

.. code-block:: none

    cat data.txt | redis-cli --pipe

.. That will produce an output similar to this:

応答はこのようになります:

.. code-block:: none

    All data transferred. Waiting for the last reply...
    Last reply received from server.
    errors: 0, replies: 1000000

.. The redis-cli utility will also make sure to only redirect errors received
.. from the Redis instance to the standard output.

redis-cli ユーティリティは、Redis インスタンスから受信したエラーを標準出力にリダイレクトします。

.. Generating Redis Protocol

Redis プロトコルを生成する
==============================

.. The Redis protocol is extremely simple to generate and parse, and is
.. [Documented here](/topics/protocol). However in order to generate protocol for
.. the goal of mass insertion you don't need to understand every detail of the
.. protocol, but just that every command is represented in the following way:

Redis プロトコルの生成およびパースは非常にシンプルで、 `ここにドキュメント化 <http://redis.io/topics/protocol>`_ されています。しかし、mass insertion のためのプロトコルを生成するにあたり、すべてのプロトコルの詳細まで理解する必要はありません。各コマンドが、以下のように表現されることだけを理解しておいてください:

.. code-block:: none

    *<args><cr><lf>
    $<len><cr><lf>
    <arg0><cr><lf>
    <arg1><cr><lf>
    ...
    <argN><cr><lf>

.. Where `<cr>` means "\r" (or ASCII character 13) and `<lf>` means "\n" (or ASCII character 10).

ここで、'<cr>' は　"\\t" (ASCII 文字コード 13) を、'<lf>' は "\\n" (ASCII 文字コード 10) を表します。

.. For instance the command **SET key value** is represented by the following protocol:

たとえば **SET key value** というコマンドは、以下のプロトコルで表現されます:

.. code-block:: none

    *3<cr><lf>
    $3<cr><lf>
    SET<cr><lf>
    $3<cr><lf>
    key<cr><lf>
    $5<cr><lf>
    value<cr><lf>

.. Or represented as a quoted string:

または引用符で囲った文字列で表現すると:

.. code-block:: none

    "*3\r\n$3\r\nSET\r\n$3\r\nkey\r\n$5\r\nvalue\r\n"

.. The file you need to generate for mass insertion is just composed of commands
.. represented in the above way, one after the other.

mass insertion のために必要なファイルは、上記の方法で表現された 1 つ 1 つのコマンドから構成されます。

.. The following Ruby function generates valid protocol:

以下は、妥当なプロトコルを生成する Ruby 関数です。

.. code-block:: ruby

    def gen_redis_proto(*cmd)
        proto = ""
        proto << "*"+cmd.length.to_s+"\r\n"
        cmd.each{|arg|
            proto << "$"+arg.to_s.bytesize.to_s+"\r\n"
            proto << arg.to_s+"\r\n"
        }
        proto
    end

    puts gen_redis_proto("SET","mykey","Hello World!").inspect

.. Using the above function it is possible to easily generate the key value pairs
.. in the above example, with this program:

この関数を使うと、前述のキー・バリューペアは以下のプログラムで簡単に生成できます:

.. code-block:: ruby

    (0...1000).each{|n|
        STDOUT.write(gen_redis_proto("SET","Key#{n}","Value#{n}"))
    }

.. We can run the program directly in pipe to redis-cli in order to perform our
.. first mass import session.

このプログラムの実行結果をパイプで直接 redis-cli に送れば、大量データをインポートするセッションを実行できます。

.. code-block:: ruby

    $ ruby proto.rb | redis-cli --pipe
    All data transferred. Waiting for the last reply...
    Last reply received from server.
    errors: 0, replies: 1000

.. How the pipe mode works under the hoods

pipe モードが内部でどのように動作しているか
=====================================================

.. The magic needed inside the pipe mode of redis-cli is to be as fast as netcat
.. and still be able to understand when the last reply was sent by the server
.. at the same time.

redis-cli の pipe モードの内部で必要な魔法は、netcat と同程度に高速で、かつ、サーバーから送信される応答を理解できる、というものです。

.. This is obtained in the following way:

これは以下の方法で実現されています:

.. + redis-cli --pipe tries to send data as fast as possible to the server.
.. + At the same time it reads data when available, trying to parse it.
.. + Once there is no more data to read from stdin, it sends a special **ECHO** command with a random 20 bytes string: we are sure this is the latest command sent, and we are sure we can match the reply checking if we receive the same 20 bytes as a bulk reply.
.. + Once this special final command is sent, the code receiving replies starts to match replies with this 20 bytes. When the matching reply is reached it can exit with success.

* redis-cli --pipe は可能なかぎり高速にデータをサーバーへ送信する。
* それと同時に、得られた受信データを読み、パースを試みる。
* 標準入力からのデータ入力が終わったら、ランダムな 20 バイトの文字列とともに、特殊な **ECHO** コマンドを送信する: これが最後のコマンドだとわかっているため、受信データをチェックし、同じ 20 バイトからなる bulk reply であるかのマッチングが可能。
* この特殊コマンドが送信されたら、コードは応答と 20 バイト文字列とのマッチングを始める。もしマッチする応答が見つかったら、成功とともに終了する。

.. Using this trick we don't need to parse the protocol we send to the server in order to understand how many commands we are sending, but just the replies.

このトリックを使うことで、いくつのコマンドを送信したか把握しておくために、サーバーへ送信するプロトコルをパースする必要がなくなり、応答のパースを行うだけで済むようになります。

.. However while parsing the replies we take a counter of all the replies parsed so that at the end we are able to tell the user the amount of commands transferred to the server by the mass insert session.

一方応答については、受け取ったすべての応答をパースするため、最終的には、 mass insert セッション中に転送されたコマンドの数をユーザーに提示することができます。
