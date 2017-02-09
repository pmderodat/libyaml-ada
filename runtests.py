#! /usr/bin/env python3

import argparse
import difflib
import os
import os.path
import subprocess


parser = argparse.ArgumentParser(description='Run the testsuite')
parser.add_argument('--valgrind', action='store_true',
                    help="Run testcases under Valgrind's memcheck")
parser.add_argument(
    '--build-mode', default='debug',
    help='Change the build mode for LibYAML_Ada and test programs'
)


ROOT_DIR = os.path.abspath(os.path.dirname(__file__))
TESTS_DIR = os.path.join(ROOT_DIR, 'tests')
TMP_DIR = os.path.join(TESTS_DIR, 'tmp')


def find_testcases():
    """
    Generator that yields absolute path for all testcases.
    """
    for dirpath, dirnames, filenames in os.walk(TESTS_DIR):
        rel_dirpath = os.path.relpath(dirpath, TESTS_DIR)
        if rel_dirpath.startswith('tmp'):
            continue
        for fn in filenames:
            if fn.endswith('.adb'):
                yield os.path.join(dirpath, fn)


def testcase_name(tc_path):
    return os.path.splitext(os.path.basename(tc_path))[0]


def rstrip_lines(lines):
    return [line.rstrip() for line in lines]


def build_testcases(args, testcases):
    """
    Build all testcases so they are ready to run.
    """

    source_dirs = {os.path.dirname(tc) for tc in testcases}
    lib_project_file = os.path.abspath(
        os.path.join(ROOT_DIR, 'libyaml_ada.gpr')
   )
    project_file = os.path.join(TMP_DIR, 'tests.gpr')

    # Create all the temporary directories
    if not os.path.exists(TMP_DIR):
        os.mkdir(TMP_DIR)
    for tc in testcases:
        tc_dir = os.path.join(TMP_DIR, testcase_name(tc))
        if not os.path.exists(tc_dir):
            os.mkdir(tc_dir)

    # Create a project file to build all testcase drivers
    def format_string_list(str_list):
        return ', '.join('"{}"'.format(s) for s in str_list)

    with open(project_file, 'w') as f:
        f.write(
'''with "{}";

project Tests is

    for Languages use ("Ada");
    for Source_Dirs use ({});
    for Main use ({});
    for Object_Dir use "obj-" & LibYAML_Ada.Build_Mode;

    package Compiler renames LibYAML_Ada.Compiler;

end Tests;
'''.format(lib_project_file,
           format_string_list(source_dirs),
           format_string_list(os.path.basename(tc) for tc in testcases)))

    subprocess.check_call(['gprbuild', '-j0', '-p', '-q',
                           '-XBUILD_MODE={}'.format(args.build_mode),
                           '-P{}'.format(project_file)])


def run_testcase(args, tc):
    """
    Run a testcase.

    Return a string as an error message if there is an error. Return None
    otherwise (i.e. if test is successful).
    """

    tc_name = testcase_name(tc)
    tc_dir = os.path.join(TMP_DIR, tc_name)
    tc_output = os.path.join(os.path.dirname(tc), '{}.out'.format(tc_name))
    tc_exec = os.path.join(TMP_DIR, 'obj-debug', tc_name)

    if not os.path.isdir(tc_dir):
        os.mkdir(TMP_DIR)

    if not os.path.exists(tc_output):
        return '{}.out is missing'.format(tc_name)

    actual_output_file = os.path.join(tc_dir, 'actual.out')
    argv = [tc_exec]
    if args.valgrind:
        argv = ['valgrind', '--leak-check=full', '-q'] + argv
    with open(actual_output_file, 'w') as f:
        try:
            subprocess.check_call(argv, cwd=TESTS_DIR,
                                  stdout=f, stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as exc:
            return str(exc)

    # Compare the actual output and the expected one
    with open(tc_output, 'r') as f:
        expected_output = rstrip_lines(f.readlines())
    with open(actual_output_file, 'r') as f:
        actual_output = rstrip_lines(f.readlines())

    diff = list(difflib.unified_diff(expected_output, actual_output,
                                     'expected', 'actual',
                                     lineterm=''))
    if diff:
        def diff_color(line):
            if line.startswith('-'):
                return '31'
            elif line.startswith('+'):
                return '36'
            elif line.startswith('@'):
                return '32'
            else:
                return '0'
        return 'output mismatch:\n{}'.format(
            '\n'.join('  \x1b[{}m{}\x1b[0m'.format(
                diff_color(line), line
            ) for line in diff)
        )


def main(args):
    if not os.path.isdir(TMP_DIR):
        os.mkdir(TMP_DIR)

    testcases = sorted(find_testcases())
    build_testcases(args, testcases)
    for tc in testcases:
        tc_name = testcase_name(tc)
        error = run_testcase(args, tc)
        if error:
            print('\x1b[31mFAIL\x1b[0m {}: {}'.format(tc_name, error))
        else:
            print('\x1b[32mOK\x1b[0m   {}'.format(tc_name))


if __name__ == '__main__':
    main(parser.parse_args())
