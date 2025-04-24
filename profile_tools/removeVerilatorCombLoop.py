def get_instr_data(log_file_path):
    # Using https://docs.python.org/3/tutorial/errors.html for try and except structure and also using https://docs.python.org/3/library/functions.html#open
    try:
        # Using https://docs.python.org/3/library/functions.html#open
        data = open(log_file_path, 'r')
        ret_set = []
        for i in data:
            ret_set.append(i.strip("\n"))
        return ret_set
    except:
        return []

def get_rid_of_comments(arr):
    ret = []
    for line in arr:
        if(len(line) >= 2 and line.strip(" \t")[0:2] == "//"):
            pass
        else:
            ret.append(line)
    return ret

def get_line_with_vars(arr):
    ret = []
    for line in arr:
        split = line.strip(" \t").split("=")
        for i in range(0, len(split)):
            split[i] = split[i].strip(" \t")
        if(len(split) == 2 and len(split[0]) > 0 and len(split[1]) > 0 and (not ("for" in line)) and (not ("if" in line)) and (not ("parameter" in line)) and (not ("assign" in line)) and (not ("<=" in line))):
            ret.append([True, split[0], line])
        else:
            ret.append([False, "", line])
    return ret

def comment_all_but(arr, name):
    ret = []
    for i in arr:
        if(i[0] == False):
            ret.append(i[2])
        else:
            if(name in i[1]):
                ret.append(i[2])
            else:
                ret.append("//"+i[2])
    return ret

def comment_these(arr, name_arr):
    ret = []
    for i in arr:
        if(i[0] == False):
            ret.append(i[2])
        else:
            has_added = False
            for name in name_arr:
                if(name in i[1] and has_added == False):
                    has_added = True
                    ret.append("//"+i[2])
            if(has_added == False):
                ret.append(i[2])
    return ret

filename = "./icache.txt"

# open the file
data = get_instr_data(filename)
data = get_rid_of_comments(data)
data = get_line_with_vars(data)

var_names = ["commit", "state_next", "dfp_addr", "tag_in", "wmask", "din", "vvv", "web", "dfp_wdata", "dfp_write", "wset", "lru_update", "halt", "ufp_resp", "rdata", "no_val"]#, "dfp_read", "dfp_dread", "commit"]

data_out = comment_these(data, var_names)

for name in var_names:
    data_out +=[""]
    data_out +=[""]
    data_out += ["///////////////////////////////////////////////"]
    data_out += ["///////////////////////////////////////////////"]
    data_out +=[f"// VAR: {name}"]
    data_out +=[""]
    data_out += comment_all_but(data, name)

for i in data_out:
    print(i)
