// IMPORTED KEYBOARD MODULE
module OnePulse (
    output reg signal_single_pulse,
    input wire signal,
    input wire clock
    );
    
    reg signal_delay;

    always @(posedge clock) begin
        if (signal == 1'b1 & signal_delay == 1'b0)
            signal_single_pulse <= 1'b1;
        else
            signal_single_pulse <= 1'b0;
        signal_delay <= signal;
    end
endmodule


module KeyboardDecoder(
    output reg [511:0] key_down,
    output wire [8:0] last_change,
    output reg key_valid,
    inout wire PS2_DATA,
    inout wire PS2_CLK,
    input wire rst,
    input wire clk
    );
    
    parameter [1:0] INIT			= 2'b00;
    parameter [1:0] WAIT_FOR_SIGNAL = 2'b01;
    parameter [1:0] GET_SIGNAL_DOWN = 2'b10;
    parameter [1:0] WAIT_RELEASE    = 2'b11;
    
    parameter [7:0] IS_INIT			= 8'hAA;
    parameter [7:0] IS_EXTEND		= 8'hE0;
    parameter [7:0] IS_BREAK		= 8'hF0;
    
    reg [9:0] key, next_key;		// key = {been_extend, been_break, key_in}
    reg [1:0] state, next_state;
    reg been_ready, been_extend, been_break;
    reg next_been_ready, next_been_extend, next_been_break;
    
    wire [7:0] key_in;
    wire is_extend;
    wire is_break;
    wire valid;
    wire err;
    
    wire [511:0] key_decode = 1 << last_change;
    assign last_change = {key[9], key[7:0]};
    
    KeyboardCtrl_0 inst (
        .key_in(key_in),
        .is_extend(is_extend),
        .is_break(is_break),
        .valid(valid),
        .err(err),
        .PS2_DATA(PS2_DATA),
        .PS2_CLK(PS2_CLK),
        .rst(rst),
        .clk(clk)
    );
    
    OnePulse op (
        .signal_single_pulse(pulse_been_ready),
        .signal(been_ready),
        .clock(clk)
    );
    
    always @ (posedge clk, posedge rst) begin
        if (rst) begin
            state <= INIT;
            been_ready  <= 1'b0;
            been_extend <= 1'b0;
            been_break  <= 1'b0;
            key <= 10'b0_0_0000_0000;
        end else begin
            state <= next_state;
            been_ready  <= next_been_ready;
            been_extend <= next_been_extend;
            been_break  <= next_been_break;
            key <= next_key;
        end
    end
    
    always @ (*) begin
        case (state)
            INIT:            next_state = (key_in == IS_INIT) ? WAIT_FOR_SIGNAL : INIT;
            WAIT_FOR_SIGNAL: next_state = (valid == 1'b0) ? WAIT_FOR_SIGNAL : GET_SIGNAL_DOWN;
            GET_SIGNAL_DOWN: next_state = WAIT_RELEASE;
            WAIT_RELEASE:    next_state = (valid == 1'b1) ? WAIT_RELEASE : WAIT_FOR_SIGNAL;
            default:         next_state = INIT;
        endcase
    end
    always @ (*) begin
        next_been_ready = been_ready;
        case (state)
            INIT:            next_been_ready = (key_in == IS_INIT) ? 1'b0 : next_been_ready;
            WAIT_FOR_SIGNAL: next_been_ready = (valid == 1'b0) ? 1'b0 : next_been_ready;
            GET_SIGNAL_DOWN: next_been_ready = 1'b1;
            WAIT_RELEASE:    next_been_ready = next_been_ready;
            default:         next_been_ready = 1'b0;
        endcase
    end
    always @ (*) begin
        next_been_extend = (is_extend) ? 1'b1 : been_extend;
        case (state)
            INIT:            next_been_extend = (key_in == IS_INIT) ? 1'b0 : next_been_extend;
            WAIT_FOR_SIGNAL: next_been_extend = next_been_extend;
            GET_SIGNAL_DOWN: next_been_extend = next_been_extend;
            WAIT_RELEASE:    next_been_extend = (valid == 1'b1) ? next_been_extend : 1'b0;
            default:         next_been_extend = 1'b0;
        endcase
    end
    always @ (*) begin
        next_been_break = (is_break) ? 1'b1 : been_break;
        case (state)
            INIT:            next_been_break = (key_in == IS_INIT) ? 1'b0 : next_been_break;
            WAIT_FOR_SIGNAL: next_been_break = next_been_break;
            GET_SIGNAL_DOWN: next_been_break = next_been_break;
            WAIT_RELEASE:    next_been_break = (valid == 1'b1) ? next_been_break : 1'b0;
            default:         next_been_break = 1'b0;
        endcase
    end
    always @ (*) begin
        next_key = key;
        case (state)
            INIT:            next_key = (key_in == IS_INIT) ? 10'b0_0_0000_0000 : next_key;
            WAIT_FOR_SIGNAL: next_key = next_key;
            GET_SIGNAL_DOWN: next_key = {been_extend, been_break, key_in};
            WAIT_RELEASE:    next_key = next_key;
            default:         next_key = 10'b0_0_0000_0000;
        endcase
    end

    always @ (posedge clk, posedge rst) begin
        if (rst) begin
            key_valid <= 1'b0;
            key_down <= 511'b0;
        end else if (key_decode[last_change] && pulse_been_ready) begin
            key_valid <= 1'b1;
            if (key[8] == 0) begin
                key_down <= key_down | key_decode;
            end else begin
                key_down <= key_down & (~key_decode);
            end
        end else begin
            key_valid <= 1'b0;
            key_down <= key_down;
        end
    end

endmodule












// BELOW IS MY WORK

module debounce(pb_debounced, pb, clk);
input pb, clk;
output pb_debounced;

reg[3:0] DFF;

always @(posedge clk) begin
    DFF[3:1] <= DFF[2:0];
    DFF[0] <= pb; 
end

assign pb_debounced = (DFF == 4'b1111) ? 1'b1 : 1'b0;

endmodule


module one_pulse(pb_debounced, pb_onepulse, clk);
input pb_debounced, clk;
output pb_onepulse;

reg pb_onepulse;
reg pb_debounced_delay;

always @(posedge clk) begin
    pb_onepulse <= pb_debounced & (!pb_debounced_delay);
    pb_debounced_delay <= pb_debounced;
end
endmodule

module one_signal(pb, clk, pb_onepulse);
input pb, clk;
output pb_onepulse;

wire w1;

debounce d1(w1, pb, clk);
one_pulse d2(w1, pb_onepulse, clk);

endmodule

module one_second_decrement(clk, rst_n, en, in, limit, out);
input clk, rst_n, en;
input [6:0] in;
input [6:0] limit;
output reg [6:0] out;

reg [26:0] count;   
reg [6:0] temp;
reg [6:0] next_out;

wire is_reset;
assign is_reset = ((rst_n == 1'b1) || (en == 1'b0)) ? 1'b1 : 1'b0;

wire one_second_enable;
assign one_second_enable = (count == 27'd100000000) ? 1'b1 : 1'b0;

always @(*) begin
    if(is_reset) begin
        out = in;
    end
    else begin
        out = next_out;
    end
end

always @(posedge clk) begin
    if(is_reset) begin
        temp <= in;
        count <= 27'd0;
    end
    else begin
        count <= count + 27'd1;
        if(one_second_enable) begin
            count <= 27'd0;
            if ((temp > limit) && (en == 1'b1)) begin // 1 second = 100 Mhz
                next_out <= temp - 7'd5;
                temp <= temp - 7'd5;
            end
            else next_out <= temp;
        end
        else next_out <= temp;
    end
end

endmodule

module TOP(clk, btn_left, btn_right, btn_up, btn_down, btn_center, digits, segments, LED, PS2_CLK, PS2_DATA);
input btn_left, btn_right, btn_up, btn_down, btn_center;
inout wire PS2_CLK, PS2_DATA;
input clk;
output reg [3:0] digits;
output reg [6:0] segments;
output reg [3:0] LED;

reg is_coffee, is_coke, is_oolong, is_water;

parameter [6:0] num_0 = 7'b0000001;
parameter [6:0] num_1 = 7'b1001111;
parameter [6:0] num_2 = 7'b0010010;
parameter [6:0] num_3 = 7'b0000110;
parameter [6:0] num_4 = 7'b1001100;
parameter [6:0] num_5 = 7'b0100100;
parameter [6:0] num_6 = 7'b0100000;
parameter [6:0] num_7 = 7'b0001111;
parameter [6:0] num_8 = 7'b0000000;
parameter [6:0] num_9 = 7'b0000100;

wire plus_5, plus_10, plus_50, rst_n, cancel_n;
reg [6:0] total_money; // range from 0 ~ 127

one_signal o1(btn_left, clk, plus_5);
one_signal o2(btn_center, clk, plus_10);
one_signal o3(btn_right, clk, plus_50);
one_signal o4(btn_up, clk, rst_n);
one_signal o5(btn_down, clk, cancel_n);


reg [2:0] state, next_state;
reg [6:0] limit;

// parameter [2:0] INIT = 3'd0;
parameter [2:0] INSERT = 3'd1;
parameter [2:0] INSERT_MAX = 3'd2;
parameter [2:0] BUY_COFFEE = 3'd3;
parameter [2:0] BUY_COKE = 3'd4;
parameter [2:0] BUY_OOLONG = 3'd5;
parameter [2:0] BUY_WATER = 3'd6;
parameter [2:0] CANCEL = 3'd7;

// KEYBOARD

// TESTING KEYBOARD SIGNAL
// always @(*) begin
//     if(is_coffee) LED = 4'b1000;
//     else if(is_coke) LED = 4'b0100;
//     else if(is_oolong) LED = 4'b0010;
//     else if(is_water) LED = 4'b0001;
//     else LED = 4'b0000;
// end

parameter [8:0] KEY_CODES_a = 9'b0_0001_1100; // a => 1C
parameter [8:0] KEY_CODES_s = 9'b0_0001_1011; // s => 1B
parameter [8:0] KEY_CODES_d = 9'b0_0010_0011; // d => 23
parameter [8:0] KEY_CODES_f = 9'b0_0010_1011; // f => 2B
    
wire [511:0] key_down;
wire [8:0] last_change;
wire been_ready;

reg [3:0] key_num;
        
KeyboardDecoder key_de (
    .key_down(key_down),
    .last_change(last_change),
    .key_valid(been_ready),
    .PS2_DATA(PS2_DATA),
    .PS2_CLK(PS2_CLK),
    .rst(rst_n),
    .clk(clk)
);

always @ (*) begin
    if(rst_n) begin
        is_coffee = 1'b0;
        is_coke = 1'b0;
        is_oolong = 1'b0;
        is_water = 1'b0;
    end
    else begin
        if((state == BUY_COFFEE || state == BUY_COKE || state == BUY_OOLONG || state == BUY_WATER) 
        && (next_state == INSERT)) begin
            is_coffee = 1'b0;
            is_coke = 1'b0;
            is_oolong = 1'b0;
            is_water = 1'b0;
        end
        else begin
            if (been_ready && key_down[last_change] == 1'b1) begin
                if (key_num != 4'b1111) begin
                    case(key_num) 
                        4'b0001: is_coffee = 1'b1;
                        4'b0010: is_coke = 1'b1;
                        4'b0100: is_oolong = 1'b1;
                        default: is_water = 1'b1;
                    endcase
                end 
                else begin
                    is_coffee = is_coffee;
                    is_coke = is_coke;
                    is_oolong = is_oolong;
                    is_water = is_water;
                end
            end 
            else begin
                is_coffee = is_coffee;
                is_coke = is_coke;
                is_oolong = is_oolong;
                is_water = is_water;
            end
        end
    end
end

always @ (*) begin
    case (last_change)
        KEY_CODES_a : key_num = 4'b0001;
        KEY_CODES_s : key_num = 4'b0010;
        KEY_CODES_d : key_num = 4'b0100;
        KEY_CODES_f : key_num = 4'b1000;
        default : key_num = 4'b1111;
    endcase
end
// KEYBOARD


// FSM

reg en;
wire [6:0] decre_total_money;
one_second_decrement o6(clk, rst_n, en, total_money, limit, decre_total_money);

always @(posedge clk) begin
    if(rst_n) begin
        state <= INSERT;
        total_money <= 7'd0;
        en <= 1'b0;
        limit <= 7'd0;
    end
    else begin
        state <= next_state;
        case(state) // deal with the value of total money
            INSERT: begin
                en <= 1'b0;
                if(plus_5) total_money <= total_money + 7'd5;
                else if(plus_10) total_money <= total_money + 7'd10;
                else if(plus_50) total_money <= total_money + 7'd50;
                else total_money <= total_money;

                if(total_money >= 7'd80) LED[3] = 1'b1;
                else LED[3] = 1'b0;
                if(total_money >= 7'd30) LED[2] = 1'b1;
                else LED[2] = 1'b0;
                if(total_money >= 7'd25) LED[1] = 1'b1;
                else LED[1] = 1'b0;
                if(total_money >= 7'd20) LED[0] = 1'b1;
                else LED[0] = 1'b0;
            end

            INSERT_MAX: begin
                LED <= 4'b1111;
                total_money <= 7'd100;
            end

            BUY_COFFEE: begin
                LED <= 4'b1000;
                if(LED == 4'b1000) begin
                    en <= 1'b1;
                    total_money <= decre_total_money;
                end
                else begin
                    total_money <= total_money - 7'd80;
                    limit <=  7'd0;
                end
            end

            BUY_COKE: begin
                LED <= 4'b0100;
                if(LED == 4'b0100) begin
                    en <= 1'b1;
                    total_money <= decre_total_money;
                end
                else begin
                    total_money <= total_money - 7'd30;
                    limit <=  7'd0;
                end
            end

            BUY_OOLONG: begin
                LED <= 4'b0010;
                if(LED == 4'b0010) begin
                    en <= 1'b1;
                    total_money <= decre_total_money;
                end
                else begin
                    total_money <= total_money - 7'd25;
                    limit <=  7'd0;
                end
            end

            BUY_WATER: begin
                LED <= 4'b0001;
                if(LED == 4'b0001) begin
                    en <= 1'b1;
                    total_money <= decre_total_money;
                end
                else begin
                    total_money <= total_money - 7'd20;
                    limit <=  7'd0;
                end
            end
            
            default: begin  // CANCEL state     
                total_money <= decre_total_money;
                en <= 1'b1;
                LED <= 4'b0000; 
                limit <= 7'd0;
            end

        endcase
    end
end


always @(*) begin
    next_state = state; // default state is the original one

    case(state)           
        INSERT: begin
            if(cancel_n) next_state = CANCEL;
            else if(is_coffee && (total_money >= 7'd80)) next_state = BUY_COFFEE; // coffee = $80
            else if(is_coke && (total_money >= 7'd30)) next_state = BUY_COKE;     // coke = $30
            else if(is_oolong && (total_money >= 7'd25)) next_state = BUY_OOLONG; // oolong = $25
            else if(is_water && (total_money >= 7'd20)) next_state = BUY_WATER;   // water = $20
            else if(total_money > 7'd95) next_state = INSERT_MAX;
            else next_state = INSERT;
        end

        INSERT_MAX: begin
            if(cancel_n) next_state = CANCEL;
            else if(is_coffee) next_state = BUY_COFFEE; 
            else if(is_coke) next_state = BUY_COKE; 
            else if(is_oolong) next_state = BUY_OOLONG; 
            else if(is_water) next_state = BUY_WATER; 
            else next_state = INSERT_MAX;
        end
            
        BUY_COFFEE: begin
            if(total_money == 7'd0) next_state = INSERT;
        end
            
        
        BUY_COKE: begin
            if(total_money == 7'd0) next_state = INSERT;
        end
            
        BUY_OOLONG: begin
            if(total_money == 7'd0) next_state = INSERT;
        end
            
        BUY_WATER: begin
            if(total_money == 7'd0) next_state = INSERT;
        end
             
        default: begin  // CANCEL state
            if(total_money == 7'd0) next_state = INSERT;
        end

    endcase
end

// FSM


// 7_SEGMENT
reg [19:0] refresh_counter;
wire [1:0] activating_counter;
always @(posedge clk or posedge rst_n) begin 
        if(rst_n==1)
            refresh_counter <= 0;
        else
            refresh_counter <= refresh_counter + 1;
end 

assign activating_counter = refresh_counter[19:18];

reg [6:0] temp_segments [2:0];

always @(*) begin
    if(total_money == 7'd0) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_0;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd5) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_0;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd10) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_1;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd15) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_1;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd20) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_2;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd25) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_2;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd30) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_3;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd35) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_3;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd40) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_4;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd45) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_4;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd50) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_5;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd55) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_5;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd60) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_6;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd65) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_6;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd70) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_7;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd75) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_7;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd80) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_8;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd85) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_8;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd90) begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_9;
        temp_segments[2] <= num_0;
    end
    else if(total_money == 7'd95) begin
        temp_segments[0] <= num_5;
        temp_segments[1] <= num_9;
        temp_segments[2] <= num_0;
    end
    else begin
        temp_segments[0] <= num_0;
        temp_segments[1] <= num_0;
        temp_segments[2] <= num_1;
    end
end


always @(*) begin
    if((total_money == 7'd0) || (total_money == 7'd5)) begin
        // 1 digits in total
        digits <= 4'b1110;
        segments <= temp_segments[0];
    end
    else if(total_money < 7'd100) begin
        // 2 digits in total
        if(activating_counter == 2'b00) begin
            digits <= 4'b1110;
            segments <= temp_segments[0];
        end
        else begin
            digits <= 4'b1101;
            segments <= temp_segments[1];
        end
    end
    else begin
        // 3 digits in total
        if(activating_counter == 2'b00) begin
            digits <= 4'b1110;
            segments <= temp_segments[0];
        end
        else if(activating_counter == 2'b01) begin
            digits <= 4'b1101;
            segments <= temp_segments[1];
        end
        else begin
            digits <= 4'b1011;
            segments <= temp_segments[2];
        end
    end
end

// 7_SEGMENT


endmodule
