#!/usr/bin/env python3
import os
import glob
import requests

# identify rdf file to edit
def find_rdf(directory):
    rdf_files = glob.glob(os.path.join(directory, '*.rdf'))
    return rdf_files

# Add xml to the file to let Radiant know the files exist
def add_lines_to_rdf(file_path, lines_to_add):
    # check if files added to rdf already
    with open(file_path, 'r') as file:
        file_content = file.read()   
    if "mnc.vhd" in file_content:
        return

    # read data
    with open(file_path, 'r') as file:
        file_lines = file.readlines()

    # find location to add data within
    found_index = -1
    for i, line in enumerate(file_lines):
        if "</Source>" in line:
            found_index = i
            break
    # add lines to the rdf
    if found_index != -1:
        updated_lines = file_lines[:found_index+1] + lines_to_add + file_lines[found_index+1:]
        with open(file_path, 'w') as file:
            file.writelines(updated_lines)
        print("Lines added successfully.")
    else:
        print("</Source> not found in the file.")

def download_files(files_to_download):
    for file in files_to_download:
        # get the data of each file
        url = f"https://github.com/Polidori-112/MacNCheese/blob/main/vhdl_files/{file}"
        response = requests.get(url)
        
        # Check if the request was successful
        if response.status_code == 200:
            # Save the file content to the specified save path
            save_path = "source/impl_1/" + file
            with open(save_path, 'wb') as file:
                file.write(response.content)
        else:
            print(f"Error getting file: {file}')
        
        
# files to download
files_to_download = ['ramdp.vhd', 'uart_tx.vhd', 'uart_rx.vhd', 'ram_sampler.vhd', 'raw_sampler.vhd', 'mnc.vhd']
# Lines to add
lines_to_add = [
    '        <Source name="source/impl_1/uart_tx.vhd" type="VHDL" type_short="VHDL">\n',
    '            <Options/>\n',
    '        </Source>\n',
    '        <Source name="source/impl_1/uart_rx.vhd" type="VHDL" type_short="VHDL">\n',
    '            <Options/>\n',
    '        </Source>\n',
    '        <Source name="source/impl_1/ram_sampler.vhd" type="VHDL" type_short="VHDL">\n',
    '            <Options/>\n',
    '        </Source>\n',
    '        <Source name="source/impl_1/ramdp.vhd" type="VHDL" type_short="VHDL">\n',
    '            <Options/>\n',
    '        </Source>\n',
    '        <Source name="source/impl_1/raw_sampler.vhd" type="VHDL" type_short="VHDL">\n',
    '            <Options/>\n',
    '        </Source>\n',
    '        <Source name="source/impl_1/mnc.vhd" type="VHDL" type_short="VHDL">\n',
    '            <Options/>\n',
    '        </Source>\n'
]

file_path = find_rdf("./")

download_files(files_to_download)

add_lines_to_file(file_path, lines_to_add)
