--Known issues (TODO):
--	Rx no worky on higher baud
--	make higher baud
--	change write data from couter to input
--	make clk_in option
--	prevent it from writing unused data when quit
--  have tx output be at fastest possible rate

Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity middle is 
generic(
	byterate   : in  integer := 50; -- Used to send byte when high (MUST BE <= 3840) 
								    -- this is bytes per second
	NUM_INPUTS  : natural := 8;
	NUM_SAMPLES : natural := 256;
	ADDR_WIDTH  : natural := 8    -- log2 of num_samples
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
	CLKHF_DIV : String := "0b00"); -- Divide 48MHz clock by 2?N (0-3)
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
	reset      : in std_logic;
	serial_rxd : in std_logic;
	data       : out std_logic_vector(7 downto 0)
);
end component;



component ramdp is
  generic (
    WORD_SIZE : natural := 8; -- Bits per word (read/write block size)
    N_WORDS : natural := 16; -- Number of words in the memory
    ADDR_WIDTH : natural := 4 -- This should be log2 of N_WORDS; see the Big Guide to Memory for a way to eliminate this manual calculation
   );
  port (
    clk : in std_logic;
    r_addr : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
    r_data : out std_logic_vector(WORD_SIZE - 1 downto 0);
    w_addr : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
    w_data : in std_logic_vector(WORD_SIZE - 1 downto 0);
    w_enable : in std_logic
  );
end component;

signal clk_96 : std_logic; --9600 Hz clk
signal clk_48 : std_logic; --48 MHz clk
signal en : std_logic; -- flipped high to set UART byte
signal byte_counter : integer range 0 to 4800000 := 0; -- clock divider for data tx
signal clk_counter : integer range 0 to 4800000 := 0;
signal ready : std_logic; -- unused output of tx module
signal data_tx : std_logic_vector(7 downto 0); -- UART byte to be transmitted
signal data_rx : std_logic_vector(7 downto 0); -- UART byte to be received
signal rx_reset : std_logic := '0'; -- set high to reset outpur of rx module
signal tx_init : std_logic := '1'; -- set high when transmitting bytes over UART
signal wr_en : std_logic := '0'; -- set high to write to ram, low to read
signal clk_custom : std_logic; -- clock at specified byte rate

signal ram_counter : unsigned(ADDR_WIDTH downto 0) := (others => '0'); -- address of ram to read/write
signal w_data_reg  : std_logic_vector(NUM_INPUTS - 1 downto 0); -- register to write to ram
signal w_addr_reg  : std_logic_vector(ADDR_WIDTH - 1 downto 0); -- address to write to ram
signal r_addr_reg  : std_logic_vector(ADDR_WIDTH - 1 downto 0); -- register to read to ram
signal r_data_reg  : std_logic_vector(NUM_INPUTS - 1 downto 0); -- address to read to ram
signal finished_w  : std_logic := '0'; -- flipped high when write completed

type state_type is (rdy, writing, reading); -- state definitions ie. 'writing' to RAM
signal state : state_type := rdy; -- state of machine

begin
--generate 48MHz clock
osc : HSOSC generic map ( CLKHF_DIV => "0b00")
	port map (CLKHFPU => '1',
	CLKHFEN => '1',
	CLKHF => clk_48);

-- trasmit to UART
tx : uart_tx port map(
	clk_out    => clk_96,
	clk_in     => clk_48,
	enable     => en,
	ready      => ready,
	data       => data_tx,
	serial_txd => serial_txd
);

-- receive from UART
rx : uart_rx port map(
	clk_48 => clk_48,
	reset => rx_reset,
	serial_rxd => serial_rxd,
	data => data_rx
);

-- RAM
ram : ramdp 
	generic map(
		WORD_SIZE   => NUM_INPUTS,
		N_WORDS     => NUM_SAMPLES,
		ADDR_WIDTH  => ADDR_WIDTH
	) port map(
		clk         => clk_48,
		r_addr      => r_addr_reg,
		r_data      => r_data_reg, 
		w_addr      => w_addr_reg,
		w_data      => w_data_reg,
		w_enable    => wr_en
);


spi_cs <= '1';

-- Generates custom clock based on input byterate
process (clk_48) begin
if (rising_edge(clk_48)) then
	if (clk_counter < 48000000 / byterate) then
		clk_counter <= clk_counter + 1;
	else
		clk_counter <= 0;
		clk_custom <= not clk_custom;
	end if;

end if;

end process;

-- transmit bytes at specified byterate when requested
process (clk_96) begin
if (rising_edge(clk_96)) then
	-- runs only during read state
	if (tx_init = '1') then
		byte_counter <= byte_counter + 1;
		-- set tx enable once every specified byterate
		if (byte_counter < (9600 / byterate)) then
			en <= '1';
		else
			en <= '0';
			byte_counter <= 0;
		end if;
	else
		en <= '0';
	end if;
end if;
end process;


-- read/write to ram logic
process (clk_custom) begin
if (rising_edge(clk_custom)) then
	
	case (state) is
		-- idle state
		when rdy =>
			-- reset variables
			ram_counter <= (others => '0');
			rx_reset <= '0';
			tx_init <= '0';
			-- switch to state when requested
			if (finished_w = '1') then
				finished_w <= '0';
				rx_reset <= '1';
				state <= reading;
			elsif (data_rx = "01010011" or data_rx = "01110011") then -- 's' or 'S' ASCII
				rx_reset <= '1';
				state <= writing;
			else
				state <= rdy;
			end if;
		-- write to RAM state
		when writing =>
			tx_init <= '0';
			-- write to RAM
			wr_en <= '1';
			w_data_reg <= std_logic_vector(ram_counter(8 downto 1));--data_in);
			w_addr_reg <= std_logic_vector(ram_counter(ADDR_WIDTH - 1 downto 0));
			ram_counter <= ram_counter + 1;
			-- Allow rx module to receive after 1 second delay
			if ((ram_counter) > byterate) then
				rx_reset <= '0';
			end if;
			-- finish and reset counter
			if (ram_counter >= NUM_SAMPLES - 1 or ((ram_counter * NUM_INPUTS) = 1000000000 ) or data_rx = "01110001" or data_rx = "01010001") then
				finished_w <= '1';
				state <= rdy;
			end if;
		-- read to RAM state
		when reading =>
			tx_init <= '1';
			-- Read data
			wr_en <= '0';
			r_addr_reg <= std_logic_vector(ram_counter(ADDR_WIDTH - 1 downto 0));
			data_tx <= r_data_reg;
			-- Allow rx module to receive after 1 second delay
			if ((ram_counter) > byterate) then
				rx_reset <= '0';
			end if;
			ram_counter <= ram_counter + 1;
			-- finish and reset counter
			if (ram_counter >= NUM_SAMPLES - 1 or ((ram_counter * NUM_INPUTS) >= 1000000000 ) or data_rx = "01010001" or data_rx = "01110001") then
				state <= rdy;
			end if;
			
		when others =>
			state <= rdy;
	end case;
			

end if;
end process;

end synth;