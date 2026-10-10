#!/usr/bin/env python3
"""Runs every Mercday harness suite flag headless, one Godot process at a time.

Each flag writes <out>/<flag>.log; a status line per flag is appended to <out>/_status.txt as it ends, and the
file ends with DONE. The exit code is 0 only when every flag is green, PRE-EXISTING or no-summary.
"""
import argparse
import datetime
import os
import re
import subprocess
import sys
import time

DEFAULT_EXE = "U:/Godot_v4.6.2-stable_win64_console.exe"
HARNESS_FILE = os.path.join("Scripts", "Tests", "HarnessEntry.gd")
FLAG_PATTERN = re.compile(r'\["(--[a-z0-9-]+)", ')
SUMMARY_PATTERN = re.compile(r"TESTS SUMMARY: (\d+)/(\d+) passed, (\d+) failed")
FAIL_PATTERN = re.compile(r"^FAIL (.+?) \| ")
SIM_SUMMARY = "PLAYABILITY SUMMARY"


def ascii_text(text):
    return text.encode("ascii", "replace").decode("ascii")


def discover_flags(project):
    path = os.path.join(project, HARNESS_FILE)
    with open(path, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    start = text.find("static func _suite_flags(")
    if start < 0:
        raise SystemExit("run_suites: no _suite_flags in %s" % path)
    end = text.find("\n]", start)
    block = text[start:] if end < 0 else text[start:end]
    end_of_list = block.find("\n\t]")
    if end_of_list >= 0:
        block = block[:end_of_list]
    return FLAG_PATTERN.findall(block)


def flag_list(spec):
    out = []
    for part in (spec or "").split(","):
        part = part.strip()
        if part:
            out.append(part if part.startswith("--") else "--" + part)
    return out


def read_known(path):
    if not path:
        return set()
    with open(path, encoding="utf-8", errors="replace") as handle:
        return {line.strip() for line in handle if line.strip() and not line.strip().startswith("#")}


def kill_tree(proc):
    if os.name == "nt":
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
    else:
        proc.kill()
    try:
        proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        pass


def run_godot(exe, project, extra, log_path, timeout):
    args = [exe, "--headless", "--path", project] + extra
    started = time.time()
    timed_out = False
    with open(log_path, "wb") as log:
        proc = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
        try:
            code = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            kill_tree(proc)
            code = proc.returncode if proc.returncode is not None else -1
    seconds = time.time() - started
    with open(log_path, encoding="utf-8", errors="replace") as handle:
        lines = handle.read().splitlines()
    return {"exit": code, "timeout": timed_out, "seconds": seconds, "lines": lines}


def parse_run(name, run, kind):
    result = {"flag": name, "exit": run["exit"], "timeout": run["timeout"], "seconds": run["seconds"],
              "passed": 0, "total": 0, "failed": 0, "summary": "no summary", "labels": [], "kind": kind}
    result["script_errors"] = sum(1 for line in run["lines"] if "SCRIPT ERROR" in line)
    parse_errors = sum(1 for line in run["lines"] if "Parse Error" in line and "SCRIPT ERROR" not in line)
    result["script_errors"] += parse_errors
    for line in run["lines"]:
        found = FAIL_PATTERN.match(line)
        if found:
            result["labels"].append(found.group(1))
        if kind == "sim" and SIM_SUMMARY in line:
            result["summary"] = line.strip()
        if kind == "suite":
            hit = SUMMARY_PATTERN.search(line)
            if hit:
                result["summary"] = line.strip()
                result["passed"], result["total"], result["failed"] = (int(hit.group(1)), int(hit.group(2)),
                                                                       int(hit.group(3)))
    return result


def verdict(result, known):
    clean = result["exit"] == 0 and not result["timeout"] and result["script_errors"] == 0
    if result["kind"] == "suite":
        clean = clean and result["failed"] == 0 and result["total"] > 0
    if clean:
        return "green"
    if result["flag"] in known:
        return "PRE-EXISTING"
    labels_known = result["labels"] and all(label in known for label in result["labels"])
    if (result["kind"] == "suite" and labels_known and result["exit"] == 1 and not result["timeout"]
            and result["script_errors"] == 0 and result["total"] > 0):
        return "PRE-EXISTING"
    if (result["kind"] == "suite" and result["summary"] == "no summary" and result["exit"] == 0
            and not result["timeout"] and result["script_errors"] == 0 and not result["labels"]):
        return "no-summary"
    return "red"


def status_line(result, state):
    line = "%s %s | exit %s" % (result["flag"], result["summary"], result["exit"])
    if result["timeout"]:
        line += " | TIMEOUT"
    if result["script_errors"]:
        line += " | SCRIPT ERROR %d" % result["script_errors"]
    if state == "PRE-EXISTING":
        line += " | PRE-EXISTING"
    return ascii_text(line)


def append_status(path, line):
    with open(path, "a", encoding="ascii", newline="\n") as handle:
        handle.write(line + "\n")


def print_table(results, states):
    width = max([len("flag")] + [len(r["flag"]) for r in results])
    print("%s %7s %7s %7s %5s %8s  %s" % ("flag".ljust(width), "passed", "total", "failed", "exit", "seconds",
                                          "verdict"))
    for result, state in zip(results, states):
        shown = "NO SUMMARY" if state == "no-summary" else state
        print(ascii_text("%s %7d %7d %7d %5s %8.1f  %s" % (result["flag"].ljust(width), result["passed"],
                                                          result["total"], result["failed"], result["exit"],
                                                          result["seconds"], shown)))
    green = states.count("green")
    pre = states.count("PRE-EXISTING")
    nosum = states.count("no-summary")
    red = states.count("red")
    print("TOTALS: %d flags, %d green, %d pre-existing, %d no-summary, %d red; %d/%d checks passed, %d failed, "
          "%.1f s" % (
        len(results), green, pre, nosum, red, sum(r["passed"] for r in results), sum(r["total"] for r in results),
        sum(r["failed"] for r in results), sum(r["seconds"] for r in results)))
    return red == 0


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description="Run the Mercday harness suite flags one at a time.")
    parser.add_argument("--exe", default=DEFAULT_EXE, help="Godot console executable")
    parser.add_argument("--project", default=here, help="project folder (default: this script's folder)")
    parser.add_argument("--out", default="", help="log folder (default <project>/_logs/suites/<YYYYMMDD-HHMMSS>)")
    parser.add_argument("--timeout", type=int, default=600, help="seconds per flag before the run is killed")
    parser.add_argument("--only", default="", help="comma list of flags to run; unknown names still go to the harness")
    parser.add_argument("--skip", default="", help="comma list of flags to leave out")
    parser.add_argument("--compile", action="store_true", help="run the compile check first")
    parser.add_argument("--sim", type=int, default=0, help="run --playability-sim=DAYS after the suites")
    parser.add_argument("--seed", default="", help="pass --auto-seed=S to the sim")
    parser.add_argument("--known", default="", help="file of flags or check labels to tolerate, one per line")
    parser.add_argument("--list", action="store_true", help="print the discovered flags and exit")
    opts = parser.parse_args()

    project = os.path.abspath(opts.project)
    flags = discover_flags(project)
    if opts.list:
        for flag in flags:
            print(flag)
        print("%d suite flags" % len(flags))
        return 0
    only = flag_list(opts.only)
    unknown = [flag for flag in only if flag not in flags]
    if unknown:
        print("run_suites: not a suite flag, passed to the harness anyway: %s" % ", ".join(unknown))
    skip = set(flag_list(opts.skip))
    chosen = [flag for flag in (only or flags) if flag not in skip]
    known = read_known(opts.known)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = os.path.abspath(opts.out) if opts.out else os.path.join(project, "_logs", "suites", stamp)
    os.makedirs(out, exist_ok=True)
    status_path = os.path.join(out, "_status.txt")
    open(status_path, "w", encoding="ascii").close()
    print("run_suites: %d flags, logs in %s" % (len(chosen), ascii_text(out)))

    jobs = []
    if opts.compile:
        jobs.append(("compile", ["--quit"], "compile"))
    for flag in chosen:
        jobs.append((flag, ["--", flag], "suite"))
    if opts.sim > 0:
        sim_args = ["--", "--playability-sim=%d" % opts.sim]
        if opts.seed != "":
            sim_args.append("--auto-seed=%s" % opts.seed)
        jobs.append(("--playability-sim", sim_args, "sim"))

    results = []
    states = []
    for name, extra, kind in jobs:
        log_name = name.lstrip("-") + ".log"
        run = run_godot(opts.exe, project, extra, os.path.join(out, log_name), opts.timeout)
        result = parse_run(name, run, kind)
        state = verdict(result, known)
        line = status_line(result, state)
        append_status(status_path, line)
        print(line)
        results.append(result)
        states.append(state)
    append_status(status_path, "DONE")
    ok = print_table(results, states)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
