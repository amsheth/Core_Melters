# Using https://matplotlib.org/stable/api/pyplot_summary.html#module-matplotlib.pyplot for code snippets

import argparse
import matplotlib.pyplot as plt

def run_analysis(filename):
    # Parse the file and return a list of each entry
    data = parse_file(filename)

    # Analyze the queue entry
    processed_data = analyzer(data)

    # Plot the results
    
    plot_results(processed_data)

    plot_time_series_results(processed_data)
    
    


def parse_file(filename):
    # Check if the file exists
    try:
        with open(filename, 'r') as f:
            print("READING FILE: ", filename)
            entries = []        
            # Skip the first line
            next(f)
            for line in f:
                # split the line into a list of words
                entries.append([word.strip() for word in line.split(",")])

            return entries

    except Exception as e:
        # Raise an exception if the file does not exist
        raise FileNotFoundError("File does not exist: ", filename)

def analyzer(data):
    # Iterate over the list of Fetch Q length
    queue_length = []
    size = 0

    for entry in data:
        if(int(entry[1],16) == 1):
            size += 1
        if(int(entry[2],16) == 1):
            size += -1
        if(int(entry[0],16) == 1):
            size = 0
        queue_length.append(size)
            
    return queue_length

def plot_results(processed_data):
    # Plot the fetch q length
    plt.hist(processed_data, bins=range(min(processed_data), max(processed_data) + 2), edgecolor='black')
    plt.title("Distribution of fetch queue size")
    plt.xlabel("# Elements in Fetch Queue")
    plt.ylabel("Frequency")
    

    # Save the plot
    plt.savefig("fetch_q_size_hist.png")
    # plt.show()

def plot_time_series_results(processed_data):
    # Plot the fetch q length
    plt.plot([i for i in range(0, len(processed_data))], processed_data)
    plt.title("Fetch queue size over time")
    plt.xlabel("Time")
    plt.ylabel("# Elements in Fetch Queue")
    

    # Save the plot
    plt.savefig("fetch_q_size_plot.png")
    # plt.show()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fetch Q Sniffer')
    parser.add_argument('--filename', type=str, help='File to read', required=False,
                        default='fetch_q_sniffer.log')
    
    args = parser.parse_args()
    
    run_analysis(args.filename)