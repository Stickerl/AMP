library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

entity FeedFifo is
port(
    reset_n_i   : in std_ulogic;
    sys_clk_i   : in std_ulogic;

    wrempty_i   : in std_ulogic;
    wrfull_i    : in std_ulogic;
    
    dbg_data_a  : in dbg_data_buf_t;
    
    fifo_word_o : out std_ulogic_vector(dbg_word_size_c+dbg_id_size_c-1 downto 0);
    
    wrclk_o     : out std_ulogic;
    wrreq_o     : out std_ulogic
);
end FeedFifo;

architecture register_slaughter of FeedFifo is --brachial
    signal shadow_dbg_data_a    : dbg_data_buf_t;
    signal mask_s               : std_ulogic_vector(num_dbg_words_c-1 downto 0);
    
begin
    wrclk_o <= sys_clk_i;

    gen_mask_comp : for i in 0 to num_dbg_words_c-1 generate
        comp : entity work.shadow_compare
        port map(
            reset_n_i           => reset_n_i,
            dbg_data_i          => dbg_data_a(i),
            shadow_dbg_data_i   => shadow_dbg_data_a(i),
            mask_o              => mask_s(i));
    end generate;   

    write_2_fifo : process(sys_clk_i, reset_n_i)
        variable index_v : integer := 0;
    begin
        if reset_n_i = '0' then
            shadow_dbg_data_a   <= (others => (others => '0'));
            wrreq_o             <= '0';
            fifo_word_o         <= (others => '0');
        elsif sys_clk_i'event and sys_clk_i='1' then
            if unsigned(mask_s) /= 0 then
                index_v         := log2lut_c(to_integer(unsigned(mask_s))); -- get bit position of highest asserted bit
                wrreq_o         <= '1';
                fifo_word_o <= std_ulogic_vector(to_unsigned(index_v, 7)) & dbg_data_a(index_v); -- index, toggle, data
                shadow_dbg_data_a(index_v) <= dbg_data_a(index_v);
            else
                wrreq_o <= '0';
            end if;
        end if;
    end process;
end register_slaughter;