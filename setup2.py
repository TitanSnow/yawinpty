from setuptools import setup
from distutils.extension import Extension
from distutils.command.build_ext import build_ext
from distutils.command.build_clib import build_clib
from distutils.msvc9compiler import MSVCCompiler
from distutils.sysconfig import customize_compiler
try:
    from Cython.Build import cythonize
except ImportError:
    cythonize = None
from subprocess import check_output, check_call
from os import environ
from setupcommon import *

cmd = environ.get('comspec', 'cmd')

class WinptyExtension(Extension):
    pass

class build_winpty(build_ext):
    def build_extensions(self):
        winpty_exts = [ext for ext in self.extensions if isinstance(ext, WinptyExtension)]
        if winpty_exts:
            winpty_commit_hash = check_output([cmd, '/c', r'cd winpty\src\shared && GetCommitHash.bat']).decode()
            winpty_gen_include = check_output([cmd, '/c', r'cd winpty\src\shared && UpdateGenVersion.bat {}'.format(winpty_commit_hash)]).decode()
            if winpty_gen_include[-2:] == '\r\n':
                winpty_gen_include = winpty_gen_include[:-2]

            check_call(['lib', '/nologo', '/def:winpty.def', '/out:winpty.lib'])
        for ext in winpty_exts:
            ext.include_dirs += ['winpty/src/{}'.format(winpty_gen_include)]

        static(self.compiler)
        build_ext.build_extensions(self)

class build_winpty_agent(build_clib):
    def finalize_options(self):
        self.set_undefined_options('build', ('build_lib', 'build_clib'))
        build_clib.finalize_options(self)
    def get_library_names(self):
        return []
    def build_libraries(self, libraries):
        static(self.compiler)
        if libraries:
            winpty_commit_hash = check_output([cmd, '/c', r'cd winpty\src\shared && GetCommitHash.bat']).decode()
            winpty_gen_include = check_output([cmd, '/c', r'cd winpty\src\shared && UpdateGenVersion.bat {}'.format(winpty_commit_hash)]).decode()
            if winpty_gen_include[-2:] == '\r\n':
                winpty_gen_include = winpty_gen_include[:-2]
        for lib in libraries:
            lib[1]['include_dirs'] += ['winpty/src/{}'.format(winpty_gen_include)]

        for (lib_name, build_info) in libraries:
            sources = build_info.get('sources')
            sources = list(sources)

            # First, compile the source code to object files in the library
            # directory.  (This should probably change to putting object
            # files in a temporary build directory.)
            macros = build_info.get('macros')
            include_dirs = build_info.get('include_dirs')
            objects = self.compiler.compile(sources,
                                            output_dir=self.build_temp,
                                            macros=macros,
                                            include_dirs=include_dirs,
                                            debug=self.debug)

            if lib_name == 'winpty-agent':
                self.compiler.link_executable(objects, lib_name,
                                            output_dir=self.build_clib,
                                            debug=self.debug,
                                            libraries=build_info.get('libraries'))
            elif lib_name == 'winpty':
                self.compiler.link_shared_lib(objects, lib_name,
                                            output_dir=self.build_clib,
                                            debug=self.debug,
                                            libraries=build_info.get('libraries'))
    def run(self):
        environ["DISTUTILS_USE_SDK"] = ""
        environ["MSSdk"] = ""
        assert("DISTUTILS_USE_SDK" in environ and "MSSdk" in environ)

        if not self.libraries:
            return

        self.compiler = CustomMSVCCompiler(dry_run=self.dry_run,
                                     force=self.force)
        customize_compiler(self.compiler)

        if self.include_dirs is not None:
            self.compiler.set_include_dirs(self.include_dirs)
        if self.define is not None:
            # 'define' option is a list of (name,value) tuples
            for (name,value) in self.define:
                self.compiler.define_macro(name, value)
        if self.undef is not None:
            for macro in self.undef:
                self.compiler.undefine_macro(macro)

        self.build_libraries(self.libraries)

        del environ["DISTUTILS_USE_SDK"]
        del environ["MSSdk"]

