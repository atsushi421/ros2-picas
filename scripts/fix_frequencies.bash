#!/bin/bash

FREQUENCY=${1:-"2100000"}

for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "userspace" | sudo tee $i
done

cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_frequencies

for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_setspeed; do
    echo "$FREQUENCY" | sudo tee $i
done

sudo sh -c "echo 0 > /sys/devices/system/cpu/cpufreq/boost"

# Unlimit CPU bandwidth for RT tasks
sudo sh -c "echo -1 > /proc/sys/kernel/sched_rt_runtime_us"
sudo sh -c "echo -1 > /proc/sys/kernel/sched_rt_period_us"
