import argparse
import matplotlib.pyplot as plt
from collections import defaultdict

def run_analysis(args):
    # Parse the file and return a list of each ROB head entry
    stall_list = parse_file(args.filename)

    stall_events, stall_cause = process_burst(stall_list)
    
    # print(request_list)

    # Plot the results
    plot_results(stall_events, stall_cause, args)

    print("Finished analyzing the stall entries")

def parse_file(filename):
    # Check if the file exists
    try:
        with open(filename, 'r') as f:
            print("READING FILE: ", filename)
            entries = []        
            # Skip the first 2 lines
            next(f)
            next(f)
            for line in f:
                # Ignore blank lines and lines that start with #
                if (line[0] == '#' or line == "\n"):
                    continue

                # split the line into a list of words
                temp = [word.strip() for word in line.split(",")]

                # Convert the hex values to integers
                temp = [int(word, 16) for word in temp]
                # print(temp)

                # Append the list to the entries list
                entries.append(temp)

            return entries
    except Exception as e:
        # Raise an exception if the file does not exist
        raise FileNotFoundError("File does not exist: ", filename)

def process_burst(stall_list):

    total_num_cycles = len(stall_list)
    stall_cycles = 0
    stall_events = defaultdict(int)
    stall_cause = defaultdict(int)

    for entry in stall_list:
        if entry[-1] == 1:
            stall_cycles += 1
            if entry[1] == 1:
                stall_cause["RS FULL"] += 1
            if entry[2] == 1:
                stall_cause["BRANCH RS FULL"] += 1
            if entry[3] == 1:
                stall_cause["ALU RS FULL"] += 1
            if entry[4] == 1:
                stall_cause["SQ FULL"] += 1
            if entry[5] == 1:
                stall_cause["LD RS FULL"] += 1
            if entry[6] == 1:
                stall_cause["BOTH ALU QUEUE FULL"] += 1
            if entry[7] == 1:
                stall_cause["BR QUEUE FULL"] += 1
            if entry[8] == 1:
                stall_cause["DIV QUEUE FULL"] += 1
            if entry[9] == 1:
                stall_cause["MULT QUEUE FULL"] += 1
            if entry[10] == 1:
                stall_cause["MULT BUSY"] += 1
            if entry[11] == 1:
                stall_cause["DIV BUSY"] += 1
            if entry[12] == 1:
                stall_cause["FREE LIST EMPTY"] += 1
            if entry[13] == 1:
                stall_cause["FETCH QUEUE EMPTY"] += 1   
            if entry[14] == 1:
                stall_cause["ROB FULL"] += 1

        if entry[1] == 1:
            stall_events["RS FULL"] += 1
        if entry[2] == 1:
            stall_events["BRANCH RS FULL"] += 1
        if entry[3] == 1:
            stall_events["ALU RS FULL"] += 1
        if entry[4] == 1:
            stall_cause["SQ FULL"] += 1
        if entry[5] == 1:
            stall_cause["LD RS FULL"] += 1
        if entry[6] == 1:
            stall_events["BOTH ALU QUEUE FULL"] += 1
        if entry[7] == 1:
            stall_events["BR QUEUE FULL"] += 1
        if entry[8] == 1:
            stall_events["DIV QUEUE FULL"] += 1
        if entry[9] == 1:
            stall_events["MULT QUEUE FULL"] += 1
        if entry[10] == 1:
            stall_events["MULT BUSY"] += 1
        if entry[11] == 1:
            stall_events["DIV BUSY"] += 1
        if entry[12] == 1:
            stall_events["FREE LIST EMPTY"] += 1
        if entry[13] == 1:
            stall_events["FETCH QUEUE EMPTY"] += 1
        if entry[14] == 1:
            stall_events["ROB FULL"] += 1
        if entry[15] == 1:
            stall_events["DISPATCH STALL"] += 1
        

    print("Total number of cycles: ", total_num_cycles)
    print("Total number of stall cycles: ", stall_cycles)
    return stall_events, stall_cause

def plot_results(stall_events, stall_cause, args):
    # First plot the different stall causes on a histogram
    fig, ax = plt.subplots()
    ax.bar(stall_cause.keys(), stall_cause.values())
    ax.set_xlabel("Stall Cause")
    ax.set_ylabel("Number of Stalls")
    ax.set_title("Stall Causes")
    plt.xticks(rotation=90)
    plt.tight_layout()
    plt.savefig(args.output_name + "_stall_cause.png")

    # Now plot the stall events
    fig, ax = plt.subplots()
    ax.bar(stall_events.keys(), stall_events.values())
    ax.set_xlabel("Frequencies of Tracked Events")
    ax.set_ylabel("Frequency")
    ax.set_title("Event")
    plt.xticks(rotation=90)
    plt.tight_layout()
    plt.savefig(args.output_name + "_tracked_events.png")




if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Analyze the stall conditions")
    parser.add_argument("--filename", type=str, help="The file to analyze", required=False,
                        default='stall_sniffer.log')
    parser.add_argument("--output_name", type=str, help="The name of the output file", required=True)
    
    args = parser.parse_args()

    run_analysis(args)