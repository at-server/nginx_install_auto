#!/bin/bash -
# auto_nginx_install-bin-1.0.1.sh
# Auto install nginx server
# Auto configuration nginx
# Author: ry
# Version: 1.0.1
# 


###
. /etc/init.d/functions


### Vars
temp_dir=/tmp/__nginx_install_`date +'%y%m%d%H%M%S'`__$$__
PWD=$(cd $(dirname $BASH_SOURCE); pwd -P)

### Logging
#   - logging debug 'debug'
function logging() {
    local RETVAL=$?
    local level
    local _date

    if [ $# -lt 2 ]; then
        if [ $RETVAL -ne 0 ]; then
            return $RETVAL
        else
            logging debug "$*"
        fi
    else
        level="$1"
        shift
    fi

    _date="$(date '+%Y-%m-%d %H:%M:%S') [$level]"

    case x"$level" in
        x'debug')
            # if [ x"$DEBUG" = x'y' ]; then
            #     echo -n -e "$_date $*"
            # fi ;;
            echo -n -e "$_date $*" ;;
        x'warning'|x'warn')
            echo -n -e "\033[33m$_date $*\033[0m" ;;
        x'error')
            echo -n -e "\033[31m$_date $*\033[0m" ;;
    esac

    return $RETVAL
}

### Get args
while getopts \
    ':u:c:n:h:s:t:i:l:p:D:j' opt; do
    # u, daemon user
    # c, core for CPU
    # n, normal install, default set
    # h, http agency server hostname:port
    # s, https agency server hostname:port
    # t, https cert file, crt=site.crt,key=site.key
    # i, real node name={/ip:port/ip:port},name={...}.
    # l, document root, default 'html'
    # p, enable upstream http=upsteam_name,https=upstream_name
    # D, extra args
    # j, multiple process run this job

    __set__=__set__

    case x"$opt" in
        x'u')
            daemon_user="$OPTARG" ;;
        x'c')
            cpu_core="$OPTARG" ;;
        x'n')
            normal_install=y ;;
        x'h')
            http_port="$OPTARG" ;;
        x's')
            https_port="$OPTARG" ;;
        x't')
            cert_file="$OPTARG" ;;
        x'i')
            _node="$OPTARG" ;;
        x'l')
            document_root="$OPTARG" ;;
        x'p')
            _upstream="$OPTARG" ;;
        x'D')
            extra_data="${extra_data} $OPTARG" ;;
        x'j')
            multi_job='y' ;;
        *)
            echo -e \
                 "Usage: $BASH_SOURCE [OPT] [VALUE] v1.0.1\\n" \
                 '           -u, STRING, nginx daemon user.\n' \
                 '           -c, NUMBER, cpu cores.\n' \
                 '           -n, Normal install, default.\n' \
                 '           -h, STRING, http hostname:port(set http).\n' \
                 '           -s, STRING, https hostname:port(set https).\n' \
                 '           -t, STRING, https cert file, crt=site.crt,key=site.key.\n' \
                 '           -i, STRING, real node name={/ip:port/ip:port},name={...}.\n' \
                 '           -l, STRING, document root, default 'html'.\n' \
                 '           -p, STRING, enable upstring mode, http=upsteam_name,https=upstream_name.\n' \
                 '           -D, STRING, extra args, using nginx configure.\n' \
                 '           -j, Enable multiple process make.'

            exit 1 ;;
    esac
done

