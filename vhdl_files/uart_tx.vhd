-- uart_tx.vhd

-- Writes the input byte to UART @ 230400 Baud (No parity bit)
-- Set enable to high when byte is ready to be sent
-- Ready is high when byte is not being sent/module is ready to receive new byte to send
-- Byte is transmitted through serial_txd to pin 14 for UART communication
-- Ensure pin 16 is set high when using UART communications
--
-- IMPORTANT NOTE: On rare occassions, specific repeated transmissions could cause Radiant to no longer
-- recognize the ICE40UP5K FPGA, making it unflashable by Radiant. In this case, flashing any project-- through Yosys or some other synthesis tool should reset the FPGA to a recognizeable/flashable state
-- 
-- Tufts ES 4 (http://www.ece.tufts.edu/es/4/)

Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity uart_tx is 
port(
	clk_out    : out std_logic; --230400 Hz clk
	clk_48     : in  std_logic; --48 MHz clk
	enable     : in  std_logic; --Rising edge of this causes singular byte send
	ready      : out std_logic; --High when not sending byte
	data       : in  std_logic_vector(7 downto 0); -- byte to be sent
	serial_txd : out std_logic --UART output
);
end; 

architecture synth of uart_tx is

signal clk_23 : std_logic; --230400hz clk

signal count : integer range 0 to 5000 := 0; --divisor for 48MHz->230400Hz
signal flag : std_logic := '0'; --set to one to initiate byte send

--rdy: waiting to send, --send data: sending, --check bits: determine which of the two states to be in
type state_type is (rdy, send_data, check_bits);
signal state : state_type := rdy;

signal tx_data : std_logic_vector(9 downto 0); --full data chunk to send
signal tx_temp : std_logic; --variable for serial_txd output
signal bit_count : integer range 0 to 11 := 0; --keeps track of which tx_data bit is being sent
signal rst : std_logic := '0'; --reset pin, TODO: include as input if needed

signal enable_rst : std_logic; --helps identify rising edge of enable input
signal data_count : integer range 0 to 10 := 0; --extra count to use in BAUD_RATE_GEN process
signal writeable : std_logic := '0'; --temp value for ready output

begin

--Creates 230400Hz clk
--Sets flag high when bit should be transmitted
BAUD_RATE_GEN : process(clk_48)
begin
	if (rising_edge(clk_48)) then
		--reset count when needed
		if (state = rdy) then
			count <= 0;
		--generate new clock
		elsif (count < 208) then
			count <= count + 1;
			flag <= '0';
		else
			count <= 0;
			clk_23 <= not clk_23;
			--set flag to 1 when necessary
			if (data_count < 10 and enable = '1') then
				data_count <= data_count + 1;
				flag <= '1';
				writeable <= '1';
			elsif (enable = '0') then
				data_count <= 0;
				writeable <= '0';
			end if;
		end if;
	end if;
end process;

--Transmit data
DATA_TRANSMIT : process(clk_48)
begin
	if (rising_edge(clk_48)) then
		case(state) is
		
		--idle state, waiting to send
		when rdy =>
			tx_temp <= '1'; --ready/idle state of UART output
			if (rst = '1') then
				state <= rdy;
			else
				state <= send_data; --check if ready to send bit
				tx_data <=  '1' & data & '0'; --set a 'register' with input byte value
			end if;

		--writes data to the tx_temp signal
		--waits for rising_edge of enable to initiate it
		when send_data =>
			if (writeable = '1') then
				tx_temp <= tx_data(bit_count);
				bit_count <= bit_count + 1;
				state <= check_bits;
			else
				tx_temp <= '1'; --idle state of output
			end if;

		--intermediate state: determines which state to be in
		when check_bits =>
			--send data if needed
			if (flag = '1') then
				if (bit_count < 10) then
					state <= send_data;
				else
					state <= rdy;
					bit_count <= 0;
				end if;
			--check again, remaining in this state
			else
				state <= check_bits;
			end if;
			--ensure it is always in a proper state
			when others => state <= rdy;
		end case;
	end if;
end process;

--wire up tmp values to outputs
clk_out <= clk_23;
serial_txd <= tx_temp;
ready <= not writeable;

end synth;
