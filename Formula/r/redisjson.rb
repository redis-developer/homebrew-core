class Redisjson < Formula
  desc "Json data structure for Redis"
  homepage "https://github.com/redisjson/redisjson"
  url "https://github.com/redisjson/redisjson.git",
      tag:      "v8.4.0",
      revision: "21a2b4dd37b21f23684795f6f2d8282c224f2b01"
  license all_of: [
    "AGPL-3.0-only",
    "BSD-3-Clause", # deps/readies
  ]
  head "https://github.com/redisjson/redisjson.git", branch: "master"

  depends_on maximum_macos: [:sequoia, :build]
  depends_on "cmake" => :build
  depends_on "coreutils" => :build
  depends_on "llvm@18" => :build
  depends_on "make" => :build
  depends_on "python@3.14" => :build
  depends_on "rust" => :build

  def install
    # Add GNU tools to PATH (required by build system)
    ENV.prepend_path "PATH", Formula["coreutils"].opt_libexec/"gnubin"
    ENV.prepend_path "PATH", Formula["make"].opt_libexec/"gnubin"
    ENV.prepend_path "PATH", Formula["llvm@18"].opt_bin

    # Build the module
    system "make", "all"

    module_files = Dir.glob("bin/*-release/rejson.so")

    odie "Module not found at expected path: bin/*-release/rejson.so" if module_files.empty?

    lib.install module_files.first
  end

  def post_install
    # Set execute permissions on the module
    source_module = lib/"rejson.so"
    chmod 0755, source_module
  end

  def caveats
    <<~EOS
      RedisJSON module has been installed to:
        #{opt_lib}/rejson.so

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
        handle = dlopen("#{lib}/rejson.so", RTLD_NOW|RTLD_LOCAL);
        if (handle == NULL) {
          fprintf(stderr, "Module #{lib}/rejson.so failed to load: %s\\n", dlerror());
          return 1;
        }

        // Find RedisModule_OnLoad symbol like Redis does
        onload = (int (*)(void *, void **, int))(unsigned long) dlsym(handle, "RedisModule_OnLoad");
        if (onload == NULL) {
          dlclose(handle);
          fprintf(stderr, "Module does not export RedisModule_OnLoad() symbol. Module not loaded.\\n");
          return 1;
        }

        printf("RedisJSON module loaded successfully\\n");
        dlclose(handle);
        return 0;
      }
    C

    system ENV.cc, "test.c", "-o", "test"
    assert_match "RedisJSON module loaded successfully", shell_output("./test")
  end
end
