# task-runner

## A. Summary

Do you have a bunch of scripts/commands that you need to run at certain intervals? To log their output? To have timeouts for? Then **task-runner** is for you!

Features:

 * simple file-defined tasks
 * per-second task frequency
 * timeout function
 * logs output, exit code and last run time
 * light-weight, low dependency

Example: I have a few scripts that I run to collect sensor data that gets posted to InfluxDB; because I need to collect this data every 15 seconds, cron will not work, in this case, **task-runner** is a great alternative.

## B. Dependencies

- BASH

## C. Supported Systems

**task-runner** has been tested on CentOS Linux 7 & 8/RHEL 7 & 8

It should run on macOS, Windows/WSL, other Linux distributions.

### Installation

1. Clone this repo to your preferred directory (eg: `/opt/`)

```
cd /opt
git clone https://github.com/curtis86/task-runner
```

2. Follow the usage instructions below!

### Usage

These steps assume that **task-runner** has been installed to `/opt/task-runner`...

1. Install the systemd service file
   `cp /opt/task-runner/.setup/task-runner.service /etc/systemd/system/`

2. Copy sample config - update values included if necessary
   `cp /opt/task-runner/task-runner.conf-sample /opt/task-runner/task-runner.conf`

3. Enable & start task-runner service
   `systemctl enable task-runner && systemctl start task-runner`

4. Define your tasks! See: `tasks/README.md` to configure tasks.

## Sample output

Sample output for a test task, from the `task-runner.log` file:

```
Fri Dec 20 17:13:32 AEDT 2019 - [test] Creating new task
Fri Dec 20 17:13:32 AEDT 2019 - [test]: ran successfully
```

## Notes

 * Task data, such as output, exit code and last run time are saved to `taskdata/<task-name>`
 * You do not have to restart the `task-runner` service when tasks are added or removed. They will be picked up automatically.
 * To disable a task, simply remove the `.task` extension on the file.

## Disclaimer

I'm not a programmer, but I do like to make things! Please use this at your own risk.

## License

The MIT License (MIT)

Copyright (c) 2019 Curtis K

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
