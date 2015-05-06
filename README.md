# PyHP.js

PyHP.js compiles [PyHP](https://github.com/juokaz/pyhp) interpreter to a JavaScript VM.

Highly unstable and work in progress.

Based on [PyPy compiled to JavaScript](https://github.com/rfk/pypyjs).

## Building

### Starting the VM

    vagrant up
    vagrant ssh
    cd /var/www/pyhp.js

### Building the interpreter

    cd /var/www/pyhp.js/pyhp
    rpython --backend=js --opt=jit --translation-backendopt-remove_asserts --inline-threshold=25 --output=pyhp.vm.js targetpyhp.py
