library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

entity Modulator is
port (mod_clk_i         :   in  std_ulogic;

      sample_i          :   in  signed (dac_bits downto 0) :=(others=> '0'); -- input for loop
      bitstream_o       :   out std_ulogic; -- output of loop
      
      rst_n_i           :   in  std_ulogic;
        
      dbg_chan0_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0');
      dbg_chan1_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0');
      dbg_chan2_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0');
      dbg_chan3_o       :   out std_ulogic_vector(dbg_word_size_c-1 downto 0) := (others => '0')
      );
end Modulator;

architecture FirstOrder of Modulator is
    constant koeff_a1_c :   signed (31 downto 0) := to_signed(3070, 32);
    constant koeff_b1_c :   signed (31 downto 0) := to_signed(2047, 32);
    constant pos_feed_c :   signed (31 downto 0) := resize(to_signed(2047, 32) * koeff_a1_c,  32);  -- positive feedback * a1
    constant neg_feed_c :   signed (31 downto 0) := resize(to_signed(-2047, 32) * koeff_a1_c, 32); -- negative feedback * a1

    -- register value (delayed by 1 sys_clk)
    signal reg_s        :   signed (31 downto 0) :=(others =>'0');
    -- zero padded input sample
    --signal ext_sempl_s  :   signed (31 downto 0) :=(others =>'0');
    -- value subracted from input sample
    -- single bit output of DAC
    signal bitstream_s  :   std_ulogic;
    signal feedback_s   :   signed (31 downto 0) :=to_signed(0, 32);
    signal ext_sempl_s  :   signed (31 downto 0) :=to_signed(0, 32);
    -- signalize new data in debugging bus (even if samples are equal)
    signal toggle_s     :   std_ulogic :='0';
    
begin
    bitstream_o <= bitstream_s;
        
    -- Debugging outputs
    dbg_chan2_o      <= toggle_s & std_ulogic_vector(reg_s(31 downto 16));
    dbg_chan3_o      <= toggle_s & std_ulogic_vector(reg_s(15 downto 0));
    
    Calc    :   process (mod_clk_i, rst_n_i)
        variable diff_v     : signed (31 downto 0) :=(others =>'0');
        --variable feedback_v : signed (31 downto 0) :=(others =>'0');
        --variable ext_sempl_v: signed (31 downto 0) :=(others =>'0'); 
        
    begin
        if rst_n_i = '0' then
            ext_sempl_s <= (others => '0');
            diff_v      := (others => '0');
            reg_s       <= (others => '0');
            feedback_s  <= (others => '0');
            --feedback_v  := (others => '0');
            bitstream_s <= '0';
            toggle_s    <= '0';
            dbg_chan0_o <= (others => '0');
            dbg_chan1_o <= (others => '0');
            
        elsif mod_clk_i' event and mod_clk_i = '1' then
            --ext_sempl_v := resize(resize(sample_i, ext_sempl_v'length) * koeff_b1_c, ext_sempl_v'length); -- extend input to 32 bit and apply b1
            ext_sempl_s <= resize(sample_i * koeff_b1_c, ext_sempl_s'length); -- extend input to 32 bit and apply b1
            diff_v      := ext_sempl_s - feedback_s;
            reg_s       <= diff_v + reg_s; -- Register value for next iteration
            if (diff_v + reg_s) < 0 then
                feedback_s  <= neg_feed_c; --'1' & "11" & (dac_bits-2 downto 0 => '0'); -- max negative val of shortened range
            else
                feedback_s  <= pos_feed_c; --'0' & "00" & (dac_bits-2 downto 0 => '1'); -- max positive val of shortened range
            end if;
            bitstream_s  <= not std_ulogic(reg_s(31));
            toggle_s     <= not(toggle_s);
            dbg_chan0_o      <= toggle_s & bitstream_s & std_ulogic_vector(ext_sempl_s(31) & ext_sempl_s(29 downto 16));
            dbg_chan1_o      <= toggle_s & std_ulogic_vector(ext_sempl_s(15 downto 0));
        end if;
    end process;
end FirstOrder;