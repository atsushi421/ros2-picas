METHODS=(
    "picas_multi"
    "picas_multi_separate"
    "picas_single"
    "default_multi"
    "default_multi_separate"
    "default_single"
)
NUM_CORES=4
DURATION_S=300

function remove_create_dir() {
    DIR=$1
    if [ -d "$DIR" ]; then
        rm -rf "$DIR"
    fi
    mkdir -p "$DIR"
}

TARGET_PROC=""
PERF_PROC=""
trap 'sudo kill $TARGET_PROC $PERF_PROC; exit 0' SIGINT SIGTERM

for METHOD in "${METHODS[@]}"; do
    echo "=========================="
    echo "METHOD: $METHOD"
    echo "=========================="

    rm -rf build install log
    source /opt/ros/humble/setup.bash

    RESULT_DIR=""
    if [ "$METHOD" == "picas_multi" ]; then
        colcon build --allow-overriding rclcpp --cmake-args -DPICAS=TRUE
        RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_picas_mt${NUM_CORES}/"
        remove_create_dir "$RESULT_DIR"
        source install/setup.bash
        taskset -c 1-4 ros2 run picas_example_mt example_mt -- $RESULT_DIR "default_multi" 1>/dev/null 2>&1 &

    elif [ "$METHOD" == "picas_multi_separate" ]; then
        colcon build --allow-overriding rclcpp --cmake-args -DPICAS=TRUE
        RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_picas_mt_separate${NUM_CORES}/"
        remove_create_dir "$RESULT_DIR"
        source install/setup.bash
        taskset -c 1-4 ros2 run picas_example_mt example_mt -- $RESULT_DIR "default_multi" 1 1>/dev/null 2>&1 &

    elif [ "$METHOD" == "picas_single" ]; then
        colcon build --allow-overriding rclcpp --cmake-args -DPICAS=TRUE
        RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_picas_st${NUM_CORES}/"
        remove_create_dir "$RESULT_DIR"
        sudo bash -c "source /opt/ros/humble/setup.bash; source /home/atsushi/ros2-picas/install/setup.bash; ros2 run picas_example_mt example_mt -- $RESULT_DIR default_single 1>/dev/null 2>&1 &"

    elif [ "$METHOD" == "default_multi" ]; then
        colcon build --allow-overriding rclcpp --cmake-args -DPICAS=FALSE
        RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_default_mt${NUM_CORES}/"
        remove_create_dir "$RESULT_DIR"
        source install/setup.bash
        taskset -c 1-4 ros2 run picas_example_mt example_mt -- $RESULT_DIR "default_multi" 1>/dev/null 2>&1 &

    elif [ "$METHOD" == "default_multi_separate" ]; then
        colcon build --allow-overriding rclcpp --cmake-args -DPICAS=FALSE
        RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_default_mt_separate${NUM_CORES}/"
        remove_create_dir "$RESULT_DIR"
        source install/setup.bash
        taskset -c 1-4 ros2 run picas_example_mt example_mt -- $RESULT_DIR "default_multi" 1 1>/dev/null 2>&1 &

    elif [ "$METHOD" == "default_single" ]; then
        colcon build --allow-overriding rclcpp --cmake-args -DPICAS=FALSE
        RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_default_st${NUM_CORES}/"
        remove_create_dir "$RESULT_DIR"
        source install/setup.bash
        taskset -c 1-4 ros2 run picas_example_mt example_mt -- $RESULT_DIR "default_single" 1>/dev/null 2>&1 &

    elif [ "$METHOD" == "cie" ]; then
        colcon build --allow-overriding rclcpp --cmake-args -DPICAS=FALSE
        RESULT_DIR="/home/atsushi/ros2-picas/results/case_study_cie_${NUM_CORES}/"
        remove_create_dir "$RESULT_DIR"
        # sudo bash -c "source /opt/ros/humble/setup.bash; source /home/atsushi/ros2-picas/install/setup.bash; ros2 run ros2_thread_configurator thread_configurator_node --config-file /home/atsushi/ros2-picas/config_for_case_study.yaml"
        # sudo bash -c "source /opt/ros/humble/setup.bash; source /home/atsushi/ros2-picas/install/setup.bash; ros2 run picas_example_mt example_mt -- /home/atsushi/ros2-picas/results/case_study_cie_4/ callback_isolated"
    fi

    sleep 3
    TARGET_PROC=$(pgrep -f install/picas_example_mt)
    echo "TARGET_PROC: $TARGET_PROC"
    # taskset -c 5 watch -n 1 ps -p <pid> -o pid,comm,rss,vsz
    sudo perf-custom-6.8 stat -e context-switches -p $TARGET_PROC -o "$RESULT_DIR/perf_stat.txt" &
    PERF_PROC=$!
    sleep $DURATION_S
    sudo kill $TARGET_PROC $PERF_PROC
    wait $TARGET_PROC
done
