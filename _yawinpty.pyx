cimport winpty
from sys import version_info

__version__ = '0.4.3.dev4'

cdef ws2str(winpty.LPCWSTR wmsg):
    """convert LPCWSTR to str"""
    if wmsg == NULL:
        return None
    if wmsg[0] == 0:
        return ''
    cdef int sz = winpty.WideCharToMultiByte(winpty.CP_UTF8, winpty.WC_ERR_INVALID_CHARS, wmsg, -1, NULL, 0, NULL, NULL)
    if sz == 0:
        WinError._raise_lasterror()
    cdef char* amsg = <char*>winpty.malloc(sz + 1)
    if amsg == NULL:
        raise MemoryError('malloc failed')
    cdef int rc = winpty.WideCharToMultiByte(winpty.CP_UTF8, winpty.WC_ERR_INVALID_CHARS, wmsg, -1, amsg, sz, NULL, NULL)
    if rc == 0:
        winpty.free(amsg)
        WinError._raise_lasterror()
    amsg[sz] = <char>0
    msg = <bytes>amsg
    winpty.free(amsg)
    return msg.decode('utf8')

cdef winpty.LPWSTR as2ws(const char* amsg) except <winpty.LPWSTR>1:
    """convert char* to LPWSTR
    must free the result"""
    cdef winpty.LPWSTR  wmsg
    if amsg == NULL:
        return NULL
    if amsg[0] == 0:
        wmsg = <winpty.LPWSTR>winpty.malloc(sizeof(winpty.WCHAR))
        if wmsg == NULL:
            raise MemoryError('malloc failed')
        wmsg[0] = 0
        return wmsg
    cdef int sz = winpty.MultiByteToWideChar(winpty.CP_UTF8, winpty.MB_ERR_INVALID_CHARS, amsg, -1, NULL, 0)
    if sz == 0:
        WinError._raise_lasterror()
    wmsg = <winpty.LPWSTR>winpty.malloc(sizeof(winpty.WCHAR) * (sz + 1))
    if wmsg == NULL:
        raise MemoryError('malloc failed')
    cdef int rc = winpty.MultiByteToWideChar(winpty.CP_UTF8, winpty.MB_ERR_INVALID_CHARS, amsg, -1, wmsg, sz)
    if rc == 0:
        winpty.free(wmsg)
        WinError._raise_lasterror()
    wmsg[sz] = 0
    return wmsg

cdef winpty.LPWSTR str2ws(st) except <winpty.LPWSTR>1:
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
    cdef winpty.winpty_error_ptr_t _errobj
    def __cinit__(self):
        """should not use this
        use `create_ErrorObject` instead"""
        self._errobj = NULL
    def __dealloc__(self):
        """free the errobj"""
        winpty.winpty_error_free(self._errobj)
    def get_code(self):
        """get error code from errobj"""
        if self._errobj == NULL:
            raise ValueError('NULL is not a valid errobj')
        return winpty.winpty_error_code(self._errobj)
    def get_msg(self):
        """get error msg from errobj"""
        if self._errobj == NULL:
            raise ValueError('NULL is not a valid errobj')
        return ws2str(winpty.winpty_error_msg(self._errobj))
cdef create_ErrorObject(winpty.winpty_error_ptr_t errobj):
    """create _ErrorObject with `winpty_error_ptr_t errobj`"""
    self = _ErrorObject()
    self._errobj = errobj
    return self

class WinptyError(RuntimeError):
    """base error class for winpty

    there are 'error codes' for winpty to specify errors

    each error class maps a error code

    `self.code` is the original code for internal use

    `self.args[0]` is the textual representation of the error
    """

    def __init__(self, code, err_msg):
        """init WinptyError with `code` and `err_msg`"""
        RuntimeError.__init__(self, err_msg)
        self.code = code
    @staticmethod
    def _from_code(code):
        """get Error type from code"""
        mp = {
            winpty.WINPTY_ERROR_OUT_OF_MEMORY: OutOfMemory,
            winpty.WINPTY_ERROR_SPAWN_CREATE_PROCESS_FAILED: SpawnCreateProcessFailed,
            winpty.WINPTY_ERROR_LOST_CONNECTION: LoseConnection,
            winpty.WINPTY_ERROR_AGENT_EXE_MISSING: AgentExeMissing,
            winpty.WINPTY_ERROR_UNSPECIFIED: Unspecified,
            winpty.WINPTY_ERROR_AGENT_DIED: AgentDied,
            winpty.WINPTY_ERROR_AGENT_TIMEOUT: AgentTimeout,
            winpty.WINPTY_ERROR_AGENT_CREATION_FAILED: AgentCreationFailed}
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
        """init UnknownError with `code` and `err_msg`"""
        WinptyError.__init__(self, code, err_msg)
