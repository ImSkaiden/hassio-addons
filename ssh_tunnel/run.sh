#!/usr/bin/with-contenv bashio

set -e

# https://github.com/hassio-addons/bashio

bashio::log.info "Public key:"

cat /root/.ssh/id_rsa.pub

BASE="ssh -o StrictHostKeyChecking=no"
TUN="-o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -N"

# --- ИЗМЕНЕНИЯ ЗДЕСЬ ---

if bashio::config.has_value 'tunnel_ports'; then
    for port_pair in $(bashio::config 'tunnel_ports'); do
        # port_pair должен быть в формате remote_port:local_port, например 80:8080
        # Если вы хотите разрешить привязку к 0.0.0.0 (любому интерфейсу) на удаленном сервере,
        # формат должен быть remote_ip:remote_port:local_ip:local_port
        # Но для простоты (как в исходном коде) используем remote_port:localhost:local_port
        
        # Разделяем строку на удаленный и локальный порт
        REMOTE_PORT=$(echo "${port_pair}" | cut -d ':' -f 1)
        LOCAL_PORT=$(echo "${port_pair}" | cut -d ':' -f 2)

        if [ -n "$REMOTE_PORT" ] && [ -n "$LOCAL_PORT" ]; then
            bashio::log.info "Adding tunnel: -R ${REMOTE_PORT}:localhost:${LOCAL_PORT}"
            # -R remote_socket:host:hostport
            # Подключения к удаленному порту REMOTE_PORT будут перенаправлены на localhost:LOCAL_PORT
            TUN="${TUN} -R ${REMOTE_PORT}:localhost:${LOCAL_PORT}"
        else
            bashio::log.warning "Invalid port pair in tunnel_ports: ${port_pair}. Skipping."
        fi
    done
fi

# --- КОНЕЦ ИЗМЕНЕНИЙ ---


if ! bashio::config.equals 'socks_port' 0; then
    # -D [bind_address:]port
    # Currently the SOCKS4 and SOCKS5 protocols are supported, and ssh will act
    # as a SOCKS server.
    TUN="${TUN} -D *:$(bashio::config 'socks_port')"
fi

if ! bashio::config.is_empty 'advanced'; then
    TUN="${TUN} $(bashio::config 'advanced')"
fi

SRV="$(bashio::config 'ssh_user')@$(bashio::config 'ssh_host')"

if ! bashio::config.equals 'ssh_port' 22; then
    SRV="-p $(bashio::config 'ssh_port') ${SRV}"
fi

set +e

while true
do
    if ! bashio::config.is_empty 'before'; then
        CMD="${BASE} ${SRV} $(bashio::config 'before')"
        bashio::log.info "[ $(date +'%m-%d-%Y') ] run: ${CMD}"
        eval $CMD
    fi

    CMD="${BASE} ${TUN} ${SRV}"
    bashio::log.info "[ $(date +'%m-%d-%Y') ] run tunnel: ${CMD}"
    eval $CMD

    sleep 30
done