#! /usr/bin/env python
# wget-mp.py

# == Description ============================================================
# A simple python script for parallel file fitching using wget.

# == License ================================================================
# Copyright (c) 2010, cbaoth
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.

# == Comments, Todo etc. ====================================================
# ...

import sys, os, traceback
import string
import re
import time
import subprocess
from subprocess import Popen
from threading import Timer

# ----------------------------------------------------------------------
# constants
# ----------------------------------------------------------------------
PROGNAME = "wget multi process"
VERSION = "20120802"
# http user agent used for identifiaction
UAGENT = "Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.4b) Gecko/20030517 Mozilla Firebird/0.6"
# max concurrent processes
MAXPROC = 8
# max runtime before process gets killed (timeout in seconds)
PROCESSTIMEOUT = 0 # 10*60
# debug level
BASENAME = os.path.basename(sys.argv[0])
DYNNAME = 0
REFETCH = 0
DEBUG = 0
# wget timeouts (0 = disabled)
CONNECTTIMEOUT=0  # wget default: 0, connection time
DNSTIMEOUT=0      # wget default: 0, dns lookup time
READTIMEOUT=900   # wget default: 900, read idle time

# ----------------------------------------------------------------------
# print stuff
# ----------------------------------------------------------------------
def p_dbg(msg, level=1):
    if (DEBUG >= level):
        print "* DBG-%s: %s" % (level, msg)

def p_msg(msg):
    print "> %s" % (msg)

def p_err(msg):
    print >> sys.stderr, "ERROR: %s" % (msg)

# ----------------------------------------------------------------------
# add simple timer to Popen class
# ----------------------------------------------------------------------
def start_timer(self):
    self.start_time = time.mktime(time.gmtime())
Popen.start_timer = start_timer
def get_runtime(self):
    return time.mktime(time.gmtime()) - self.start_time
Popen.get_runtime = get_runtime

# ----------------------------------------------------------------------
# process handling
# ----------------------------------------------------------------------
class ProcessPool:

    def __init__(self, process_timeout=PROCESSTIMEOUT, max_processes=MAXPROC):
        self.proc = []
        self.process_timeout = process_timeout
        self.max_processes = max_processes
        #self.clean_lock = threading.RLock()

    def __clean(self):
        newproc = []
        for p in self.proc:
            if (p.poll() == None):
                if (self.process_timeout > 0 and p.get_runtime() > self.process_timeout):
                    p_msg("process %s killed, exceeded max runtime (%s sec)" % (p.pid, self.process_timeout))
                    p.kill()
                else:
                    p_dbg("process %s running since %s sec" % (p.pid, p.get_runtime()), 2)
                    newproc.append(p)
            else:
                p_dbg("process %s finished" % (p.pid), 3)
        self.proc = newproc

    def killall(self):
        p_dbg("it's killing time ...")
        for p in self.proc:
            if (p.poll() == None):
                p_msg("process %s killed (killall called)" % (p.pid))
                p.kill()

    def run(self, cmd):
        while (len(self.proc) >= self.max_processes):
            self.__clean()
            time.sleep(1)
            #Timer(1, self.__clean).start()
        p_dbg("spawning new process: " + str(cmd), 2)
        p = subprocess.Popen(cmd, stdout=None)
        p.start_timer()
        p_dbg("new process: " + str(p.pid), 3)
        self.proc.append(p)

    def finalize(self, timeout=0, verbose=1):
        p_dbg("finalizing")
        stime = time.mktime(time.gmtime())
        self.__clean()
        idx = 0
        while (len(self.proc) > 0):
            dtime = time.mktime(time.gmtime()) - stime
            if (timeout > 0 and dtime >= timeout):
                self.killall()
            if (verbose > 0 and idx % 10 == 0):
                p_msg("waiting for %s processes to finish (runtime: %1.0fs) .." % (len(self.proc), dtime))
            self.__clean()
            idx = idx + 1
            time.sleep(1)


# ----------------------------------------------------------------------
# core
# ----------------------------------------------------------------------
#def error(msg, ecode=1):
#    p_err(msg)
#    sys.exit(ecode)

def url2filename(url):
    target = re.sub("^(https?|ftp|file):/+", "", url)
    target = re.sub("/+$", "", target)
    target = target.replace("/", "+")
    target = target.replace(" ", "_")
    return target


def guessUrlFromFilename(filename):
    target = re.sub(".*/", "", filename) # strip file path
    target = re.sub("^", "http://", target) # we assume http protoclo
    target = target.replace("+", "/")
    return target


