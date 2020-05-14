library ieee;
use ieee.STD_LOGIC_UNSIGNED.all;
use ieee.std_logic_1164.all;

	-- Add your library and packages declaration here ...

entity adc_top_tb is
end adc_top_tb;

architecture TB_ARCHITECTURE of adc_top_tb is
	-- Component declaration of the tested unit
	component adc_top
	port(
		adc_clk : out STD_LOGIC;
		adc_sclk : out STD_LOGIC;
		adc_dout : in STD_LOGIC;
		adc_ready : in STD_LOGIC;
		adc_sync : out STD_LOGIC;
		adc_npwrdwn : out STD_LOGIC;
		adc_clkdiv : out STD_LOGIC;
		adc_format : out STD_LOGIC_VECTOR(2 downto 0);
		adc_mode : out STD_LOGIC_VECTOR(1 downto 0);
		adc_test_mode : in STD_LOGIC_VECTOR(3 downto 0);
		all_reset : in STD_LOGIC;
		rx_reset : in STD_LOGIC;
		irq_fifo_full : out STD_LOGIC;
		trigger_sample : in STD_LOGIC;
		trigger_sync : in STD_LOGIC;
		loop_in : in STD_LOGIC;
		adc_config : in STD_LOGIC_VECTOR(23 downto 0);
		adc_status : out STD_LOGIC_VECTOR(15 downto 0);
		sync_count : in STD_LOGIC_VECTOR(31 downto 0);
		sfifo_rdclk : in STD_LOGIC;
		sfifo_rden : in STD_LOGIC;
		sfifo_rpreset : in STD_LOGIC;
		sfifo_empty : out STD_LOGIC;
		sfifo_used : out STD_LOGIC_VECTOR(9 downto 0);
		sfifo_dout : out STD_LOGIC_VECTOR(31 downto 0);
		clk_100m : in STD_LOGIC;
		clk_25m : in STD_LOGIC );
	end component;

	-- Stimulus signals - signals mapped to the input and inout ports of tested entity
	signal adc_dout : STD_LOGIC;
	signal adc_ready : STD_LOGIC;
	signal adc_test_mode : STD_LOGIC_VECTOR(3 downto 0);
	signal all_reset : STD_LOGIC;
	signal rx_reset : STD_LOGIC;
	signal trigger_sample : STD_LOGIC;
	signal trigger_sync : STD_LOGIC;
	signal loop_in : STD_LOGIC;
	signal adc_config : STD_LOGIC_VECTOR(23 downto 0);
	signal sync_count : STD_LOGIC_VECTOR(31 downto 0);
	signal sfifo_rdclk : STD_LOGIC;
	signal sfifo_rden : STD_LOGIC;
	signal sfifo_rpreset : STD_LOGIC;
	signal clk_100m : STD_LOGIC;
	signal clk_25m : STD_LOGIC;
	-- Observed signals - signals mapped to the output ports of tested entity
	signal adc_clk : STD_LOGIC;
	signal adc_sclk : STD_LOGIC;
	signal adc_sync : STD_LOGIC;
	signal adc_npwrdwn : STD_LOGIC;
	signal adc_clkdiv : STD_LOGIC;
	signal adc_format : STD_LOGIC_VECTOR(2 downto 0);
	signal adc_mode : STD_LOGIC_VECTOR(1 downto 0);
	signal irq_fifo_full : STD_LOGIC;
	signal adc_status : STD_LOGIC_VECTOR(15 downto 0);
	signal sfifo_empty : STD_LOGIC;
	signal sfifo_used : STD_LOGIC_VECTOR(9 downto 0);
	signal sfifo_dout : STD_LOGIC_VECTOR(31 downto 0);

	-- Add your code here ...

begin

	-- Unit Under Test port map
	UUT : adc_top
		port map (
			adc_clk => adc_clk,
			adc_sclk => adc_sclk,
			adc_dout => adc_dout,
			adc_ready => adc_ready,
			adc_sync => adc_sync,
			adc_npwrdwn => adc_npwrdwn,
			adc_clkdiv => adc_clkdiv,
			adc_format => adc_format,
			adc_mode => adc_mode,
			adc_test_mode => adc_test_mode,
			all_reset => all_reset,
			rx_reset => rx_reset,
			irq_fifo_full => irq_fifo_full,
			trigger_sample => trigger_sample,
			trigger_sync => trigger_sync,
			loop_in => loop_in,
			adc_config => adc_config,
			adc_status => adc_status,
			sync_count => sync_count,
			sfifo_rdclk => sfifo_rdclk,
			sfifo_rden => sfifo_rden,
			sfifo_rpreset => sfifo_rpreset,
			sfifo_empty => sfifo_empty,
			sfifo_used => sfifo_used,
			sfifo_dout => sfifo_dout,
			clk_100m => clk_100m,
			clk_25m => clk_25m
		);

	-- Add your stimulus here ... 
	
	c25m: process
	begin
		clk_25m <= '0';
		wait for 20ns;
		clk_25m <= '1';
		wait for 20ns;
	end process;
	
	c100m: process
	begin
		clk_100m <= '0';
		wait for 5ns;
		clk_100m <= '1';
		wait for 5ns;
	end process;
	
	loop_in <= clk_25m;		-- initial
	
	test: process
	begin
		sync_count <= X"12345678";
		adc_config <= X"100500";
		adc_ready <= '1';
		adc_dout <= '0';
		adc_test_mode <= X"0";
		all_reset <= '1';
		rx_reset <= '0';
		trigger_sample <= '0';
		trigger_sync <= '0';
		wait for 100ns;
		all_reset <= '0';
		wait for 100us;
		
		trigger_sync <= '1';
		wait for 20ns;
		trigger_sync <= '0';
		
		wait for 100ns;
		adc_config <= X"100580";
		
		wait for 100ns;
		adc_config <= X"100506";
		
		wait for 100ns;
		adc_test_mode(3) <= '1';		-- switch to adc test mode
		adc_test_mode(2 downto 0) <= "010";
		sync_count <= X"00000000";
		
		--wait for 100us;	   				-- wait for a few samples
		--wait until falling_edge(adc_ready);		-- then wait to sync up with sampler
		--adc_test_mode(2 downto 0) <= "010";
		
		-- end of test
		wait for 10ms;
	end process;

end TB_ARCHITECTURE;

configuration TESTBENCH_FOR_adc_top of adc_top_tb is
	for TB_ARCHITECTURE
		for UUT : adc_top
			use entity work.adc_top(behavioural);
		end for;
	end for;
end TESTBENCH_FOR_adc_top;

