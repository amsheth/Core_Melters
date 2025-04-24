import argparse
import matplotlib.pyplot as plt

MULT = int('0111011', 2)
DIV =  int('0111111', 2)
NUM_BINS = 6

def run_analysis(filename):
    # Parse the file and return a list of each ROB head entry
    rob_entries_list = parse_file(filename)

    # Analyze the ROB entries and return a list of ROB entries that are waiting
    instr_wait_tracker = analyzer(rob_entries_list)

    # Plot the results
    plot_results(instr_wait_tracker, args)

    # Plot by opcode
    plot_by_opcode(instr_wait_tracker, args)

    print("Finished analyzing the ROB entries")

def parse_file(filename):
    # Check if the file exists
    try:
        with open(filename, 'r') as f:
            print("READING FILE: ", filename)
            entries = []        

            num_commits = 0

            # Skip the first line
            next(f)
            for line in f:
                # split the line into a list of words
                entries.append([word.strip() for word in line.split(",")])
                if (line[:9] == "0x0, 0x1,"):
                    num_commits += 1


            # print(len(entries))
            # print("COMMIT TOTAL", num_commits)

            return entries

    except Exception as e:
        # Raise an exception if the file does not exist
        raise FileNotFoundError("File does not exist: ", filename)

def analyzer(rob_entries_list):
    # is_waiting = False
    wait_cycles = 0
    num_branches = 0
    num_mispredicts = 0
    cycles_rob_empty = 0
    cycles_rob_full = 0
    total_cycles = 0
    prev_order = -1
    num_instructions = 0
    instr_wait_tracker = []

    # print(f"ROB Entry list length {len(rob_entries_list)}")

    num_lines = 0

    # Iterate over the list of ROB entries
    for entry in rob_entries_list:
        num_lines += 1
        try:
            # Check if the entry is invalid, and skip this entry
            if entry[3] == "0xxx" or entry[3] == "opcode":
                # print("Invalid entry: ", entry)
                continue

            rob_rst = int(str(entry[0]), 16)
            commit = int(entry[1], 16)
            mispred = int(entry[2], 16)
            # Branch misprediction case
            # if (mispred == 1 and commit == 1):
            #     # Add to the number of mispredictions
            #     num_mispredicts += 1
            #     num_branches += 1

            #     # Reset the number of wait cycles, continue to next entry
            #     wait_cycles = 0
            #     continue

            opcode = int(entry[3], 16)
            # Check if the instruction is ALU, MULT, or DIV
            if (opcode == int('0110011', 2)):
                # This is an ALU instruction -- use custom encoding to mark mults and divs
                # Convert inst from hex to binary
                inst = bin(int(entry[8], 16))[2:].zfill(32)

                # Check the first 7 characters of the instruction to determine if it is a mult or div
                if (inst[:7] == '0000001'):
                    # Check the funct3 value to determine mult vs div
                    if (inst[17:20] in ['000', '001', '010', '011']):
                        opcode = MULT
                    else:
                        opcode = DIV
            # Check if the instruction is a branch instruction
            if (opcode == int('1100011', 2) and commit == 1):
                # This is a branch instruction
                num_branches += 1
                if (mispred == 1): # Not a necessary check since we checked for mispred earlier
                    num_mispredicts += 1

            pc = int(entry[4], 16)
            pc_next = int(entry[5], 16)
            pc_calc = entry[6] # This is a string until the value is ready to be committed
            order = int(entry[7], 16)
            if (commit == 1 and prev_order != order):
                prev_order = order
                num_instructions += 1
            inst = int(entry[8], 16)
            rob_empty = int(entry[9], 16)
            rob_full = int(entry[10], 16)
            rob_empty = int(entry[9], 16)
            rob_full = int(entry[10], 16)

            if commit == 1:
                # This is a "commit" instruction
                # is_waiting = False
                instr_wait_tracker.append([rob_rst, commit, mispred, opcode, pc, pc_next, int(pc_calc, 16), order, inst, wait_cycles])
                wait_cycles = 0
            elif rob_empty != 1:
                # This is a "waiting" instruction
                # is_waiting = True
                wait_cycles += 1
            elif rob_empty == 1:
                # The ROB is empty
                cycles_rob_empty += 1
                wait_cycles = 0
            
            if rob_full == 1:
                # The ROB is full
                cycles_rob_full += 1

            total_cycles += 1
        except ValueError as e:
            print(f"Error processing entry {entry}: {e}")

    if (num_branches == 0):
        print("No branches found")
    else:     
        print("Branch prediction accuracy: ", 1 - num_mispredicts / num_branches)
    print(f"ROB empty percentage {cycles_rob_empty / total_cycles * 100}%")
    print(f"ROB full percentage {cycles_rob_full / total_cycles * 100}%")
    print(f"Total number instructions: {num_instructions}")
    print(f"Last order {prev_order}")
    print(f"Length of inst wait tracker {len(instr_wait_tracker)}")
    print("NUM LINES", num_lines)

    return instr_wait_tracker

