-- #################################
-- not completely implemented

library IEEE;
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.all;
use work.Global_params.all;

entity SignalGenerator is
port(   sample_clk_i    : in  std_ulogic;

        rst_n_i         : in  std_ulogic;

        multiplier_i    : in  unsigned(dac_bits-1 downto 0); -- multiplier/ 2**dac_bits = scale
        signal_select_i : in  std_ulogic_vector(1 downto 0); 
            -- 0 -> sine
            -- 1 -> cosine
            -- 2 -> ramp
            -- 3 -> triangle
        uint_sample_o   : out unsigned(dac_bits-1 downto 0);
        signed_sample_o : out signed(dac_bits+1 downto 0);
        offset_o        : out unsigned(dac_bits downto 0);
        dbg_chan0_o     : out std_ulogic_vector(dbg_word_size_c-1 downto 0) :=(others => '0');
        dbg_chan1_o     : out std_ulogic_vector(dbg_word_size_c-1 downto 0) :=(others => '0')
);
end SignalGenerator;

architecture SignalLuts of SignalGenerator is

    constant max_val_c  : unsigned(dac_bits downto 0):= (others => '1');

    type sample_lst is array (0 to 63) of unsigned (dac_bits-1 downto 0);
    signal sin_a : sample_lst :=  ( X"800",X"8C8",X"98F",X"A52",X"B0F",X"BC5",X"C71",X"D12",
                                    X"DA7",X"E2E",X"EA6",X"F0D",X"F63",X"FA7",X"FD8",X"FF5",
                                    X"FFF",X"FF5",X"FD8",X"FA7",X"F63",X"F0D",X"EA6",X"E2E",
                                    X"DA7",X"D12",X"C71",X"BC5",X"B0F",X"A52",X"98F",X"8C8",
                                    X"800",X"737",X"670",X"5AD",X"4F0",X"43A",X"38E",X"2ED",
                                    X"258",X"1D1",X"159",X"0F2",X"09C",X"058",X"027",X"00A",
                                    X"000",X"00A",X"027",X"058",X"09C",X"0F2",X"159",X"1D1",
                                    X"258",X"2ED",X"38E",X"43A",X"4F0",X"5AD",X"670",X"737");
                                    
    signal cos_a : sample_lst :=   (X"FFF",X"FF5",X"FD8",X"FA7",X"F63",X"F0D",X"EA6",X"E2E",
                                    X"DA7",X"D12",X"C71",X"BC5",X"B0F",X"A52",X"98F",X"8C8",
                                    X"800",X"737",X"670",X"5AD",X"4F0",X"43A",X"38E",X"2ED",
                                    X"258",X"1D1",X"159",X"0F2",X"09C",X"058",X"027",X"00A",
                                    X"000",X"00A",X"027",X"058",X"09C",X"0F2",X"159",X"1D1",
                                    X"258",X"2ED",X"38E",X"43A",X"4F0",X"5AD",X"670",X"737",
                                    X"800",X"8C8",X"98F",X"A52",X"B0F",X"BC5",X"C71",X"D12",
                                    X"DA7",X"E2E",X"EA6",X"F0D",X"F63",X"FA7",X"FD8",X"FF5");

    signal ramp_a : sample_lst := ( X"000",X"040",X"080",X"0C0",X"100",X"140",X"180",X"1C0",
                                    X"200",X"240",X"280",X"2C0",X"300",X"340",X"380",X"3C0",
                                    X"400",X"440",X"480",X"4C0",X"500",X"540",X"580",X"5C0",
                                    X"600",X"640",X"680",X"6C0",X"700",X"740",X"780",X"7C0",
                                    X"800",X"840",X"880",X"8C0",X"900",X"940",X"980",X"9C0",
                                    X"A00",X"A40",X"A80",X"AC0",X"B00",X"B40",X"B80",X"BC0",
                                    X"C00",X"C40",X"C80",X"CC0",X"D00",X"D40",X"D80",X"DC0",
                                    X"E00",X"E40",X"E80",X"EC0",X"F00",X"F40",X"F80",X"FC0");

    signal tri_a : sample_lst := (  X"000",X"040",X"080",X"0C0",X"100",X"140",X"180",X"1C0",
                                    X"200",X"240",X"280",X"2C0",X"300",X"340",X"380",X"3C0",
                                    X"400",X"440",X"480",X"4C0",X"500",X"540",X"580",X"5C0",
                                    X"600",X"640",X"680",X"6C0",X"700",X"740",X"780",X"7C0",
                                    X"800",X"7BF",X"77F",X"73F",X"6FF",X"6BF",X"67F",X"63F",
                                    X"5FF",X"5BF",X"57F",X"53F",X"4FF",X"4BF",X"47F",X"43F",
                                    X"3FF",X"3BF",X"37F",X"33F",X"2FF",X"2BF",X"27F",X"23F",
                                    X"1FF",X"1BF",X"17F",X"13F",X"0FF",X"0BF",X"07F",X"03F");
    
    signal cnt_s        : unsigned(7 downto 0) :=X"00"; -- count samples
    signal ext_multip_s : unsigned(dac_bits+1 downto 0);
    signal toggle_s     : std_ulogic;
    signal padding_bit_s  : std_ulogic_vector(15 downto dac_bits) := (others => '0'); -- bits reserved for dbg_bus
    
