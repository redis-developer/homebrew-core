class Redis < Formula
  desc "Persistent key-value database, with built-in net interface"
  homepage "https://redis.io/"
  url "https://download.redis.io/releases/redis-8.6.1.tar.gz"
  sha256 "6873fc933eeb7018aa329e868beac7228695f50c0d46f236a4ff1a6d7f7bb5b6"
  license all_of: [
    "AGPL-3.0-only",
    "BSD-2-Clause", # deps/jemalloc, deps/linenoise, src/lzf*
    "BSL-1.0", # deps/fpconv
    "MIT", # deps/lua
    any_of: ["CC0-1.0", "BSD-2-Clause"], # deps/hdr_histogram
  ]
  revision 1
  head "https://github.com/redis/redis.git", branch: "unstable"

  no_autobump! because: :bumped_by_upstream

  bottle do
    sha256 cellar: :any,                 arm64_tahoe:   "9c8066d1449fe4409ceac586524fabe20ffbc5d0550dd51c6854cd44fb36dc18"
    sha256 cellar: :any,                 arm64_sequoia: "47545c5a6b4111af674b84fb0ea731451a77c43ab7d14b30202c7952d56f455f"
    sha256 cellar: :any,                 arm64_sonoma:  "da7ab72d1d8f23e7d4faf24c8819128eb209ca613d5baf7d5b093385e4051081"
    sha256 cellar: :any,                 sonoma:        "4741855b02343ac4c68bde8aee23e6865cbdeb5ba2d16c67b46b991db06adc03"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "dcc94d4c8530780cd3cb0f4bda5952d3ce97c088a970ab561c114eeaf06b1efb"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "8e8351a1d086b3a541b28fff6ae7aad46033045fd9440a707d10b972e1bbc41f"
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "cmake" => :build
  depends_on "coreutils" => :build
  depends_on "libtool" => :build
  depends_on "llvm@18" => :build
  depends_on "python@3.14" => :build
  depends_on "rust" => :build
  depends_on "openssl@3"

  on_macos do
    depends_on "make" => :build # Needs Make 4.0+
  end

  conflicts_with "valkey", because: "both install `redis-*` binaries"

  resource "redisjson" do
    url "https://github.com/redisjson/redisjson.git",
    revision: "107144fd2c0a6b325108352bf83ed6e6f731a20f"
  end

  resource "redisbloom" do
    url "https://github.com/redisbloom/redisbloom.git",
    revision: "fd8f01c9f13a8d6424481e8c6c9316178f8601b2"
  end

  resource "redistimeseries" do
    url "https://github.com/redistimeseries/redistimeseries.git",
    revision: "05fd355db748676861dc4c17d19c8c1ca74c0154"
  end

  resource "redisearch" do
    url "https://github.com/redisearch/redisearch.git",
    revision: "0deb13f8de3c32ffee224e9c3072e3281c33e7b0"
  end

  def install
    openssl = Formula["openssl@3"]

    system "make", "install", "PREFIX=#{prefix}", "CC=#{ENV.cc}", "BUILD_TLS=yes"

    resource("redisjson").stage do
      # Add GNU tools to PATH (required by build system)
      ENV.prepend_path "PATH", Formula["coreutils"].opt_libexec/"gnubin"
      # Build the module
      system "gmake", "all"
      lib.install Dir.glob("bin/*-release/rejson.so").first
    end

    resource("redisbloom").stage do
      # Add GNU tools to PATH (required by build system)
      ENV.prepend_path "PATH", Formula["coreutils"].opt_libexec/"gnubin"

      # Set minimum SDK version for macOS
      if OS.mac?
        ENV["OSX_MIN_SDK_VER"] = case MacOS.version
        when :tahoe then "26.0"
        when 15 then "15.0"
        when 14 then "14.0"
        else MacOS.version.to_s
        end
      end

      # Build the module
      system "gmake", "all"
      lib.install Dir.glob("bin/*-release/redisbloom.so").first
    end

    resource("redistimeseries").stage do
      # Add GNU tools to PATH (required by build system)
      ENV.prepend_path "PATH", Formula["coreutils"].opt_libexec/"gnubin"

      # Set compiler flags for OpenSSL
      ENV.append "CFLAGS", "-I#{openssl.opt_include}"
      ENV.append "CXXFLAGS", "-I#{openssl.opt_include}"
      ENV.append "CPPFLAGS", "-I#{openssl.opt_include}"
      ENV.append "LDFLAGS", "-L#{openssl.opt_lib}"
      # Build the module
      system "gmake", "build", "openssl_prefix=#{openssl.opt_prefix}", "OPENSSL_PREFIX=#{openssl.opt_prefix}"
      lib.install Dir.glob("bin/*-release/redistimeseries.so").first
    end

    resource("redisearch").stage do
      # Add GNU tools to PATH (required by build system)
      ENV.prepend_path "PATH", Formula["coreutils"].opt_libexec/"gnubin"
      # RediSearch has been verified to support runtime CPU detection for SIMD optimizations
      ENV.runtime_cpu_detection
      # Build the module
      system "gmake", "build", "OPENSSL_ROOT_DIR=#{openssl.opt_prefix}", "IGNORE_MISSING_DEPS=1"
      lib.install Dir.glob("bin/*-release/search-community/redisearch.so").first
    end

    %w[run db/redis log].each { |p| (var/p).mkpath }

    # Fix up default conf file to match our paths
    inreplace "redis.conf" do |s|
      s.gsub! "/var/run/redis_6379.pid", var/"run/redis.pid"
      s.gsub! "dir ./", "dir #{var}/db/redis/"
      s.sub!(/^bind .*$/, "bind 127.0.0.1 ::1")
    end

    etc.install "redis.conf"
    etc.install "sentinel.conf" => "redis-sentinel.conf"
  end

  def post_install
    # Set execute permissions on module files
    %w[redisbloom.so rejson.so redisearch.so redistimeseries.so].each do |file|
      chmod 0755, lib/file
    end

    # Add loadmodule directives to redis.conf
    redis_conf = Pathname.new(HOMEBREW_PREFIX)/"etc/redis.conf"

    if redis_conf.exist?
      conf_content = redis_conf.read

      # Add loadmodule directives for each Redis module
      %w[redisbloom.so rejson.so redisearch.so redistimeseries.so].each do |file|
        module_path = opt_lib/file
        loadmodule_line = "loadmodule #{module_path}"

        next if conf_content.include?(loadmodule_line)

        ohai "Adding #{file} module to redis.conf"
        File.open(redis_conf, "a") do |f|
          f.write "\n# #{file} module\n"
          f.write "#{loadmodule_line}\n"
        end
        conf_content = redis_conf.read
      end
    else
      opoo "redis.conf not found at #{redis_conf}"
    end
  end

  service do
    run [opt_bin/"redis-server", etc/"redis.conf"]
    keep_alive true
    error_log_path var/"log/redis.log"
    log_path var/"log/redis.log"
    working_dir var
  end

  test do
    system bin/"redis-server", "--test-memory", "2"
    %w[run db/redis log].each { |p| assert_path_exists var/p, "#{var/p} doesn't exist!" }

    # Test that all modules can be loaded
    %w[redisbloom.so rejson.so redisearch.so redistimeseries.so].each do |file|
      module_path = lib/file
      assert_path_exists module_path, "#{file} module not found at #{module_path}"

      # Test that the module loads successfully
      output = shell_output("#{bin}/redis-server --loadmodule #{module_path} --test-memory 2 2>&1", 1)
      assert_match "Module", output
    end
  end
end