### Analyze options
test -z "$daemon_user" && daemon_user=nobody
test -z "$cpu_core" && cpu_core=$(cat /proc/cpuinfo | grep 'processor' | wc -l)
test -z "$http_port" -a -z "$https_port" && http_port='localhost:80'
# Upstream
if [ -n "$_upstream" ]; then
    # Real node
    if ! NODE=$(echo "$_node" | egrep -o \
         '\w+=\{(/[[:digit:]]{1,4}\.[[:digit:]]{1,4}\.[[:digit:]]{1,4}\.[[:digit:]]{1,4}:[[:digit:]]+){1,}}'); then
        logging error 'Usage: -i, STRING, real node name={/ip:port/ip:port},name={...}.\n'
        logging error 'Real node parameter format error.\n'
        exit 1
    fi
    HTTP=$(echo "$_upstream" | egrep -o 'http=[^,]+' | cut -d= -f2)
    HTTPS=$(echo "$_upstream" | egrep -o 'https=[^,]+' | cut -d= -f2)
    if [ -z "$HTTP" -a -z "$HTTPS" ]; then
        logging error '-p, STRING, enable upstring mode, http=upsteam_name,https=upstream_name.\n'
        logging error 'Upstream parameter format error.\n'
        exit 1
    fi
    if [ -n "$HTTP" ]; then
        if ! echo "$_node" | egrep "${HTTP}=" &> /dev/null; then
            logging error "Upstream $HTTP undefined for http.\n"
            exit 1
        fi
    fi
    if [ -n "$HTTPS" ]; then
        if ! echo "$_node" | egrep "${HTTPS}=" &> /dev/null; then
            logging error "Upstream $HTTPS undefined for https.\n"
            exit 1
        fi
        # set https port
        https_port=${https_port:=localhost:443}
    fi
    if [ -n "$http_port" -a -z "$HTTP" ] || [ -n "$https_port" -a -z "$HTTPS" ]; then
        logging error 'Http(s) port was opened, And upstream closing.\n'
        logging error '-p, STRING, enable upstring mode, http=upsteam_name,https=upstream_name.\n'
        exit 1
    fi
fi

if [ -n "$https_port" ]; then
    if [ -n "$cert_file" ]; then
        HTTPS_CRT=$(echo "$cert_file" | egrep -o 'crt=[^,]+') || \
            { logging error "CRT file not found, $cert_file.\n"; exit 1; }
        HTTPS_KEY=$(echo "$cert_file" | egrep -o 'key=[^,]+') || \
            { logging error "KEY file not found, $cert_file.\n"; exit 1; }
        HTTPS_CRT=`echo $HTTPS_CRT | cut -d= -f2`
        HTTPS_KEY=`echo $HTTPS_KEY | cut -d= -f2`
        if [ ! -f "$HTTPS_CRT" -o ! -f "$HTTPS_KEY" ]; then
            logging error 'Cert file must be a file that exists for https.\n'
            exit 1
        fi
    else
        logging error "Https cert undefined for https.\n"
        exit 1
    fi
fi

if ! echo "$extra_data" | grep '\-\-prefix' &> /dev/null; then
    extra_data="$extra_data --prefix=/opt/nginx"
fi

if ! echo "$extra_data" | grep '\-\-with\-pcre' &> /dev/null; then
    extra_data="${extra_data} --with-pcre=$temp_dir/__TAR__/pcre-8.42"
fi

extra_data="${extra_data} --with-http_ssl_module --with-http_realip_module"

INSTALL_PATH=$(echo "$extra_data" | egrep -o '\-\-prefix=[^[:blank:]]+' | cut -d= -f2)
test -z "$INSTALL_PATH" && \
    { logging error "Get nginx install path error.\n"; exit 1; }

test x"$__set__" != x'__set__' -o -z "$_upstream" && normal_install=y

### Wait
function terminal_wait() {
    ### Wait
    declare -i time
    time=$1; shift

    if [ $time -eq 0 -o $time -ge 100 -o -z "$*" ]; then
        return 1
    fi

    while [ $time -ge 0 ]; do
        printf "\r$*, %02d seconds later." "$time"
        sleep 1
        let time--
    done
    echo;
}

### Echo install info
cat <<EOF | egrep -v '^\s*$'
* Nginx install configure:
    - Daemon user: $daemon_user
    - Running cpu core: $cpu_core
    - Nginx install path: $INSTALL_PATH
    - Upstream: ${HTTP:+http=$HTTP}${HTTPS:+, https=$HTTPS}
    - Real node: $(echo "$NODE" | awk '{ if (NR==1) { print($0) } else { print("                 "$0) } }')
    $(test -n "$https_port" && { echo -n '- CERT file: '; echo "CRT=$HTTPS_CRT, KEY=$HTTPS_KEY"; })
    ${http_port:+- Server Name(HTTP): $http_port}
    ${https_port:+- Server Name(HTTPS): $https_port}
    - Extra data: $extra_data
EOF

terminal_wait 10 'Confirm the input and continue'

### Clean all temp directory
function clean_temp_dir() {
    logging warn "Clean temp data, now.\n"
    logging warn "rm -rf $temp_dir\n"
    [ -n "$temp_dir" ] && \rm -rf $temp_dir
}

