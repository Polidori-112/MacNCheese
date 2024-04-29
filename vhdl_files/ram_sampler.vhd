-- ram_sampler.vhd

-- Writes data to the ram, then reads and sends it to UART TX when requested
-- Send an ASCII 's' or 'S' to initiate write TO RAM and 'q' or 'Q' to initiate read FROM RAM
-- Initiating read will immediately stop a write
-- Initial state is writing to RAM so data will be ready to be printed at startup
--
-- byte_rate is samples or bytes read from data_in every second if use_ext_clk is low
-- if use_ext_clk is high, samples or bytes will be read every rising edge of clk_in--
-- NUM_SAMPLES will limit amount of samples read to allow the rest of your project to use the RAM
-- If you wish to use RAM on chip in addition to this module, do not use/overwrite below addresses
-- Module uses up RAM addresses 0 to NUM_SAMPLES * 8 - 1
-- Ensure pins 14, 15, and 16 are set to serial_txd, serial_rxd, and HIGH respectively
--
-- Tufts ES 4 (http://www.ece.tufts.edu/es/4/)

Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity ram_sampler is 
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
end;

architecture synth of ram_sampler is

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

component ramdp is
  generic (
    WORD_SIZE : natural := 8; -- Bits per word (read/write block size)
    N_WORDS : natural := 16;  -- Number of words in the memory
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

signal clk_23 : std_logic; -- 230 kHz clk
signal en : std_logic; -- flipped high to set UART byte
signal byte_counter : integer range 0 to 20 := 0; -- clock divider for data tx
signal clk_counter : integer range 0 to 24000000 := 0;
signal ready : std_logic; -- unused output of tx module
signal data_tx : std_logic_vector(7 downto 0); -- UART byte to be transmitted
signal data_rx : std_logic_vector(7 downto 0); -- UART byte to be received
signal rx_reset : std_logic := '0'; -- set high to reset outpur of rx module
signal tx_init : std_logic := '1'; -- set high when transmitting bytes over UART
signal wr_en : std_logic := '0'; -- set high to write to ram, low to read
signal clk_custom : std_logic; -- clock at specified byte rate

signal write_counter : unsigned(ADDR_WIDTH downto 0) := (others => '0'); -- address of ram to write
signal read_counter : unsigned(ADDR_WIDTH downto 0) := (others => '0'); -- address of ram to read
signal ram_used    : unsigned(ADDR_WIDTH downto 0) := (others => '0'); -- stores amount of ram written to reading
signal w_data_reg  : std_logic_vector(NUM_INPUTS - 1 downto 0); -- register to write to ram
signal w_addr_reg  : std_logic_vector(ADDR_WIDTH - 1 downto 0); -- address to write to ram
signal r_addr_reg  : std_logic_vector(ADDR_WIDTH - 1 downto 0); -- register to read to ram
signal r_data_reg  : std_logic_vector(NUM_INPUTS - 1 downto 0); -- address to read to ram
signal finished_w  : std_logic := '0'; -- flipped high when write completed

type state_type is (writing, rdy, reading); -- state definitions ie. 'writing' to RAM
signal state : state_type := writing; -- state of machine

begin

-- trasmit to UART
tx : uart_tx port map(
	clk_out    => clk_23,
	clk_48     => clk_48,
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

-- Generates custom clock
process (clk_48) begin
if (rising_edge(clk_48)) then
	-- create one based on input byterate
	if (use_ext_clk = 0) then
		-- create clock at desired byterate
		if (clk_counter < 24000000 / byterate) then
			clk_counter <= clk_counter + 1;
		else
			clk_counter <= 0;
			clk_custom <= not clk_custom;
		end if;
	else
		-- use input clock if desired
		clk_custom <= clk_in;
	end if;
end if;

end process;

-- transmit bytes when reading
process (clk_23) begin
if (rising_edge(clk_23)) then
	-- runs only during read state
	if (tx_init = '1' and read_counter + 1 < ram_used and ((read_counter * NUM_INPUTS) < 1000000000 )) then
		byte_counter <= byte_counter + 1;
		-- set tx enable at fastest possible byterate
		if (byte_counter < 20) then
			-- write to uart
			en <= '1';
		else
			en <= '0';
			byte_counter <= 0;
			-- set the uart register
			r_addr_reg <= std_logic_vector(read_counter(ADDR_WIDTH - 1 downto 0));
			data_tx <= r_data_reg;
			-- increment read value
			read_counter <= read_counter + 1;
		end if;
	elsif (tx_init = '0') then
		read_counter <= (others => '0');
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
			write_counter <= (others => '0');
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
			elsif (data_rx = "01010001" or data_rx = "01110001") then -- 'q' or 'Q' ASCII
				rx_reset <= '1';
				state <= reading;
			else
				state <= rdy;
			end if;
		-- write to RAM state
		when writing =>
			tx_init <= '0';
			-- write to RAM
			wr_en <= '1';
			ram_used <= (others => '0');
			w_data_reg <= std_logic_vector(data_in);
			w_addr_reg <= std_logic_vector(write_counter(ADDR_WIDTH - 1 downto 0));
			write_counter <= write_counter + 1;
			-- Allow rx module to receive
			rx_reset <= '0';
			-- finish and reset counter
			if (write_counter >= NUM_SAMPLES - 1 or ((write_counter * NUM_INPUTS) >= 1000000000 ) or data_rx = "01110001" or data_rx = "01010001") then
				ram_used <= write_counter;
				finished_w <= '1';
				state <= rdy;
			end if;
		-- read to RAM state
		when reading =>
			tx_init <= '1';
			-- Read data
			wr_en <= '0';
			-- Allow rx module to receive
			rx_reset <= '0';
			-- move state when finished reading
			if (read_counter + 1 >= ram_used or ((read_counter * NUM_INPUTS) >= 1000000000 )) then
				state <= rdy;
			end if;

		when others =>
			state <= rdy;
	end case;
end if;
end process;

end synth;
