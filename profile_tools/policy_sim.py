# Spike analyzer tool

# Using https://docs.python.org/3/library/string.html#module-string
# Using https://docs.python.org/3/library/stdtypes.html#tuple
# Using https://docs.python.org/3/tutorial/inputoutput.html for printing
# More sources listed below


NUM_ENTRIES = 2**6

BRANCH_HISTORY_LENGTH = 1

# A list of dictionary with is_branch, pc, pc_if_branch
def process_inst(raw_inst_list):
    ret_list = []

    for inst in raw_inst_list:
        processed_inst = {}

        # Using https://docs.python.org/3/library/stdtypes.html#str.split for split
        split_inst = inst.split()
        
        # Using https://docs.python.org/3/library/functions.html#int for converting hex to int
        processed_inst["pc"] = int(split_inst[3], base=16)
        processed_inst["inst"] = int(split_inst[4].strip("()"), base=16)
        processed_inst["is_branch"] = (((processed_inst["inst"]) % (2 ** 7)) == int("0x63", base=16))

        if(processed_inst["is_branch"]):
            imm11 = (processed_inst["inst"] >> 7) % (2 ** 1);
            imm4_1 = (processed_inst["inst"] >> 8) % (2 ** 4);
            imm10_5 = (processed_inst["inst"] >> 25) % (2 ** 6);
            imm12 = (processed_inst["inst"] >> 31) % (2 ** 1);
            offset = imm4_1 * (2 ** 1) + imm10_5 * (2 ** 5) + imm11 * (2 ** 11) - imm12 * (2 ** 12)
            processed_inst["pc_if_branch"] = processed_inst["pc"] + offset

        ret_list.append(processed_inst)
        
    return ret_list

def get_instr_data(log_file_path):
    # Using https://docs.python.org/3/tutorial/errors.html for try and except structure and also using https://docs.python.org/3/library/functions.html#open
    try:
        # Using https://docs.python.org/3/library/functions.html#open
        data = open(log_file_path, 'r')
        ret_set = []
        for i in data:
            ret_set.append(i)
        return ret_set
    except:
        return []

# N_Gram creator
def create_n_gram_set(input_list, n):
    output_length = len(input_list) - n + 1
    output = []

    for i in range(0, output_length):
        element = []
        
        for offset in range (0, n):
            element.append(input_list [i + offset])
        
        output.append(tuple(element))
    
    return output


# RISC POLICY
# > Forward branches are predicted as not taken
# > Backward branches are predicted as taken
def branch_policy_risc_suggest(instr):
    if(instr["pc_if_branch"] < instr["pc"]):
        return True
    else:
        return False

def branch_policy_risc_suggest_update(instr, was_taken):
    pass



# ALWAYS_TAKEN POLICY
def branch_policy_always_taken(instr):
    return True;

def branch_policy_always_taken_update(instr, was_taken):
    pass



# 2 BIT SATURATING COUNTER POLICY
counter = [0]*NUM_ENTRIES

def branch_policy_2_bit_saturating_1_entry(instr):
    counter_index = (instr["pc"] >> 2) % NUM_ENTRIES;
    if(counter[counter_index] >= 2):
        return True
    else:
        return False

def branch_policy_2_bit_saturating_1_entry_update(instr, was_taken):
    counter_index = (instr["pc"] >> 2) % NUM_ENTRIES;
    if(was_taken and (counter[counter_index] < 3)):
        counter[counter_index] = counter[counter_index] + 1
    elif((not was_taken) and (counter[counter_index] > 0)):
        counter[counter_index] = counter[counter_index] - 1

# 2-LEVEL
branch_policy = [0] * NUM_ENTRIES
branch_history = [0]


def branch_policy_2_level(instr):
    counter_index = (instr["pc"] >> 2) % int(NUM_ENTRIES / (2 ** BRANCH_HISTORY_LENGTH))
    counter_index = branch_history[0] + (counter_index << BRANCH_HISTORY_LENGTH)
    if(branch_policy[counter_index] >= 2):
        return True
    else:
        return False

