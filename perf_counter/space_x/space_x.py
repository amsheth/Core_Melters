import argparse
from pathlib import Path
import random
import os
import subprocess
import pdb
import time

RANDOM_SEED = 42

I_CACHE_NUM_SETS = [32]
D_CACHE_NUM_SETS = [32]
I_CACHE_NUM_WAYS = [1]
D_CACHE_NUM_WAYS = [2, 4, 8]
RAS_SIZE = [4, 8]
BP_GHR_BITS = [1, 2, 3]
FETCH_Q_SIZE = [8, 16, 32]
# FREE_LIST_SIZE = [2, 4, 8, 16, 32]
ALU_RES_STATION_SIZE = [2, 4, 6, 8]
BRANCH_RES_STATION_SIZE = [2, 4, 8]
MULT_DIV_RES_STATION = [2, 4, 8]
ROB_SIZE = [2, 8, 32]
LOAD_RES_STATION = [2, 4, 8]
STORE_QUEUE_SIZE = [2, 4, 8]
MULT_NUM_STAGES = [4, 6]
DIV_NUM_STAGES = [33]

def gather_test_files(args):
    # Walk the testcode directory and get the names of all the testcode files
    testcode_files = []
    for root, dirs, files in os.walk(args.testcode_dir):
        for file in files:
            if file.endswith(".c") or file.endswith(".elf") or file.endswith(".s"):
                # Check if there is a file with the same name but different extension
                # If there is, don't add the new file
                name_without_extension = os.path.splitext(file)[0]

                # Only add .elf files
                if (file.endswith(".elf")):
                    # Check that root ends with a slash
                    if (root[-1] != "/"):
                        testcode_files.append(root + "/" + file)
                    else:
                        testcode_files.append(root + file)
                
                # pdb.set_trace()

    print("Testcode files found: ", testcode_files)

    return testcode_files

