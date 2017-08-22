cimport c
import subprocess

__version__ = '0.4.3'

cdef ws2str(c.LPCWSTR wmsg):
    """convert LPCWSTR to str"""
    if wmsg == NULL:
        return None
    if wmsg[0] == 0:
        return ''
    cdef int sz = c.WideCharToMultiByte(c.CP_UTF8, c.WC_ERR_INVALID_CHARS, wmsg, -1, NULL, 0, NULL, NULL)
    if sz == 0:
        WinError._raise_lasterror()
    cdef char* amsg = <char*>c.malloc(sz + 1)
    if amsg == NULL:
        raise MemoryError('malloc failed')
    cdef int rc = c.WideCharToMultiByte(c.CP_UTF8, c.WC_ERR_INVALID_CHARS, wmsg, -1, amsg, sz, NULL, NULL)
    if rc == 0:
        c.free(amsg)
        WinError._raise_lasterror()
    amsg[sz] = <char>0
    msg = <bytes>amsg
    c.free(amsg)
    return msg.decode('utf8')

cdef c.LPWSTR as2ws(const char* amsg) except <c.LPWSTR>1:
    """convert char* to LPWSTR
    must free the result"""
    cdef c.LPWSTR  wmsg
    if amsg == NULL:
        return NULL
    if amsg[0] == 0:
        wmsg = <c.LPWSTR>c.malloc(sizeof(c.WCHAR))
        if wmsg == NULL:
            raise MemoryError('malloc failed')
        wmsg[0] = 0
        return wmsg
    cdef int sz = c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, amsg, -1, NULL, 0)
    if sz == 0:
        WinError._raise_lasterror()
    wmsg = <c.LPWSTR>c.malloc(sizeof(c.WCHAR) * (sz + 1))
    if wmsg == NULL:
        raise MemoryError('malloc failed')
    cdef int rc = c.MultiByteToWideChar(c.CP_UTF8, c.MB_ERR_INVALID_CHARS, amsg, -1, wmsg, sz)
    if rc == 0:
        c.free(wmsg)
        WinError._raise_lasterror()
    wmsg[sz] = 0
    return wmsg

cdef c.LPWSTR str2ws(st) except <c.LPWSTR>1:
    if isinstance(st, str):
        st = st.encode('utf8')
    if isinstance(st, bytes):
        return as2ws(st)
    elif st is None:
        return NULL
    else:
        raise TypeError('str/bytes/None excepted, {} got'.format(type(st).__name__))

cdef class _ErrorObject:
    """errobj handle class for internal use"""
    cdef c.winpty_error_ptr_t _errobj
    def __cinit__(self):
        self._errobj = NULL
    def __init__(self):
        """should not use this
        use ``create_ErrorObject`` instead"""
        raise NotImplementedError
    def __dealloc__(self):
        """free the errobj"""
        c.winpty_error_free(self._errobj)
    def get_code(self):
        """get error code from errobj"""
        if self._errobj == NULL:
            raise ValueError('NULL is not a valid errobj')
        return c.winpty_error_code(self._errobj)
    def get_msg(self):
        """get error msg from errobj"""
        if self._errobj == NULL:
            raise ValueError('NULL is not a valid errobj')
        return ws2str(c.winpty_error_msg(self._errobj))
cdef create_ErrorObject(c.winpty_error_ptr_t errobj):
    """create _ErrorObject with ``winpty_error_ptr_t errobj``"""
    cdef _ErrorObject self = _ErrorObject.__new__(_ErrorObject)
    self._errobj = errobj
    return self

class YawinptyError(RuntimeError):
    """base error class for yawinpty"""
    pass

