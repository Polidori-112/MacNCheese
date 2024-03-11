Library IEEE;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity top is 
port(
	-- Necessary for Logic Analyzer, do not touch
	txd     : out std_logic; --UART Tx, must be pin 14
	rxd     : in std_logic;  --UART Rx, must be pin 15
	spi_cs  : out std_logic  --UART CS, must be pin 16 and HIGH
	
	-- Place your I/O values below this line
	
);
end;

architecture synth of top is
-- Necessary for logic analyzer, do not touch
component middle is
port(
	data_in    : in  std_logic_vector(7 downto 0);
	clk_in     : in  std_logic;
	clk_out    : out std_logic;
	serial_txd : out std_logic;
	serial_rxd : in  std_logic;
	spi_cs     : out std_logic
);
end component;

signal sample_bits : std_logic_vector(7 downto 0) := "01000001";
signal sample_clk  : std_logic;

-- Place signals and components after this line

--signal S : unsigned(3 downto 0) := "0000";
signal inp : unsigned(5 downto 0) := "000000";
signal seg1 : std_logic_vector(6 downto 0);
signal pin : std_logic_vector(1 downto 0);



signal counter : unsigned(25 downto 0);
signal clk : std_logic;
signal outie : std_logic_vector(6 downto 0);
signal outie1 : std_logic_vector(6 downto 0);

 signal y1 : unsigned (3 downto 0);

 component sevenseg is
 port(
 S : in unsigned(3 downto 0);
 segments : out std_logic_vector(6 downto 0)
 );
 end component;

 component dddd is
   port(
     count : in unsigned(5 downto 0);
     tens : out std_logic_vector(6 downto 0);
     ones : out std_logic_vector(6 downto 0)
   );
 end component;

-- Place signals and components above this line
begin
-- Necessary for logic analyzer, do not touch

mid : middle port map(
	data_in    => sample_bits,  -- change to sample when done
	clk_in     => sample_clk,
	clk_out    => clk,
	serial_txd => txd,
	serial_rxd => rxd,
	spi_cs     => spi_cs
);

-- Place logic after this line

ddd : dddd port map (count => inp, tens => outie, ones  => outie1);


process (clk) begin
  if rising_edge(clk) then
    counter <= counter + 1;
    pin(1) <= counter(18);
    pin(0) <= not counter(18);
    if (counter(18)) then
      seg1 <= outie;
    else
      seg1 <= outie1;
    end if;
  end if;
end process;

inp <= counter(25 downto 20);
sample_bits <= '0' & seg1;

end;