begin  
        
    -- selects one of the signal lists, reads a sample, scales and returns it
    sample_from_lut : process(sample_clk_i, rst_n_i, multiplier_i)
        variable cur_sample_v   : unsigned(2*dac_bits downto 0);
        variable cur_offset_v   : unsigned(2*dac_bits-1 downto 0);
        variable cur_sin_smpl_v : signed(dac_bits downto 0);
    begin
        if rst_n_i = '0' then
            cur_sample_v    := (others => '0');
            cnt_s           <= x"00";
            uint_sample_o   <= (others => '0');
            signed_sample_o <= (others => '0');
            ext_multip_s    <= (resize(multiplier_i, ext_multip_s'length) sll 1) +1;
            cur_sin_smpl_v  := (others => '0');
            --dbg_chan0_o     <= (others => '0');
            --dbg_chan1_o     <= (others => '0');
            
        elsif sample_clk_i'event and sample_clk_i='1' then
            ext_multip_s    <= (resize(multiplier_i, ext_multip_s'length) sll 1) +1;
            
            -- sample counter
            if cnt_s = 63 then
                cnt_s <= x"00";
            else
                cnt_s <= cnt_s + 1;
            end if;
            
            -- signal lut multiplexer
            case signal_select_i is
                when "00"   => cur_sample_v := '0' & x"000" & sin_a(to_integer(cnt_s));
                when "01"   => cur_sample_v := '0' & x"000" & cos_a(to_integer(cnt_s));
                when "10"   => cur_sample_v := '0' & x"000" & ramp_a(to_integer(cnt_s));
                when "11"   => cur_sample_v := '0' & x"000" & tri_a(to_integer(cnt_s));
                when others => cur_sample_v := '0' & x"000" & sin_a(to_integer(cnt_s));
            end case;
            
            -- calculate amplitude
            cur_sample_v    := resize((cur_sample_v * ext_multip_s) srl dac_bits, cur_sample_v'length) ; -- srl scale current sample
            uint_sample_o   <= resize(cur_sample_v, uint_sample_o'length);
            cur_offset_v    := resize((ext_multip_s srl 1)+1, cur_offset_v'length); -- max_val * multiplier / 2 to calculate offset 
            offset_o        <= resize(cur_offset_v, offset_o'length); 
            toggle_s        <= not toggle_s;
            cur_sin_smpl_v  := resize(signed(cur_sample_v) - signed(cur_offset_v), cur_sin_smpl_v'length);
            signed_sample_o <= resize(cur_sin_smpl_v, signed_sample_o'length);
            --dbg_chan1_o     <=  toggle_s & "000" & std_ulogic_vector(cur_sin_smpl_v);
            --dbg_chan0_o     <= toggle_s & padding_bit_s & std_ulogic_vector(cur_sample_v(dac_bits-1 downto 0));
        end if;
    end process;
end SignalLuts;