class WinptyError(YawinptyError):
    """there are 'error codes' for winpty to specify errors

    each error class maps a error code

    ``self.code`` is the original code for internal use

    ``self.args[0]`` is the textual representation of the error
    """

    def __init__(self, code, err_msg):
        """init WinptyError with ``code`` and ``err_msg``"""
        super().__init__(err_msg)
        self.code = code
    @staticmethod
    def _from_code(code):
        """get Error type from code"""
        mp = {
            c.WINPTY_ERROR_OUT_OF_MEMORY: OutOfMemory,
            c.WINPTY_ERROR_SPAWN_CREATE_PROCESS_FAILED: SpawnCreateProcessFailed,
            c.WINPTY_ERROR_LOST_CONNECTION: LoseConnection,
            c.WINPTY_ERROR_AGENT_EXE_MISSING: AgentExeMissing,
            c.WINPTY_ERROR_UNSPECIFIED: Unspecified,
            c.WINPTY_ERROR_AGENT_DIED: AgentDied,
            c.WINPTY_ERROR_AGENT_TIMEOUT: AgentTimeout,
            c.WINPTY_ERROR_AGENT_CREATION_FAILED: AgentCreationFailed}
        return mp.get(code, UnknownUnknownError)
    @staticmethod
    def _from_errobj(errobj):
        """get Error type from errobj"""
        return WinptyError._from_code(errobj.get_code())
    @staticmethod
    def _raise_errobj(errobj):
        """raise a Error instance from errobj"""
        err_type = WinptyError._from_errobj(errobj)
        if err_type is UnknownUnknownError:
            raise UnknownError(errobj.get_code(), errobj.get_msg())
        else:
            raise err_type(errobj.get_msg())
class UnknownError(WinptyError):
    """class UnknownError for unknown error code"""
    def __init__(self, code, err_msg):
        """init UnknownError with ``code`` and ``err_msg``"""
        super().__init__(code, err_msg)
class UnknownUnknownError(UnknownError):
    """class UnknownUnknownError for unspecified error code"""
    def __init__(self, err_msg):
        """init UnknownUnknownError with ``err_msg``"""
        super().__init__(None, err_msg)
class OutOfMemory(WinptyError, MemoryError):
    """class OutOfMemory for WINPTY_ERROR_OUT_OF_MEMORY"""
    def __init__(self, err_msg):
        """init OutOfMemory with ``err_msg``"""
        super().__init__(c.WINPTY_ERROR_OUT_OF_MEMORY, err_msg)
class SpawnCreateProcessFailed(WinptyError):
    """class SpawnCreateProcessFailed for WINPTY_ERROR_SPAWN_CREATE_PROCESS_FAILED"""
    def __init__(self, err_msg):
        """init SpawnCreateProcessFailed with ``err_msg``"""
        super().__init__(c.WINPTY_ERROR_SPAWN_CREATE_PROCESS_FAILED, err_msg)
class LoseConnection(WinptyError):
    """class LoseConnection for WINPTY_ERROR_LOST_CONNECTION"""
    def __init__(self, err_msg):
        """init LoseConnection with ``err_msg``"""
        super().__init__(c.WINPTY_ERROR_LOST_CONNECTION, err_msg)
class AgentExeMissing(WinptyError):
    """class AgentExeMissing for WINPTY_ERROR_AGENT_EXE_MISSING"""
    def __init__(self, err_msg):
        """init AgentExeMissing with ``err_msg``"""
        super().__init__(c.WINPTY_ERROR_AGENT_EXE_MISSING, err_msg)
class Unspecified(WinptyError):
    """class Unspecified for WINPTY_ERROR_UNSPECIFIED"""
    def __init__(self, err_msg):
        """init Unspecified with ``err_msg``"""
        super().__init__(c.WINPTY_ERROR_UNSPECIFIED, err_msg)
class AgentDied(WinptyError):
    """class AgentDied for WINPTY_ERROR_AGENT_DIED"""
    def __init__(self, err_msg):
        """init AgentDied with ``err_msg``"""
        super().__init__(c.WINPTY_ERROR_AGENT_DIED, err_msg)
class AgentTimeout(WinptyError):
    """class AgentTimeout for WINPTY_ERROR_AGENT_TIMEOUT"""
    def __init__(self, err_msg):
        """init AgentTimeout with ``err_msg``"""
        super().__init__(c.WINPTY_ERROR_AGENT_TIMEOUT, err_msg)
