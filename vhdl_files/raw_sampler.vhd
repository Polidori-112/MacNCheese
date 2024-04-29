-- ram_sampler.vhd

-- writes data directly to UART at specified clock rate
-- Send an ASCII 's' or 'S' to initiate UART transmission 'q' or 'Q' to stop transmission
-- Initiating read will immediately stop a write
-- Initial state is writing to RAM so data will be ready to be printed at startup
--
-- byte_rate is samples or bytes read from data_in every second if use_ext_clk is low
-- if use_ext_clk is high, samples or bytes will be read every rising edge of clk_in
-- Ensure pins 14, 15, and 16 are set to serial_txd, serial_rxd, and HIGH respectively
--
-- Tufts ES 4 (http://www.ece.tufts.edu/es/4/)

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
	clk_in     : in  std_logic; -- Input clock to sync logic to
	clk_48     : in  std_logic; -- 48MHz clk for inter-project use(module uses 1 of 1 HSOSC on chip)
	serial_txd : out std_logic; -- UART Tx, must be pin 14
	serial_rxd : in  std_logic  -- UART Rx, must be pin 15
);
end;

architecture synth of raw_sampler is
component uart_tx is
port(
	clk_out    : out std_logic; --230400 Hz clk
	clk_48     : in  std_logic; --48 MHz clk
	enable     : in  std_logic; --Rising edge of this causes singular byte send
	ready      : out std_logic; --High when not sending byte
	data       : in  std_logic_vector(7 downto 0); -- byte to be sent
	serial_txd : out std_logic --UART output
);
end component;

component uart_rx is
port(
	clk_48     : in std_logic; -- input clk at 48 MHz
	reset      : in std_logic; -- set high to set output data to all zeros
							   -- while low it remains it remains unchanged util new byte received
	serial_rxd : in std_logic; -- input signal
	data       : out std_logic_vector(7 downto 0) -- output byte received
);
end component;


signal clk_23 : std_logic; -- 230400 Hz clk
signal en : std_logic; -- Tx enable: set high to initiate byte transmission
signal counter : integer range 0 to 115300 := 0; -- for setting enable for debugging
signal data_tx : std_logic_vector(7 downto 0); -- byte to transmit
signal data_rx : std_logic_vector(7 downto 0); -- byte received
signal init : std_logic; -- initiate transmission: used to determine whether software is requesting transmissions
signal reset : std_logic; -- unused, connected to rx port

begin
-- set transmitted data to data read
data_tx <= data_in;

tx : uart_tx port map(
	clk_out    => clk_23,
	clk_48     => clk_48,
	enable     => en,
	data       => data_tx,
	serial_txd => serial_txd
);

rx : uart_rx port map(
	clk_48 => clk_48,
	reset => reset,
	serial_rxd => serial_rxd,
	data => data_rx
);


process (clk_23) begin
if (rising_edge(clk_23)) then
	-- send byte every byterate if selected
	if (init = '1' and use_ext_clk = 0) then
		counter <= counter + 1;
		if (counter < (115200 / byterate)) then
			en <= '1';
		else
			en <= '0';
			counter <= 0;
		end if;
	-- send byte every rising edge of clk_in if selected
	elsif (init = '1' and use_ext_clk = 1) then
		en <= clk_in;
	else
		en <= '0';
	end if;
	-- Only allow transmissions if GUI/software sends 's' or 'S' bit prior
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
