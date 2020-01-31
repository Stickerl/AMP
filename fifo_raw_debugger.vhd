library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.all;
use work.Global_params.all;

entity fifo_raw_debugger is
--port(
    -- fifo_test_clk_s <= mod_clk_s
--);
end fifo_raw_debugger;

architecture read_write_test of fifo_raw_debugger is

begin


    -- #############################
    -- Test Debugging FIFO         #
    -- #############################
    
    --fifo_gen_clk_psc :   entity work.Gen_freq port map (reset_n_i,clk50_i,x"0000_03E8",fifo_test_clk_s); -- gen 0.5Hz clk
--    fifo_test_clk_s <= mod_clk_s;
--    -- used because real modulator causes strange single pulses after a valid burst of tree pulses (dbg_clk_o)
--    fifo_wr_test    :process (fifo_test_clk_s, reset_n_i)
--        variable toggle_v    : std_ulogic :='0';
--    begin
--        if reset_n_i = '0' then
--            toggle_v := '0';
--            dbg_cnt_s <= (others => '0');
--            dbg_data_a(1) <= (others => '0');
--            dbg_data_a(2) <= (others => '0');
--            dbg_data_a(0) <= (others => '0');
--        elsif fifo_test_clk_s'event and fifo_test_clk_s='1' then
--            if dbg_cnt_s = 63 then
--                dbg_cnt_s <= (others => '0');
--                toggle_v := not(toggle_v);
--                dbg_data_a(0) <= toggle_v & X"0" & std_ulogic_vector(sine_a(to_integer(dbg_cnt_s)));--toggle_v & std_ulogic_vector(dbg_cnt_s);
--                dbg_data_a(1) <= toggle_v & X"0" & std_ulogic_vector(ramp_a(to_integer(dbg_cnt_s)));--toggle_v & x"000A"; -- if 2 items 2 fifo -> plausible data
--                dbg_data_a(2) <= toggle_v & X"0" & std_ulogic_vector(helios_a(to_integer(dbg_cnt_s)));
--            else
--                toggle_v := not(toggle_v);
--                dbg_cnt_s <= dbg_cnt_s + 1;
--                dbg_data_a(0) <= toggle_v & X"0" & std_ulogic_vector(sine_a(to_integer(dbg_cnt_s)));--toggle_v & std_ulogic_vector(dbg_cnt_s);
--                dbg_data_a(1) <= toggle_v & X"0" & std_ulogic_vector(ramp_a(to_integer(dbg_cnt_s)));--toggle_v & x"000A"; -- if 2 items 2 fifo -> plausible data
--                dbg_data_a(2) <= toggle_v & X"0" & std_ulogic_vector(helios_a(to_integer(dbg_cnt_s)));--toggle_v & x"000F"; -- if 3 items 2 fifo -> wrong data on myRio
--                --dbg_data_a(3) <= toggle_v & x"0007";
--            end if;
--        end if; 
--    end process;

--    fifo_wr_test    : process(fifo_test_clk_s, reset_n_i)
--    begin
--        if reset_n_i = '0' then
--            cycles_s_rst_s <= (others => '0');
--            dbg_fifo_in_s   <= (others => '0');
--            dbg_fifo_wr_a(wrreq) <= '0';
--                
--        elsif fifo_test_clk_s'event and fifo_test_clk_s = '0' then
--            if cycles_s_rst_s = 0 then
--                cycles_s_rst_s <= cycles_s_rst_s +1;
--                dbg_fifo_in_s <= x"0A0003"; -- identifier 5
--                dbg_fifo_wr_a(wrreq) <= '1';
--            elsif cycles_s_rst_s = 1 then
--                cycles_s_rst_s <= cycles_s_rst_s +1;
--                dbg_fifo_in_s <= x"080003"; -- identifier 4
--                dbg_fifo_wr_a(wrreq) <= '1';
--            else
--                dbg_fifo_in_s <= (others => '0');
--                dbg_fifo_wr_a(wrreq) <= '0';
--            end if;
--        end if;
--    end process;

--    fifo_rd_test    : process (clk50_s)
--    begin
--        if clk50_s'event and clk50_s='1' then
--            if not(dbg_fifo_rd_a(rdempty)) then
--                --dbg_data_s(dbg_reg)  <= dbg_fifo_out_s(23 downto 8);
--                led_o (6 downto 0)  <= dbg_fifo_out_s( 6 downto 0);
--                dbg_fifo_rd_a(rdreq) <= '1';
--            else
--                dbg_fifo_rd_a(rdreq) <= '0';
--            end if;
--        end if; 
--    end process;

end read_write_test;