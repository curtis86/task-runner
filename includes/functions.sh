function setup() {
  [ ! -f "${log_file}" ] && touch "${log_file}"
  [ ! -d "${taskdata_dir}" ] && mkdir "${taskdata_dir}"
  [ ! -d "${task_dir}" ] && mkdir "${task_dir}"
}

# Logs to file
log() {
  _log_msg="$( date ) - $@"
  set -u && echo "${_log_msg}" >> "${log_file}"
}

# Echo/error
ee() {
  echo "ERROR: $@" >&2
}

# Echo/warning
we() {
  echo "WARNING: $@" >&2
}

# Echo/debug
de() {
  echo "$@" >&2
}


# Prints usage
function print_usage() {
  cat << EOF
Usage: ${progname} <options>
EOF
}

# Exits with options
function exit_unlock() {
  if [ $# -gt 1 ]; then _exit_code=$1 ; else _exit_code=0; fi
  unlock && exit ${_exit_code}
}

# Locks program
function lock() {
  local _date_now=$( date +%s )
  touch "${lock_file}"
  set -u && echo -e "pid=$$\ntimestamp=${_date_now}" > "${lock_file}"
}

# Unlocks program
function unlock() {
  set -u && rm "${lock_file}"
}

# Checks if lock exists
function check_lock() {
  local _date_now=$( date +%s )

  if [ -f "${lock_file}" ]; then
    local _date_last_run="$( grep 'timestamp' "${lock_file}" | cut -d\= -f2 )"
    local _last_pid="$( grep 'pid' "${lock_file}" | cut -d\= -f2 )"

    # Crude way to check if process is still running...
    if ! kill -0 ${_last_pid} >/dev/null 2>&1 ; then
      we "Lock file found, but process with PID ${_last_pid} not found. Clearing lock file."
      unlock
    elif [ $(( _date_now - _date_last_run )) -ge ${run_timeout} ]; then
        we "Lock file found, but lock time exceeds timeout of ${run_timeout} seconds. Removing stale lock file..."
        unlock
    else
       ee "Script is currently locked with PID ${_last_pid}."
       exit
    fi
  fi
}

# Updates a lock timestap
function update_lock_timestamp() {
  local date_now=$( date +%s )
  sed -i "s/timestamp=.*/timestamp=${date_now}/g" "${lock_file}"
}

# Checks for conf file
function check_conf_file() {
  if [ ! -f "${home_dir}/task-runner.conf" ]; then
    ee "configuration file ${home_dir}/task-runner.conf not found. If this is the first time you are running this script, you may need to first move the sample config to task-runner.conf" && exit 1
  else
    return 0
fi
}

# Gets value from key/value pair from file (ie. command=) 
# Returns empty on no match, or error.
function getval() {
  [ $# -ne 2 ] && return 1
  local _key="$1"
  local _file="$2" 
  export _value

  if _value="$( grep "^${_key}=" "${_file}" | awk -F= '{ print $NF }' )"; then
    echo "${_value}"
  else
    echo
  fi
}

function validate_task() {
  local _task="$1"
  local _task_name="$( echo "${_task}" | sed 's/.task//g' )"
  local _task_file="${task_dir}/${_task}"
  local task_freq task_timeout task_command

  if [ -f "${_task_file}" ]; then
    task_freq="$( grep ^frequency= "${_task_file}" | cut -d= -f2 )"
    task_timeout="$( grep ^timeout= "${_task_file}" | cut -d= -f2 )"
    task_command="$( grep ^command= "${_task_file}" | cut -d= -f2 )"
  else
    echo "[${_task_name}] Task file ${_task_file} not found. Might have been deleted before getting run." >&2
    return 1
  fi

  # Perform additional validation here - at minimum, we need task command and for it to be executable.
  if [ -z "${task_command}" ]; then
      # TODO add a 5 minute delay on tasks that do not have a command
      #log "[${t}] Task command empty. Skipping."
      :
  fi
  
#  [ ! -x "${task_command}" ] && { log "[${t}] Task command is not executable. Skipping." >&2 ; return 1;}
  # TODO - add a check that command is executable
}

# Process task (set up dirs, etc) - also decides if task should run
function process_task() {
  local _task="$1"
  local _task_name="$( echo "${_task}" | sed 's/.task//g' )"
  local _task_file="${task_dir}/${_task}"
  local _task_taskdata_dir="${taskdata_dir}/${_task_name}"
  local _task_timeout _task_frequency _task_exitcode _task_lastrun _task_state
  local _TASK_NEW=0
  local _RUN_TASK=1

  export _task_output

  # New task
  if [ ! -d "${_task_taskdata_dir}" ]; then
    log "[${_task_name}] Creating new task"
    mkdir "${_task_taskdata_dir}" || return 1
    touch "${_task_taskdata_dir}"/{active,lastrun,output,state,exitcode,pause} || return 1
  else
    _TASK_NEW=1
  fi 

  # Enforce defaults if they are not set
  # check if string is found in task file, if not, define it
  _task_frequency="$( grep ^frequency= "${_task_file}" | cut -d= -f2 )"
  _task_timeout="$( grep ^timeout= "${_task_file}" | cut -d= -f2 )"

  [ -z "${_task_frequency}" ] && set -u && _task_frequency=${default_frequency} echo "frequency=${default_frequency}" >> "${_task_file}"
  [ -z "${_task_timeout}" ] && set -u && _task_timeout=${default_timeout} && echo "timeout=${default_timeout}" >> "${_task_file}"

  # Now check if the task is running/ready for next run etc
  if [ ${_TASK_NEW} -eq 0 ]; then
    _RUN_TASK=0
  else
    _task_lastrun=$( cat "${_task_taskdata_dir}/lastrun" )

    if [ -z "${_task_lastrun}" ]; then
      _RUN_TASK=0
      _task_lastrun=999999999999
      break
    fi

    date_now=$( date +%s )
    _time_since_last_run=$(( date_now - _task_lastrun ))

    if [ ${_time_since_last_run} -ge ${_task_frequency} ]; then
      _RUN_TASK=0
    fi
     
  fi

  if [ ${_RUN_TASK} -eq 0 ]; then
    _task_command="$( grep ^command= "${_task_file}" | awk -F '=' '{ print $NF }' )"
    _task_lastrun=$( date +%s ) && set -u && echo "${_task_lastrun}" > "${_task_taskdata_dir}/lastrun"
    _task_state="running" && set -u && echo "${_task_state}" > "${_task_taskdata_dir}/state"
    _date_now=$( date +%s )

    if _task_output="$( timeout -s ${kill_signal} ${_task_timeout} $_task_command 2>&1 )" ; then
      _task_exitcode=0
      log "[${_task_name}]: ran successfully"
    else
      _task_exitcode=$?
      log "[${_task_name}] failed with non-zero exit code"
    fi
   
    [ -n "${_task_output}" ] && set -u && echo "${_task_output}" >> "${_task_taskdata_dir}/output"
    set -u && echo "${_task_exitcode}" > "${_task_taskdata_dir}/exitcode"
    set -u && echo "${_task_lastrun}" > "${_task_taskdata_dir}/lastrun"
    _task_state="waiting" && set -u && echo "${_task_state}" > "${_task_taskdata_dir}/state"

  fi

}

# Validate all tasks in array
function run_tasks() {
  active_tasks=( $( cd "${task_dir}" && ls -1 *.task 2>/dev/null ) )
  active_task_count=${#active_tasks[@]}

  [ ${active_task_count} -lt 1 ] && return 1

  for t in "${active_tasks[@]}" ; do 
    validate_task "${t}" ; process_task "${t}" &
  done 
}

# List tasks (from taskdata dir - may include deleted tasks
function list_tasks() {
  active_tasks=( $( cd "${task_dir}" && ls -1 *.task ) )
  active_task_count=${#active_tasks[@]}
  tasks_skipped=0
  task_list_output="\n"

  [ ${active_task_count} -eq 0 ] && de "No tasks found." && return 1

  for t in "${active_tasks[@]}" ; do
    if validate_task "${t}" ; then
      _task_file="${task_dir}/${t}"
      _task_taskdata_file="$( echo "${taskdata_dir}/${t}" | sed 's/.task//g' )"
      _task_command="$( getval "command" "${_task_file}" )"
      _task_lastrun="$( cat "${task_dir}/${t}"/lastrun 2>&1 )"
    else
      ((tasks_skipped++))
     fi 
  done

  [ ${tasks_skipped} -gt 0 ] && echo -e "\nSkipped ${tasks_skipped} tasks due to validation errors."
}
