import unittest
from yawinpty import *
from os import environ
from random import randint
import pickle
import sys

cmd = environ['comspec']

class YawinptyTest(unittest.TestCase):
    """tests for yawinpty"""
    def test_helloworld(self):
        """test simple use"""
        pty = Pty(Config(Config.flag.plain_output))
        cfg = SpawnConfig(SpawnConfig.flag.auto_shutdown, cmdline = r'python tests\helloworld.py')
        with open(pty.conout_name(), 'r') as fout:
            pty.spawn(cfg)
            out = fout.read()
        self.assertEqual(out, 'helloworld\n')
    def test_errors(self):
        """test Error classes inherit"""
        for code in range(1, 9):
            err_type = WinptyError._from_code(code)
            err_inst = err_type('awd')
            self.assertTrue(issubclass(err_type, WinptyError))
            self.assertIsInstance(err_inst, WinptyError)
            self.assertIsInstance(err_inst, err_type)
            self.assertEqual(err_inst.code, code)
            self.assertEqual(err_inst.args[0], 'awd')
    def test_echo(self):
        """test echo (IO)"""
        pty = Pty(Config(Config.flag.plain_output))
        pty.spawn(SpawnConfig(SpawnConfig.flag.auto_shutdown, cmdline = r'python tests\echo.py'))
        exc = []
        with open(pty.conin_name(), 'w') as fin:
            for i in range(32):
                tmp = []
                for j in range(i):
                    st = str(j)
                    tmp.append(st)
                    fin.write(st)
                fin.write('\n')
                exc += [''.join(tmp)] * 2
            fin.write('\x1a\n')
        with open(pty.conout_name(), 'r') as fout:
            out = fout.read()
        exc += ['^Z', '']
        self.assertEqual('\n'.join(exc), out)
    def test_spawn_fail(self):
        """test behavior when spawn fail"""
        try:
            Pty().spawn(SpawnConfig(appname = 'notexists'))
        except SpecifiedSpawnCreateProcessFailed as e:
            self.assertEqual(e.winerror, 2)
        else:
            self.assertTrue(False)
    def test_env(self):
        """test env passing"""
        env = environ.copy()
        def randstr():
            return ''.join([chr(randint(ord('A'), ord('Z'))) for i in range(randint(1, 32))])
        for i in range(128):
            key = randstr()
            if key not in env:
                env[key] = randstr()
        pty = Pty()
        pty.spawn(SpawnConfig(SpawnConfig.flag.auto_shutdown, cmdline = r'python tests\env.py', env = env))
        with open(pty.conout_name(), 'rb') as f:
            f.read()
        with open('env', 'rb') as f:
            self.assertEqual(pickle.load(f), env)
    def test_wait_subprocess(self):
        """test Pty.wait_subprocess"""
        with Pty() as pty:
            pty.spawn(SpawnConfig(cmdline = r'python tests\true.py'))
            pty.wait_subprocess()
        with Pty() as pty:
            pty.spawn(SpawnConfig(cmdline = r'python tests\false.py'))
            try:
                pty.wait_subprocess()
            except ExitNonZero as e:
                self.assertEqual(e.exitcode, 1)
            else:
                self.assertTrue(False)
    def test_cwd(self):
        """test cwd in spawn"""
        with Pty(Config(Config.flag.plain_output)) as pty:
            pty.spawn(SpawnConfig(SpawnConfig.flag.auto_shutdown, appname = sys.executable, cmdline = [sys.executable, '-c', 'print(__import__(\'os\').getcwd())'], cwd = 'C:\\'))
            with open(pty.conout_name(), 'r') as f:
                self.assertEqual(f.readline(), 'C:\\\n')

if __name__ == '__main__':
    unittest.main()
