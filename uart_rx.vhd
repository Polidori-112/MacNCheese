Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity uart_rx is
port(
	clk_48     : in std_logic;
	serial_rxd : in std_logic;
	data       : out std_logic_vector(7 downto 0)
);
end;


architecture synth of uart_rx is

type state_type is (rdy, recv_data);
signal state : state_type := rdy;

signal count : integer range 0 to 5000 := 0; --divisor for 48MHz->9600Hz
signal flag : std_logic := '0'; --set to one to initiate byte read
signal bit_count : integer range 0 to 10 := 0; --keeps track of which tx_data bit is being sent

signal data_temp : std_logic_vector(9 downto 0);

begin

--Creates 9600Hz bit flip
--Sets flag high when bit should be read
FLAG_GEN : process(clk_48)
begin
	if (rising_edge(clk_48)) then
		--reset count when needed
		if (state = rdy) then
			count <= 0;
		--generate new clock
		elsif (count < 5000) then
			count <= count + 1;
			flag <= '0';
		else
			count <= 0;
			flag <= '1';
		end if;
	end if;
end process;



process (clk_48) begin
	if (rising_edge(clk_48)) then
		case (state) is
		
		when rdy =>
			if (serial_rxd = '0') then
				state <= recv_data;
			else
				state <= rdy;
			end if;
			bit_count <= 0;
		
		when recv_data =>
			if (bit_count < 10) then
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

data <= data_temp(8 downto 1);

end;
