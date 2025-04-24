# Script will run sim on testcode files, then run the burst and rob sniffers

import os
import argparse
import pdb
from pathlib import Path

def gather_test_files(args):
    # Walk the testcode directory and get the names of all the testcode files
    testcode_files = []
    for root, dirs, files in os.walk(args.testcode_dir):
        for file in files:
            if file.endswith(".c") or file.endswith(".elf") or file.endswith(".s"):
                # Check if there is a file with the same name but different extension
                # If there is, don't add the new file
                name_without_extension = os.path.splitext(file)[0]

                # Don't add duplicates
                if (root + "/" + name_without_extension + ".c" in testcode_files) or \
                    (root + "/" + name_without_extension + ".elf" in testcode_files) or \
                    (root + "/" + name_without_extension + ".s" in testcode_files):
                    print("DUPLICATE FILE FOUND: ", root + "/" + name_without_extension + ".c")
                    continue

                # Check that root ends with a slash
                if (root[-1] != "/"):
                    testcode_files.append(root + "/" + file)
                else:
                    testcode_files.append(root + file)
                
                # pdb.set_trace()

    print("Testcode files found: ", testcode_files)

    return testcode_files

def run_sim(args, testcode_files):
    # For debugging
    # testcode_files = ["/home/bikrant2/fa24_ece411_Core_Melters/mp_ooo/testcode/cp3_release_benches/fft.c"]

    # pdb.set_trace()
    
    # Make clean the sim directory
    os.chdir(args.sim_dir)
    os.system("make clean")

    for testcode_file in testcode_files:
        # Run the sim on all the testcode files
        os.chdir(args.sim_dir)
        
        testcode_file_without_extension = os.path.splitext(os.path.basename(testcode_file))[0]

        # Print out the testcode file being run
        print("\n\n\nRUNNING SIM ON: ", testcode_file, "\n")

        # Go to the output directory and delete the folder that is the name of the testcode file without extension if it exists
        if (os.path.exists(args.output_dir + "/" + testcode_file_without_extension)):
            os.system("rm -rf " + args.output_dir + testcode_file_without_extension)
        
        
        os.mkdir(args.output_dir + testcode_file_without_extension)

        # Run the sim and pipe the output to the new folder: "make run_vcs_top_tb PROG="
        os.system("make run_vcs_top_tb PROG=" + testcode_file + " | tee " + args.output_dir + testcode_file_without_extension + "/sim_output.txt")

        # pdb.set_trace()

        # Run spike -- choose the elf file based on whether the testcode file is an .elf or a .c/.s file
        if (testcode_file.endswith(".elf")):
            os.system("make spike ELF=" + testcode_file)
        else:
            os.system("make spike ELF=" + "./bin/" + testcode_file_without_extension + ".elf")
        os.system("diff -s spike/commit.log spike/spike.log > " + args.output_dir + testcode_file_without_extension + "/spike_diff.txt")


        # Move the generated log files (.log files in the perf_counter folder) to the new output folder
        os.system("mv ../perf_counter/*.log " + args.output_dir + testcode_file_without_extension)

        # pdb.set_trace()

        # Change to the perf counter directory
        os.chdir("../perf_counter")

        # Disable write permissions on the log files
        os.system("chmod a-w " + args.output_dir + testcode_file_without_extension + "/*.log")

        # pdb.set_trace()

        # Run the burst sniffer on the log files
        os.system("python3 ../perf_counter/burst_sniff.py --filename \"" + args.output_dir + testcode_file_without_extension + "/burst_sniffer.log\" --output_name \"" + testcode_file_without_extension + "\" | tee " + args.output_dir + testcode_file_without_extension + "/burst_sniff_py.log")

        # pdb.set_trace()

        # Run the fetch queue sniffer
        os.system("python3 ../perf_counter/fetch_q_sniffer.py --filename \"" + args.output_dir + testcode_file_without_extension + "/fetch_q_sniffer.log\" | tee " + args.output_dir + testcode_file_without_extension + "/fetch_q_sniff_py.log")

        # pdb.set_trace()

        # Run the ROB sniffer
        os.system("python3 ../perf_counter/rob_sniff.py --filename \"" + args.output_dir + testcode_file_without_extension + "/rob_sniffer.log\" --output_name \"" + testcode_file_without_extension + "\" | tee " + args.output_dir + testcode_file_without_extension + "/rob_sniff_py.log")

        # pdb.set_trace()

        # Run the stall sniffer
        os.system("python3 ../perf_counter/stall_sniff.py --filename \"" + args.output_dir + testcode_file_without_extension + "/stall_sniffer.log\" --output_name \"" + testcode_file_without_extension + "\" | tee " + args.output_dir + testcode_file_without_extension + "/stall_sniff_py.log")

        # Move all the generated plots to the output folder
        os.system("mv ../perf_counter/*.png " + args.output_dir + testcode_file_without_extension)

        print("\n\n\nFinished running sim and analysis on: ", testcode_file, "\n\n\n")

        # pdb.set_trace()
    


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run the performance counter script')
    parser.add_argument('--output_dir', type=str, help='The testcode file to run the sim on', required=False,
                        default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/perf_counter/output/")
    parser.add_argument('--testcode_dir', type=str, help='The directory containing the testcode files', required=False,
                        default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/testcode/")
    parser.add_argument('--sim_dir', type=str, help='The directory containing the sim files', required=False,
                        default=f"{str(Path.home())}/fa24_ece411_Core_Melters/mp_ooo/sim/")
    
    args = parser.parse_args()

    testcode_files = gather_test_files(args)
    run_sim(args, testcode_files)
