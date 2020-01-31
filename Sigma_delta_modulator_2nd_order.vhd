library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

entity Modulator2nd is
port (mod_clk_i         :   in  std_ulogic;

      sample_i          :   in  signed (dac_bits-1 downto 0) :=(others=> '0'); -- input for loop
      bitstream_o       :   out std_ulogic; -- output of loop
      
      rst_n_i           :   in  std_ulogic;
        
      dbg_chan0_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0');
      dbg_chan1_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0');
      dbg_chan2_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0');
      dbg_chan3_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0')
      );
end Modulator2nd;

architecture SecondOrder of Modulator2nd is
    -- register value (delayed by 1 sys_clk)
    signal reg1_s       :   signed (dac_bits+1 downto 0) :=(others =>'0');
    signal reg2_s       :   signed (dac_bits+5 downto 0) :=(others =>'0');  
    -- zero padded input sample
    signal ext_sempl_s  :   signed (dac_bits+1 downto 0) :=(others =>'0');
    -- value subracted from input sample
    signal feedback_s   :   signed (dac_bits+1 downto 0) :=(others =>'0');
    -- single bit output of DAC
    signal bitstream_s  :   std_ulogic;
    -- temp signal to monitor signal between 1st and 2nd stage (delayed by 1 clk)
    signal stage1_o_s   :   signed (dac_bits+5 downto 0) :=(others =>'0');
    -- signalize new data in debugging bus (even if samples are equal)
    signal toggle_s     :   std_ulogic :='0';
    
begin
    bitstream_o <= bitstream_s;
        
    -- Debugging outputs
    dbg_chan0_o      <= toggle_s & std_ulogic_vector(stage1_o_s(dac_bits+5 downto 2)); --"00" & std_ulogic_vector(ext_sempl_s);
    dbg_chan1_o      <= toggle_s & "00" & std_ulogic_vector(feedback_s);
    dbg_chan2_o      <= toggle_s & std_ulogic_vector(reg2_s(dac_bits+5 downto 2));
    dbg_chan3_o      <= toggle_s & (dac_bits+2 downto 0 => '0') & bitstream_s;
    
    Calc    :   process (mod_clk_i, rst_n_i)
        variable diff_1st_v : signed (dac_bits+1 downto 0) :=(others =>'0');
        variable diff_2nd_v : signed (dac_bits+5 downto 0) :=(others =>'0');
        variable int_1st_v  : signed (dac_bits+1 downto 0) :=(others =>'0');
        variable int_2nd_v  : signed (dac_bits+5 downto 0) :=(others =>'0');
        variable int_1ovfl_v: signed (dac_bits+2 downto 0) :=(others =>'0');
        variable int_2ovfl_v: signed (dac_bits+6 downto 0) :=(others =>'0');
        variable stage1_o_v : signed (dac_bits+5 downto 0) :=(others =>'0');
        
    begin
        if rst_n_i = '0' then
            ext_sempl_s <= (others => '0');
            diff_1st_v  := (others => '0');
            diff_2nd_v  := (others => '0');
            int_1st_v   := (others => '0');
            int_2nd_v   := (others => '0');
            reg1_s      <= (others => '0');
            reg2_s      <= (others => '0');
            feedback_s  <= (others => '0');
            bitstream_s <= '0';
            toggle_s    <= '0';
            
        elsif mod_clk_i' event and mod_clk_i = '1' then
            -- 1st stage
            ext_sempl_s <= sample_i(dac_bits-1) & sample_i(dac_bits-1) & sample_i; -- extend input by 2 bit, consider 2s complement
            diff_1st_v  := ext_sempl_s - feedback_s;
            int_1ovfl_v := signed(diff_1st_v(dac_bits+1) & diff_1st_v) + signed(reg1_s(dac_bits+1) & reg1_s);
            
            if int_1ovfl_v > (2**(dac_bits+2)-1) then
                int_1st_v   := '0' & (dac_bits downto 0 => '1');
            elsif int_1ovfl_v < -(2**(dac_bits+2)) then
                int_1st_v   := '1' & (dac_bits downto 0 => '0');
            else
                int_1st_v   := diff_1st_v + reg1_s;           -- Integrator
            end if;
                
            reg1_s      <= int_1st_v;                     -- Register value for next iteration
            
            -- 2nd stage, extend word size of stage 1 by 2, consider 2s complement
            stage1_o_v  := int_1st_v(dac_bits+1) & (2 downto 0 => int_1st_v(dac_bits+1)) & int_1st_v(dac_bits+1 downto 0);
            stage1_o_s  <= stage1_o_v;
            diff_2nd_v  := stage1_o_v - feedback_s;
            int_2ovfl_v := signed(diff_2nd_v(dac_bits +5) & diff_2nd_v) + signed(reg2_s(dac_bits+5) & reg2_s);
            
            if int_2ovfl_v > (2**(dac_bits+6)-1) then
                int_2nd_v   := '0' & (dac_bits+4 downto 0 => '1');
            elsif int_2ovfl_v < -(2**(dac_bits+6)) then
                int_2nd_v   := '1' & (dac_bits+4 downto 0 => '0');
            else
                int_2nd_v   := diff_2nd_v + reg2_s;           -- Integrator
            end if;
            
            reg2_s      <= int_2nd_v;
            
            -- calc feedback
            if int_2nd_v(dac_bits+5) = '1' then
                feedback_s  <= '1' & "11" & (dac_bits-2 downto 0 => '0'); -- max negative val of shortened range
            else
                feedback_s  <= '0' & "00" & (dac_bits-2 downto 0 => '1'); -- max positive val of shortened range
            end if;
            bitstream_s  <= std_ulogic(int_2nd_v(dac_bits+5));
            toggle_s    <= not(toggle_s);
        end if;
    end process;
end SecondOrder;