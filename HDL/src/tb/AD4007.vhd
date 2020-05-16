--##############################################################################
--! Model of an AD AD4007 ADC in 3 wire turbo mode.
--! For simulation only
--##############################################################################

library ieee;
use ieee.NUMERIC_STD.all;
use ieee.STD_LOGIC_1164.all;

ENTITY AD4007 IS
port(
    sck_i: in std_ulogic;
    cnv_i: in std_ulogic;
    sdi_i: in std_ulogic;
    sdo_o: out std_ulogic;

    tbData_i : in std_ulogic_vector(17 downto 0)
);
END AD4007;

ARCHITECTURE rtl of AD4007 IS
-- FSM states
type states is (cnv_start, cnv_load, cnv_wait, data_ready);
signal fsmStates: states := data_ready;
signal nextState: states := data_ready;
--clock
signal ad4007InternalClk:std_ulogic :='0';

--Internal signals for ADC
signal counter : std_ulogic_vector(4 downto 0) := "11110";
signal dataOutputEN : std_ulogic := '0';
--Forced the data to 'z' to reflect the way the ADC actualy behaves
signal data : std_ulogic_vector(17 downto 0) := (others => 'Z');
signal data_d : std_ulogic_vector(17 downto 0) := (others => 'Z');
signal dataShift : std_ulogic_vector(17 downto 0) := (others => 'Z');
begin

    --! Use an internal clock to gonvern the adc timings
    --! @vhdlflow
    make_int_100m_clk: process
    begin
        ad4007InternalClk <= '0';
        wait for 5 ns;
        ad4007InternalClk <= '1';
        wait for 5 ns;
    end process;

    --Use an FSM to control the output with the form
    --! \dot
    --! digraph AD4007_conversion {
    --! "cnv_start" -> "cnv_load" [label = "int clk"]
    --! "cnv_load" -> "cnv_wait" [label = "int clk"]
    --! "cnv_wait" -> "cnv_wait" [label = "count > 0"]
    --! "cnv_wait" -> "data_ready" [label = "count = 0"]
    --! "data_ready" -> "cnv_start" [lable = "cnv high"]
    --! }
    --! \enddot

    stateChange: process(fsmStates,counter,cnv_i)
    begin
        case fsmStates is
            when cnv_start =>
                data <= tbData_i;
                nextState <= cnv_load;
            when cnv_load =>
                data_d <= data;
                dataOutputEN <= '0';
                nextState <= cnv_wait;
            when cnv_wait =>
                if (counter = "00000") then
                    dataOutputEN <= '1';
                    nextState <= data_ready;
                else
                    nextState <= cnv_wait;
                end if;
            when data_ready =>
                if (cnv_i = '1') then
                    nextState <= cnv_start;
                else
                    nextState <= data_ready;
                end if;
        end case;
    end process;

    --! Advnace the FSM
    --! @vhdlflow
    advanceFSM: process(ad4007InternalClk)
    begin
        if(rising_edge(ad4007InternalClk)) then
            fsmStates <= nextState;
        else
            fsmStates <= fsmStates;
        end if;
    end process;

    --! Process to hold the conversion for 320ns as per the AD4007
    --! @vhdlflow
    conversionWait: process(ad4007InternalClk, fsmStates)
    begin
        if(rising_edge(ad4007InternalClk)) then
            if(fsmStates = cnv_load) then
                counter <= ("11110");
            elsif(fsmStates = cnv_wait) then
                counter <= std_ulogic_vector(unsigned(counter) - 1);
            else
                counter <= counter;
            end if;
        end if;
    end process;

    --! Process clocked by the incomming SCLK and used to shift out the data
    --! @vhdlflow
    shiftData: process(sck_i,dataOutputEN,data_d)
    begin
        if(dataOutputEN = '0') then
            dataShift <= data_d;
            sdo_o <= 'Z';
        elsif(rising_edge(sck_i)) then
            sdo_o <= dataShift(17);
            dataShift(17 downto 1) <= dataShift(16 downto 0);
            dataShift(0) <= 'Z'; --Replecates the device
        else
            sdo_o <= dataShift(17);
            dataShift <= dataShift;
        end if;
    end process;
end ARCHITECTURE;
