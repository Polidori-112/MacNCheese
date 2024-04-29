-- mnc.vhd

-- Highest level module of MacNCheese Serial VHDL Plotter
-- reads data from selected bits and outputs over USB to computer to display
-- data is sent and read at 230400 BAUD with no parity bit
-- when use_ram is low, data is continuously read to the output in real time
-- when use_ram is high, data is buffered into RAM on FPGA then output when full/prematurely quit (not real time)
-- recomended setting for most situations is use_ram set to low
-- use of RAM only recommended for reads > 10000 bytes/second or reads of data immediately at or after startup
--
-- for when use_ram LOW: (recommended for most cases)
-- writes data directly to UART at specified clock rate
-- Send an ASCII 's' or 'S' to initiate UART transmission 'q' or 'Q' to stop transmission
-- Initiating read will immediately stop a write
-- Initial state is writing to RAM so data will be ready to be printed at startup
--
-- for when use_ram HIGH:
-- Writes data to the ram, then reads and sends it to UART TX when requested
-- Send an ASCII 's' or 'S' to initiate write TO RAM and 'q' or 'Q' to initiate read FROM RAM
-- Initiating read will immediately stop a write
-- Initial state is writing to RAM so data will be ready to be printed at startup
--
-- byte_rate is samples or bytes read from data_in every second if use_ext_clk is low
-- if use_ext_clk is high, samples or bytes will be read every rising edge of clk_in
--
-- NUM_SAMPLES will limit amount of samples read to allow the rest of your project to use the RAM
-- If you wish to use RAM on chip in addition to this module, do not use/overwrite below addresses
-- Module uses up RAM addresses 0 to NUM_SAMPLES * 8 - 1
-- Ensure pins 14, 15, and 16 are set to serial_txd, serial_rxd, and HIGH respectively
--
-- Tufts ES 4 (http://www.ece.tufts.edu/es/4/)
--
-- Github Repository: https://github.com/Polidori-112/MacNCheese (as of 05/2024)

Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity MNC is 
generic(
	use_ram     : integer := 0;    -- Used to select which sampler is used: 0 for Continuous Read, 1 for RAM
	use_ext_clk : integer := 0;    -- Used to connect sampling rate to defined clock signal
	                               -- Must additionally connect 'ext_clk' to defined clock
	byterate    : integer := 1;    -- Used to send byte when high (MUST BE <= 10000) 
								   -- this is bytes per second transmitted when use_ext_clk = 0
								   -- Set this value to 1 when use_ext_clk is high
	NUM_INPUTS  : natural := 8;    -- Number of input bits (DO NOT CHANGE)
	NUM_SAMPLES : natural := 1024; -- When using RAM Maximum number of samples (must be < 1000000)
	ADDR_WIDTH  : natural := 10    -- When using RAM log2 of num_samples (rounded up)
);
port(
	data_in    : in std_logic_vector(7 downto 0); -- input to be written
	clk_48     : in std_logic;  -- 48MHz clk for inter-procect use(module uses 1 of 1 HSOSC on chip)
	ext_clk    : in std_logic;  -- Sampling clock to sync sampler with logic
							    -- Must be manually connected, < 10 kHz for use_ram = 0 and 'use_ext_clk' must be 1
	serial_txd : out std_logic; -- UART Tx, must be pin 14
	serial_rxd : in  std_logic; -- UART Rx, must be pin 15
	spi_cs     : out std_logic  -- UART CS, must be pin 16 and HIGH
);
end;

architecture synth of MNC is

-- Intermediate values between higher-level module and sampler modules
-- Allows four I/O to be properly mapped to respective sampler module
signal data_in_RAM    : std_logic_vector(7 downto 0);
signal clk_48_RAM     : std_logic;
signal serial_txd_RAM : std_logic;
signal serial_rxd_RAM : std_logic;
signal data_in_RAW    : std_logic_vector(7 downto 0);
signal clk_48_RAW     : std_logic;
signal serial_txd_RAW : std_logic;
signal serial_rxd_RAW : std_logic;

-- RAM SAMPLER
component ram_sampler is 
generic(
	byterate   : in integer := 1;   -- Used to send byte when high (MUST BE <= 20000) 
								    -- this is bytes per second
	use_ext_clk : in integer := 0;  -- Used to connect sampling rate to defined clock signal
	                                -- Must additionally connect 'ext_clk' to defined clock
	NUM_INPUTS  : natural := 8;     -- DO NOT CHANGE
	NUM_SAMPLES : natural := 1024;  -- Maximum amount of samples you wish to read
	ADDR_WIDTH  : natural := 10     -- log2 of num_samples (rounded up)
);
port(
	data_in    : in  std_logic_vector(7 downto 0); -- input to be written
	clk_in     : in  std_logic; -- Input clock to sync logic to
	clk_48     : in  std_logic; -- 48MHz clk for inter-project use(module uses 1 of 1 HSOSC on chip)
	serial_txd : out std_logic; -- UART Tx, must be pin 14
	serial_rxd : in  std_logic  -- UART Rx, must be pin 15
);
end component;

-- RAW SAMPLER
component raw_sampler is
generic(
	byterate    : in integer := 1;  -- Used to send byte when high (MUST BE <= 20000) 
								    -- this is bytes per second
	use_ext_clk : in integer := 0   -- Used to connect sampling rate to defined clock signal
	                                -- Must additionally connect 'ext_clk' to defined clock
);
port(
	data_in    : in  std_logic_vector(7 downto 0); -- input to be written
	clk_in     : in  std_logic; -- Input clock to sync logic to
	clk_48     : in  std_logic; -- 48MHz clk for inter-project use(module uses 1 of 1 HSOSC on chip)
	serial_txd : out std_logic; -- UART Tx, must be pin 14
	serial_rxd : in  std_logic  -- UART Rx, must be pin 15
);
end component;


begin


ram_sample : ram_sampler 
generic map (
	byterate    => byterate,
	use_ext_clk => use_ext_clk,
	NUM_INPUTS  => NUM_INPUTS,
	NUM_SAMPLES => NUM_SAMPLES, 
	ADDR_WIDTH  => ADDR_WIDTH
) port map (
	data_in    => data_in_RAM,
	clk_in     => ext_clk,
	clk_48     => clk_48_RAM,
	serial_txd => serial_txd_RAM,
	serial_rxd => serial_rxd_RAM
);

raw_sample : raw_sampler
generic map (
	byterate => byterate,
	use_ext_clk => use_ext_clk
) port map  (
	data_in    => data_in_RAW,
	clk_in     => ext_clk,
    clk_48     => clk_48_RAW,    
    serial_txd => serial_txd_RAW,
	serial_rxd => serial_rxd_RAW     
);


-- Set top output signals to associated middle level signals
-- Dependant on use_ram alone
data_in_RAM    <= data_in    when use_ram = 1 else "00000000"; 
clk_48_RAM     <= clk_48     when use_ram = 1 else '0';
serial_rxd_RAM <= serial_rxd when use_ram = 1 else '0';

data_in_RAW    <= data_in    when use_ram = 0 else "00000000";
clk_48_RAW     <= clk_48     when use_ram = 0 else '0';
serial_rxd_RAW <= serial_rxd when use_ram = 0 else '0';

serial_txd <= serial_txd_RAW when use_ram = 0 else serial_txd_RAM;

end;


	