class CustomMSVCCompiler(MSVCCompiler):
    def manifest_setup_ldargs(self, output_filename, build_temp, ld_args):
        pass
    def manifest_get_embed_info(self, target_desc, ld_args):
        return None
    def initialize(self, plat_name=None):
        MSVCCompiler.initialize(self, plat_name)
        self.compile_options += ['/EHsc']
        self.compile_options_debug += ['/EHsc']


ext_module = WinptyExtension('yawinpty',
    include_dirs = [
        'winpty/src/include'],
    sources = [
        'yawinpty.pyx' if cythonize is not None else 'yawinpty.cpp'],
    libraries = ['winpty'],
    language='c++')
if cythonize is not None:
    ext_module = cythonize(
        ext_module,
        compiler_directives = {
            'embedsignature': True,
            'language_level': 3})
else:
    ext_module = [ext_module]

setup(
    name = 'yawinpty',
    version = version(),
    description = 'yet another winpty binding for python',
    long_description = readme(),
    author = 'TitanSnow',
    author_email = 'tttnns1024@gmail.com',
    url = 'https://github.com/PSoWin/yawinpty',
    license = 'MIT',
    platforms = ['Windows'],
    classifiers = classifiers(),
    zip_safe = False,
    cmdclass = {
        'build_ext': build_winpty,
        'build_clib': build_winpty_agent},
    ext_modules = ext_module,
    libraries = [['winpty-agent', {
        'include_dirs': [
            'winpty/src/include'],
        'macros': [
            ('UNICODE', None),
            ('_UNICODE', None),
            ('NOMINMAX', None),
            ('WINPTY_AGENT_ASSERT', None)],
        'libraries': [
            'advapi32',
            'shell32',
            'user32'],
        'sources': [
            'winpty/src/agent/Agent.cc',
            'winpty/src/agent/AgentCreateDesktop.cc',
            'winpty/src/agent/ConsoleFont.cc',
            'winpty/src/agent/ConsoleInput.cc',
            'winpty/src/agent/ConsoleInputReencoding.cc',
            'winpty/src/agent/ConsoleLine.cc',
            'winpty/src/agent/DebugShowInput.cc',
            'winpty/src/agent/DefaultInputMap.cc',
            'winpty/src/agent/EventLoop.cc',
            'winpty/src/agent/InputMap.cc',
            'winpty/src/agent/LargeConsoleRead.cc',
            'winpty/src/agent/NamedPipe.cc',
            'winpty/src/agent/Scraper.cc',
            'winpty/src/agent/Terminal.cc',
            'winpty/src/agent/Win32Console.cc',
            'winpty/src/agent/Win32ConsoleBuffer.cc',
            'winpty/src/agent/main.cc',
            'winpty/src/shared/BackgroundDesktop.cc',
            'winpty/src/shared/Buffer.cc',
            'winpty/src/shared/DebugClient.cc',
            'winpty/src/shared/GenRandom.cc',
            'winpty/src/shared/OwnedHandle.cc',
            'winpty/src/shared/StringUtil.cc',
            'winpty/src/shared/WindowsSecurity.cc',
            'winpty/src/shared/WindowsVersion.cc',
            'winpty/src/shared/WinptyAssert.cc',
            'winpty/src/shared/WinptyException.cc',
            'winpty/src/shared/WinptyVersion.cc']}],
    ['winpty', {
        'include_dirs': [
            'winpty/src/include'],
        'macros': [
            ('UNICODE', None),
            ('_UNICODE', None),
            ('NOMINMAX', None),
            ('COMPILING_WINPTY_DLL', None)],
        'libraries': [
            'advapi32',
            'user32'],
        'sources': [
            'winpty/src/libwinpty/AgentLocation.cc',
            'winpty/src/libwinpty/winpty.cc',
            'winpty/src/shared/BackgroundDesktop.cc',
            'winpty/src/shared/Buffer.cc',
            'winpty/src/shared/DebugClient.cc',
            'winpty/src/shared/GenRandom.cc',
            'winpty/src/shared/OwnedHandle.cc',
            'winpty/src/shared/StringUtil.cc',
            'winpty/src/shared/WindowsSecurity.cc',
            'winpty/src/shared/WindowsVersion.cc',
            'winpty/src/shared/WinptyAssert.cc',
            'winpty/src/shared/WinptyException.cc',
            'winpty/src/shared/WinptyVersion.cc']}]])