trap clean_temp_dir 2 3 9 15

# Add user
if ! id $daemon_user &> /dev/null; then
    logging warn "$daemon_user not exists.\n"
    useradd -M -s /sbin/nologin $daemon_user && \
        logging debug "$daemon_user user created.\n" || \
        { logging error "$daemon_user user create failed.\n"; exit 1; }
else
    logging debug "$daemon_user exists.\n"
fi

### Debug mode
# test x"$DEBUG" = x'y' && logging debug 'Enable debug mode.\n'
# logging debug 'Enable debug mode.\n'

### Installing
logging debug 'Start install nginx.\n'
# Mkdir temporary directory
if [ -d "$temp_dir" ]; then
    logging error "Temp directory: ${temp_dir} already exists.\n"
    exit 1
else
    logging debug "Mkdir '$temp_dir'"
    mkdir ${temp_dir} &> /dev/null && \
        { success; echo; } || \
        { failure; echo; exit 1; }
fi
# Get packages
logging debug 'Get all packages'
archive_line_start=`awk '/^__ARCHIVE_BELOW__$/ { print NR + 1; exit 0; }' $BASH_SOURCE`
tail -n+$archive_line_start $BASH_SOURCE > $temp_dir/__TAR__.tar.gz && \
    { success; echo; } || \
    { failure; echo; clean_temp_dir; exit 1; }

# Change dir to src
logging debug "Change to temp dir $temp_dir.\n"
cd $temp_dir

# Tar pack
logging debug "Unpack all gz pack.\n"
tar zxf ./__TAR__.tar.gz && \
    cd __TAR__ || \
    { logging error "Get all pack failure $temp_dir.\n"; exit 1; }

# Get pcre
logging debug 'Get pcre package'
tar zxf pcre-8.42.tar.gz && { success; echo; } || \
    { failure; echo; logging error "Get pcre pack failure $temp_dir.\n"; exit 1; }

# Get nginx
logging debug 'Get nginx package.\n'
tar zxf nginx-1.12.2.tar.gz && \
    cd nginx-1.12.2 || \
    { logging error "Get nginx pack failure $temp_dir.\n"; exit 1; }

# Start configure
logging debug 'Configure nginx'
./configure $extra_data > /dev/null && \
    { success; echo; } || \
    { failure; echo; logging error "Configure nginx failure $temp_dir.\n"; exit 1; }

# Start make
logging debug 'Make nginx '
if [ x"$multi_job" = x'y' ]; then
    echo -n '(Enabled Multiple process make)'
    make -j $cpu_core > /dev/null
else
    make > /dev/null
fi

test $? -eq 0 && \
    { success; echo; } || \
    { failure; echo; logging error "Make nginx failure $temp_dir.\n"; exit 1; }

# Start make install
logging debug 'Make install nginx'
make install > /dev/null && \
    { success; echo; } || \
    { failure; echo; logging error "Make install nginx failure $temp_dir.\n"; exit 1; }

# Install finished
logging debug 'Nginx installed.\n'

cd $INSTALL_PATH

### Set nginx config
if [ -n "$https_port" ]; then
    logging debug "Copy cert file to $INSTALL_PATH"
    \cp $HTTPS_CRT ./conf/
    \cp $HTTPS_KEY ./conf/
    success; echo
fi

# Make log dir
[ ! -d "/log/nginx" ] && \
    { logging warn "/log/nginx not exists.\n"; mkdir -p /log/nginx;
      logging debug "mkdir -p /log/nginx"; success; echo; }

chown $daemon_user.$daemon_user /log/nginx

logging debug 'Set nginx config.\n'
cat <<EOF > ./conf/nginx.conf
user  $daemon_user;
worker_processes  $cpu_core;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;
worker_rlimit_nofile 65535;


events {
    use epoll;
    worker_connections  65535;
}


EOF

