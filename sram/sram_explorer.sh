#!/bin/bash

# Copying code segments from https://linuxconfig.org/bash-scripting-tutorial
# Copying code segments from https://www.geeksforgeeks.org/bash-scripting-introduction-to-bash-and-bash-scripting/
# Copying code segments from https://opensource.com/resources/what-bash

port_option=(1 2)

entry_option=(16 32 64 128 256 512)

width_option=(2 4 6 8 10 12 14 16 18 20 32 48 64)

for ((port = 0; port < ${#port_option[@]}; port++)); do
    for((entry=0; entry < ${#entry_option[@]}; entry++)); do
        for((width=0; width <${#width_option[@]}; width++)); do
            p=${port_option[$port]}
            e=${entry_option[$entry]}
            w=${width_option[$width]}
            file_name=config/mp_ooo_${p}_port_${e}_entry_${w}_bit.json
            touch $file_name
            echo {                       >> ${file_name}
            echo \"num_rw_ports\": ${p}, >> ${file_name}
            echo \"word_size\"   : ${w}, >> ${file_name}
            echo \"write_size\"  : 2, >> ${file_name}
            echo \"num_words\"   : ${e}  >> ${file_name}
            echo }                       >> ${file_name}

            echo          $file_name
        done
    done
done