# PyHP.js

![Alt text](/docs/bench.png?raw=true "Bench")

PyHP.js compiles [PyHP](https://github.com/juokaz/pyhp) interpreter to a JavaScript VM.

Highly unstable and work in progress.

Based on [PyPy compiled to JavaScript](https://github.com/rfk/pypyjs).

## How does it work?

[PyHP](https://github.com/juokaz/pyhp) PHP interpreter written in Python is
translated into C using [RPython](https://rpython.readthedocs.org/en/latest/),
translated into JavaScript using [emscripten](https://github.com/kripken/emscripten).

The resulting javascript file is [asm.js](http://asmjs.org/). It can be loaded
in any browser or ran with Node.js.

## Building

    docker pull rfkelly/pypyjs-build
    make build
    node build/pyhp.vm.js example.php

Or build the less optimized, but easier to inspect debug version

    make build-debug
    node build/pyhp-debug.vm.js example.php

## Why?

TBD
