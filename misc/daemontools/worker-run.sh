#!/bin/sh
# Copyright (c) 2010-2011 Yahoo! Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

WORKER="/usr/local/sbin/pogo-worker"
WORKER_KEY="/usr/local/etc/pogo/worker.key"
RUN_AS_USER="root"

exec 2>&1

if [ ! -f "$WORKER_KEY" ]; then
  echo "ERROR cannot start pogo-worker: $WORKER_KEY is missing"
  exit 1
fi

echo "starting pogo-worker"

# linux only?
if [ -w "/proc/sys/fs/file-max" ]; then
  echo "131072" > /proc/sys/fs/file-max
fi

# hopefully somewhat portable
ulimit -n 131072
exec setuidgid $RUN_AS_USER $WORKER

