METHODS=(
    "picas_multi"
    "picas_multi_separate"
    "picas_single"
    "default_multi"
    "default_multi_separate"
    "default_single"
)
NUM_LOAD_TASKS=(0 2 4 6 8 10 12 14 16 18 20)
NUM_CORES=4
DURATION_S=60

function remove_create_dir() {
    DIR=$1
    if [ -d "$DIR" ]; then
        rm -rf "$DIR"
    fi
    mkdir -p "$DIR"
}

TARGET_PROC=""

function set_affinity_balance() {
    # Wait until the process is running
    while true; do
        TARGET_PROC=$(pgrep -f install/picas_example_mt)
        if [[ -n "$TARGET_PROC" ]]; then
            break
        fi
        sleep 1
    done

    # Wait until there are at least four 'example_mt' threads with CPU usage >= 10%
    while true; do
        mt_count=$(ps -L -p "$TARGET_PROC" -o comm=,pcpu= --no-headers |
            awk '$1 ~ /example_mt/ && $2 >= 10.0 { count++ } END { print count+0 }')
        if ((mt_count >= 4)); then
            break
        fi
        sleep 1
    done

    # Store CPU usage per thread (LWP)
    ps -L -p $TARGET_PROC -o lwp=,%cpu=,comm= --no-headers |
        awk '{ printf "%s %.2f %s\n", $1, $2, $3 }' |
        sort -k2 -nr >/tmp/tid_cpu_usage.tmp

    i=0
    CORES=(17 18 19 20)
    while read -r tid cpu cmd; do
        if [[ $cmd == *"example_mt"* ]]; then
            if [ "$METHOD" == "picas_single" ]; then
                # Because PiCAS-single does not work well.
                affinity=${CORES[$((i % ${#CORES[@]}))]}
                sudo taskset -p -c $affinity $tid >/dev/null
                echo "Set TID $tid (CPU usage: $cpu%) to CPU $affinity"
                ((i++))
            else
                # Global in CORES
                sudo taskset -p -c 17-20 $tid >/dev/null
                echo "Set TID $tid (CPU usage: $cpu%) to CPU 17-20"
                if [[ $METHOD == "default"* ]]; then
                    # Set SCHED_FIFO 90 for fair evaluation
                    sudo chrt -f 90 -p $tid >/dev/null
                    echo "Set TID $tid (CPU usage: $cpu%) to SCHED_FIFO 90"
                fi
            fi
        fi
    done </tmp/tid_cpu_usage.tmp

    rm -f /tmp/tid_cpu_usage.tmp
}

trap 'sudo kill $TARGET_PROC; exit 0' SIGINT SIGTERM

for METHOD in "${METHODS[@]}"; do
    for NUM_LOAD_TASK in "${NUM_LOAD_TASKS[@]}"; do
        echo "=========================="
        echo "METHOD: $METHOD"
        echo "NUM_LOAD_TASK: $NUM_LOAD_TASK"
        echo "=========================="

        # rm -rf build install log
        source /opt/ros/humble/setup.bash

        RESULT_DIR=""
        if [ "$METHOD" == "picas_multi" ]; then
            colcon build --allow-overriding rclcpp --cmake-args -DPICAS=TRUE
            RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_picas_mt${NUM_CORES}_${NUM_LOAD_TASK}/"
            remove_create_dir "$RESULT_DIR"
            source install/setup.bash
            sudo bash -c "source /opt/ros/humble/setup.bash; source /home/atsushi/ros2-picas/install/setup.bash; ros2 run picas_example_mt example_mt -- $RESULT_DIR default_multi 0 $NUM_LOAD_TASK & 1>/dev/null 2>&1 &"
            set_affinity_balance

        elif [ "$METHOD" == "picas_multi_separate" ]; then
            colcon build --allow-overriding rclcpp --cmake-args -DPICAS=TRUE
            RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_picas_mt_separate${NUM_CORES}_${NUM_LOAD_TASK}/"
            remove_create_dir "$RESULT_DIR"
            source install/setup.bash
            sudo bash -c "source /opt/ros/humble/setup.bash; source /home/atsushi/ros2-picas/install/setup.bash; ros2 run picas_example_mt example_mt -- $RESULT_DIR default_multi 1 $NUM_LOAD_TASK 1>/dev/null 2>&1 &"
            set_affinity_balance

        elif [ "$METHOD" == "picas_single" ]; then
            colcon build --allow-overriding rclcpp --cmake-args -DPICAS=TRUE
            RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_picas_st${NUM_CORES}_${NUM_LOAD_TASK}/"
            remove_create_dir "$RESULT_DIR"
            sudo bash -c "source /opt/ros/humble/setup.bash; source /home/atsushi/ros2-picas/install/setup.bash; ros2 run picas_example_mt example_mt -- $RESULT_DIR default_single 0 $NUM_LOAD_TASK 1>/dev/null 2>&1 &"
            set_affinity_balance

        elif [ "$METHOD" == "default_multi" ]; then
            colcon build --allow-overriding rclcpp --cmake-args -DPICAS=FALSE
            RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_default_mt${NUM_CORES}_${NUM_LOAD_TASK}/"
            remove_create_dir "$RESULT_DIR"
            source install/setup.bash
            ros2 run picas_example_mt example_mt -- $RESULT_DIR "default_multi" 0 $NUM_LOAD_TASK 1>/dev/null 2>&1 &
            set_affinity_balance

        elif [ "$METHOD" == "default_multi_separate" ]; then
            colcon build --allow-overriding rclcpp --cmake-args -DPICAS=FALSE
            RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_default_mt_separate${NUM_CORES}_${NUM_LOAD_TASK}/"
            remove_create_dir "$RESULT_DIR"
            source install/setup.bash
            ros2 run picas_example_mt example_mt -- $RESULT_DIR "default_multi" 1 $NUM_LOAD_TASK 1>/dev/null 2>&1 &
            set_affinity_balance

        elif [ "$METHOD" == "default_single" ]; then
            colcon build --allow-overriding rclcpp --cmake-args -DPICAS=FALSE
            RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_default_st${NUM_CORES}_${NUM_LOAD_TASK}/"
            remove_create_dir "$RESULT_DIR"
            source install/setup.bash
            ros2 run picas_example_mt example_mt -- $RESULT_DIR "default_single" 0 $NUM_LOAD_TASK 1>/dev/null 2>&1 &
            set_affinity_balance

        elif [ "$METHOD" == "cie" ]; then
            colcon build --allow-overriding rclcpp --cmake-args -DPICAS=FALSE
            RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_cie_${NUM_CORES}_${NUM_LOAD_TASK}/"
            remove_create_dir "$RESULT_DIR"
            # sudo bash -c "source /opt/ros/humble/setup.bash; source /home/atsushi/ros2-picas/install/setup.bash; ros2 run ros2_thread_configurator thread_configurator_node --config-file /home/atsushi/ros2-picas/config_for_case_study.yaml"
            # sudo bash -c "source /opt/ros/humble/setup.bash; source /home/atsushi/ros2-picas/install/setup.bash; ros2 run picas_example_mt example_mt -- /home/atsushi/ros2-picas/results/case_study_cie_4/ callback_isolated 0 $NUM_LOAD_TASK 1>/dev/null 2>&1 &"
        fi

        sleep 3
        TARGET_PROC=$(pgrep -f install/picas_example_mt)
        echo "TARGET_PROC: $TARGET_PROC"
        # taskset -c 5 watch -n 1 ps -p <pid> -o pid,comm,rss,vsz
        sudo perf-custom-6.8 stat -e context-switches -p $TARGET_PROC -o "$RESULT_DIR/perf_stat.txt" &
        sleep $DURATION_S
        sudo kill $TARGET_PROC
    done
done
