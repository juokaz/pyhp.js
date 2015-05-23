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

DOCKER_ARGS = -ti -v /tmp:/tmp -v $(CURDIR):$(CURDIR) -w $(CURDIR) -e "CFLAGS=$$CFLAGS" -e "LDFLAGS=$$LDFLAGS" -e "EMCFLAGS=$$EMCFLAGS" -e "EMLDFLAGS=$$EMLDFLAGS" -e "IN_DOCKER=1"

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

# This makes a releasable tarball containing the compiled pyhp interpreter,
# supporting javascript code, and the python stdlib modules and tooling.

VERSION = 0.1.0

.PHONY: build
build: fetch_externals ./build/pyhp.vm.js

.PHONY: build-debug
build-debug: fetch_externals ./build/pyhp-debug.vm.js

# This is the necessary incantation to build the PyHP js backend
# in "release mode", optimized for deployment to the web.  It trades
# off some debuggability in exchange for reduced code size.

./build/pyhp.vm.js:
	mkdir -p build
	#$(PYPY) ./$(EXTERNALS)/pypy/rpython/bin/rpython --backend=js --opt=jit --translation-backendopt-remove_asserts --inline-threshold=25 --output=./build/pyhp.vm.js ./$(EXTERNALS)/pyhp/targetpyhp.py
	export EMLDFLAGS="--embed-file $(CURDIR)/$(EXTERNALS)/pyhp/bench.php@/bench.php" && $(PYPY) ./$(EXTERNALS)/pypy/rpython/bin/rpython --backend=js --opt=jit --translation-backendopt-remove_asserts --inline-threshold=25 --output=./build/pyhp.vm.js ./$(EXTERNALS)/pyhp/targetpyhp.py


# This builds a debugging-friendly version that is bigger but has e.g.
# more asserts and better traceback information.

./build/pyhp-debug.vm.js:
	mkdir -p build
	export EMLDFLAGS="$$EMLDFLAGS -g2 -s ASSERTIONS=1" && $(PYPY) ./$(EXTERNALS)/pypy/rpython/bin/rpython --backend=js --opt=jit --inline-threshold=25 --output=./build/pyhp-debug.vm.js ./$(EXTERNALS)/pyhp/targetpyhp.py


# This builds a version of pypy.js without its JIT, which is useful for
# investigating the size or performance of the core interpreter.

./build/pyhp-nojit.vm.js:
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

update_externals: fetch_externals
	cd $(EXTERNALS)/pypy; \
	git pull
	cd $(EXTERNALS)/pyhp; \
	git pull
