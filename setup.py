#!/usr/bin/env python3
import os
import glob
import requests

# identify rdf file to edit
def find_rdf(directory):
    rdf_files = glob.glob(os.path.join(directory, '*.rdf'))
    return rdf_files[0]

# identify pdc file to edit
def find_pdc(directory):
    pdc_files = glob.glob(os.path.join(directory, '*.pdc'))
    if (len(pdc_files) == 0):
        return 0
    return pdc_files[0]


# identify top module
def find_top_module(rdf_file_path):
    with open(rdf_file_path, 'r') as file:
        file_lines = file.readlines()

    top_module = None
    prev_line = None
    for line in file_lines:
        if 'Options top_module=' in line:
            # Split the line by double quotation marks and extract the second element
            top_module = prev_line.split('"')[1]
            break
        prev_line = line
    if (top_module == None):
        print("Error: top module not found")
        exit(1)

    return top_module

# Add data to the file
def add_lines_to_file(file_path, line_identifier, lines_to_add):
    # check if files added to rdf already (useful for rdf file only)
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
        if line_identifier in line:
            found_index = i
            break
    # add lines to the rdf
    if found_index != -1:
        updated_lines = file_lines[:found_index+1] + lines_to_add + file_lines[found_index+1:]
        with open(file_path, 'w') as file:
            file.writelines(updated_lines)
        print(f"Lines added successfully to {file_path}")
        return 0
    else:
        print(f"Error appending file: {file_path}")
        return 1

def download_files(files_to_download):
    for file in files_to_download:
        # get the data of each file
        url = f"https://raw.githubusercontent.com/Polidori-112/MacNCheese/main/vhdl_files/{file}"
        response = requests.get(url)
        
        # Check if the request was successful
        if response.status_code == 200:
            # Save the file content to the specified save path
            save_path = "source/impl_1/" + file
            with open(save_path, 'wb') as file:
                file.write(response.content)
            print(f"Successfully Downloaded: {file}")
        else:
            print(f"Error getting file: {file}")
        
        
# files to download
files_to_download = ['ramdp.vhd', 'uart_tx.vhd', 'uart_rx.vhd', 'ram_sampler.vhd', 'raw_sampler.vhd', 'mnc.vhd']
# Lines to add
rdf_lines_to_add = [
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
entity_lines_to_add = [
    "        serial_txd : out std_logic; -- UART Tx, must be pin 14\n",
    "        serial_rxd : in  std_logic; -- UART Rx, must be pin 15\n",
    "        spi_cs     : out std_logic; -- UART CS, must be pin 16 and HIGH\n",
]
arch_lines_to_add = [
    "component MNC is\n",
    "generic(\n",
    "	use_ram     : integer := 0;    -- Used to select which sampler is used: 0 for Continuous Read, 1 for RAM\n",
    "	use_ext_clk : integer := 0;    -- Used to connect sampling rate to defined clock signal\n",
    "	                               -- Must additionally connect 'ext_clk' to defined clock\n",
    "	byterate    : integer := 1;    -- Used to send byte when high (MUST BE <= 10000)\n",
    "								   -- this is bytes per second transmitted when use_ext_clk = 0\n",
    "								   -- Set this value to 1 when use_ext_clk is high\n",
    "	NUM_INPUTS  : natural := 8;    -- Number of input bits (DO NOT CHANGE)\n",
    "	NUM_SAMPLES : natural := 1024; -- When using RAM Maximum number of samples (must be < 1000000)\n",
    "	ADDR_WIDTH  : natural := 10    -- When using RAM log2 of num_samples (rounded up)\n",
    ");\n",
    "port(\n",
    "	data_in    : in std_logic_vector(7 downto 0); -- input to be written\n",
    "	clk_48     : in std_logic;  -- 48MHz clk for inter-procect use(module uses 1 of 1 HSOSC on chip)\n",
    "	ext_clk    : in std_logic;  -- Sampling clock to sync sampler with logic\n",
    "							    -- Must be manually connected, < 20 kHz and 'use_ext_clk' must be 1\n",
    "	serial_txd : out std_logic; -- UART Tx, must be pin 14\n",
    "	serial_rxd : in  std_logic; -- UART Rx, must be pin 15\n",
    "	spi_cs     : out std_logic  -- UART CS, must be pin 16 and HIGH\n",
    ");\n",
    "end component;\n"
]
port_lines_to_add = [
    "-- INITIAL SETUP: Constant read, 10 samples per second\n",
    "sampler : mnc generic map (\n",
    "   use_ram     => 0,\n",
    "   use_ext_clk => 0,\n",
    "   byterate    => 10,\n",
    "   NUM_SAMPLES => 1024,\n",
    "   ADDR_WIDTH  => 10\n",
    "   ) port map (\n",
    "   data_in     => , -- TODO: FILL IN WITH SIGNALS TO PROBE\n",
    "   clk_48      => , -- TODO: FILL IN WITH 48 MHZ CLK\n",
    "   ext_clk     => , -- TODO: <OPTIONAL> FILL IN WITH EXT_CLK IF USING, DELETE LINE IF NOT\n",
    "   serial_txd  => serial_txd,\n",
    "   serial_rxd  => serial_rxd,\n",
    "   spi_cs      => spi_cs\n",
    ");\n"
]
pdc_lines_to_add = [
    "ldc_set_location -site {15} [get_ports serial_rxd]\n",
    "ldc_set_location -site {14} [get_ports serial_txd]\n",
    "ldc_set_location -site {16} [get_ports spi_cs]\n"
]



# Download .vhd files
download_files(files_to_download)

# Edit the .rdf file so Radiant recognizes them
rdf_file_path = find_rdf("./")
add_lines_to_file(rdf_file_path, "</Source>", rdf_lines_to_add)
# 
# Add serial pins to entity declaration
top_file = find_top_module(rdf_file_path)
add_lines_to_file(top_file, "port(", entity_lines_to_add)
# 
# Add component to architecture
add_lines_to_file(top_file, "architecture", arch_lines_to_add)
# 
# Add port map template
add_lines_to_file(top_file, "begin", port_lines_to_add)

# Edit the I/O pin values
pdc_file_path = find_pdc("./")
if (pdc_file_path):
    add_lines_to_file(pdc_file_path, "", pdc_lines_to_add)
else:
    # generate error message for this specific case
    print("\nIt seems you do not have a pin out yet. \nPlease set the pins of your top level I/O before flashing.\nMake sure the following values are connected to the following pins:\n    serial_txd: 14\n    serial_rxd: 15\n    spi_cs:     16")

