library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.Global_params.all;

entity Sigma_delta_modulator_htb is
port(use_sine_i     : in    std_ulogic;
     clk_i          : in    std_ulogic;
     bitstream_o    : out   std_ulogic);
end entity;

architecture fpg_bg of Sigma_delta_modulator_htb is
    signal clk_s        : std_ulogic;
    signal sim_data_s   : unsigned (dac_bits-1 downto 0) :=(others => '0');
    signal cnt_s        : unsigned (4 downto 0) := (others => '0');
    signal inc_en_s     : std_ulogic :='0';
    signal ramp_s       : unsigned (dac_bits-1 downto 0) :=(others => '0');
    signal sine_s       : unsigned (dac_bits-1 downto 0) :=(others => '0');
    signal sample_nr_s  : unsigned (5 downto 0) :="000000";
    
    type sample_lst is array (0 to 63) of unsigned (dac_bits-1 downto 0);
    signal sine_a : sample_lst :=  (X"800",X"864",X"8C4",X"91C",X"96A",X"9AA",X"9D9",X"9F6",
                                    X"A00",X"9F6",X"9D9",X"9AA",X"96A",X"91C",X"8C4",X"864",
                                    X"800",X"79C",X"73C",X"6E4",X"696",X"656",X"627",X"60A",
                                    X"600",X"60A",X"627",X"656",X"696",X"6E4",X"73C",X"79C",
                                    X"800",X"864",X"8C4",X"91C",X"96A",X"9AA",X"9D9",X"9F6",
                                    X"A00",X"9F6",X"9D9",X"9AA",X"96A",X"91C",X"8C4",X"864",
                                    X"800",X"79C",X"73C",X"6E4",X"696",X"656",X"627",X"60A",
                                    X"600",X"60A",X"627",X"656",X"696",X"6E4",X"73C",X"79C");
                                    
-- full scale range                   X"7FF",X"98E",X"B0E",X"C70",X"DA6",X"EA5",X"F62",X"FD7",
--                                    X"FFE",X"FD7",X"F62",X"EA5",X"DA6",X"C70",X"B0E",X"98E",
--                                    X"7FF",X"670",X"4F0",X"38E",X"258",X"159",X"09C",X"027",
--                                    X"000",X"027",X"09C",X"159",X"258",X"38E",X"4F0",X"670",
--                                    X"7FF",X"98E",X"B0E",X"C70",X"DA6",X"EA5",X"F62",X"FD7",
--                                    X"FFE",X"FD7",X"F62",X"EA5",X"DA6",X"C70",X"B0E",X"98E",
--                                    X"7FF",X"670",X"4F0",X"38E",X"258",X"159",X"09C",X"027",
--                                    X"000",X"027",X"09C",X"159",X"258",X"38E",X"4F0",X"670");

begin

    --GEN_CLK : entity work.Gen_freq port map (clk50_i, x"0001_7D78", clk_s);
    
    psc : process (clk_i)
    begin
        if clk_i' event and clk_i = '1' then
            if cnt_s = 8 then
                inc_en_s <='1';
                cnt_s <= (others => '0');
            else
                inc_en_s <='0';
                cnt_s <= cnt_s+1;
            end if;
        end if;
    end process;
    
    ramp_sweep : process (clk_i)
    begin 
        if clk_i' event and clk_i = '1' then
            if inc_en_s = '1' then
                if ramp_s >= 2**(dac_bits-1)-1 then
                    ramp_s <= ('1' & (dac_bits-2 downto 0 => '0'));
                else
                    ramp_s <= ramp_s + 1;
                end if;
            end if;
        end if;
    end process;
    
    sample_sweep : process (clk_i)
    begin 
        if clk_i' event and clk_i = '1' then
            if inc_en_s = '1' then
                if sample_nr_s = "111111" then
                    sample_nr_s <= (others => '0');
                else
                    sample_nr_s <= sample_nr_s + 1;
                end if;
            end if;
        end if;
    end process;
    
    sine_s <= sine_a(to_integer(sample_nr_s));
    
    xor_switch : process (clk_i, use_sine_i)
    begin
        if clk_i'event and clk_i='1' then
            if use_sine_i = '1' then
                sim_data_s <= sine_s;
            else
                sim_data_s <= ramp_s;
            end if;
        end if;
    end process;
    -- does not work any more, because sigma delta modulator accepts only signed data
    --Modulation : entity work.Modulator port map (sim_data_s,clk_i,'1',bitstream_o);    
end fpg_bg;