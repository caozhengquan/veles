# -*- coding: utf-8 -*-
"""
.. invisible:
     _   _ _____ _     _____ _____
    | | | |  ___| |   |  ___/  ___|
    | | | | |__ | |   | |__ \ `--.
    | | | |  __|| |   |  __| `--. \
    \ \_/ / |___| |___| |___/\__/ /
     \___/\____/\_____|____/\____/

Created on May 15, 2014

Enables the interactive debugging of errors occured during pickling
and unpickling.

███████████████████████████████████████████████████████████████████████████████

Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.

███████████████████████████████████████████████████████████████████████████████
"""


import six
from six.moves import cPickle as pickle  # pylint: disable=W0611
import sys
from pickle import PicklingError, UnpicklingError, HIGHEST_PROTOCOL


# : The best protocol value for pickle().
best_protocol = HIGHEST_PROTOCOL


def augment__str__(fn):
    def __str__(self):
        return "%s\n%s" % (
            fn(self),
            "To debug this error, add --debug-pickle to the command line "
            "arguments or execute from veles.pickle2 "
            "import setup_pickle_debug; setup_pickle_debug()")
    return __str__


__pe__str__ = PicklingError.__str__
__upe__str__ = UnpicklingError.__str__
PicklingError.__str__ = augment__str__(PicklingError.__str__)
UnpicklingError.__str__ = augment__str__(UnpicklingError.__str__)
del augment__str__


def setup_pickle_debug():
    """Enables the interactive debugging of errors occured during pickling
    and unpickling.
    """
    if six.PY3:
        global pickle
        pickle.dump = pickle._dump
        pickle.dumps = pickle._dumps
        pickle.load = pickle._load
        pickle.loads = pickle._loads
    else:
        import pickle  # pylint: disable=W0621
        for module in sys.modules.values():
            if "pickle" in getattr(module, "__dict__", {}):
                module.__dict__["pickle"] = pickle
        pickle._Pickler = pickle.Pickler
        pickle._Unpickler = pickle.Unpickler
    orig_save = pickle._Pickler.save
    orig_load = pickle._Unpickler.load

    def save(self, obj):
        try:
            return orig_save(self, obj)
        except (PicklingError, TypeError, AssertionError):
            import traceback
            import pdb
            six.print_("\033[1;31mPickling failure\033[0m", file=sys.stderr)
            traceback.print_exc()
            # look at obj
            pdb.set_trace()

    def load(self):
        try:
            return orig_load(self)
        except (UnpicklingError, ImportError, AssertionError, KeyError):
            import traceback
            import pdb
            six.print_("\033[1;31mUnpickling failure\033[0m", file=sys.stderr)
            traceback.print_exc()
            # examine the exception
            pdb.post_mortem()

    pickle._Pickler.save = save
    pickle._Unpickler.load = load
    PicklingError.__str__ = __pe__str__
    UnpicklingError.__str__ = __upe__str__
