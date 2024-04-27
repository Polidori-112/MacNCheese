# MacNCheese
![logo](logo.png)

### Tufts ECE Sr. Design Capstone Project
#### Link to Youtube Video: Markup :  [Setup Description](https://www.youtube.com/watch?v=Jvebyqo9Zz0)
Above is a youtube video giving a detailed description on what this is, how it works, and most importantly, how to add it to your Radiant projects moving forward.

VHDL Files Basic info: 
- Top Level Module: MNC.vhd
- setup.py will automatically add the files to a Radiant Project and initiate a port mapping in your top file
- Baud rate = 230400
- Two options/modes: read data with/without help of RAM. Both are initiated with a sending of the 's' or 'S' ASCII character through UART. The RAM stops writing and initiates reading when either the maximum samples are hit or a 'q' or 'Q' ASCII character is sent through the UART.
- The rest should be covered in the comments and variable descriptions (which admittedly could use a bit of work)
- Zip file contains full Radiant 'Project' files and such

## Known Issues / Future Features
* Read from RAM after starting up system not currently working
    * works after sending byte to provoke write to RAM
* Read from RAM transmits a lot of empty bytes for small byte rates
  * not large concern as this does not affect data and is not an expected use case of the program
* Would like to see reduction in variables/ports
  * byterate and use_ext_clk can realistically be merged to one if byterate = 0 sets use_ext_clk to '1'
  * NUM_INPUTS could be removed from generic map
  * ADDR_WIDTH could be calculated from any given input NUM_SAMPLES within the VHDL
  * use_ram could potentially be set/removed such that the system is always writing to RAM, but also reading at the same speed, or however fast possible.
    * system will automatically exit if RAM ever gets fille up
* setup.py not always working
    * pins file needs to be initiated in Radiant by setting up >=1 output prior to running current version of script
    * .rdf file for .vhd source linkings has a few different formats it chooses to write in and current script only works for one method. In my short analysis of the software, I could not deduce how to identify which format it will use
