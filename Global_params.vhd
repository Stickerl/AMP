library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package Global_params is
    
    -- ADC related constants
    constant adc_word_len_c     : integer       := 12;
    constant cpol_adc_c         : std_ulogic    := '1';
    constant bytes_p_frame_c    : integer       := 2;   -- dac_bits/8 if dac_bits rem 8 /= 0 else dac_bits/8 +1
    
    -- sigma-delta modulator related constants
    constant ord_c              : integer       := 2;
    constant dac_bits           : integer       := 16;  -- input word size of DAC
    constant del_cnt_bits       : integer       := 10;              -- delay counter bit with
    
    -- array containing debugging data
    constant dbg_size_c         : integer       := 3;--4;
    type dbg_names_t is (dbg_ext_sample, dbg_feedback, dbg_reg, dbg_bitstream);
    constant dbg_enum           : dbg_names_t   :=dbg_ext_sample;
    type dbg_array_t is array(dbg_names_t) of std_ulogic_vector(15 downto 0);
    --dbg_size_c-1 downto 0) of std_ulogic_vector(15 downto 0);
    
    -- Debug Data buffer
    constant num_dbg_words_c    : integer       := 10;
    constant dbg_word_size_c    : integer       := 17;
    constant dbg_id_size_c      : integer       := 7;
    type dbg_data_buf_t is array(num_dbg_words_c-1 downto 0) of std_ulogic_vector(dbg_word_size_c-1 downto 0);
    
    -- WR control bus
    type wr_ctrl_names_t is (wrclk, wrreq, wrempty, wrfull);
    type rd_ctrl_names_t is (rdclk, rdreq, rdfull);
    type dbg_fifo_wr_t is array(wr_ctrl_names_t) of std_ulogic;
    type dbg_fifo_rd_t is array(rd_ctrl_names_t) of std_ulogic;
    
    -- HDLC Decoder constants
    constant hdlc_cnt_size_c    : integer       := 1; -- define #bits for bytes-counter in hdlc decoder
    constant hdlc_word_size_c   : integer       := 2;
    
    type log2lut_t is array(1 to 1023) of natural;
    constant log2lut_c : log2lut_t := (
        0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,4,4,4,4,
        4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,
        5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
        5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
        6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
        6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
        6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,
        7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
        7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
        7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
        7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
        7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
        7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
        8,8,8,8,8,8,8,8,8,8,8,8,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
        9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9);
end;