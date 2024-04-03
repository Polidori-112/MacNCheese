Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity middle is 
generic(
	byterate   : in  integer := 10 -- Used to send byte when high (MUST BE <= 3840) 
								    -- this is bytes per second
);
port(
	data_in    : in  std_logic_vector(7 downto 0); -- input to be written
	clk_out    : out std_logic; -- 48MHz clk for inter-procect use(module uses 1 of 1 HSOSC on chip)
	serial_txd : out std_logic; -- UART Tx, must be pin 14
	serial_rxd : in  std_logic; -- UART Rx, must be pin 15
	spi_cs     : out std_logic  -- UART CS, must be pin 16 and HIGH
);
end;

architecture synth of middle is

component HSOSC is
generic (
	CLKHF_DIV : String := "0b00"); -- Divide 48MHz clock by 2�N (0-3)
port(
	CLKHFPU : in std_logic := 'X'; -- Set to 1 to power up
	CLKHFEN : in std_logic := 'X'; -- Set to 1 to enable output
	CLKHF : out std_logic := 'X'); -- Clock output
end component;

component uart_tx is
port(
	clk_out    : out std_logic;
	clk_in     : in std_logic;
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
signal clk_48 : std_logic;
signal en : std_logic;
signal counter : integer range 0 to 115200 := 0; -- for setting enable for debugging
signal ready : std_logic;
signal data_tx : std_logic_vector(7 downto 0);
signal data_rx : std_logic_vector(7 downto 0);
signal init : std_logic;
signal test : std_logic;

signal use_external_clk : std_logic := '0';

begin

data_tx <= "01011001"; --data_in;

--generate 48MHz clock
osc : HSOSC generic map ( CLKHF_DIV => "0b00")
	port map (CLKHFPU => '1',
	CLKHFEN => '1',
	CLKHF => clk_48);


tx : uart_tx port map(
	clk_out    => clk_23,
	clk_in     => clk_48,
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

spi_cs <= '1';
clk_out <= clk_23;

process (clk_23) begin
if (rising_edge(clk_23)) then
	
	if (init = '1') then
		counter <= counter + 1;
		if (counter < (115200 / byterate)) then
			en <= '1';
		else
			en <= '0';
			counter <= 0;
		end if;
	else
		en <= '0';
	end if;
	
	if (data_rx = "01110010") then
		init <= '1';
		--use_external_clk <= '1';
	elsif (data_rx = "01010010") then
		init <= '1';
		--use_external_clk <= '0';
	else
		init <= '1';
	end if;
end if;
end process;

end synth;