def plot_results(instr_wait_tracker, args):
    # Plot the distrbution of waiting cycles
    wait_cycles = [entry[-1] for entry in instr_wait_tracker]
    plt.hist(wait_cycles, bins=range(min(wait_cycles), max(wait_cycles) + 2), edgecolor='black')
    plt.title("Distribution of Waiting Cycles")
    plt.xlabel("Cycles")
    plt.ylabel("Frequency")
    

    # Save the plot
    plt.savefig(f"waiting_cycles_{args.output_name}.png")

def plot_by_opcode(instr_wait_tracker, args):
    
    # Create a dictionary to store the waiting cycles for each opcode

    opcode_to_index= {}

    # Map ALU instructions to index 0
    opcode_to_index[int('0110111', 2)] = 0 # lui
    opcode_to_index[int('0010111', 2)] = 0 # auipc
    opcode_to_index[int('0010011', 2)] = 0 # imm
    opcode_to_index[int('0110011', 2)] = 0 # reg

    # Map Load instructions to index 1
    opcode_to_index[int('0000011', 2)] = 1 # load
    
    # Map JAL, JALR, and BRANCH instructions to index 2
    opcode_to_index[int('1101111', 2)] = 2 # jal
    opcode_to_index[int('1100111', 2)] = 2 # jalr
    opcode_to_index[int('1100011', 2)] = 2 # branch

    # Map MULT to index 3
    opcode_to_index[MULT] = 3

    # Map DIV to index 4
    opcode_to_index[DIV] = 4

    # Map Store instructions to index 5
    opcode_to_index[int('0100011', 2)] = 5 # store

    # Mapping of opcode index to name of opcode
    opcode_index_to_name = {0: "ALU", 1: "Load", 2: "Branch/Jump", 3: "Mult", 4: "Div", 5:"Store"}

    # Create a list that contains tuples mapping the opcode to the waiting cycles
    opcode_wait_cycles = [[] for i in range(NUM_BINS)]

    # Iterate over the list of ROB entries
    for entry in instr_wait_tracker:
        opcode = entry[3]
        wait_cycles = entry[-1]

        # Append the waiting cycles to the corresponding opcode
        opcode_wait_cycles[opcode_to_index[opcode]].append(wait_cycles)

    # Create 5 separate subplots for each opcode
    fig, axs = plt.subplots(3, 2, figsize=(15, 15))
    fig.suptitle("Number of Cycles on ROB Head for Each Opcode")

    # Plot the distrbution of waiting cycles for each opcode (5 total plots)
    for i in range(3):
        for j in range(2):
            if i * 2 + j < NUM_BINS:
                # Check if the list is empty
                if len(opcode_wait_cycles[i * 2 + j]) == 0:
                    continue
                min_cycle = min(opcode_wait_cycles[i * 2 + j])
                max_cycle = max(opcode_wait_cycles[i * 2 + j])
                bins = range(0, max_cycle + 2, 1)
                axs[i, j].hist(opcode_wait_cycles[i * 2 + j], bins=bins, edgecolor='black', rwidth=0.8, align='left')    
                axs[i, j].set_title(opcode_index_to_name[i * 2 + j])
                axs[i, j].set_xlabel("Cycles")
                axs[i, j].set_xticks(range(0, max_cycle + 2, 1))
                axs[i, j].set_ylabel("Frequency")
            
    # Save the plot
    plt.savefig(f"waiting_cycles_by_opcode_{args.output_name}.png")

    # ALU opcode binary to LUI, AUIPC, IMM, REG
    opcode_bin_to_str = {int('0110111', 2): "lui", int('0010111', 2): "auipc", int('0010011', 2): "imm", int('0110011', 2): "reg"}

    # Print out the order of ALU outliers
    for entry in instr_wait_tracker:
        if opcode_to_index[entry[3]] == 0 and entry[-1] > 4:
            # Print out the order (in hexadecimal), instruction (in hexadecimal), opcode in binary, and number of cycles waited
            print(f"Order: {hex(entry[7])}, Instruction: {hex(entry[8])}, Opcode: {bin(entry[3])[2:].zfill(7)} -- {opcode_bin_to_str[entry[3]]}, Cycles: {entry[-1]}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='ROB Sniffer')
    parser.add_argument('--filename', type=str, help='File to read', required=False,
                        default='rob_sniffer.log')
    parser.add_argument('--output_name', type=str, help='Name for images', required=True)
    
    args = parser.parse_args()
    
    run_analysis(args.filename)