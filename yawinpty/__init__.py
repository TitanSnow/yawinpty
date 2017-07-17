import site
import ctypes

SetDllDirectoryA = ctypes.windll.Kernel32.SetDllDirectoryA

for path in site.getsitepackages():
    SetDllDirectoryA(path)

from _yawinpty import *