class UnknownUnknownError(UnknownError):
    """class UnknownUnknownError for unspecified error code"""
    def __init__(self, err_msg):
        """init UnknownUnknownError with `err_msg`"""
        UnknownError.__init__(self, None, err_msg)
class OutOfMemory(WinptyError, MemoryError):
    """class OutOfMemory for WINPTY_ERROR_OUT_OF_MEMORY"""
    def __init__(self, err_msg):
        """init OutOfMemory with `err_msg`"""
        WinptyError.__init__(self, winpty.WINPTY_ERROR_OUT_OF_MEMORY, err_msg)
class SpawnCreateProcessFailed(WinptyError):
    """class SpawnCreateProcessFailed for WINPTY_ERROR_SPAWN_CREATE_PROCESS_FAILED"""
    def __init__(self, err_msg):
        """init SpawnCreateProcessFailed with `err_msg`"""
        WinptyError.__init__(self, winpty.WINPTY_ERROR_SPAWN_CREATE_PROCESS_FAILED, err_msg)
class LoseConnection(WinptyError):
    """class LoseConnection for WINPTY_ERROR_LOST_CONNECTION"""
    def __init__(self, err_msg):
        """init LoseConnection with `err_msg`"""
        WinptyError.__init__(self, winpty.WINPTY_ERROR_LOST_CONNECTION, err_msg)
class AgentExeMissing(WinptyError):
    """class AgentExeMissing for WINPTY_ERROR_AGENT_EXE_MISSING"""
    def __init__(self, err_msg):
        """init AgentExeMissing with `err_msg`"""
        WinptyError.__init__(self, winpty.WINPTY_ERROR_AGENT_EXE_MISSING, err_msg)
class Unspecified(WinptyError):
    """class Unspecified for WINPTY_ERROR_UNSPECIFIED"""
    def __init__(self, err_msg):
        """init Unspecified with `err_msg`"""
        WinptyError.__init__(self, winpty.WINPTY_ERROR_UNSPECIFIED, err_msg)
class AgentDied(WinptyError):
    """class AgentDied for WINPTY_ERROR_AGENT_DIED"""
    def __init__(self, err_msg):
        """init AgentDied with `err_msg`"""
        WinptyError.__init__(self, winpty.WINPTY_ERROR_AGENT_DIED, err_msg)
class AgentTimeout(WinptyError):
    """class AgentTimeout for WINPTY_ERROR_AGENT_TIMEOUT"""
    def __init__(self, err_msg):
        """init AgentTimeout with `err_msg`"""
        WinptyError.__init__(self, winpty.WINPTY_ERROR_AGENT_TIMEOUT, err_msg)
class AgentCreationFailed(WinptyError):
    """class AgentCreationFailed for WINPTY_ERROR_AGENT_CREATION_FAILED"""
    def __init__(self, err_msg):
        """init AgentCreationFailed with `err_msg`"""
        WinptyError.__init__(self, winpty.WINPTY_ERROR_AGENT_CREATION_FAILED, err_msg)
class RespawnError(WinptyError):
    """class RespawnError
    raised if call `spawn` method on one `Pty` instance more than once"""
    def __init__(self):
        WinptyError.__init__(self, None, 'Cannot spawn on one `Pty` instance more than once')
if version_info >= (3, 4):
    class WError(OSError):
        pass
else:
    class WError(Exception):
        def __init__(self, errno, strerror, filename = None, winerror = None, filename2 = None):
            Exception.__init__(self)
            self.errno = errno
            self.strerror = strerror
            self.filename = filename
            self.winerror = winerror
            self.filename2 = filename2
class WinError(WError, WinptyError):
    """windows error"""
    def __init__(self, err_code):
        """init WinError with `err_code` got from `GetLastError()`"""
        cdef winpty.LPWSTR buf
        cdef winpty.DWORD rv = winpty.FormatMessageW(winpty.FORMAT_MESSAGE_ALLOCATE_BUFFER | winpty.FORMAT_MESSAGE_FROM_SYSTEM | winpty.FORMAT_MESSAGE_IGNORE_INSERTS, NULL, err_code, 0, <winpty.LPWSTR>&buf, 0, NULL)
        if rv == 0:
            WinError._raise_lasterror()
        msg = ws2str(buf)
        if winpty.LocalFree(buf) != NULL:
            WinError._raise_lasterror()
        WError.__init__(self, None, msg, None, err_code)
        WinptyError.__init__(self, None, msg)
    @classmethod
    def _from_lasterror(cls):
        """return WinError by last error of windows
        for internal use"""
        return cls(winpty.GetLastError())
    @classmethod
    def _raise_lasterror(cls):
        """raise WinError by last error of windows
        for internal use"""
        raise cls._from_lasterror()
