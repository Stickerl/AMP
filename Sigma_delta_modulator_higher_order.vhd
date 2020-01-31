library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

entity Modulator is
port (mod_clk_i         :   in  std_ulogic;

      sample_i          :   in  signed (dac_bits-1 downto 0) :=(others=> '0'); -- input for loop
      sample_fct_i      :   in  signed ()
      previous_i        :   in  signed ()
      previs_fct_i      :   in  signed ()
      feedback_i        :   in  signed (dac_bits-1 downto 0) :=(others=> '0');
      
      modulator_o       :   out signed (dac_bits-1 downto 0) :=(others=> '0'); -- output of loop
      
      rst_n_i           :   in  std_ulogic;
        
      dbg_chan0_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0');
      dbg_chan1_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0');
      dbg_chan2_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0');
      dbg_chan3_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0')
      );
end Modulator;

architecture MultiOrder of Modulator is
    -- register value (delayed by 1 sys_clk)
    signal reg_s        :   signed (dac_bits+1 downto 0) :=(others =>'0');
    -- value subracted from input sample
    signal feedback_s   :   signed (dac_bits+1 downto 0) :=(others =>'0');
    -- single bit output of DAC
    signal modulator_s  :   std_ulogic;
    -- signalize new data in debugging bus (even if samples are equal)
    signal toggle_s     :   std_ulogic :='0';
    
begin
    modulator_o <= modulator_s;
        
    -- Debugging outputs
    dbg_chan0_o      <= toggle_s & "00" & std_ulogic_vector(ext_sempl_v);
    dbg_chan1_o      <= toggle_s & "00" & std_ulogic_vector(feedback_s);
    dbg_chan2_o      <= toggle_s & "00" & std_ulogic_vector(reg_s);
    dbg_chan3_o      <= toggle_s & (dac_bits+2 downto 0 => '0') & modulator_s;
    
    Calc    :   process (mod_clk_i, rst_n_i)
        variable diff_v     : signed (dac_bits+1 downto 0) :=(others =>'0');
        variable int_out_v  : signed (dac_bits+1 downto 0) :=(others =>'0');
        variable ext_sempl_v: signed (dac_bits) :=(others => '0');     -- zero padded input sample
        
    begin
        if rst_n_i = '0' then
            ext_sempl_v <= (others => '0');
            diff_v      := (others => '0');
            int_out_v   := (others => '0');
            reg_s       <= (others => '0');
            feedback_s  <= (others => '0');
            modulator_s <= '0';
            toggle_s    <= '0';
            
        elsif mod_clk_i' event and mod_clk_i = '1' then
            ext_sempl_v <= sample_i(dac_bits-1) & sample_i(dac_bits-1) & sample_i; -- extend input by 2 bit
            diff_v      := ext_sempl_v - feedback_s;
            int_out_v   := diff_v + reg_s;                -- Integrator
            reg_s       <= int_out_v;                     -- Register value for next iteration
            modulator_s <= int_out_v;
            toggle_s    <= not(toggle_s);
        end if;
    end process;
    
end MultiOrder;


if int_out_v(dac_bits+1) = '1' then
                feedback_s  <= '1' & "11" & (dac_bits-2 downto 0 => '0'); -- max negative val of shortened range
            else
                feedback_s  <= '0' & "00" & (dac_bits-2 downto 0 => '1'); -- max positive val of shortened range
            end if;