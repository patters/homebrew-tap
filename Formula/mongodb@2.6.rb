class MongodbAT26 < Formula
  desc "High-performance document-oriented database"
  homepage "https://www.mongodb.org/"
  url "https://fastdl.mongodb.org/src/mongodb-src-r2.6.12.tar.gz"
  sha256 "2dd51eabcfcd133573be74c0131c85b67764042833e7d94077e86adc0b9406dc"

  bottle do
    cellar :any_skip_relocation
    sha256 "233a848522494300b37a97498d6349b9d734a0bf637ade1d9a5ed56783e6982f" => :sierra
    sha256 "3178051c3c82b0f0b306bd85a43693fc3f5dfb898fa2eb13ab21620e00c8a916" => :el_capitan
    sha256 "57b17de046e3808e1357271eb7fd0de4b33aeaa1fdfcce5494a35daf4ba95260" => :yosemite
  end

  if MacOS.version >= "10.13"
    patch :DATA
  end

  depends_on "scons" => :build
  depends_on "openssl"

  def install
    # patch :DATA
    # patch :p0, :DATA

    # This modifies the SConstruct file to include 10.10, 10.11, and 10.12 osx versions as accepted build options.
    inreplace "SConstruct", /osx_version_choices = \[.+?\]/, "osx_version_choices = ['10.6', '10.7', '10.8', '10.9', '10.10', '10.11', '10.12', '10.13']"

    args = %W[
      --prefix=#{prefix}
      -j#{ENV.make_jobs}
      --cc=#{ENV.cc}
      --cxx=#{ENV.cxx}
      --osx-version-min=#{MacOS.version}
      --full
    ]

    args << "--use-system-boost" if build.with? "boost"
    args << "--64" if MacOS.prefer_64_bit?

    # Pass the --disable-warnings-as-errors flag to Scons when on Yosemite
    # or later, otherwise 2.6.x won't build from source due to a Clang 3.5+
    # error - https://github.com/mongodb/mongo/pull/956#issuecomment-94545753
    args << "--disable-warnings-as-errors" if MacOS.version >= :yosemite

    if build.with? "openssl"
      args << "--ssl" << "--extrapath=#{Formula["openssl"].opt_prefix}"
    end

    # args << "CCFLAGS=-mmacosx-version-min=#{MacOS.version}"
    # args << "LINKFLAGS=-mmacosx-version-min=#{MacOS.version}"

    # args << "--use-sasl-client" if build.with? "sasl"
    # args << "--use-system-boost" if build.with? "boost"
    # args << "--use-new-tools"
    # args << "--build-mongoreplay=true"

    scons "install", *args

    (buildpath+"mongod.conf").write mongodb_conf
    etc.install "mongod.conf"

    (var/"mongodb").mkpath
    (var/"log/mongodb").mkpath
  end

  def mongodb_conf; <<~EOS
    systemLog:
      destination: file
      path: #{var}/log/mongodb/mongo.log
      logAppend: true
    storage:
      dbPath: #{var}/mongodb
    net:
      bindIp: 127.0.0.1
    EOS
  end

  plist_options :manual => "mongod --config #{HOMEBREW_PREFIX}/etc/mongod.conf"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/mongod</string>
        <string>--config</string>
        <string>#{etc}/mongod.conf</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>KeepAlive</key>
      <false/>
      <key>WorkingDirectory</key>
      <string>#{HOMEBREW_PREFIX}</string>
      <key>StandardErrorPath</key>
      <string>#{var}/log/mongodb/output.log</string>
      <key>StandardOutPath</key>
      <string>#{var}/log/mongodb/output.log</string>
      <key>HardResourceLimits</key>
      <dict>
        <key>NumberOfFiles</key>
        <integer>1024</integer>
      </dict>
      <key>SoftResourceLimits</key>
      <dict>
        <key>NumberOfFiles</key>
        <integer>1024</integer>
      </dict>
    </dict>
    </plist>
    EOS
  end

  test do
    system "#{bin}/mongod", "--sysinfo"
  end
end

__END__
diff --git a/src/mongo/db/structure/catalog/namespace.h b/src/mongo/db/structure/catalog/namespace.h
index fafa10b..b5ce4ad 100644
--- a/src/mongo/db/structure/catalog/namespace.h
+++ b/src/mongo/db/structure/catalog/namespace.h
@@ -55,7 +55,7 @@ namespace mongo {
         bool operator!=(const char *r) const { return strcmp(buf, r) != 0; }
         bool operator!=(const Namespace& r) const { return strcmp(buf, r.buf) != 0; }
 
-        bool hasDollarSign() const { return strchr( buf , '$' ) > 0;  }
+        bool hasDollarSign() const { return strchr( buf , '$' ) != 0;  }
 
         int hash() const; // value returned is always > 0

diff --git a/src/mongo/db/client.h b/src/mongo/db/client.h
index 2017c51..5777634 100644
--- a/src/mongo/db/client.h
+++ b/src/mongo/db/client.h
@@ -260,6 +260,6 @@ namespace mongo {
         return *c;
     }
 
-    inline bool haveClient() { return currentClient.get() > 0; }
+    inline bool haveClient() { return currentClient.get() != 0; }
 
 };

diff --git a/src/mongo/db/fts/fts_matcher.cpp b/src/mongo/db/fts/fts_matcher.cpp
index c9fad05..0e6630a 100644
--- a/src/mongo/db/fts/fts_matcher.cpp
+++ b/src/mongo/db/fts/fts_matcher.cpp
@@ -128,7 +128,7 @@ namespace mongo {
          * @param haystack, raw string to be parsed
          */
         bool FTSMatcher::_phraseMatches( const string& phrase, const string& haystack ) const {
-            return strcasestr( haystack.c_str(), phrase.c_str() ) > 0;
+            return strcasestr( haystack.c_str(), phrase.c_str() ) != 0;
         }
     }
 }

diff --git a/src/mongo/client/connpool.h b/src/mongo/client/connpool.h
index 9bf4583..e344aca 100644
--- a/src/mongo/client/connpool.h
+++ b/src/mongo/client/connpool.h
@@ -323,7 +323,7 @@ namespace mongo {
             return _conn;
         }
 
-        bool ok() const { return _conn > 0; }
+        bool ok() const { return _conn != 0; }
 
         string getHost() const { return _host; }
 
diff --git a/src/mongo/s/shard.h b/src/mongo/s/shard.h
index 247fbde..25dbc56 100644
--- a/src/mongo/s/shard.h
+++ b/src/mongo/s/shard.h
@@ -292,7 +292,7 @@ namespace mongo {
             _finishedInit = true;
         }
         
-        bool ok() const { return _conn > 0; }
+        bool ok() const { return _conn != 0; }
 
         /**
            this just passes through excpet it checks for stale configs

diff --git a/src/mongo/s/d_state.cpp b/src/mongo/s/d_state.cpp
index 8e46206..bfe630e 100644
--- a/src/mongo/s/d_state.cpp
+++ b/src/mongo/s/d_state.cpp
@@ -831,7 +831,7 @@ namespace mongo {
         if ( ! shardingState.hasVersion( ns ) )
             return false;
 
-        return ShardedConnectionInfo::get(false) > 0;
+        return ShardedConnectionInfo::get(false) != 0;
     }
 
     class UnsetShardingCommand : public MongodShardCommand {
