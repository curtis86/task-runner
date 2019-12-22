# Defining tasks in task-runner

Tasks are defined in the `tasks` directory. A task is a single file that ends in the `.task` extension.

A task file has the following fields:

 * command: the command to run
 * frequency: how often the task should run (in seconds)
 * timeout: timeout of the script (in seconds)
 
A minimal task file needs only the command:
```
command=/usr/bin/hostname
```

The `timeout` and `frequency` will be set the global defaults, as defined in `task-runner.conf`

An example of a more full configuration, where timeout and frequency are defined:
```
command=/usr/bin/hostname
frequency=30
timeout=10
```

**Note:** do not wrap the full command in quotes. It should be left unquoted; if your directory or files have spaces/special chars, you should escape them.


### TODO

In future, the following options will be added

 * log level
 * toggle writing output
