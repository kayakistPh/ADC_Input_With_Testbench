--##############################################################################
--! FPGA side implementation of input for AD4007
--! For details of the part see AD data sheet.
--! For details of the interface see ../documentation/ADCinputAD4007.md
--! For testbench see /tb/AD4007.vhd and /tb/tb_ADCinputAD4007.vhd
--##############################################################################

library ieee;
use ieee.NUMERIC_STD.all;
use ieee.STD_LOGIC_1164.all;

ENTITY tb_ADCinputAD4007 IS
END tb_ADCinputAD4007;

ARCHITECTURE tb of tb_ADCinputAD4007 IS
component ADCinputAD4007
port
(
    --Clocks and control
    clk100m_i: in std_ulogic; -- 100MHz clock input
    reset_n_i: in std_ulogic; -- Reset in the same clock domain as the main clk
    sampleRate_i: in std_ulogic_vector(4 downto 0); -- Sets sample rate

    --Interface to ADC
    -- Note pins are names to be consistant with IC and schematic, SPI interface
    -- named from IC perspective.
    sck_o: out std_ulogic;
    cnv_o: out std_ulogic;
    sdi_o: out std_ulogic;
    sdo_i: in std_ulogic;

    --Interface to rest of FPGA
    data_o: out std_ulogic_vector(17 downto 0);
    dataReady_o: out std_ulogic;
    dataRead_i: in std_ulogic
);
end component ADCinputAD4007;

component AD4007
port
(
    sck_i: in std_ulogic;
    cnv_i: in std_ulogic;
    sdi_i: in std_ulogic;
    sdo_o: out std_ulogic;

    tbData_i : in std_ulogic_vector(17 downto 0)
);
end component AD4007;

--Testbench signals

signal clock: std_logic;
signal reset_n: std_logic;
signal sclk, sdo, cnv, sdi: std_logic; --Tracks to ADC
--Connections to rest of ADC
signal sampleRate: std_ulogic_vector(4 downto 0) := "00000";
signal data: std_ulogic_vector(17 downto 0):= "101011110000110011";
signal dataReady, dataRead: std_logic;

--Connections for testbench
signal tbData : std_ulogic_vector(17 downto 0);


--Testbench Control
signal samples_tested : std_ulogic_vector(4 downto 0):= "00000";
signal LatchedDataIn : std_ulogic_vector(17 downto 0);
signal LatchedDataOut : std_ulogic_vector(17 downto 0);
signal checkDataPoint:std_ulogic; --Logic function so no init
signal dataCorrect :std_ulogic :='0';

begin
    -- Attach the components
    adc: AD4007
    port map(
        sck_i => sclk,
        cnv_i => cnv,
        sdi_i => sdi,
        sdo_o => sdo,
        tbData_i => tbData
    );

    fpgaADCport: ADCinputAD4007
    port map(
        --Clocks and control
        clk100m_i => clock,
        reset_n_i => reset_n,
        sampleRate_i => sampleRate,

        sck_o => sclk,
        cnv_o => cnv,
        sdi_o => sdi,
        sdo_i => sdo,

        --Interface to rest of FPGA
        data_o => data,
        dataReady_o => dataReady,
        dataRead_i => dataRead
    );

    --! Use an internal clock to gonvern the adc timings
    --! @vhdlflow
    make_int_100m_clk: process
    begin
        clock <= '0';
        wait for 5 ns;
        clock <= '1';
        wait for 5 ns;
    end process;

    --! Reads the data from the block when triggered by a data ready flag
    --! latches this for comparison
    collectdata: process(clock, dataReady)
    begin
        if(rising_edge(clock)) then
             if (dataReady = '1') then
                 LatchedDataOut <= data;
                 dataRead <= '1';
             else
                 dataRead <= '0';
             end if;
         end if;
     end process;


    --! Generates a new value to be loaded into the ADC
    --! Initaly does debug vaules 0,1,A's etc. then generates random patterns
    loadNewdata: process(cnv,tbData)
    begin
        if(falling_edge(cnv)) then
            samples_tested <= std_ulogic_vector(unsigned(samples_tested) + 1);
            LatchedDataIn <= tbData;
            if (samples_tested = "00000") then
                tbData <= "000000000000000000";
            elsif (samples_tested = "00001") then
                tbData <= "111111111111111111";
            elsif (samples_tested = "00010") then
                tbData <= "101010101010101010";
            elsif (samples_tested = "00011") then
                tbData <= "101011110000110011";
            elsif (samples_tested = "00100") then
                tbData <= "101010010011001101";
            else
                tbData <= "000000001111000000";
            end if;
        end if;
    end process;

    checkData:process(checkDataPoint)
    begin
        if rising_edge(checkDataPoint) then
            if (LatchedDataIn = LatchedDataOut) then
                dataCorrect <= '1';
            else
                dataCorrect <= '0';
            end if;
        end if;
    end process;

    --! Main testbench controlling process
    tb : process
    begin
        --hold in reset for 30ns
        reset_n <= '0';
        wait for 10 ns;
        reset_n <= '1';
        wait for 30 ns;
        reset_n <= '0';
        wait for 100 ms;
    end process;

    checkDataPoint <= dataReady and dataRead;
end ARCHITECTURE;