class SpecifiedSpawnCreateProcessFailed(SpawnCreateProcessFailed, WinError):
    """class SpecifiedSpawnCreateProcessFailed for WINPTY_ERROR_SPAWN_CREATE_PROCESS_FAILED
    with known OS error code from `GetLastError()`"""
    def __init__(self, os_err_code, err_msg):
        SpawnCreateProcessFailed.__init__(self, err_msg)
        WinError.__init__(self, os_err_code)
class SubprocessError(WinptyError):
    """class SubprocessError for error of subprocess"""
    def __init__(self, process_id, err_msg):
        WinptyError.__init__(self, None, err_msg)
        self.process_id = process_id
class TimeoutExpired(SubprocessError):
    """class TimeoutExpired for time expired in waiting"""
    def __init__(self, process_id):
        SubprocessError.__init__(self, process_id, 'Timeout expired')
class ExitNonZero(SubprocessError):
    """class ExitNonZero for non-zero exitcode of subprocess"""
    def __init__(self, process_id, exitcode):
        SubprocessError.__init__(self, process_id, 'Exit with non-zero')
        self.exitcode = exitcode

class _Flag:
    """class _Flag contains flags

    conerr
    ======
     Create a new screen buffer (connected to the "conerr" terminal pipe) and
     pass it to child processes as the STDERR handle.  This flag also prevents
     the agent from reopening CONOUT$ when it polls -- regardless of whether the
     active screen buffer changes, winpty continues to monitor the original
     primary screen buffer.

    plain_output
    ============
     Don't output escape sequences.

    color_escapes
    =============
     Do output color escape sequences.  These escapes are output by default, but
     are suppressed with WINPTY_FLAG_PLAIN_OUTPUT.  Use this flag to reenable
     them.

    allow_curproc_desktop_creation
    ==============================
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
    ====
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
    ====
     QuickEdit mode is initially disabled, and the agent does not send mouse
     mode sequences to the terminal.  If it receives mouse input, though, it
     still writes MOUSE_EVENT_RECORD values into CONIN.

    auto
    ====
     QuickEdit mode is initially enabled.  As CONIN enters or leaves mouse
     input mode (i.e. where ENABLE_MOUSE_INPUT is on and ENABLE_QUICK_EDIT_MODE
     is off), the agent enables or disables mouse input on the terminal.

     This is the default mode.

    force
    =====
     QuickEdit mode is initially disabled, and the agent enables the terminal's
     mouse input mode.  It does not disable terminal mouse mode (until exit)."""

    none=         0
    auto=         1
    force=        2

