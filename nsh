#! /usr/bin/python3
import sys
import os

def main():
    while True:
        line = input(os.getcwd() + ' $ ')
        args = parse_line(line)
        if args[0] in builtin_functions:
            builtin_functions[args[0]](args)
        else:
            execute_line(args)

def execute_line(args):
    pid = os.fork()
    if pid == 0:
        os.execvp(args[0], args)
    elif pid < 0:
        print("error with fork!")
    else:
        while True:
            wpid, status = os.waitpid(pid, os.WUNTRACED)
            if os.WIFEXITED(status) or os.WIFSIGNALED(status): break

# TODO: use AST?
def parse_line(line):
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
        else:
            current_arg += s
    append_arg(False)
    return args

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
