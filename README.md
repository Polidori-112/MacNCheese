# MacNCheese
Sr. Design Capstone Project

Currently just working VHDL files

Basic info: 
- Baud rate = 230400.
- Two options/modes: read data with/without help of RAM. Both are initiated with a sending of the 's' or 'S' ASCII character through UART. The RAM stops writing and initiates reading when either the maximum samples are hit or a 'q' or 'Q' ASCII character is sent through the UART.
- The rest should be covered in the comments and variable descriptions (which admittedly could use a bit of work).