cdef class Config:
    """class Config to handle a winpty config object"""
    cdef winpty.winpty_config_t* _cfg
    def __cinit__(self):
        self._cfg = NULL
    def __init__(self, *flags):
        """init Config with `flags`
        `flags` is combine of `Config.flag.*`"""
        cdef winpty.UINT64 rf = 0
        for flag in flags:
            rf |= <winpty.UINT64>flag
        cdef winpty.winpty_error_ptr_t err
        self._cfg = winpty.winpty_config_new(rf, &err)
        if err != NULL:
            WinptyError._raise_errobj(create_ErrorObject(err))
    def __dealloc__(self):
        winpty.winpty_config_free(self._cfg)
    def set_initial_size(self, cols, rows):
        """set initial size"""
        winpty.winpty_config_set_initial_size(self._cfg, cols, rows)
    def set_mouse_mode(self, mouse_mode):
        """set mouse mode to `mouse_mode` which is one of `Config.mouse_mode`"""
        winpty.winpty_config_set_mouse_mode(self._cfg, mouse_mode)
    def set_agent_timeout(self, timeout):
        """Amount of time (in ms) to wait for the agent to startup and to wait for any given
        agent RPC request.  Must be greater than 0.  Can be INFINITE."""
        winpty.winpty_config_set_agent_timeout(self._cfg, timeout)
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
    =============
     If the spawn is marked "auto-shutdown", then the agent shuts down console
     output once the process exits.  The agent stops polling for new console
     output, and once all pending data has been written to the output pipe, the
     agent closes the pipe.  (At that point, the pipe may still have data in it,
     which the client may read.  Once all the data has been read, further reads
     return EOF.)

    exit_after_shutdown
    ===================
     After the agent shuts down output, and after all output has been written
     into the pipe(s), exit the agent by closing the console.  If there any
     surviving processes still attached to the console, they are killed.

     Note: With this flag, an RPC call (e.g. winpty_set_size) issued after the
     agent exits will fail with an I/O or dead-agent error.

    mask
    ====
    mask of flags"""

    auto_shutdown=1
    exit_after_shutdown=2
    mask=(0 \
        | auto_shutdown \
        | exit_after_shutdown \
    )

cdef class SpawnConfig:
    """class SpawnConfig to handle spawn config object"""
    cdef winpty.winpty_spawn_config_t* _cfg
    def __cinit__(self):
        self._cfg = NULL
    def __init__(self, *spawnFlags, appname = None, cmdline = None, cwd = None, env = None):
        """init SpawnConfig
        `spawnFlags` is a combine of `SpawnConfig.flag.*`
        `env` is like `{'VAR1': 'VAL1', 'VAR2': 'VAL2'}`
        N.B.: If you want to gather all of the child's output, you may want the
        `auto_shutdown` flag."""
        cdef winpty.LPWSTR wappname = NULL, wcmdline = NULL, wcwd = NULL, wenv = NULL, temp = NULL
        cdef winpty.size_t envsz = 0
        cdef winpty.size_t tmpsz = 0
        cdef winpty.size_t newsz = 0
        cdef winpty.UINT64 rf = 0
        cdef winpty.winpty_error_ptr_t err
        try:
            wappname = str2ws(appname)
            wcmdline = str2ws(cmdline)
            wcwd = str2ws(cwd)
            if env:
                for var, val in env.items():
                    temp = str2ws(var)
                    if temp == NULL:
                        raise ValueError('NULL is not valid')
                    tmpsz = winpty.wcslen(temp)
                    newsz = envsz + sizeof(winpty.WCHAR) * (tmpsz + 1)
                    wenv = <winpty.LPWSTR>winpty.realloc(wenv, newsz)
                    if wenv == NULL:
                        raise MemoryError('realloc failed')
                    winpty.memcpy((<char*>wenv) + envsz, temp, sizeof(winpty.WCHAR) * tmpsz)
                    (<winpty.LPWSTR>((<char*>wenv) + newsz - sizeof(winpty.WCHAR)))[0] = <winpty.WCHAR>b'='
                    envsz = newsz
                    winpty.free(temp)
                    temp = NULL
                    temp = str2ws(val)
                    if temp == NULL:
                        raise ValueError('NULL is not valid')
                    tmpsz = winpty.wcslen(temp)
                    newsz = envsz + sizeof(winpty.WCHAR) * (tmpsz + 1)
                    wenv = <winpty.LPWSTR>winpty.realloc(wenv, newsz)
                    if wenv == NULL:
                        raise MemoryError('realloc failed')
                    winpty.memcpy((<char*>wenv) + envsz, temp, newsz - envsz)
                    envsz = newsz
                    winpty.free(temp)
                    temp = NULL
                wenv = <winpty.LPWSTR>winpty.realloc(wenv, envsz + sizeof(winpty.WCHAR))
                if wenv == NULL:
                    raise MemoryError('realloc failed')
                (<winpty.LPWSTR>((<char*>wenv) + envsz))[0] = 0
            for flag in spawnFlags:
                rf |= <winpty.UINT64>flag
            self._cfg = winpty.winpty_spawn_config_new(rf, wappname, wcmdline, wcwd, wenv, &err)
            if err != NULL:
                WinptyError._raise_errobj(create_ErrorObject(err))
        finally:
            winpty.free(wappname)
            winpty.free(wcmdline)
            winpty.free(wcwd)
            winpty.free(wenv)
            winpty.free(temp)
    def __dealloc__(self):
        winpty.winpty_spawn_config_free(self._cfg)
    flag = _SpawnFlag()
    def __getattribute__(self, attr):
        """stop getting 'flag' from an instance"""
        if attr == 'flag':
            raise AttributeError("'{}' object has no attribute '{}'".format(type(self).__name__, attr))
        else:
            return object.__getattribute__(self, attr)

INFINITE = <winpty.DWORD>winpty.INFINITE

cdef class Pty:
    """class Pty to handle winpty object"""
    cdef winpty.winpty_t* _pty
    cdef winpty.BOOL _spawned
    cdef winpty.BOOL _closed
    cdef winpty.HANDLE _process
    cdef winpty.HANDLE _thread
    def __cinit__(self):
        self._spawned = 0
        self._closed = 0
        self._process = NULL
        self._thread = NULL
        self._pty = NULL
    def __init__(self, Config config = Config()):
        """start agent with `config`"""
        cdef winpty.winpty_error_ptr_t err
        with nogil:
            self._pty = winpty.winpty_open(config._cfg, &err)
        if err != NULL:
            WinptyError._raise_errobj(create_ErrorObject(err))
    def __dealloc__(self):
        self.close()
    def conin_name(self):
        """get conin name"""
        return ws2str(winpty.winpty_conin_name(self._pty))
    def conout_name(self):
        """get conout name"""
        return ws2str(winpty.winpty_conout_name(self._pty))
    def conerr_name(self):
        """get conerr name"""
        return ws2str(winpty.winpty_conerr_name(self._pty))
    cdef winpty.HANDLE agent_process(self):
        """get process handle of the agent"""
        return winpty.winpty_agent_process(self._pty)
    def agent_process_id(self):
        """get process id of the agent"""
        return winpty.GetProcessId(self.agent_process())
    def set_size(self, cols, rows):
        """set the size of terminal"""
        cdef winpty.winpty_error_ptr_t err
        cdef winpty.BOOL rs = winpty.winpty_set_size(self._pty, cols, rows, &err)
        if err != NULL:
            WinptyError._raise_errobj(create_ErrorObject(err))
        return rs != 0
    def spawn(self, SpawnConfig spawn_config):
        """spawn process
        returns (process ID, thread ID) of spawned process

        `spawn` can only be called once per Pty instance.  If it is called
        before the output data pipe(s) is/are connected, then collected output is
        buffered until the pipes are connected, rather than being discarded."""
        if self._spawned != 0:
            raise RespawnError
        cdef winpty.HANDLE process, thread
        cdef winpty.DWORD ec
        cdef winpty.winpty_error_ptr_t err
        cdef winpty.BOOL rv
        with nogil:
            rv = winpty.winpty_spawn(self._pty, spawn_config._cfg, &process, &thread, &ec, &err)
        if err != NULL:
            errobj = create_ErrorObject(err)
            err_type = WinptyError._from_errobj(errobj)
            if err_type is SpawnCreateProcessFailed:
                raise SpecifiedSpawnCreateProcessFailed(ec, errobj.get_msg())
            else:
                WinptyError._raise_errobj(errobj)
        if rv == 0:
            raise UnknownUnknownError('winpty_spawn returned false')
        self._spawned = 1
        self._process = process
        self._thread = thread
        return (winpty.GetProcessId(process), winpty.GetProcessId(thread))
    def wait_agent(self, timeout = INFINITE):
        """wait for agent process"""
        wait_process(self.agent_process(), timeout)
    def close(self):
        """close pty and kill subprocess"""
        if self._closed == 0:
            self._closed = 1
            with nogil:
                winpty.CloseHandle(self._process)
                winpty.CloseHandle(self._thread)
                winpty.winpty_free(self._pty)
    def wait_subprocess(self, timeout = INFINITE):
        """wait for spawned process"""
        wait_process(self._process, timeout)
    def __enter__(self):
        return self
    def __exit__(self, exception_type, exception_value, traceback):
        self.close()
    def _get_handles(self):
        """get handles by int"""
        return (<winpty.uintptr_t>self.agent_process(),
                <winpty.uintptr_t>self._process,
                <winpty.uintptr_t>self._thread)

cdef wait_process(winpty.HANDLE prs, winpty.DWORD timeout):
    cdef winpty.DWORD rv
    with nogil:
        rv = winpty.WaitForSingleObject(prs, timeout)
    if rv == winpty.WAIT_FAILED:
        WinError._raise_lasterror()
    if rv == winpty.WAIT_TIMEOUT:
        raise TimeoutExpired(winpty.GetProcessId(prs))
    check_exitcode(prs)
cdef check_exitcode(winpty.HANDLE prs):
    cdef winpty.DWORD ec
    cdef winpty.BOOL rv = winpty.GetExitCodeProcess(prs, &ec)
    if rv == 0:
        WinError._raise_lasterror()
    if ec != 0:
        raise ExitNonZero(winpty.GetProcessId(prs), ec)