class AgentCreationFailed(WinptyError):
    """class AgentCreationFailed for WINPTY_ERROR_AGENT_CREATION_FAILED"""
    def __init__(self, err_msg):
        """init AgentCreationFailed with ``err_msg``"""
        super().__init__(c.WINPTY_ERROR_AGENT_CREATION_FAILED, err_msg)
class RespawnError(YawinptyError):
    """class RespawnError
    raised if call ``spawn`` method on one ``Pty`` instance more than once"""
    def __init__(self):
        super().__init__('Cannot spawn on one ``Pty`` instance more than once')
if c.PY_VERSION_HEX >= 0x03040000:
    class WError(OSError):
        pass
else:
    class WError(Exception):
        def __init__(self, errno, strerror, filename = None, winerror = None, filename2 = None):
            super().__init__()
            self.errno = errno
            self.strerror = strerror
            self.filename = filename
            self.winerror = winerror
            self.filename2 = filename2
class WinError(WError, YawinptyError):
    """windows error"""
    def __init__(self, err_code):
        """init WinError with ``err_code`` got from ``GetLastError()``"""
        cdef c.LPWSTR buf
        cdef c.DWORD rv = c.FormatMessageW(c.FORMAT_MESSAGE_ALLOCATE_BUFFER | c.FORMAT_MESSAGE_FROM_SYSTEM | c.FORMAT_MESSAGE_IGNORE_INSERTS, NULL, err_code, 0, <c.LPWSTR>&buf, 0, NULL)
        if rv == 0:
            WinError._raise_lasterror()
        msg = ws2str(buf)
        if c.LocalFree(buf) != NULL:
            WinError._raise_lasterror()
        super().__init__(None, msg, None, err_code)
    @classmethod
    def _from_lasterror(cls):
        """return WinError by last error of windows
        for internal use"""
        return cls(c.GetLastError())
    @classmethod
    def _raise_lasterror(cls):
        """raise WinError by last error of windows
        for internal use"""
        raise cls._from_lasterror()
class SpecifiedSpawnCreateProcessFailed(WinError):
    """class SpecifiedSpawnCreateProcessFailed for WINPTY_ERROR_SPAWN_CREATE_PROCESS_FAILED
    with known OS error code from ``GetLastError()``"""
    def __init__(self, os_err_code):
        super().__init__(os_err_code)
class SubprocessError(YawinptyError):
    """class SubprocessError for error of subprocess"""
    def __init__(self, process_id, err_msg):
        super().__init__(err_msg)
        self.process_id = process_id
class TimeoutExpired(SubprocessError):
    """class TimeoutExpired for time expired in waiting"""
    def __init__(self, process_id):
        super().__init__(process_id, 'Timeout expired')
class ExitNonZero(SubprocessError):
    """class ExitNonZero for non-zero exitcode of subprocess"""
    def __init__(self, process_id, exitcode):
        super().__init__(process_id, 'Exit with non-zero')
        self.exitcode = exitcode

class _Flag:
    """class _Flag contains flags

    conerr
     Create a new screen buffer (connected to the "conerr" terminal pipe) and
     pass it to child processes as the STDERR handle.  This flag also prevents
     the agent from reopening CONOUT$ when it polls -- regardless of whether the
     active screen buffer changes, winpty continues to monitor the original
     primary screen buffer.

    plain_output
     Don't output escape sequences.

    color_escapes
     Do output color escape sequences.  These escapes are output by default, but
     are suppressed with WINPTY_FLAG_PLAIN_OUTPUT.  Use this flag to reenable
     them.

    allow_curproc_desktop_creation
     On XP and Vista, winpty needs to put the hidden console on a desktop in a
     service window station so that its polling does not interfere with other
     (visible) console windows.  To create this desktop, it must change the
     process' window station (i.e. SetProcessWindowStation) for the duration of
     the winpty_open call.  In theory, this change could interfere with the
     winpty client (e.g. other threads, spawning children), so winpty by default
     spawns a special agent process to create the hidden desktop.  Spawning
     processes on Windows is slow, though, so if
     WINPTY_FLAG_ALLOW_CURPROC_DESKTOP_CREATION is set, winpty changes this
     process' window station instead.
     See https://github.com/rprichard/winpty/issues/58.

    mask
     mask of flags"""

    conerr=             0x1
    plain_output=       0x2
    color_escapes=      0x4
    allow_curproc_desktop_creation=0x8
    mask = (0 \
        | conerr \
        | plain_output \
        | color_escapes \
        | allow_curproc_desktop_creation \
    )
