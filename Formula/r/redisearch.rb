class Redisearch < Formula
  desc "Query and indexing engine for Redis"
  homepage "https://github.com/RediSearch/RediSearch"
  url "https://github.com/redisearch/redisearch.git",
      tag:      "v8.4.2",
      revision: "9e2b676313f417209c3464fe21ae166ef931b770"
  license all_of: [
    "AGPL-3.0-only",
    "Apache-2.0", # deps/VectorSimilarity/deps/ScalableVectorSearch, deps/s2geometry, deps/friso
    "BSD-3-Clause", # deps/googletest, deps/hiredis, deps/snowball, deps/geohash
    "MIT", # deps/RedisModulesSDK, deps/libuv, deps/libnu, deps/miniz, deps/fast_float, src/hll
    "Artistic-1.0-Perl", # deps/phonetics
  ]
  head "https://github.com/redisearch/redisearch.git", branch: "master"

  depends_on "cmake" => :build
  depends_on "coreutils" => :build
  depends_on "llvm@18" => :build
  depends_on "make" => :build
  depends_on "python@3.14" => :build
  depends_on "rust" => :build

  depends_on "openssl@3"

  def install
    # Set up build environment
    llvm = Formula["llvm@18"]
    openssl = Formula["openssl@3"]

    ENV.prepend_path "PATH", llvm.opt_bin
    ENV.prepend_path "PATH", Formula["make"].opt_prefix/"libexec/gnubin"
    ENV.prepend_path "PATH", Formula["coreutils"].opt_prefix/"libexec/gnubin"
    ENV.runtime_cpu_detection

    # Build the module
    system "make", "build", "OPENSSL_ROOT_DIR=#{openssl.opt_prefix}", "IGNORE_MISSING_DEPS=1"

    module_files = Dir.glob("bin/*-release/search-community/redisearch.so")

    odie "Module not found at expected path: bin/*-release/search-community/redisearch.so" if module_files.empty?

    lib.install module_files.first
  end

  def post_install
    # Set execute permissions on the module
    source_module = lib/"redisearch.so"
    chmod 0755, source_module
  end

  def caveats
    <<~EOS
      RediSearch module has been installed to:
        #{opt_lib}/redisearch.so

      This module is designed to extend Redis with JSON data types.
    EOS
  end

  test do
    # Test that mimics exactly how Redis loads modules
    (testpath/"test.c").write <<~C
      #include <stdio.h>
      #include <dlfcn.h>

      int main() {
        void *handle;
        int (*onload)(void *, void **, int);

        // Load module like Redis does
        handle = dlopen("#{lib}/redisearch.so", RTLD_NOW|RTLD_LOCAL);
        if (handle == NULL) {
          fprintf(stderr, "Module #{lib}/redisearch.so failed to load: %s\\n", dlerror());
          return 1;
        }

        // Find RedisModule_OnLoad symbol like Redis does
        onload = (int (*)(void *, void **, int))(unsigned long) dlsym(handle, "RedisModule_OnLoad");
        if (onload == NULL) {
          dlclose(handle);
          fprintf(stderr, "Module does not export RedisModule_OnLoad() symbol. Module not loaded.\\n");
          return 1;
        }

        printf("RediSearch module loaded successfully\\n");
        dlclose(handle);
        return 0;
      }
    C

    system ENV.cc, "test.c", "-o", "test"
    assert_match "RediSearch module loaded successfully", shell_output("./test")
  end
end