def generate_params(args):

    # Check if the output folder exists
    if not os.path.exists(args.output_dir):
        os.mkdir(args.output_dir)

    all_params = list()

    for icache_set in I_CACHE_NUM_SETS:
        for dcache_set in D_CACHE_NUM_SETS:    
            for icache_ways in I_CACHE_NUM_WAYS:
                for dcache_ways in D_CACHE_NUM_WAYS:
                    for ras_size in RAS_SIZE:
                        for bp_size in BP_GHR_BITS:
                            for fetch_q_size in FETCH_Q_SIZE:
                                # for free_list_size in FREE_LIST_SIZE:
                                for alu_res_station_size in ALU_RES_STATION_SIZE:
                                    for branch_res_station_size in BRANCH_RES_STATION_SIZE:
                                        for mult_div_res_station in MULT_DIV_RES_STATION:
                                            for rob_size in ROB_SIZE:
                                                for load_res_station in LOAD_RES_STATION:
                                                    for store_queue_size in STORE_QUEUE_SIZE:
                                                        for NUM_MULT in MULT_NUM_STAGES:
                                                            for NUM_DIV in DIV_NUM_STAGES:
                                                                params = {}
                                                                params["PARAM_NUM_I_SETS"] = icache_set
                                                                params["PARAM_NUM_I_WAYS"] = icache_ways
                                                                params["PARAM_NUM_D_SETS"] = dcache_set
                                                                params["PARAM_NUM_D_WAYS"] = dcache_ways
                                                                params["PARAM_RAS_SIZE"] = ras_size
                                                                params["PARAM_BP_GHR_BITS"] = bp_size
                                                                params["PARAM_FETCH_Q_SIZE"] = fetch_q_size
                                                                # params["PARAM_FREE_LIST_SIZE"] = free_list_size
                                                                params["PARAM_ALU_RES_STATION_SIZE"] = alu_res_station_size
                                                                params["PARAM_BRANCH_RES_STATION_SIZE"] = branch_res_station_size
                                                                params["PARAM_MULT_DIV_RES_STATION"] = mult_div_res_station
                                                                params["PARAM_ROB_SIZE"] = rob_size
                                                                params["PARAM_LOAD_RES_STATION"] = load_res_station
                                                                params["PARAM_STORE_QUEUE_SIZE"] = store_queue_size
                                                                params["PARAM_MULT_NUM_STAGES"] = NUM_MULT
                                                                params["PARAM_DIV_NUM_STAGES"] = NUM_DIV

                                                                all_params.append(params)


    id = 0

    os.chdir(args.sim_dir)
    os.system("make clean")

    # Randomly arrange the parameters
    random.seed(RANDOM_SEED)
    random.shuffle(all_params)

    if (args.num_runs > 0):
        subset_to_run = all_params[:args.num_runs]
    else:
        subset_to_run = all_params

    start = args.resume_at if (args.resume_at != 0) else args.user_id * (args.num_runs // args.num_users)
    end = (args.user_id + 1) * (args.num_runs // args.num_users)

    subset_to_run = subset_to_run[start:end]


    if (args.resume_at == 0):
        # os.system("rm *.log")
        os.system("rm results_*.csv")

    test_files = gather_test_files(args)

    id = start

    start_time = time.time()

    # pdb.set_trace()
    
    try:
        for i in range(len(subset_to_run)):
            print("Running simulation on run ", id)
            # pdb.set_trace()
            for test in test_files:
                testcode_file_without_extension = os.path.splitext(test)[0].split("/")[-1]
                with open(f"results_{testcode_file_without_extension}.csv", "a") as out_file:

                    # print(f"RUNNING SIM ON TEST {test}")

                    create_param_file(args, subset_to_run[i])
                    
                    # os.system("make run_verilator_top_tb PROG=" + args.test_file + " | tee " + args.output_dir + testcode_file_without_extension + f"/sim_output_{id}.txt")
                    os.system("make run_verilator_top_tb PROG=" + test + f" | grep \"IPC\" > temp_output_{id}.log")

                    ipc = 0

                    # Search the output file for "Monitor: Segment IPC:" and print the IPC
                    with open(f"temp_output_{id}.log", "r") as f:
                       for line in f.readlines():
                            if "Monitor: Segment IPC:" in line:
                                # Convert the last word to a float
                                ipc = float(line.split()[-1])
                                break

                    # print("IPC:", ipc)

                    if (i == 0):
                        # Output the parameters in CSV format
                        out_file.write("IPC,")
                        for key in subset_to_run[i]:
                            out_file.write(f"{key},")
                        out_file.write(f"ID")
                        out_file.write("\n")

                    # Output the IPC and the parameters in CSV format
                    out_file.write(f"{ipc},")
                    for key in subset_to_run[i]:
                        out_file.write(f"{subset_to_run[i][key]},")
                    out_file.write(f"{id}")
                    out_file.write("\n")

                out_file.close()

                # create_param_file(args, subset_to_run[i])
                    
                # # os.system("make run_verilator_top_tb PROG=" + args.test_file + " | tee " + args.output_dir + testcode_file_without_extension + f"/sim_output_{id}.txt")
                # os.system("make run_verilator_top_tb PROG=" + test + f" | grep \"IPC\" > temp_output_{id}.log")

                # ipc = 0

                # # Search the output file for "Monitor: Segment IPC:" and print the IPC
                # with open(f"temp_output_{id}.log", "r") as f:
                #     for line in f.readlines():
                #         if "Monitor: Segment IPC:" in line:
                #             # Convert the last word to a float
                #             ipc = float(line.split()[-1])
                #             break

                # # print("IPC:", ipc)

                # # Output the IPC and the parameters
                # out_file.write("IPC: " + str(ipc) + " PARAMS: " + str(subset_to_run[i]) + "\n")

            # print("SIMULATION FINISHED ON RUN ", id)

            id += 1
    except KeyboardInterrupt:
        print("Keyboard interrupt detected. Exiting...")
        sys.exit(0)

    end_time = time.time()
    print("Total time taken: ", end_time - start_time)

    os.system("rm temp_output_*.log")


def create_param_file(args, params):
    with open(args.params_file_path, "w") as f:
        # Write the sysverilog package
        f.write("package exploration_params;\n")
        for key in params:
            f.write(f"\tlocalparam {key} = {params[key]};\n")

        f.write("endpackage : exploration_params\n")
        f.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--params_file_path', type=str, required=False,
                        default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/pkg/parameters.sv")
    parser.add_argument('--test_file', type=str, required=False,
                        default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/testcode/coremark_im.elf")
                        # default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/small_testcases/ooo_test.s")
    parser.add_argument('--output_dir', type=str, help='The testcode file to run the sim on', required=False,
                        default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/space_exploration/output/")
    parser.add_argument('--testcode_dir', type=str, help='The directory containing the testcode files', required=False,
                        default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/testcode/")
    parser.add_argument('--sim_dir', type=str, help='The directory containing the sim files', required=False,
                        default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/sim/")
    parser.add_argument('--spike', type=bool, help='Whether to run spike', required=False, default=False)
    parser.add_argument('--synth', type=bool, help='Whether to run synthesis', required=False, default=False)
    parser.add_argument('--synth_dir', type=str, help='The directory containing the synthesis files', required=False,
                        default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/synth/")
    parser.add_argument('--verilator', type=bool, help='Whether to run verilator', required=False, default=False)
    parser.add_argument('--num_users', type=int, help='The number of users running the script', required=True)
    parser.add_argument('--user_id', type=int, help='The id of the user running the script', required=True)
    parser.add_argument('--num_runs', type=int, help='The number of runs to do', required=True)
    parser.add_argument('--resume_at', type=int, help='The run to resume at', required=False, default=0)

    
    args = parser.parse_args()

    generate_params(args)

    # python3 space_x.py --num_users 1 --user_id 0 --num_runs 5

