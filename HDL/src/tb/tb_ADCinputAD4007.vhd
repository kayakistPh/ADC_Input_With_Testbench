--##############################################################################
--! FPGA side implementation of input for AD4007
--! For details of the part see AD data sheet.
--! For details of the interface see ../documentation/ADCinputAD4007.md
--! For testbench see /tb/AD4007.vhd and /tb/tb_ADCinputAD4007.vhd
--##############################################################################

library ieee;
use ieee.NUMERIC_STD.all;
use ieee.STD_LOGIC_1164.all;	

--Include OSVVM libs
library osvvm;
use osvvm.OsvvmGlobalPkg.all;
use osvvm.AlertLogPkg.all;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;
use osvvm.TranscriptPkg.all;



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

shared variable adc_data: CovPType;

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

     --! Performs the check on the data input to the test and data receieved from it
	 --! Raises an error if there is a differance. 
	 checkData:process(checkDataPoint)
    begin
        if rising_edge(checkDataPoint) then
            if (LatchedDataIn = LatchedDataOut) then
                dataCorrect <= '1';
            else
                dataCorrect <= '0';
            end if;
			AlertIfNotEqual(LatchedDataIn, LatchedDataOut, "Missmatch in data input to testbench and data receieved", ERROR);
        end if;
    end process;

    --! Main testbench controlling process
    tb : process
	variable RandDat : RandomPType;
    begin
		--Setup OSVVM
		SetGlobalAlertEnable(TRUE);
		SetAlertStopCount(ERROR,10);
		SetLogEnable(INFO,TRUE);
		RandDat.InitSeed(RandDat'instance_name); 
		-- Set up the coverage bins
		-- First Bin is within 20 of 0
		adc_data.AddBins(Name => "ADC close to 0 posative",
		CovBin => GenBin(0,20,1),
		AtLeast => 1);		   
		-- Witin 20 of 0 negative side ADC is twos complement
		adc_data.AddBins(Name => "ADC close to 0 negative",
		CovBin => GenBin(262123,262143,1),
		AtLeast => 1);
		-- Most posative
		adc_data.AddBins(Name => "ADC posative",
		CovBin => GenBin(131052,131071,1),
		AtLeast => 1);
		-- Most negative
		adc_data.AddBins(Name => "ADC negative",
		CovBin => GenBin(131073,131094,1),
		AtLeast => 1);
		
		
        --hold in reset for 30ns
        reset_n <= '0';
        wait for 10 ns;
        reset_n <= '1';
		Log("System in reset", INFO);
        wait for 30 ns;
        reset_n <= '0';
		Log("Out of reset ---TEST BEGINS", INFO); 
				
		wait on cnv until cnv = '0';
		samples_tested <= std_ulogic_vector(unsigned(samples_tested) + 1);
        LatchedDataIn <= tbData;
        tbData <= "000000000000000000";
		Log("Testing all 0s", INFO);
		
		wait on cnv until cnv = '0';
		samples_tested <= std_ulogic_vector(unsigned(samples_tested) + 1);
        LatchedDataIn <= tbData;
        tbData <= "000000000000000000";
		Log("Testing all 0s", INFO);
		
		wait on cnv until cnv = '0';
		samples_tested <= std_ulogic_vector(unsigned(samples_tested) + 1);
        LatchedDataIn <= tbData;
        tbData <= "111111111111111111";
		Log("Testing all 1s", INFO);
		
		wait on cnv until cnv = '0';
		samples_tested <= std_ulogic_vector(unsigned(samples_tested) + 1);
        LatchedDataIn <= tbData;
        tbData <= "101010101010101010";
		Log("Testing all As", INFO);
		
		wait on cnv until cnv = '0';
		samples_tested <= std_ulogic_vector(unsigned(samples_tested) + 1);
        LatchedDataIn <= tbData;
        tbData <= "101011110000110011";
		Log("Testing direction pattern", INFO);
		
		Log("Bit patterns tested begin random tests", INFO);
			
		loop 
			  wait on cnv until cnv = '0';
			  samples_tested <= std_ulogic_vector(unsigned(samples_tested) + 1);
        	  LatchedDataIn <= tbData;
        	  tbData <= RandDat.Randslv(0,262143,18);
			  --Store the cover
			  adc_data.ICover(to_integer(unsigned(tbData)));
			  adc_data.WriteBin;
			  exit when adc_data.IsCovered;
		end loop;
		Log("Reached end of test", INFO);
		ReportAlerts("AD4007 test");
		adc_data.FileOpenWriteBin("./AD4007_data_test.txt", WRITE_MODE);
		TranscriptClose;
		Alert("End of Test", FAILURE); --Force the end of the test		
    end process;

    checkDataPoint <= dataReady and dataRead;
end ARCHITECTURE;
