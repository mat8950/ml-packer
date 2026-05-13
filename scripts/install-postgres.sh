#!/bin/bash
set -e

dnf install -y postgresql16-server postgresql16-contrib

dnf clean all
rm -rf /var/cache/dnf
