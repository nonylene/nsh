#! /usr/bin/python3
import sys
import os
import signal

# do not ignore SIGPIPE
signal.signal(signal.SIGPIPE,signal.SIG_DFL)

def main():
    while True:
        line = input(os.getcwd() + ' $ ')
        commands = parse_line(line)
        if [] in commands:
            print("no command")
            continue
        execute_commands(commands)

def execute_commands(commands):

    def wait_child(pid):
        while True:
            wpid, status = os.waitpid(pid, os.WUNTRACED)
            if os.WIFEXITED(status) or os.WIFSIGNALED(status):
                break

    if len(commands) == 1:
        args = commands[0]
        if args[0] in builtin_functions:
            builtin_functions[args[0]](args)
        else:
            pid = os.fork()
            if pid == 0:
                os.execvp(args[0], args)
            elif pid < 0:
                print("error with fork!")
            else:
                wait_child(pid)
    else:
        pid = os.fork()
        if pid == 0:
            execute_pipe(commands)
        elif pid < 0:
            print("error with fork!")
        else:
            wait_child(pid)

def execute_args(args, exit_builtin = False):
    if args[0] in builtin_functions:
        builtin_functions[args[0]](args)
        if exit_builtin: exit()
    else:
        os.execvp(args[0], args)

def execute_pipe(commands):
    # use as queue
    current_args = commands.pop(-1)
    end = len(commands) == 1
    r, w = os.pipe()
    pid = os.fork()
    if pid == 0:
        # child
        os.close(r)
        os.dup2(w, 1)
        os.close(w)
        if len(commands) == 1:
            # last
            args = commands[0]
            execute_args(args, True)
        else:
            execute_pipe(commands)
    elif pid < 0:
        print("error with fork!")
    else:
        # parent
        os.close(w)
        os.dup2(r, 0)
        os.close(r)
        execute_args(current_args, True)

# TODO: use AST?
def parse_line(line):
    commands = []
    args = []
    current_arg = str()

    # '"'
    double_quote = False
    # "'"
    single_quote = False
    # '\'
    escaping = False

    def append_arg(allow_empty):
        # modify variable
        nonlocal current_arg
        if allow_empty or current_arg: args.append(current_arg)
        current_arg = str()

    for s in line:
        if s == '\n':
            append_arg(False)
        elif escaping:
            escaping = False
            current_arg += s
        elif s == '\\':
            escaping = True
        elif s == '"':
            if double_quote:
                double_quote = False
                append_arg(True)
            elif single_quote:
                current_arg += s
            else:
                double_quote = True
        elif s == "'":
            if single_quote:
                single_quote = False
                append_arg(True)
            elif double_quote:
                current_arg += s
            else:
                single_quote = True
            single_quote = True
        elif s in [" ", "\t"]:
            if not (single_quote or double_quote or escaping):
                append_arg(False)
            else:
                current_arg += s
        elif s == "|":
            if not (single_quote or double_quote or escaping):
                append_arg(False)
                commands.append(args)
                args = []
            else:
                current_arg += s
        else:
            current_arg += s
    append_arg(False)
    commands.append(args)
    return commands

def builtin_cd(args):
    directory = args[1] if len(args) > 1 else '~'
    os.chdir(os.path.expanduser(directory))

def builtin_exit(args):
    exit()

builtin_functions = {
        "cd": builtin_cd,
        "exit": builtin_exit
        }

if __name__ == '__main__':
    main()
