========
yawinpty
========
yet another winpty binding for python

.. image:: https://ci.appveyor.com/api/projects/status/vaa9vkgs8ihivyg9?svg=true
  :target: https://ci.appveyor.com/project/TitanSnow/yawinpty
  :alt: Build status
.. image:: https://img.shields.io/github/license/PSoWin/yawinpty.svg
  :target: LICENSE
  :alt: LICENSE
.. image:: https://img.shields.io/pypi/v/yawinpty.svg
  :target: https://pypi.org/project/yawinpty
  :alt: PyPI version
.. image:: https://img.shields.io/pypi/status/yawinpty.svg
  :target: https://pypi.org/project/yawinpty
  :alt: Development status
.. image:: https://img.shields.io/pypi/dm/yawinpty.svg
  :target: https://pypi.org/project/yawinpty
  :alt: Download per month
.. image:: https://img.shields.io/pypi/wheel/yawinpty.svg
  :target: https://pypi.org/project/yawinpty
  :alt: wheel
.. image:: https://img.shields.io/pypi/pyversions/yawinpty.svg
  :target: https://pypi.org/project/yawinpty
  :alt: Support python versions
.. image:: https://codecov.io/gh/TitanSnow/yawinpty/branch/master/graph/badge.svg
  :target: https://codecov.io/gh/TitanSnow/yawinpty
  :alt: Codecov

install
=======

.. code-block:: bash

  pip install yawinpty

build from source
=================

python 3.5+
  install `Visual C++ 2015 Build Tools`_, then use ``python setup.py build`` to build

older python
  +----------+-----------------------+
  |Visual C++|CPython version        |
  +==========+=======================+
  |10.0      |3.3, 3.4               |
  +----------+-----------------------+
  |9.0       |2.6, 2.7, 3.0, 3.1, 3.2|
  +----------+-----------------------+

  install *both* `Visual C++ 2015 Build Tools`_ and the matching version of Visual C++ Build Tools. open "Visual C++ *2015* Build Tools Command Prompt" with the same arch as python, then use ``python setup.py build`` to build

.. _`Visual C++ 2015 Build Tools`: http://landinghub.visualstudio.com/visual-cpp-build-tools

basic examples
==============

get output from process
>>>>>>>>>>>>>>>>>>>>>>>

.. code-block:: python

  from yawinpty import *

  # open a pty
  with Pty() as pty:
      # spawn a process ``python -c "print('HelloWorld!')"``
      pty.spawn(SpawnConfig(SpawnConfig.flag.auto_shutdown, cmdline='python -c "print(\'HelloWorld!\')"'))
      # open the out pipe of console to read
      with open(pty.conout_name(), 'r') as f:
          # HelloWorld!
          print(f.read())

communicate with process
>>>>>>>>>>>>>>>>>>>>>>>>

.. code-block:: python

  from yawinpty import *

  with Pty() as pty:
      # spawn python repl
      pty.spawn(SpawnConfig(SpawnConfig.flag.auto_shutdown, cmdline='python'))
      # open the in pipe of console to write
      with open(pty.conin_name(), 'w') as f:
          f.write('1 + 2\n')
          # write EOF to exit python
          f.write('\x1a\n')
      with open(pty.conout_name(), 'r') as f:
          print(f.read())

gui log of console program (navie)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

.. code-block:: python

  from sys import argv
  from threading import Thread
  from subprocess import list2cmdline
  from tkinter import *
  from yawinpty import *

  root = Tk()
  con = Text(root)
  con.pack()

  def poll():
      # strip escape seq
      with Pty(Config(Config.flag.plain_output)) as pty:
          # run the cmdline passed in by ``sys.argv``
          pty.spawn(SpawnConfig(SpawnConfig.flag.auto_shutdown, cmdline=list2cmdline(argv[1:])))
          with open(pty.conout_name(), 'r') as f:
              while True:
                  ln = f.readline()
                  if not ln:
                      break
                  # log to gui
                  con.insert(END, ln)
  Thread(target=poll).start()

  root.mainloop()

using ``yawinpty``
==================

the common goal to use ``yawinpty`` is to open a pseudo terminal then spawn a process in it and send input to it's stdin and get output from it's stdout. yawinpty.Pty wrapper a pseudo-terminal and do the jobs

*class* yawinpty.\ *Pty*\ (*config=yawinpty.Config()*)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

yawinpty.Pty accept a instance of yawinpty.Config as its config

*class* yawinpty.\ *Config*\ (:emphasis:`\*flags`)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

for the flags to init a "config class" is commonly a set of Class.flag.\*. example\:

.. code-block:: python

  cfg = yawinpty.Config(yawinpty.Config.flag.plain_output)

``help(yawinpty.Config.flag)`` for more supported flags

for ``yawinpty.SpawnConfig`` it's similar

``help(yawinpty.Config)`` for more methods

instances of the ``Pty`` class have the following methods\:

Pty.\ *conin_name*\ ()
>>>>>>>>>>>>>>>>>>>>>>

Pty.\ *conout_name*\ ()
>>>>>>>>>>>>>>>>>>>>>>>

Pty.\ *conerr_name*\ ()
>>>>>>>>>>>>>>>>>>>>>>>

get the name of console in/out/err pipe. the name could be passed to builtin ``open`` to open the pipe

Pty.\ *agent_process_id*\ ()
>>>>>>>>>>>>>>>>>>>>>>>>>>>>

get the process id of the agent process

Pty.\ *set_size*\ ()
>>>>>>>>>>>>>>>>>>>>

set window size of the terminal

Pty.\ *spawn*\ (\ *spawn_config*\ )
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

spawn a process in the pty. spawn_config is a instance of ``yawinpty.SpawnConfig``. note that one Pty instance could only spawn once otherwise ``yawinpty.RespawnError`` would be raised

returns a tuple of *process id, thread id* of spawned process

*class* yawinpty.\ *SpawnConfig*\ (:emphasis:`\*spawnFlags, appname=None, cmdline=None, cwd=None, env=None`)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

``spawnFlags``
  the flags from ``yawinpty.SpawnConfig.flag``
``appname``
  full path to executable file. can be ``None`` if ``cmdline`` is specified
``cmdline``
  command line passed to the spawned process
``cwd``
  working directory for the spawned process
``env``
  the environ for the spawned process, a dict like ``{'VAR1': 'VAL1', 'VAR2': 'VAL2'}``

note that init a ``SpawnConfig`` *does not* spawn a process. a process is spawned only when calling ``Pty.spawn()``. one SpawnConfig instance could be used multitimes

Pty.\ *wait_agent*\ (\ *timeout = yawinpty.INFINITE*\ )
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

Pty.\ *wait_subprocess*\ (\ *timeout = yawinpty.INFINITE*\ )
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

wait for agent/spawned process to exit. raise yawinpty.TimeoutExpired if out of timeout

Pty.\ *close*\ ()
>>>>>>>>>>>>>>>>>

kill processes not exited, close pty and release Windows resource

exceptions
>>>>>>>>>>

all winpty related exceptions are subclasses of ``yawinpty.YawinptyError``. ``help(yawinpty)`` for more information
