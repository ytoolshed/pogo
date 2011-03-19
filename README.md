# NOTE: Pogo is a work in progress - watch this space for updates

Pogo is an agent-based system for running interruptive commands safely
on thousands of machines in parallel.

Users request that a command (or recipe, or script) be executed on a
group of target nodes by issuing new pogo jobs via the pogo(1)
command-line utility.  If the job is successfully created on the
dispatcher, the user will receive a job id and a URL in response.

The pogo dispatcher then divides the job up into tasks, one task per
target host.  The dispatcher computes a task run order and distributes
tasks to worker processes.  Workers ssh to the target nodes and run the
commands specified by the user, reporting progress and status back to
the dispatcher.

For more information see the Pogo wiki: http://github.com/ytoolshed/pogo/wiki

## LICENSE
Distributed under the terms of the Apache 2.0 license.
Copyright (c) 2010, Yahoo! Inc. All rights reserved.

