#!/usr/bin/env python3

import json
import sys

with open(sys.argv[1], "r") as f:
    bench_results = json.load(f)

results = {}
for metric in bench_results["metrics"].keys():
    metric_info = {}
    metric_info_raw = metric.split(",")
    for metric_raw in metric_info_raw:
        data = metric_raw.split("=", 1)
        metric_info[data[0].strip()] = data[1].strip()
    print(metric_info)
    if metric_info["model"] not in results.keys():
        results[metric_info["model"]] = {}
    results[metric_info["model"]][metric_info["metric"]] = bench_results["metrics"][metric]

print("model,latencies,cpu_peak_mem,gpu_peak_mem")
for model in results.keys():
    print("%s,%s,%s,%s" % (model, results[model]["latencies"], results[model]["cpu_peak_mem"], results[model]["gpu_peak_mem"]))
