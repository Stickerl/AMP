-- ##################################################################
-- Correct functionality veryfied on 04.08.2017
-- checked ramp (stepsize 1) in comparision to clk on logic analyzer
-- ##################################################################

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

entity DbgInterface is
port (
    rst_n_i             :   in  std_ulogic;
    clk_i               :   in  std_ulogic;
    dbg_fifo_word_i     :   in  std_ulogic_vector(dbg_word_size_c + dbg_id_size_c -1 downto 0);
    dbg_fifo_usedw_i    :   in  std_ulogic_vector(9 downto 0) :=(others => '0');
    dbg_rdempty_i       :   in  std_ulogic;
    
    toggle_o            :   out std_ulogic;
    identifier_o        :   out std_ulogic_vector(7 downto 0);
    dbg_bus_o           :   out std_ulogic_vector(15 downto 0);
    dbg_clk_o           :   out std_ulogic;
    rdclk_o             :   out std_ulogic;
    rdreq_o             :   out std_ulogic);
end DbgInterface;

architecture MyRio of DbgInterface is
    constant    dbg_msb_c       : integer := dbg_word_size_c + dbg_id_size_c -1; --23
    --signal      last_usedw_s    : std_ulogic_vector(9 downto 0) :=(others => '0');
    signal      rdclk_s         : std_ulogic;

begin

rdclk_o <= rdclk_s;

-- use rdempty to trigger start and end of dbg_clk_o
dbg_bus     : process (clk_i, rst_n_i)
begin
    if rst_n_i = '0' then
        rdreq_o         <= rst_n_i;
        identifier_o    <= (others => '0');
        dbg_bus_o       <= (others => '0');
        --last_usedw_s    <= (others => '0');
        rdclk_s         <= '0';
        dbg_clk_o       <= '0';
        
    elsif clk_i'event and clk_i='1' then
        rdclk_s         <= not(rdclk_s); -- divide clk_i by 2 and generate rdclk_s for fifo
        
        -- falling edge of rdclk
        if rdclk_s = '1' then
            --last_usedw_s    <= dbg_fifo_usedw_i;
            -- data available (more than one word available)
            if dbg_rdempty_i = '0' then --(unsigned(dbg_fifo_usedw_i) /= unsigned(last_usedw_s)) then unsigned(dbg_fifo_usedw_i) > 0 and 
                rdreq_o         <= '1';
                identifier_o    <= '0' & dbg_fifo_word_i(dbg_msb_c downto dbg_word_size_c); -- leave out toggle bit
                toggle_o        <= dbg_fifo_word_i(dbg_word_size_c-1);
                dbg_bus_o       <= dbg_fifo_word_i(dbg_word_size_c-2 downto 0); -- -2 because toggle bit has to be dropped
                dbg_clk_o       <= '0';
            elsif dbg_rdempty_i = '1' then --unsigned(dbg_fifo_usedw_i) = 0 then
                rdreq_o         <= '0';
                identifier_o    <= (others => '0');
                toggle_o        <= '0';
                dbg_bus_o       <= (others => '0');
            end if;
            
        -- rising edge of rdclk
        else
            dbg_clk_o       <= '1';
            if dbg_rdempty_i = '1' then--unsigned(dbg_fifo_usedw_i) = 1 and unsigned(last_usedw_s) = 1 then
                rdreq_o         <= '1';
            elsif dbg_rdempty_i = '1' then -- unsigned(dbg_fifo_usedw_i) = 0 then    
                rdreq_o         <= '0';
            end if;
        end if;   
    end if;
end process;

end MyRio;