# Normal install
if [ x"$normal_install" = x'y' ]; then
    cat <<EOF >> ./conf/nginx.conf
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    $(if [ -n "$http_port" ]; then
        printf "
    server {
        listen       %s;
        server_name  %s;
        access_log  /log/nginx/%s;
        error_log  /log/nginx/%s;

        location / {
            root   ${document_root:-html};
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }" \
        "`echo $http_port | cut -d: -f2`" \
        "`echo $http_port | cut -d: -f1`" \
        "`echo $http_port | cut -d: -f1`.http.access.log" \
        "`echo $http_port | cut -d: -f1`.http.error.log"
        fi)

    $(if [ -n "$https_port" ]; then
        printf "
    server {
        listen %s;
        server_name     %s;
        access_log  /log/nginx/%s;
        error_log  /log/nginx/%s;
        ssl on;
        ssl_certificate %s;
        ssl_certificate_key     %s;
        ssl_session_timeout 5m;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
        ssl_prefer_server_ciphers on;

        location / {
            root   ${document_root:-html};
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }" \
        "`echo $https_port | cut -d: -f2`" \
        "`echo $https_port | cut -d: -f1`" \
        "`echo $https_port | cut -d: -f1`.https.access.log" \
        "`echo $https_port | cut -d: -f1`.https.error.log" \
        "$INSTALL_PATH/conf/`basename $HTTPS_CRT`" \
        "$INSTALL_PATH/conf/`basename $HTTPS_KEY`"
    fi)
}
EOF
else
    ### head
    cat <<EOF >> ./conf/nginx.conf
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

$(
    ### Http set
    if [ -n "$http_port" ]; then
        # upstream
        _upstream_http="$(echo $_node | egrep -o "$HTTP={[^}]*" | cut -d{ -f2)"
        # upstream head
        printf "%s\n" "    upstream $(echo $http_port | cut -d: -f1).http {"
        # upstream body
        printf "%s\n" "$(echo "$_upstream_http" | \
                            awk 'BEGIN { RS="/"; }
                                { if ($0 !~ /^$/) {
                                    gsub("\n", "", $0);
                                    print("        server "$0";");
                                  }
                            }')"
        # upstream end
        echo "    }"

        # http listen
        printf "%s\n" "
    server {
        listen      $(echo $http_port | cut -d: -f2);
        server_name  $(echo $http_port | cut -d: -f1);
        access_log  /log/nginx/$(echo $http_port | cut -d: -f1).http.access.log;
        error_log  /log/nginx/$(echo $http_port | cut -d: -f1).http.error.log;

        location / {
            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_redirect off;
            proxy_http_version 1.1;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_pass http://$(echo $http_port | cut -d: -f1).http;
        }


        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }"
    fi)

$(
    ### Https set
    if [ -n "$https_port" ]; then
        # upstream server for https
        _upstream_https=$(echo $_node | egrep -o "$HTTPS={[^}]*" | cut -d{ -f2)
        # https upstream
        if [ x"$HTTP" != x"$HTTPS" ]; then
            # If the https upstream used, and set
            scheme=https
            https_url="$scheme://$(echo $https_port | cut -d: -f1).$scheme"
            # upstream mark
            printf "%s\n" "    upstream $(echo $https_port | cut -d: -f1).https {"
            # upstream body
            printf "%s\n" "$(echo "$_upstream_https" | \
                                awk 'BEGIN { RS="/"; }
                                { if ($0 !~ /^$/) {
                                    gsub("\n", "", $0);
                                    print("        server "$0";");
                                  }
                                }')"
            # upstream end
            echo "    }"
        else
            # If the https upstream is not set, HTTP is used.
            scheme=http
            https_url="$scheme://$(echo $http_port | cut -d: -f1).$scheme"
        fi

        # https listen
        printf "%s\n" "
    server {
        listen $(echo $https_port | cut -d: -f2);
        server_name $(echo $https_port | cut -d: -f1);
        access_log  /log/nginx/$(echo $https_port | cut -d: -f1).https.access.log;
        error_log  /log/nginx/$(echo $https_port | cut -d: -f1).https.error.log;
        ssl on;
        ssl_certificate $INSTALL_PATH/conf/$(basename $HTTPS_CRT);
        ssl_certificate_key     $INSTALL_PATH/conf/$(basename $HTTPS_KEY);
        ssl_session_timeout 5m;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_redirect off;
            proxy_http_version 1.1;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_pass $https_url;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }"
    fi)
}
EOF
fi

# Install finished
logging debug 'Nginx install finished.\n'

# Clean temp data
clean_temp_dir

exit 0

# Archive(soft is here)
__ARCHIVE_BELOW__