class _MouseMode:
    """class _MouseMode contains mouse modes

    none
     QuickEdit mode is initially disabled, and the agent does not send mouse
     mode sequences to the terminal.  If it receives mouse input, though, it
     still writes MOUSE_EVENT_RECORD values into CONIN.

    auto
     QuickEdit mode is initially enabled.  As CONIN enters or leaves mouse
     input mode (i.e. where ENABLE_MOUSE_INPUT is on and ENABLE_QUICK_EDIT_MODE
     is off), the agent enables or disables mouse input on the terminal.

     This is the default mode.

    force
     QuickEdit mode is initially disabled, and the agent enables the terminal's
     mouse input mode.  It does not disable terminal mouse mode (until exit)."""

    none=         0
    auto=         1
    force=        2

cdef class Config:
    """class Config to handle a winpty config object"""
    cdef c.winpty_config_t* _cfg
    def __cinit__(self):
        self._cfg = NULL
    def __init__(self, *flags):
        """init Config with ``flags``
        ``flags`` is combine of ``Config.flag.*``"""
        cdef c.UINT64 rf = 0
        for flag in flags:
            rf |= <c.UINT64>flag
        cdef c.winpty_error_ptr_t err
        self._cfg = c.winpty_config_new(rf, &err)
        if err != NULL:
            WinptyError._raise_errobj(create_ErrorObject(err))
    def __dealloc__(self):
        c.winpty_config_free(self._cfg)
    def set_initial_size(self, cols, rows):
        """set initial size"""
        c.winpty_config_set_initial_size(self._cfg, cols, rows)
    def set_mouse_mode(self, mouse_mode):
        """set mouse mode to ``mouse_mode`` which is one of ``Config.mouse_mode``"""
        c.winpty_config_set_mouse_mode(self._cfg, mouse_mode)
    def set_agent_timeout(self, timeout):
        """Amount of time (in ms) to wait for the agent to startup and to wait for any given
        agent RPC request.  Must be greater than 0.  Can be INFINITE."""
        c.winpty_config_set_agent_timeout(self._cfg, timeout)
    flag = _Flag()
    mouse_mode = _MouseMode()
    def __getattribute__(self, attr):
        """stop getting 'flag' & 'mouse_mode' from an instance"""
        if attr in ('flag', 'mouse_mode'):
            raise AttributeError("'{}' object has no attribute '{}'".format(type(self).__name__, attr))
        else:
            return object.__getattribute__(self, attr)

class _SpawnFlag:
    """class _SpawnFlag contains spawn flags

    auto_shutdown
     If the spawn is marked "auto-shutdown", then the agent shuts down console
     output once the process exits.  The agent stops polling for new console
     output, and once all pending data has been written to the output pipe, the
     agent closes the pipe.  (At that point, the pipe may still have data in it,
     which the client may read.  Once all the data has been read, further reads
     return EOF.)

    exit_after_shutdown
     After the agent shuts down output, and after all output has been written
     into the pipe(s), exit the agent by closing the console.  If there any
     surviving processes still attached to the console, they are killed.

     Note: With this flag, an RPC call (e.g. winpty_set_size) issued after the
     agent exits will fail with an I/O or dead-agent error.

    mask
     mask of flags"""

    auto_shutdown=1
    exit_after_shutdown=2
    mask=(0 \
        | auto_shutdown \
        | exit_after_shutdown \
    )

