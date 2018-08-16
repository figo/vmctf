#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

# This script is executed via the systemd service, bins.service. The
# service executes the script using the working directory into which
# the binaries are extracted.

################################################################################
##                                  K8s                                       ##
################################################################################

# Determine if the version points to a release or a CI build.
K8S_URL=https://storage.googleapis.com/kubernetes-release

# If the version does *not* begin with release/ then it's a dev version.
if ! echo "${K8S_VERSION}" | grep '^release/' >/dev/null 2>&1; then
  K8S_URL=${K8S_URL}-dev
fi

# If the version is ci/latest, release/latest, or release/stable then 
# append .txt to the version string so the next if block gets triggered.
if echo "${K8S_VERSION}" | \
   grep '^\(ci/latest\)\|\(release/\(latest\|stable\)\)$' >/dev/null 2>&1; then
  K8S_VERSION="${K8S_VERSION}.txt"
fi

# If the version points to a .txt file then its *that* file that contains
# the actual version information.
if echo "${K8S_VERSION}" | grep '\.txt$' >/dev/null 2>&1; then
  K8S_REAL_VERSION=$(curl --retry-max-time 120 -sL "${K8S_URL}/${K8S_VERSION}")
  K8S_VERSION_PREFIX=$(echo "${K8S_VERSION}" | awk -F/ '{print $1}')
  K8S_VERSION=${K8S_VERSION_PREFIX}/${K8S_REAL_VERSION}
fi

# Build the actual artifact URL.
K8S_ARTIFACT=${K8S_URL}/${K8S_VERSION}/kubernetes-node-linux-amd64.tar.gz

printf '\nfetching %s\n' "${K8S_ARTIFACT}"
curl --retry-max-time 120 -L \
  "${K8S_ARTIFACT}" | \
  tar --strip-components=3 --wildcards -xzv \
  --exclude=kubernetes/node/bin/*.tar \
  --exclude=kubernetes/node/bin/*.docker_tag \
  'kubernetes/node/bin/*'

################################################################################
##                                main()                                      ##
################################################################################
# Mark all the files in the working directory:
# 1. Executable
# 2. Owned by root:root
chmod 0755 -- *
chown root:root -- *

# Indicate the script has completed
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
