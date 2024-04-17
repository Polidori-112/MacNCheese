-- writes data directly to UART at specified clock rate

Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity raw_sampler is 
generic(
	byterate    : in integer := 1;  -- Used to send byte when high (MUST BE <= 20000) 
								    -- this is bytes per second
	use_ext_clk : in integer := 0   -- Used to connect sampling rate to defined clock signal
	                                -- Must additionally connect 'ext_clk' to defined clock
);
port(
	data_in    : in  std_logic_vector(7 downto 0); -- input to be written
	clk_in     : in  std_logic;                    -- Input clock to sync logic to
	clk_48     : in  std_logic;                    -- 48MHz clk for inter-project use(module uses 1 of 1 HSOSC on chip)
	serial_txd : out std_logic;                    -- UART Tx, must be pin 14
	serial_rxd : in  std_logic                     -- UART Rx, must be pin 15
);
end;

architecture synth of raw_sampler is
component uart_tx is
port(
	clk_out    : out std_logic;
	clk_48     : in std_logic;
	enable     : in std_logic;
	ready      : out std_logic;
	data       : in std_logic_vector(7 downto 0);
	serial_txd : out std_logic
);
end component;

component uart_rx is
port(
	clk_48     : in std_logic;
	serial_rxd : in std_logic;
	data       : out std_logic_vector(7 downto 0)
);
end component;


signal clk_23 : std_logic; -- 230400 Hz clk
signal en : std_logic;
signal counter : integer range 0 to 115300 := 0; -- for setting enable for debugging
signal ready : std_logic;
signal data_tx : std_logic_vector(7 downto 0);
signal data_rx : std_logic_vector(7 downto 0);
signal init : std_logic;

signal use_external_clk : std_logic := '0';

begin

data_tx <= data_in;

tx : uart_tx port map(
	clk_out    => clk_23,
	clk_48     => clk_48,
	enable     => en,
	ready      => ready,
	data       => data_tx,
	serial_txd => serial_txd
);

rx : uart_rx port map(
	clk_48 => clk_48,
	serial_rxd => serial_rxd,
	data => data_rx
);


process (clk_23) begin
if (rising_edge(clk_23)) then
	
	if (init = '1' and use_ext_clk = 0) then
		counter <= counter + 1;
		if (counter < (115200 / byterate)) then
			en <= '1';
		else
			en <= '0';
			counter <= 0;
		end if;
	elsif (init = '1' and use_ext_clk = 1) then
		en <= clk_in;
	else
		en <= '0';
	end if;
	
	if (data_rx = "01110011") then
		init <= '1';
	elsif (data_rx = "01010011") then
		init <= '1';
	else
		init <= '0';
	end if;
end if;
end process;

end synth;
