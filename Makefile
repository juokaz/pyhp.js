#
# Makefile for building various parts of pypyjs.
#
# Note that the pypyjs build environment is very particular - emscripten
# produces 32-bit code, so pypy must be translated using a 32-bit python
# interpreter with various 32-bit support libraries.
#
# The recommended approach is to use the pre-built docker image for the
# build environment, available via:
#
#     docker pull rfkelly/pypyjs-build
#
# If you'd like to use your own versions of these dependencies you
# will need to install:
#
#   * a working emscripten build environment
#   * a 32-bit pypy interpreter, for running the build
#   * a 32-bit cpython intereter, for running the tests
#   * 32-bit development libraries for "libffi" and "libgc"
#
# You can tweak the makefile variables below to point to such an environment.
#


# This runs the dockerized build commands as if they were in the current
# directory, with write access to the current directory.  For linux we
# can mount /etc/passwd and actually run as the current user.  For OSX
# we run as root, assuming the curdir is under /Users, and hence that
# boot2docker will automagically share it with appropriate permissions.

DOCKER_IMAGE = rfkelly/pypyjs-build

DOCKER_ARGS = -ti --rm -v /tmp:/tmp -v $(CURDIR):$(CURDIR) -w $(CURDIR) -e "CFLAGS=$$CFLAGS" -e "LDFLAGS=$$LDFLAGS" -e "EMCFLAGS=$$EMCFLAGS" -e "EMLDFLAGS=$$EMLDFLAGS" -e "IN_DOCKER=1"

ifeq ($(shell uname -s),Linux)
    # For linux, we can mount /etc/passwd and actually run as the current
    # user, making permissions work nicely on created build artifacts.
    # For other platforms we just run as the default docker user, assume
    # that the current directory is somewhere boot2docker can automagically
    # mount it, and hence build artifacts will get sensible permissions.
    DOCKER_ARGS += -v /etc/passwd:/etc/passwd -u $(USER)
endif

ifeq ($(IN_DOCKER), 1)
    DOCKER =
else
    DOCKER = docker run $(DOCKER_ARGS) $(DOCKER_IMAGE)
endif

# Change these variables if you want to use a custom build environment.
# They must point to the emscripten compiler, a 32-bit python executable
# and a 32-bit pypy executable.

EMCC = $(DOCKER) emcc
PYTHON = $(DOCKER) python
PYPY = $(DOCKER) pypy
EXTERNALS = deps


# The default target puts a built interpreter locally in ./lib.

.PHONY: lib
lib: ./lib/pyhp.vm.js

./lib/pyhp.vm.js: ./build/pyhp.vm.js
	cp ./build/pyhp.vm.js ./lib/
	python ./tools/extract_memory_initializer.py ./lib/pyhp.vm.js
	rm -rf ./lib/modules/
	python tools/module_bundler.py init ./lib/modules/

# This makes a releasable tarball containing the compiled pyhp interpreter,
# supporting javascript code, and the python stdlib modules and tooling.

VERSION = 0.1.0

.PHONY: build
build: ./build/pyhp.vm.js

.PHONY: build-debug
build-debug: ./build/pyhp-debug.vm.js

.PHONY: release
release: ./build/pyhp.js-$(VERSION).tar.gz

.PHONY: release-nojit
release-nojit: ./build/pyhp-nojit.js-$(VERSION).tar.gz

.PHONY: release-debug
release-debug: ./build/pyhp-debug.js-$(VERSION).tar.gz

./build/%.js-$(VERSION).tar.gz: RELNAME = $*.js-$(VERSION)
./build/%.js-$(VERSION).tar.gz: RELDIR = ./build/$(RELNAME)
./build/%.js-$(VERSION).tar.gz: ./build/%.vm.js
	mkdir -p $(RELDIR)/lib
	# Copy the compiled VM and massage it into the expected shape.
	cp ./build/$*.vm.js $(RELDIR)/lib/pyhp.vm.js
	python ./tools/extract_memory_initializer.py $(RELDIR)/lib/pyhp.vm.js
	# Cromulate for better compressibility, unless it's a debug build.
	if [ `echo $< | grep -- -debug` ]; then true ; else python ./tools/cromulate.py -w 1000 $(RELDIR)/lib/pyhp.vm.js ; fi
	# Copy the supporting JS library code.
	cp ./lib/pyhp.js ./lib/README.txt ./lib/*Promise*.js $(RELDIR)/lib/
	cp -r ./lib/tests $(RELDIR)/lib/tests
	# Create an indexed stdlib distribution.
	python tools/module_bundler.py init $(RELDIR)/lib/modules/
	# Copy tools for managing the distribution.
	mkdir -p $(RELDIR)/tools
	cp ./tools/module_bundler.py $(RELDIR)/tools/
	# Copy release distribution metadata.
	cp ./package.json $(RELDIR)/package.json
	cp ./README.dist.rst $(RELDIR)/README.rst
	# Tar it up, and we're done.
	cd ./build && tar -czf $(RELNAME).tar.gz $(RELNAME)
	rm -rf $(RELDIR)


# This is the necessary incantation to build the PyHP js backend
# in "release mode", optimized for deployment to the web.  It trades
# off some debuggability in exchange for reduced code size.

./build/pyhp.vm.js: fetch_externals
	mkdir -p build
	#$(PYPY) ./$(EXTERNALS)/pypy/rpython/bin/rpython --backend=js --opt=jit --translation-backendopt-remove_asserts --inline-threshold=25 --output=./build/pyhp.vm.js ./$(EXTERNALS)/pyhp/targetpyhp.py
	export EMLDFLAGS="--embed-file $(CURDIR)/$(EXTERNALS)/pyhp/bench.php@/bench.php" && $(PYPY) ./$(EXTERNALS)/pypy/rpython/bin/rpython --backend=js --opt=jit --translation-backendopt-remove_asserts --inline-threshold=25 --output=./build/pyhp.vm.js ./$(EXTERNALS)/pyhp/targetpyhp.py


# This builds a debugging-friendly version that is bigger but has e.g.
# more asserts and better traceback information.

./build/pyhp-debug.vm.js: fetch_externals
	mkdir -p build
	export EMLDFLAGS="$$EMLDFLAGS -g2 -s ASSERTIONS=1" && $(PYPY) ./$(EXTERNALS)/pypy/rpython/bin/rpython --backend=js --opt=jit --inline-threshold=25 --output=./build/pyhp-debug.vm.js ./$(EXTERNALS)/pyhp/targetpyhp.py


# This builds a version of pypy.js without its JIT, which is useful for
# investigating the size or performance of the core interpreter.

./build/pyhp-nojit.vm.js: fetch_externals
	mkdir -p build
	$(PYPY) ./$(EXTERNALS)/pypy/rpython/bin/rpython --backend=js --opt=2 --translation-backendopt-remove_asserts --inline-threshold=25 --output=./build/pyhp-nojit.vm.js ./$(EXTERNALS)/pyhp/targetpyhp.py

# Convenience target to launch a shell in the dockerized build environment.

shell:
	$(DOCKER) /bin/bash


bench: ./build/pyhp.vm.js
	$(DOCKER) node ./build/pyhp.vm.js bench.php

fetch_externals: $(EXTERNALS)/pypy $(EXTERNALS)/pyhp

$(EXTERNALS)/pypy:
	mkdir -p $(EXTERNALS); \
	cd $(EXTERNALS); \
	git clone git@github.com:rfk/pypy.git

$(EXTERNALS)/pyhp:
	mkdir -p $(EXTERNALS); \
	cd $(EXTERNALS); \
	git clone git@github.com:juokaz/pyhp.git