cdef class SpawnConfig:
    """class SpawnConfig to handle spawn config object"""
    cdef c.winpty_spawn_config_t* _cfg
    def __cinit__(self):
        self._cfg = NULL
    def __init__(self, *spawnFlags, appname = None, cmdline = None, cwd = None, env = None):
        """init SpawnConfig
        ``spawnFlags`` is a combine of ``SpawnConfig.flag.*``
        ``env`` is like ``{'VAR1': 'VAL1', 'VAR2': 'VAL2'}``
        N.B.: If you want to gather all of the child's output, you may want the
        ``auto_shutdown`` flag."""
        if not isinstance(cmdline, str) and not isinstance(cmdline, bytes) and cmdline is not None:
            cmdline = subprocess.list2cmdline(cmdline)
        cdef c.LPWSTR wappname = NULL, wcmdline = NULL, wcwd = NULL, wenv = NULL, temp = NULL
        cdef c.size_t envsz = 0
        cdef c.size_t tmpsz = 0
        cdef c.size_t newsz = 0
        cdef c.UINT64 rf = 0
        cdef c.winpty_error_ptr_t err
        try:
            wappname = str2ws(appname)
            wcmdline = str2ws(cmdline)
            wcwd = str2ws(cwd)
            if env:
                for var, val in env.items():
                    temp = str2ws(var)
                    if temp == NULL:
                        raise ValueError('NULL is not valid')
                    tmpsz = c.wcslen(temp)
                    newsz = envsz + sizeof(c.WCHAR) * (tmpsz + 1)
                    wenv = <c.LPWSTR>c.realloc(wenv, newsz)
                    if wenv == NULL:
                        raise MemoryError('realloc failed')
                    c.memcpy((<char*>wenv) + envsz, temp, sizeof(c.WCHAR) * tmpsz)
                    (<c.LPWSTR>((<char*>wenv) + newsz - sizeof(c.WCHAR)))[0] = <c.WCHAR>b'='
                    envsz = newsz
                    c.free(temp)
                    temp = NULL
                    temp = str2ws(val)
                    if temp == NULL:
                        raise ValueError('NULL is not valid')
                    tmpsz = c.wcslen(temp)
                    newsz = envsz + sizeof(c.WCHAR) * (tmpsz + 1)
                    wenv = <c.LPWSTR>c.realloc(wenv, newsz)
                    if wenv == NULL:
                        raise MemoryError('realloc failed')
                    c.memcpy((<char*>wenv) + envsz, temp, newsz - envsz)
                    envsz = newsz
                    c.free(temp)
                    temp = NULL
                wenv = <c.LPWSTR>c.realloc(wenv, envsz + sizeof(c.WCHAR))
                if wenv == NULL:
                    raise MemoryError('realloc failed')
                (<c.LPWSTR>((<char*>wenv) + envsz))[0] = 0
            for flag in spawnFlags:
                rf |= <c.UINT64>flag
            self._cfg = c.winpty_spawn_config_new(rf, wappname, wcmdline, wcwd, wenv, &err)
            if err != NULL:
                WinptyError._raise_errobj(create_ErrorObject(err))
        finally:
            c.free(wappname)
            c.free(wcmdline)
            c.free(wcwd)
            c.free(wenv)
            c.free(temp)
    def __dealloc__(self):
        c.winpty_spawn_config_free(self._cfg)
    flag = _SpawnFlag()
    def __getattribute__(self, attr):
        """stop getting 'flag' from an instance"""
        if attr == 'flag':
            raise AttributeError("'{}' object has no attribute '{}'".format(type(self).__name__, attr))
        else:
            return object.__getattribute__(self, attr)

INFINITE = <c.DWORD>c.INFINITE

