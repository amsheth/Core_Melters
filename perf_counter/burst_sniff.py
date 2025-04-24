import argparse
import matplotlib.pyplot as plt

def run_analysis(args):
    # Parse the file and return a list of each ROB head entry
    burst_list = parse_file(args.filename)

    request_list = process_burst(burst_list)
    
    # print(request_list)

    # Plot the results
    plot_results(request_list, args)

    print("Finished analyzing the burst controller entries")

def parse_file(filename):
    # Check if the file exists
    try:
        with open(filename, 'r') as f:
            print("READING FILE: ", filename)
            entries = []        
            # Skip the first line
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

def process_burst(burst_list):

    icache_request_active = False # Flag to check if the request is from the instruction cache
    dcache_request_active = False # Flag to check if the request is from the data cache
    total_cycles = 0 # Total number of cycles
    busy_cycles = 0 # Number of cycles the cacheline adapter was busy
    icache_cycles_taken = 1
    dcache_cycles_taken = 1
    request_list = []

    # Iterate through the burst list
    for entry in burst_list:
        rst = entry[0]
        icache_req = entry[1]
        dcache_req = entry[2]
        icache_resp = entry[3]
        dcache_resp = entry[4]

        if (icache_req and not icache_request_active):
            icache_request_active = True
        if (icache_request_active):
            icache_cycles_taken += 1

        if (dcache_req and not dcache_request_active):
            dcache_request_active = True
        if (dcache_request_active):
            dcache_cycles_taken += 1

        if (icache_resp and icache_request_active):
            request_list.append((True, False, icache_cycles_taken))
            icache_request_active = False
            icache_cycles_taken = 1

        if (dcache_resp and dcache_request_active):
            request_list.append((False, True, dcache_cycles_taken))
            dcache_request_active = False
            dcache_cycles_taken = 1

        if (dcache_request_active or icache_request_active):
            busy_cycles += 1

        total_cycles += 1
    
    print(f"Percent of time cacheline adapter was busy: {busy_cycles / total_cycles * 100:.2f}%")

    return request_list

def plot_results(request_list, args):

    # Create a dictionary to store the number of requests for each type
    request_dict = {"imem": 0, "dmem": 0}

    # Iterate through the request list and count the number of requests for each type
    for request in request_list:
        if request[0]:
            request_dict["imem"] += 1
        if request[1]:
            request_dict["dmem"] += 1

    # Create a pie chart
    fig, ax = plt.subplots()
    ax.pie(request_dict.values(), labels=request_dict.keys(), autopct='%1.1f%%')
    ax.axis('equal')  # Equal aspect ratio ensures that pie is drawn as a circle.

    plt.title("Requests from the Burst Controller")
    plt.savefig(f"d_vs_i_cache_traffic_{args.output_name}")
 
    # Create a histogram of the number of cycles to service each request
    fig, ax = plt.subplots(figsize=(16,9))
    cycles_to_complete_request = [request[2] for request in request_list]

    bins = range(0, max(cycles_to_complete_request) + 2, 1)
    ax.hist(cycles_to_complete_request, bins=bins, edgecolor='black', rwidth=0.8, align='left')
    ax.set_title("Number of Cycles to Complete Request")
    ax.set_xlabel("Cycles")
    ax.set_xticks(bins)
    ax.set_ylabel("Frequency")
    plt.savefig(f"cycles_to_complete_request_{args.output_name}")




if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Analyze the Burst controller")
    parser.add_argument("--filename", type=str, help="The file to analyze", required=False,
                        default='burst_sniffer.log')
    parser.add_argument("--output_name", type=str, help="The name of the output file", required=True)
    
    args = parser.parse_args()

    run_analysis(args)