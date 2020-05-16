--##############################################################################
--! FPGA side implementation of input for AD4007
--! For details of the part see AD data sheet.
--! For details of the interface see ../documentation/ADCinputAD4007.md
--! For testbench see /tb/AD4007.vhd and /tb/tb_ADCinputAD4007.vhd
--##############################################################################

library ieee;
use ieee.NUMERIC_STD.all;
use ieee.STD_LOGIC_1164.all;

ENTITY ADCinputAD4007 IS
port(
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
END ADCinputAD4007;

ARCHITECTURE rtl of ADCinputAD4007 IS
-- FSM states
type states is (start_sample, cnv_wait, setup_sclk, setup_sclk2,data_read, delay0, delay1, delay2, delay3);
signal fsmStates: states := start_sample;
signal nextState: states := start_sample;

type dataOutputStates is (outputData,dataReady,waitDataRead,dataRead,waitNextSample,waitNewData);
signal fsmStatesDout: dataOutputStates := waitNewData;
signal nextStateDout: dataOutputStates := waitNewData;


signal enable_sclk : std_ulogic := '0';
signal force_sclk_high : std_ulogic := '0';
signal cnv_counter : std_ulogic_vector(4 downto 0) := (others => '1');
signal samp_counter : std_ulogic_vector(4 downto 0) := (others => '0');
signal data_counter : std_ulogic_vector(4 downto 0) := (others => '0');
signal dataShift : std_ulogic_vector(17 downto 0) := (others => '0');


begin
    --! Use and FSM to control the gathering of the data from the ADC
    -- \dot
    --! digraph AD4007_read {
    --!   "start_sample" -> "cnv_wait" [label = "clk"]
    --!   "cnv_wait" -> "cnv_wait" [label = "count > 0"]
    --!   "cnv_wait" -> "setup_sclk" [label = "count = 0"]
    --!   "setup_sclk" -> "setup_sclk2" [label = "clk"]
    --!   "setup_sclk2" -> "data_read" [label = "clk"]
    --!   "data_read" -> "data_read" [label = "counter > 0"]
    --!   "data_read" -> "delay0"  [label = "counter = 0 and sample > 0"]
    --!   "data_read" -> "start_sample"  [label = "counter = 0 and sample = 0"]
    --!   "delay0" -> "delay1" [lable = "clk"]
    --!   "delay1" -> "delay2" [lable = "clk"]
    --!   "delay2" -> "delay3" [lable = "clk"]
    --!   "delay3" -> "start_sample" [lable = "sample = 0"]
    --!   "delay3" -> "delay0" [lable = "sample > 0"]
    --! }
    --! \enddot
    stateChange: process(fsmStates,cnv_counter,data_counter, samp_counter)
    begin
        if (reset_n_i = '1') then
            enable_sclk <= '0';
            cnv_o <= '0';
            force_sclk_high <= '0';
        else
            case fsmStates is
                when start_sample =>
                    cnv_o <= '1';
                    nextState <= cnv_wait;
                when cnv_wait =>
                    enable_sclk <= enable_sclk;
                    if (cnv_counter = "00000") then
                        nextState <= setup_sclk;
                        cnv_o <= '0';
                    else
                        nextState <= cnv_wait;
                    end if;
                -- Dual states should prevent glitches in SCLK
                when setup_sclk =>
                    force_sclk_high <= '1';
                    nextState <= setup_sclk2;
                when setup_sclk2 =>
                    force_sclk_high <= '0';
                    enable_sclk <= '1';
                    nextState <= data_read;
                when data_read =>
                    if (data_counter = "00000") then
                        enable_sclk <= '0';
                        if (samp_counter = "00000") then
                            nextState <= start_sample;
                        else
                            nextState <= delay0;
                        end if;
                    else
                        nextState <= data_read;
                    end if;
                when delay0 =>
                    nextState <= delay1;
                when delay1 =>
                    nextState <= delay2;
                when delay2 =>
                    nextState <= delay3;
                when delay3 =>
                    if (samp_counter = "00000") then
                        nextState <= start_sample;
                    else
                        nextState <= delay0;
                    end if;
            end case;
        end if;
    end process;

    --! Advnace the FSM
    --! @vhdlflow
    advanceFSM: process(clk100m_i)
    begin
        if(rising_edge(clk100m_i)) then
            fsmStates <= nextState;
        else
            fsmStates <= fsmStates;
        end if;
    end process;

    --! Process to allow the ADC 320ns for conversion
    --! @vhdlflow
    conversionWait: process(clk100m_i, fsmStates)
    begin
        if(rising_edge(clk100m_i)) then
            if(fsmStates = start_sample) then
                cnv_counter <= (others => '1');
            elsif(fsmStates = cnv_wait) then
                cnv_counter <= std_ulogic_vector(unsigned(cnv_counter) - 1);
            else
                cnv_counter <= cnv_counter;
            end if;
        end if;
    end process;


    --! Process to recieve the incomming data on the negative edge
    --! @vhdlflow
    shiftData: process(clk100m_i,fsmStates)
    begin
        if (reset_n_i = '1') then
            dataShift <= (others => '0');
            data_counter <= "10010";
        elsif(falling_edge(clk100m_i)) then
            if (fsmStates = data_read or fsmStates = setup_sclk2) then
                dataShift(17 downto 1) <= dataShift(16 downto 0);
                dataShift(0) <= sdo_i;
                data_counter <= std_ulogic_vector(unsigned(data_counter) - 1);
            elsif (fsmStates = start_sample) then
                data_counter <= "10010";
            else
                dataShift <= dataShift;
            end if;
        end if;
    end process;

    --! Process to decrement the sample counter when we are using lower sample
    --! rates.
    --! @vhdlflow
    sampleHold: process(clk100m_i, fsmStates)
    begin
        if(rising_edge(clk100m_i)) then
            if(fsmStates = start_sample) then
                samp_counter <= sampleRate_i;
            elsif(fsmStates = delay0) then
                samp_counter <= std_ulogic_vector(unsigned(samp_counter) - 1);
            else
                samp_counter <= samp_counter;
            end if;
        end if;
    end process;

    --! Process to control the buffered output of the module
    --! \dot
    --! digraph dataOut {
    --!   "outputData" -> "dataReady" [label = "clk"]
    --!   "dataReady" -> "waitDataRead" [label = "clk"]
    --!   "waitDataRead" -> "dataRead"[label = "dataRead_i = 1"]
    --!   "waitDataRead" -> "waitDataRead" [label = "clk"]
    --!   "dataRead" ->  "waitNextSample" [label = "clk"]
    --!   "waitNextSample" ->  "waitNextSample" [label = "clk"]
    --!   "waitNextSample" -> "waitNewData"  [label = "fsmStates = setup_sclk"]
    --!   "waitNewData" -> "waitNewData"  [label = "clk"]
    --!   "waitNewData" -> "outputData"  [label = "counter= 0"]
    --! }
    --! \enddot
    --! @vhdlflow
    outputDataProcess: process(fsmStatesDout, dataRead_i, fsmStates, data_counter)
    begin
        if (reset_n_i = '1') then
            data_o <= (others => '0');
            dataReady_o <= '0';
        else
            case(fsmStatesDout) is
                when outputData =>
                    data_o <= dataShift;
                    nextStateDout <= dataReady;
                when dataReady =>
                    dataReady_o <= '1';
                    nextStateDout <= waitDataRead;
                when waitDataRead =>
                    if (dataRead_i = '1') then
                        nextStateDout <= dataRead;
                    else
                        nextStateDout <= waitDataRead;
                    end if;
                when dataRead =>
                    dataReady_o <= '0';
                    nextStateDout <= waitNextSample;
                when waitNextSample =>
                    if (fsmStates = setup_sclk) then
                        nextStateDout <= waitNewData;
                    else
                        nextStateDout <= waitNextSample;
                    end if;
                when waitNewData =>
                    -- this is triggered off the data being clocked in as otherwise
                    -- it would slow the low sample rate settings
                    if (data_counter = "00000") then
                        nextStateDout <= outputData;
                    else
                        nextStateDout <= waitNewData;
                    end if;
            end case;
        end if;
    end process;

    --! Advnace the FSM
    --! @vhdlflow
    advanceDataOutFSM: process(clk100m_i)
    begin
        if(rising_edge(clk100m_i)) then
            fsmStatesDout <= nextStateDout;
        else
            fsmStatesDout <= fsmStatesDout;
        end if;
    end process;

    sck_o <= clk100m_i when enable_sclk = '1' else force_sclk_high;
    sdi_o <= '1';
end ARCHITECTURE;