def main():
    import argparse

    aparse = argparse.ArgumentParser(prog=BASENAME, description="%s (%s)" % (PROGNAME, VERSION))
    #aparse.add_argument('-v', '--verbosity', type=int, default=DEBUG
    #                    , help='set the debug level [%s]' % (DEBUG))
    aparse.add_argument('-p', '--maxproc', type=int, default=MAXPROC
                        , help='set maximum process count [%s]' % (MAXPROC))
    aparse.add_argument('-pt', '--process-timeout', type=int, default=PROCESSTIMEOUT
                        , help='kill wget after x seconds [%s sec]' % (PROCESSTIMEOUT))
    aparse.add_argument('-t', '--timeout', type=int
                        , help='set wget global timeout [individual]')
    aparse.add_argument('-ct', '--connect-timeout', type=int, default=CONNECTTIMEOUT
                        , help='set wget connect-timeout [%s sec]' % (CONNECTTIMEOUT))
    aparse.add_argument('-dt', '--dns-timeout', type=int, default=DNSTIMEOUT
                        , help='set wget dns-timeout [%s sec]' % (DNSTIMEOUT))
    aparse.add_argument('-rt', '--read-timeout', type=int, default=READTIMEOUT
                        , help='set wget read-timeout [%s sec]' % (READTIMEOUT))
    aparse.add_argument('-r', '--referer', help='referer url')
    aparse.add_argument('-d', '--dynname', action='store_true', default=DYNNAME \
                        , help="dynamically name output file, example:"
                             + " http://foo.bar/bla/baz.tar => foo.bar+bla+baz.tar")
    aparse.add_argument('-rf', '--refetch', action='store_true', default=REFETCH \
                        , help='try to refetch corrupted files by guessing the url from'
                             + ' the file name (only for files loaded with the -d option)')
    aparse.add_argument('-s', '--skipifexists', action='store_true', default=False \
                        , help="skip if the output file already exists, instead of"
                             + " continuing (only in combination with --dynname)")
    aparse.add_argument('-nc', '--nocontinue', action='store_true', default=False \
                        , help="if file already exists, don\'t try to continue"
                             + " (default) but refetch and overwrite")

    aparse.add_argument('url', nargs='+', help='url to fetch')
    args = aparse.parse_args() #sys.argv[1:]

    def usage(ecode=0):
        print aparse.print_help()
        sys.exit(ecode)

    if len(sys.argv) <= 1:
        usage(2)

    ppool = None
    try:
        # time.sleep(20)
        ppool = ProcessPool(process_timeout=args.process_timeout, max_processes=args.maxproc)

        cmd_base = ['wget', '--quiet', '-U', UAGENT]
        if (not args.nocontinue):
            cmd_base = cmd_base + ['-c']
        if (args.referer):
            cmd_base = cmd_base + ['--referer', args.referer]
        if (args.timeout):
            cmd_base = cmd_base + ['--timeout', str(args.timeout)]
        else:
            cmd_base = cmd_base + ['--connect-timeout', str(args.connect_timeout), \
                '--dns-timeout', str(args.dns_timeout), \
                '--read-timeout', str(args.read_timeout)]
        p_dbg("urls: %s" % ' '.join(args.url))
        for url in args.url:
            cmd = cmd_base
            p_msg('URL: %s' % (url))
            if (args.refetch):
                target = url
                # we don't care if the file doesn't exist, we have the name and can try to re-fetch it
                #if (not os.path.isfile(target)):
                #   p_msg('   => SKIPPING (file not found)')
                #   continue
                url = guessUrlFromFilename(url)
                p_msg('  <= ASSUMED URL: %s' % (url))
                cmd = cmd + ['-O', target]
            elif (args.dynname):
                target = url2filename(url)
                if (args.skipifexists and os.path.isfile(target)):
                    p_msg('  => SKIPPING (target exists)')
                    continue
                p_msg('  => %s' % (target))
                cmd = cmd + ['-O', target]
            p_dbg("executing: %s" % ' '.join(cmd))
            ppool.run(cmd + [url])
        ppool.finalize()
        p_msg("download(s) finished")
    except KeyboardInterrupt as e:
        p_msg('keyboard interrupt!')
        if (ppool != None):
            p_msg('%s: killing all processes!' % (PROGNAME))
            ppool.killall()
        sys.exit(1)
    #except SystemExit as e:
    #    pass
    except Exception as e:
        if (ppool != None):
            p_msg('%s: killing all processes!' % (PROGNAME))
            ppool.killall()
        #print sys.exc_type, sys.exc_value
        traceback.print_exc()
        sys.exit(1)
    #finally:

    sys.exit(0)


if __name__ == "__main__":
    main()
