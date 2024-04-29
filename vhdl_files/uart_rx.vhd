-- uart_rx.vhd

-- Receives 8 bits of data from the UART @ 230400 Baud (No parity bit)
-- Constantly outputs most recent data received to data logic vector
-- Set reset to '1' to set output data to all '0's, keep at '0' to allow new output data values
-- Connect serial_rxd to pin 15 to receive data
-- Ensure pin 16 is set high when using UART communications
--
-- Tufts ES 4 (http://www.ece.tufts.edu/es/4/)

Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity uart_rx is
port(
	clk_48     : in std_logic; -- input clk at 48 MHz
	reset      : in std_logic; -- set high to set output data to all zeros
							   -- while low it remains it remains unchanged util new byte received
	serial_rxd : in std_logic; -- input signal
	data       : out std_logic_vector(7 downto 0) -- output byte received
);
end;


architecture synth of uart_rx is

type state_type is (rdy, recv_data, rst);
signal state : state_type := rdy;

signal count : integer range 0 to 5000 := 0; --divisor for 48MHz->9600Hz
signal flag : std_logic := '0'; --set to one to initiate byte read
signal bit_count : integer range 0 to 10 := 0; --keeps track of which tx_data bit is being sent

signal data_temp : std_logic_vector(9 downto 0);

begin
--Creates 230400Hz bit flip
--Sets flag high when bit should be read
FLAG_GEN : process(clk_48)
begin
	if (rising_edge(clk_48)) then
		--reset count when needed
		if (state = rdy) then
			count <= 0;
		--generate new clock
		elsif (count < 200) then
			count <= count + 1;
			flag <= '0';
		else
			count <= 0;
			flag <= '1';
		end if;
	end if;
end process;


-- Receive data from serial_rxd -> data_temp
process (clk_48) begin
	if (rising_edge(clk_48)) then
		case (state) is
		-- reset data when requested
		when rst =>
			data_temp <= "0000000000";
			if (reset = '0') then
				state <= rdy;
			end if;
		-- idle state, changes states when reset or input signal changes
		when rdy =>
			if (reset = '1') then
				state <= rst;
			elsif (serial_rxd = '0') then
				state <= recv_data;
			else
				state <= rdy;
			end if;
			bit_count <= 0;
		-- data read state
		when recv_data =>
			if (reset = '1') then
				state <= rst;
			-- repeat for each of 10 bits
			elsif (bit_count < 10) then
				-- receive bit and shift sum by one to enter next bit
				if (flag = '1') then
					data_temp(bit_count) <= serial_rxd;
					bit_count <= bit_count + 1;
				end if;
				state <= recv_data;
			else
				state <= rdy;
			end if;
		end case;	
	end if;
end process;
-- Extract useful data bits to output
data <= data_temp(8 downto 1);

end;