cdef class Pty:
    """class Pty to handle winpty object"""
    cdef c.winpty_t* _pty
    cdef c.BOOL _spawned
    cdef c.BOOL _closed
    cdef c.HANDLE _process
    cdef c.HANDLE _thread
    def __cinit__(self):
        self._spawned = 0
        self._closed = 0
        self._process = NULL
        self._thread = NULL
        self._pty = NULL
    def __init__(self, Config config = Config()):
        """start agent with ``config``"""
        cdef c.winpty_error_ptr_t err
        with nogil:
            self._pty = c.winpty_open(config._cfg, &err)
        if err != NULL:
            WinptyError._raise_errobj(create_ErrorObject(err))
    def __dealloc__(self):
        self.close()
    def conin_name(self):
        """get conin name"""
        return ws2str(c.winpty_conin_name(self._pty))
    def conout_name(self):
        """get conout name"""
        return ws2str(c.winpty_conout_name(self._pty))
    def conerr_name(self):
        """get conerr name"""
        return ws2str(c.winpty_conerr_name(self._pty))
    cdef c.HANDLE agent_process(self):
        """get process handle of the agent"""
        return c.winpty_agent_process(self._pty)
    def agent_process_id(self):
        """get process id of the agent"""
        return c.GetProcessId(self.agent_process())
    def set_size(self, cols, rows):
        """set the size of terminal"""
        cdef c.winpty_error_ptr_t err
        cdef c.BOOL rs = c.winpty_set_size(self._pty, cols, rows, &err)
        if err != NULL:
            WinptyError._raise_errobj(create_ErrorObject(err))
        return rs != 0
    def spawn(self, SpawnConfig spawn_config):
        """spawn process
        returns (process ID, thread ID) of spawned process

        ``spawn`` can only be called once per Pty instance.  If it is called
        before the output data pipe(s) is/are connected, then collected output is
        buffered until the pipes are connected, rather than being discarded."""
        if self._spawned != 0:
            raise RespawnError
        cdef c.HANDLE process, thread
        cdef c.DWORD ec
        cdef c.winpty_error_ptr_t err
        cdef c.BOOL rv
        with nogil:
            rv = c.winpty_spawn(self._pty, spawn_config._cfg, &process, &thread, &ec, &err)
        if err != NULL:
            errobj = create_ErrorObject(err)
            err_type = WinptyError._from_errobj(errobj)
            if err_type is SpawnCreateProcessFailed:
                raise SpecifiedSpawnCreateProcessFailed(ec)
            else:
                WinptyError._raise_errobj(errobj)
        if rv == 0:
            raise UnknownUnknownError('winpty_spawn returned false')
        self._spawned = 1
        self._process = process
        self._thread = thread
        return (c.GetProcessId(process), c.GetProcessId(thread))
    def wait_agent(self, timeout = INFINITE):
        """wait for agent process"""
        wait_process(self.agent_process(), timeout)
    def close(self):
        """close pty and kill subprocess"""
        if self._closed == 0:
            self._closed = 1
            with nogil:
                c.CloseHandle(self._process)
                c.CloseHandle(self._thread)
                c.winpty_free(self._pty)
    def wait_subprocess(self, timeout = INFINITE):
        """wait for spawned process"""
        wait_process(self._process, timeout)
    def __enter__(self):
        return self
    def __exit__(self, exception_type, exception_value, traceback):
        self.close()
    def _get_handles(self):
        """get handles by int"""
        return (<c.uintptr_t>self.agent_process(),
                <c.uintptr_t>self._process,
                <c.uintptr_t>self._thread)

cdef wait_process(c.HANDLE prs, c.DWORD timeout):
    cdef c.DWORD rv
    with nogil:
        rv = c.WaitForSingleObject(prs, timeout)
    if rv == c.WAIT_FAILED:
        WinError._raise_lasterror()
    if rv == c.WAIT_TIMEOUT:
        raise TimeoutExpired(c.GetProcessId(prs))
    check_exitcode(prs)
cdef check_exitcode(c.HANDLE prs):
    cdef c.DWORD ec
    cdef c.BOOL rv = c.GetExitCodeProcess(prs, &ec)
    if rv == 0:
        WinError._raise_lasterror()
    if ec != 0:
        raise ExitNonZero(c.GetProcessId(prs), ec)

EOL = '\n'
EOF = '\x1a' + EOL
