#! /usr/bin/python3
import sys
import os
import signal

class ParseError(Exception):
    pass

class Command():
    def __init__(self, args, redirect_in, redirect_out):
        self.args = args
        self.redirect_in = redirect_in
        self.redirect_out = redirect_out

# do not ignore SIGPIPE
signal.signal(signal.SIGPIPE,signal.SIG_DFL)

def main():
    while True:
        line = input(os.getcwd() + ' $ ')
        try:
            commands = parse_line(line)
        except ParseError as e:
            print("nsh: {0}".format(e))
            continue
        execute_commands(commands)

def execute_commands(commands):

    def wait_child(pid):
        while True:
            wpid, status = os.waitpid(pid, os.WUNTRACED)
            if os.WIFEXITED(status) or os.WIFSIGNALED(status):
                break

    if len(commands) == 1:
        command = commands[0]
        args = command.args
        if args[0] in builtin_functions:
            # run builtin on current process
            builtin_functions[args[0]](args)
        else:
            pid = os.fork()
            if pid == 0:
                execvp_command(command)
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

def execute_command(command, exit_builtin = False):
    args = command.args
    if args[0] in builtin_functions:
        builtin_functions[args[0]](args)
        if exit_builtin: exit()
    else:
        execvp_command(command)

def execvp_command(command):
    args = command.args
    if command.redirect_in:
        infd = os.open(command.redirect_in, os.O_RDONLY)
        os.dup2(infd, 0)
        os.close(infd)
    if command.redirect_out:
        outfd = os.open(
                command.redirect_out, os.O_WRONLY | os.O_CREAT, 0o644)
        os.dup2(outfd, 1)
        os.close(outfd)
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
            execute_command(args, True)
        else:
            execute_pipe(commands)
    elif pid < 0:
        print("error with fork!")
    else:
        # parent
        os.close(w)
        os.dup2(r, 0)
        os.close(r)
        execute_command(current_args, True)

# TODO: use AST?
def parse_line(line):
    commands = []

    redirect_in = None
    redirect_out = None
    args = []
    current_arg = str()

    # '"'
    double_quote = False
    # "'"
    single_quote = False
    # '\'
    escaping = False
    # '>'
    redirecting_out = False
    # '<'
    redirecting_in = False

    def append_cmd():
        append_arg(False)
        nonlocal redirect_in
        nonlocal redirect_out
        nonlocal commands
        nonlocal args
        # check
        if redirect_in == str():
            raise ParseError("empty redirect in")
        if redirect_out == str():
            raise ParseError("empty redirect out")
        if not args:
            raise ParseError("empty command")
        commands.append(Command(args, redirect_in, redirect_out))
        redirect_in = None
        redirect_out = None
        args = []

    def append_arg(allow_empty, end_redirects = True):
        # modify variable
        if end_redirects:
            nonlocal redirecting_in
            redirecting_in = False
            nonlocal redirecting_out
            redirecting_out = False
        nonlocal current_arg
        if allow_empty or current_arg: args.append(current_arg)
        current_arg = str()

    def append_char(char):
        if redirecting_in:
            nonlocal redirect_in
            redirect_in += char
        elif redirecting_out:
            nonlocal redirect_out
            redirect_out += char
        else:
            nonlocal current_arg
            current_arg += char

    for s in line:
        if s == '\n':
            append_arg(False)
        elif escaping:
            escaping = False
            append_char(s)
        elif s == '\\':
            escaping = True
        elif s == '"':
            if double_quote:
                double_quote = False
                append_arg(True)
            elif single_quote:
                append_char(s)
            else:
                double_quote = True
        elif s == "'":
            if single_quote:
                single_quote = False
                append_arg(True)
            elif double_quote:
                append_char(s)
            else:
                single_quote = True
            single_quote = True
        elif s in [" ", "\t"]:
            if not (single_quote or double_quote or escaping):
                append_arg(False, False)
            else:
                append_char(s)
        elif s == ">":
            if not (single_quote or double_quote or escaping):
                if redirect_out: raise ParseError("multiple redirect out")
                append_arg(False)
                redirecting_out = True
                redirect_out = str()
            else:
                append_char(s)
        elif s == "<":
            if not (single_quote or double_quote or escaping):
                if redirect_in: raise ParseError("multiple redirect in")
                append_arg(False)
                redirecting_in = True
                redirect_in = str()
            else:
                append_char(s)
        elif s == "|":
            if not (single_quote or double_quote or escaping):
                append_cmd()
            else:
                append_char(s)
        else:
            append_char(s)

    append_arg(False)
    append_cmd()
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
