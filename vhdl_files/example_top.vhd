-- top.vhd

-- Example file demonstrating use of the MacNCheese Serial VHDL Plotter
-- Consists of simply a counter with a series of 8 consecutive bits being output to the UART
-- MNC was imported and added through use of setup.py script
-- See MNC file and github repository for more details
--
-- Tufts ES 4 (http://www.ece.tufts.edu/es/4/)
--
-- Github Repository: https://github.com/Polidori-112/MacNCheese (as of 05/2024)

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top is
  port(
        serial_txd : out std_logic; -- UART Tx, must be pin 14
        serial_rxd : in  std_logic; -- UART Rx, must be pin 15
        spi_cs     : out std_logic; -- UART CS, must be pin 16 and HIGH
        test : out std_logic
  );
end top;

architecture synth of top is
component MNC is
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
end component;

-- 48MHz clk
component HSOSC is
generic (
CLKHF_DIV : String := "0b00"); -- Divide 48MHz clock by 2�N (0-3)
port(
CLKHFPU : in std_logic := 'X'; -- Set to 1 to power up
CLKHFEN : in std_logic := 'X'; -- Set to 1 to enable output
CLKHF : out std_logic := 'X'); -- Clock output
end component;

signal clk_48 : std_logic;
signal counter : unsigned(29 downto 0) := (others => '0');
signal test_data : std_logic_vector(7 downto 0);
signal ext_clk : std_logic;


begin
-- INITIAL SETUP: Constant read, 10 samples per second
sampler : mnc generic map (
   use_ram     => 1,
   use_ext_clk => 1,
   byterate    => 10,
   NUM_SAMPLES => 1024,
   ADDR_WIDTH  => 10
   ) port map (
   data_in     => test_data, -- TODO: FILL IN WITH SIGNALS TO PROBE
   clk_48      => clk_48, -- TODO: FILL IN WITH 48 MHZ CLK
   ext_clk     => ext_clk, -- (OPTIONAL): FILL IN WITH EXT_CLK IF APPLICABLE
   serial_txd  => serial_txd,
   serial_rxd  => serial_rxd,
   spi_cs      => spi_cs
);

osc : HSOSC generic map ( CLKHF_DIV => "0b00")
port map (CLKHFPU => '1',
CLKHFEN => '1',
CLKHF => clk_48);

-- update the counter
process (clk_48) begin
if rising_edge(clk_48) then
	counter <= counter + 1;
end if;
end process;

-- output counter test data
test_data <= std_logic_vector(counter(28 downto 21));
ext_clk <= counter(20);
test <= counter(20);

end;
