### auto_nginx_install-bin-1.0.1.sh

### Nginx 自动安装脚本

### 依赖包
  - 执行安装
    - yum install zlib zlib-devel gcc gcc-c++ make -y
    - yum install openssl openssl-devel -y

### 默认路径
  - Nginx 默认安装路径
    1. /opt/nginx
  - Nginx 日志默认路径
    1. /log/nginx

### HELP
Usage: ./auto_nginx_install-bin-1.0.1.sh [OPT] [VALUE] v1.0.1
            - Nginx 运行用户，默认：nobody
              -u, STRING, nginx daemon user.

            - Nginx 运行时使用的 CPU 个数，默认自动获取个数最大化设置
              -c, NUMBER, cpu cores.

            - 实行正常安装（静态服务器而非反向代理服务器）
              -n, normal install, default.

            - HTTP 参数设置，静态服务器与反向代理服务器需设置，默认 HTTP
              -h, STRING, http hostname:port(set http).

            - HTTPS 参数设置，态服务器与反向代理服务器需设置，默认 HTTP
              -s, STRING, https hostname:port(set https).

            - 证书路径指定，设置了 HTTPS 服务器时，此项必选
              -t, STRING, https cert file, crt=site.crt,key=site.key.

            - 设置 UPSTREAM 后端服务器参数，name 表示 upstream 的命名
            - 注意 name={/1.1.1.1:90} 前面有 "/" 且后面不能有字符 "/"，命名不能有特殊字符
              -i, STRING, real node name={/ip:port/ip:port},name={...}.

            - 设置 document 路径，默认 html
              -l, STRING, document root, default 'html'.

            - 设置 UPSTREAM 模式，http=upsteam_name 中 "upsteam_name" 必须是 -i 参数中的一个命名
              -p, STRING, enable upstring mode, http=upsteam_name,https=upstream_name.

            - 设置配置 Nginx 的其他参数，或者说可以修改安装路径
              -D, STRING, extra args, using nginx configure.

            - 编译 Nginx 时，采用多进程执行 Job
              -j, Enable multiple process make.

### 实例
  - 基本安装
    1. ./auto_nginx_install-bin-1.0.1.sh     # 运行用户 nobady, 使用默认 HTTP 设置，没有 HTTPS（静态服务器）
       # 等同于 ./auto_nginx_install-bin-1.0.1.sh -n
  - 设置 HTTP 静态服务器
    1. ./auto_nginx_install-bin-1.0.1.sh -h www.myname.com:80
  - 设置 HTTPS 静态服务器
    1. ./auto_nginx_install-bin-1.0.1.sh -s www.myname.com:443 -t crt=/tmp/www.crt,key=/tmp/www.key
  - 设置 HTTP 与 HTTPS 静态服务器
    1. ./auto_nginx_install-bin-1.0.1.sh -h www.myname.com:80 -s www.myname.com:443 -t crt=/tmp/www.crt,key=/tmp/www.key
  - 设置 HTTP 反向代理服务器
    1. ./auto_nginx_install-bin-1.0.1.sh -h www.myname.com:80 -i www_baidu_com={/14.215.177.38:80/14.215.177.39:80} -p http=www_baidu_com
    # 当 -i 参数有多个命名，在 -p 中没有被使用时，将不会生效在系统中
    # 注意 -i www_baidu_com={/14.215.177.38:80/14.215.177.39:80} 前面有 "/" 且后面不能有字符 "/"，命名(www_baidu_com)不能存在特殊字符
  - 设置 HTTPS 反向代理服务器
    1. ./auto_nginx_install-bin-1.0.1.sh -s www.myname.com:443 -i www_baidu_com={/14.215.177.38:443/14.215.177.39:443} \
                                         -p https=www_baidu_com -t crt=/tmp/www.crt,key=/tmp/www.key
  - 设置 HTTP 与 HTTPS 反向代理服务器（HTTPS 代理时后端使用 HTTPS）
    1. ./auto_nginx_install-bin-1.0.1.sh -s www.myname.com:443 \
                                         -h www.myname.com:80 \
                                         -i http_baidu_com={/14.215.177.38:80/14.215.177.39:80},https_baidu_com={/14.215.177.38:443/14.215.177.39:443} \
                                         -p http=http_baidu_com,https=https_baidu_com \
                                         -t crt=/tmp/www.crt,key=/tmp/www.key
  - 设置 HTTP 与 HTTPS 反向代理服务器（HTTPS 代理时后端使用 HTTP）
    1. ./auto_nginx_install-bin-1.0.1.sh -s www.myname.com:443 \
                                         -h www.myname.com:80 \
                                         -i http_baidu_com={/14.215.177.38:80/14.215.177.39:80} \
                                         -p http=http_baidu_com,https=http_baidu_com \
                                         -t crt=/tmp/www.crt,key=/tmp/www.key
  - 修改 Nginx 安装路径
    1. ./auto_nginx_install-bin-1.0.1.sh -D--prefix=/usr/local/nginx
       # 其他参数都可以这么设置，比如： ./auto_nginx_install-bin-1.0.1.sh -D--prefix=/usr/local/nginx -D--with-pcre=/tmp/pcre -D--with-http_stub_status_module

### ChangeLog
  - 1.0.1
    1. 将 Nginx 配置文件合并。

### 开发者博客
  - https://www.zhihu.com/people/comeccc
