declare -x CONDA_DEFAULT_ENV="base"
declare -x CONDA_EXE="/data1/home/zhangyx/miniconda3/bin/conda"
declare -x CONDA_PREFIX="/data1/home/zhangyx/miniconda3"
declare -x CONDA_PROMPT_MODIFIER="(base) "
declare -x CONDA_PYTHON_EXE="/data1/home/zhangyx/miniconda3/bin/python"
declare -x CONDA_SHLVL="1"
declare -x DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1006/bus"
declare -x DEBUGINFOD_URLS="https://debuginfod.centos.org/ "
declare -x HOME="/data1/home/zhangyx"
declare -x LANG="C.UTF-8"
declare -x LESSOPEN="||/usr/bin/lesspipe.sh %s"
declare -x LOADEDMODULES=""
declare -x LOGNAME="zhangyx"
declare -x MANPATH=":"
declare -x MODULEPATH="/etc/scl/modulefiles:/usr/share/Modules/modulefiles:/etc/modulefiles:/usr/share/modulefiles"
declare -x MODULEPATH_modshare="/usr/share/Modules/modulefiles:2:/etc/modulefiles:2:/usr/share/modulefiles:2"
declare -x MODULESHOME="/usr/share/Modules"
declare -x MODULES_CMD="/usr/share/Modules/libexec/modulecmd.tcl"
declare -x MODULES_RUN_QUARANTINE="LD_LIBRARY_PATH LD_PRELOAD"
declare -x OLDPWD
declare -x PATH="/data1/home/zhangyx/tools/bin:/data1/home/zhangyx/tools/bin:/data1/home/zhangyx/bin:/data1/home/zhangyx/miniconda3/bin:/data1/home/zhangyx/.local/bin:/data1/home/zhangyx/bin:/usr/share/Modules/bin:/usr/condabin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin"
declare -x PWD="/data1/home/zhangyx"
declare -x SELINUX_LEVEL_REQUESTED=""
declare -x SELINUX_ROLE_REQUESTED=""
declare -x SELINUX_USE_CURRENT_RANGE=""
declare -x SHELL="/bin/bash"
declare -x SHLVL="1"
declare -x SSH_ASKPASS="/usr/libexec/openssh/gnome-ssh-askpass"
declare -x SSH_CLIENT="172.26.20.128 58598 22"
declare -x SSH_CONNECTION="172.26.20.128 58598 114.212.48.225 22"
declare -x USER="zhangyx"
declare -x XDG_DATA_DIRS="/data1/home/zhangyx/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
declare -x XDG_RUNTIME_DIR="/run/user/1006"
declare -x XDG_SESSION_ID="1520"
declare -x _CE_CONDA=""
declare -x _CE_M=""
declare -x _CONDA_EXE="/data1/home/zhangyx/miniconda3/bin/conda"
declare -x _CONDA_ROOT="/data1/home/zhangyx/miniconda3"
declare -x which_declare="declare -f"
declare -x CONDA_DEFAULT_ENV="base"
declare -x CONDA_EXE="/data1/home/zhangyx/miniconda3/bin/conda"
declare -x CONDA_PREFIX="/data1/home/zhangyx/miniconda3"
declare -x CONDA_PROMPT_MODIFIER="(base) "
declare -x CONDA_PYTHON_EXE="/data1/home/zhangyx/miniconda3/bin/python"
declare -x CONDA_SHLVL="1"
declare -x DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1006/bus"
declare -x DEBUGINFOD_URLS="https://debuginfod.centos.org/ "
declare -x HOME="/data1/home/zhangyx"
declare -x LANG="C.UTF-8"
declare -x LESSOPEN="||/usr/bin/lesspipe.sh %s"
declare -x LOADEDMODULES=""
declare -x LOGNAME="zhangyx"
declare -x MANPATH=":"
declare -x MODULEPATH="/etc/scl/modulefiles:/usr/share/Modules/modulefiles:/etc/modulefiles:/usr/share/modulefiles"
declare -x MODULEPATH_modshare="/usr/share/Modules/modulefiles:2:/etc/modulefiles:2:/usr/share/modulefiles:2"
declare -x MODULESHOME="/usr/share/Modules"
declare -x MODULES_CMD="/usr/share/Modules/libexec/modulecmd.tcl"
declare -x MODULES_RUN_QUARANTINE="LD_LIBRARY_PATH LD_PRELOAD"
declare -x OLDPWD
declare -x PATH="/data1/home/zhangyx/tools/bin:/data1/home/zhangyx/tools/bin:/data1/home/zhangyx/bin:/data1/home/zhangyx/miniconda3/bin:/data1/home/zhangyx/.local/bin:/data1/home/zhangyx/bin:/usr/share/Modules/bin:/usr/condabin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin"
declare -x PWD="/data1/home/zhangyx"
declare -x SELINUX_LEVEL_REQUESTED=""
declare -x SELINUX_ROLE_REQUESTED=""
declare -x SELINUX_USE_CURRENT_RANGE=""
declare -x SHELL="/bin/bash"
declare -x SHLVL="1"
declare -x SSH_ASKPASS="/usr/libexec/openssh/gnome-ssh-askpass"
declare -x SSH_CLIENT="172.26.20.128 58598 22"
declare -x SSH_CONNECTION="172.26.20.128 58598 114.212.48.225 22"
declare -x USER="zhangyx"
declare -x XDG_DATA_DIRS="/data1/home/zhangyx/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
declare -x XDG_RUNTIME_DIR="/run/user/1006"
declare -x XDG_SESSION_ID="1520"
declare -x _CE_CONDA=""
declare -x _CE_M=""
declare -x _CONDA_EXE="/data1/home/zhangyx/miniconda3/bin/conda"
declare -x _CONDA_ROOT="/data1/home/zhangyx/miniconda3"
declare -x which_declare="declare -f"
import http.server, http.client, ssl
CTX = ssl.SSLContext()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

class H(http.server.BaseHTTPRequestHandler):
    def do_POST(s): s.fw('POST')
    def do_GET(s): s.fw('GET')
    def fw(s, m):
        try:
            cl = int(s.headers.get('Content-Length', 0))
            bd = s.rfile.read(cl) if cl else None
            conn = http.client.HTTPSConnection('localhost', 9443, context=CTX, timeout=120)
            conn.putrequest(m, s.path)
            conn.putheader('Host', 'api.deepseek.com')
            for k, v in s.headers.items():
                if k.lower() not in ('host', 'content-length', 'connection'):
                    conn.putheader(k, v)
            if bd: conn.putheader('Content-Length', str(len(bd)))
            conn.endheaders()
            if bd: conn.send(bd)
            resp = conn.getresponse()
            body = resp.read()
            s.send_response(resp.status)
            for k, v in resp.getheaders():
                if k.lower() not in ('transfer-encoding', 'connection'):
                    s.send_header(k, v)
            s.end_headers()
            s.wfile.write(body)
            conn.close()
        except Exception as e:
            try: s.send_error(502, str(e))
            except: pass
    def log_message(s, *a): pass

http.server.HTTPServer(('127.0.0.1', 9444), H).serve_forever()