def branch_policy_2_level_update(instr, was_taken):
    counter_index = (instr["pc"] >> 2) % int(NUM_ENTRIES / (2 ** BRANCH_HISTORY_LENGTH))
    counter_index = branch_history[0] + (counter_index << BRANCH_HISTORY_LENGTH)

    if(was_taken and (branch_policy[counter_index] < 3)):
        branch_policy[counter_index] = branch_policy[counter_index] + 1
    elif((not was_taken) and (branch_policy[counter_index] > 0)):
        branch_policy[counter_index] = branch_policy[counter_index] - 1
    
    if(was_taken):
        branch_history[0] = (branch_history[0] << 1) + 1
    else:
        branch_history[0] = (branch_history[0] << 1) + 0
    
    branch_history[0] = branch_history[0] % (2 ** BRANCH_HISTORY_LENGTH)



# GSHARE
branch_policy_2 = [0] * NUM_ENTRIES
branch_history_2 = [0]

def branch_policy_gshare(instr):
    counter_index = (instr["pc"] >> 2) ^ branch_history_2[0]
    counter_index = counter_index % int(NUM_ENTRIES)
    if(branch_policy_2[counter_index] >= 2):
        return True
    else:
        return False

def branch_policy_gshare_update(instr, was_taken):
    counter_index = (instr["pc"] >> 2) ^ branch_history_2[0]
    counter_index = counter_index % int(NUM_ENTRIES)

    if(was_taken and (branch_policy_2[counter_index] < 3)):
        branch_policy_2[counter_index] = branch_policy_2[counter_index] + 1
    elif((not was_taken) and (branch_policy_2[counter_index] > 0)):
        branch_policy_2[counter_index] = branch_policy_2[counter_index] - 1
    
    if(was_taken):
        branch_history_2[0] = (branch_history_2[0] << 1) + 1
        # print (branch_history_2[0])
    else:
        branch_history_2[0] = (branch_history_2[0] << 1) + 0
    
    branch_history_2[0] = branch_history_2[0] % (2 ** 20)


def get_accuracy(pair_inst, predict, update, delay=5):
    num_pairs = 0
    num_branch = 0

    num_correct = 0
    num_wrong = 0
    update_queue = []

    for (a, b) in pair_inst:
        # Label if the pair is a forward branch, backward branch, or neither
        if(a["is_branch"]):
            num_branch += 1

            branch_taken = (a["pc_if_branch"] == b["pc"])

            pred_branch_taken = predict(a)

            update_queue.append([a, branch_taken, num_pairs + delay])

            if(branch_taken == pred_branch_taken):
                num_correct += 1
            else:
                num_wrong += 1
        
        while(len(update_queue) > 0 and update_queue[0][2] <= num_pairs):
            update(update_queue[0][0], update_queue[0][1])
            del update_queue[0]
        
        num_pairs += 1

    return (num_pairs, num_branch, num_correct, num_wrong)

FILE_PATH = "spike/spike.log"

raw_data = get_instr_data(FILE_PATH)

processed_data = process_inst(raw_data)

pair_inst = create_n_gram_set(processed_data, 2)

print(f"\nNumber of Instructions, ignoring the last instruction is {len(pair_inst)}")

output = get_accuracy(pair_inst, branch_policy_always_taken, branch_policy_always_taken_update)

print(f"Always taken accuracy is \t\t\t {output[2] / (output[2] + output[3])}")

output = get_accuracy(pair_inst, branch_policy_risc_suggest, branch_policy_risc_suggest_update)

print(f"Risc-v suggestion accuracy is \t\t\t {output[2] / (output[2] + output[3])}")

output = get_accuracy(pair_inst, branch_policy_2_bit_saturating_1_entry, branch_policy_2_bit_saturating_1_entry_update)

print(f"Saturating Counter accuracy, with {NUM_ENTRIES} entries, is {output[2] / (output[2] + output[3])}")

output = get_accuracy(pair_inst, branch_policy_2_level, branch_policy_2_level_update)

print(f"2-level accuracy, with {NUM_ENTRIES} entries, is {output[2] / (output[2] + output[3])}")

print(f"Ignoring the last instruction, \t\t\t {output[1] / output[0]} of instructions are branches\n")

