Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity MNC is 
generic(
	use_ram     : integer := 0;    -- Used to select which sampler is used: 0 for Continuous Read, 1 for RAM
	use_ext_clk : integer := 0;    -- Used to connect sampling rate to defined clock signal
	                               -- Must additionally connect 'ext_clk' to defined clock
	byterate    : integer := 1;    -- Used to send byte when high (MUST BE <= 20000) 
								   -- this is bytes per second transmitted when use_ext_clk = 0
								   -- Set this value to 1 when use_ext_clk is high
	NUM_INPUTS  : natural := 8;    -- Number of input bytes (DO NOT CHANGE)
	NUM_SAMPLES : natural := 1024; -- When using RAM Maximum number of samples (must be < 1000000)
	ADDR_WIDTH  : natural := 10    -- When using RAM log2 of num_samples (rounded up)
);
port(
	data_in    : in  std_logic_vector(7 downto 0); -- input to be written
	clk_48     : in std_logic; -- 48MHz clk for inter-procect use(module uses 1 of 1 HSOSC on chip)
	ext_clk    : in std_logic; -- Sampling clock to sync sampler with logic
							   -- Must be manually connected, < 20 kHz and 'use_ext_clk' must be 1
	serial_txd : out std_logic; -- UART Tx, must be pin 14
	serial_rxd : in  std_logic; -- UART Rx, must be pin 15
	spi_cs     : out std_logic  -- UART CS, must be pin 16 and HIGH
);
end;

architecture synth of MNC is

signal data_in_RAM    : std_logic_vector(7 downto 0);
signal clk_48_RAM     : std_logic;
signal serial_txd_RAM : std_logic;
signal serial_rxd_RAM : std_logic;
signal data_in_RAW    : std_logic_vector(7 downto 0);
signal clk_48_RAW     : std_logic;
signal serial_txd_RAW : std_logic;
signal serial_rxd_RAW : std_logic;

signal test_counter : unsigned(30 downto 0);


-- RAM SAMPLER
component ram_sampler is 
generic(
	byterate    : in integer := 1; -- Used to send byte when high (MUST BE <= 3840) 
				  				     -- this is bytes per second
	use_ext_clk : in integer := 0;  -- Used to connect sampling rate to defined clock signal
	                                -- Must additionally connect 'ext_clk' to defined clock
	NUM_INPUTS  : in natural := 8;
	NUM_SAMPLES : in natural := 1024;
	ADDR_WIDTH  : in natural := 10   -- log2 of num_samples (rounded up)
);
port(
	data_in    : in  std_logic_vector(7 downto 0); -- input to be written
	clk_in     : in  std_logic; -- Input clock to sync logic to
	clk_48     : in std_logic;  -- 48MHz clk for inter-project use(module uses 1 of 1 HSOSC on chip)
	serial_txd : out std_logic; -- UART Tx, must be pin 14
	serial_rxd : in  std_logic  -- UART Rx, must be pin 15
);
end component;

-- RAW SAMPLER
component raw_sampler is
generic(
	byterate    : in integer := 1;
	use_ext_clk : in integer := 0
); port(
	data_in    : in  std_logic_vector(7 downto 0); -- input to be written
	clk_in     : in  std_logic;                    -- Input clock to sync logic to
	clk_48     : in  std_logic;                    -- 48MHz clk for inter-project use(module uses 1 of 1 HSOSC on chip)
	serial_txd : out std_logic;                    -- UART Tx, must be pin 14
	serial_rxd : in  std_logic                     -- UART Rx, must be pin 15
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


	
