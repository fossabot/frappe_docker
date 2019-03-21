#!/bin/bash

set -e

chown -R frappe "${BENCH}"

# Setup bench
if [[ ! -d "${BENCH}/sites" ]]; then
    su-exec frappe bench init "${BENCH}" --ignore-exist --skip-redis-config-generation --verbose
    dockerize -template /home/frappe/templates/procfile.tmpl:${BENCH}/Procfile -template /home/frappe/templates/common_site_config.tmpl:${BENCH}/sites/common_site_config.json
fi

cd "${BENCH}" || exit 1
su-exec frappe bench set-mariadb-host "${MARIADB_HOST}"

# Make sure redis is up
dockerize -wait "tcp://${REDIS_CACHE_HOST}:13000" -wait "tcp://${REDIS_QUEUE_HOST}:11000" -wait "tcp://${REDIS_SOCKETIO_HOST}:12000"
# Make sure MariaDB is up
dockerize -wait "tcp://${MARIADB_HOST}:3306"

# Add a site if its not there (useful if you're doing multitenancy)
if [[ ! -d "${BENCH}/sites/${SITE_NAME}" ]]; then
     su-exec frappe bench new-site "${SITE_NAME}" --verbose
fi

echo "127.0.0.1 ${SITE_NAME}" | tee -a /etc/hosts

# Print all configuration
BCYAN='033[1;36m'

echo -e "${BCYAN}Configuration:"
echo -e "${BCYAN}Bench Procfile (${BENCH}/Procfile):"
cat ${BENCH}/Procfile 
echo ""
echo -e "${BCYAN}Bench Common Site Config (${BENCH}/sites/common_site_config.json):"
cat ${BENCH}/sites/common_site_config.json
echo ""

# Start bench inplace of shell
su-exec frappe bench start