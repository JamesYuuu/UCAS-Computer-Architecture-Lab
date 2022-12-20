module cache (
    input           clk,
    input           resetn,

    // cpu interface
    input           valid,
    input           op,         // 1:write 0:read
    input  [7:0]    index,
    input  [19:0]   tag,
    input  [3:0]    offset,
    input  [3:0]    wstrb,
    input  [31:0]   wdata,
    output          addr_ok,
    output          data_ok,
    output [31:0]   rdata,

    // axi interface
    output          rd_req,
    output [2:0]    rd_type,    //3'b000 byte 3'b001 half word 3'b010 word 3'b100 cache line
    output [31:0]   rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input  [31:0]   ret_data,
    output          wr_req,
    output [2:0]    wr_type,    //3'b000 byte 3'b001 half word 3'b010 word 3'b100 cache line
    output [31:0]   wr_addr,
    output [3:0]    wr_wstrb,
    output [127:0]  wr_data,
    input           wr_rdy
);

// main fsm
localparam   MAIN_IDLE    = 5'b00001;
localparam   MAIN_LOOKUP  = 5'b00010;
localparam   MAIN_MISS    = 5'b00100;
localparam   MAIN_REPLACE = 5'b01000;
localparam   MAIN_REFILL  = 5'b10000;

reg [4:0] main_state;
reg [4:0] main_next_state;

// write buffer fsm
localparam   WR_IDLE      = 2'b01;
localparam   WR_WRITE     = 2'b10;

reg[1:0]  wr_state;
reg[1:0]  wr_next_state;

// dirty bit table
reg [255:0]     dirty_way0;
reg [255:0]     dirty_way1;
wire [7:0]      dirty_index;

// ram interface
wire [7:0]      tagv_way0_addr;
wire [20:0]     tagv_way0_wdata;
wire [20:0]     tagv_way0_rdata;
wire            tagv_way0_wen;
wire [ 7:0]     tagv_way1_addr;
wire [20:0]     tagv_way1_wdata;
wire [20:0]     tagv_way1_rdata;
wire            tagv_way1_wen;

wire [ 7:0]     bank0_way0_addr;
wire [31:0]     bank0_way0_wdata;
wire [31:0]     bank0_way0_rdata;
wire [ 3:0]     bank0_way0_wen;
wire [ 7:0]     bank1_way0_addr;
wire [31:0]     bank1_way0_wdata;
wire [31:0]     bank1_way0_rdata;
wire [ 3:0]     bank1_way0_wen;
wire [ 7:0]     bank2_way0_addr;
wire [31:0]     bank2_way0_wdata;
wire [31:0]     bank2_way0_rdata;
wire [ 3:0]     bank2_way0_wen;
wire [ 7:0]     bank3_way0_addr;
wire [31:0]     bank3_way0_wdata;
wire [31:0]     bank3_way0_rdata;
wire [ 3:0]     bank3_way0_wen;

wire [ 7:0]     bank0_way1_addr;
wire [31:0]     bank0_way1_wdata;
wire [31:0]     bank0_way1_rdata;
wire [ 3:0]     bank0_way1_wen;
wire [ 7:0]     bank1_way1_addr;
wire [31:0]     bank1_way1_wdata;
wire [31:0]     bank1_way1_rdata;
wire [ 3:0]     bank1_way1_wen;
wire [ 7:0]     bank2_way1_addr;
wire [31:0]     bank2_way1_wdata;
wire [31:0]     bank2_way1_rdata;
wire [ 3:0]     bank2_way1_wen;
wire [ 7:0]     bank3_way1_addr;
wire [31:0]     bank3_way1_wdata;
wire [31:0]     bank3_way1_rdata;
wire [ 3:0]     bank3_way1_wen;

// bank selection
wire            wr_bank0_hit;
wire            wr_bank1_hit;
wire            wr_bank2_hit;
wire            wr_bank3_hit;

// request buffer
reg             req_op_r;
reg [7:0]       req_index_r;
reg [19:0]      req_tag_r;
reg [3:0]       req_offset_r;
reg [3:0]       req_wstrb_r;
reg [31:0]      req_wdata_r;

// write buffer
reg             wr_way_r;
reg [1:0]       wr_bank_r;
reg [7:0]       wr_index_r;
reg [19:0]      wr_tag_r;
reg [3:0]       wr_offset_r;
reg [3:0]       wr_wstrb_r;
reg [31:0]      wr_wdata_r;

// tag compare
wire            cache_hit;
wire            way0_hit;
wire            way1_hit;
wire            wr_way0_hit;
wire            wr_way1_hit;
wire            hit_way;

// data select
wire [31:0]     way0_load_word;
wire [31:0]     way1_load_word;
wire [31:0]     load_result;

// miss buffer
wire [127:0]    replace_data;
wire [19:0]     replace_tag;
wire            replace_way; 

reg  [127:0]    replace_data_r;
reg  [19:0]     replace_tag_r;
reg             replace_way_r;

reg [1:0]       ret_data_num;       // number of returned date

// LFSR
reg  [22:0]     pseudo_random_number;

// read data from cache
wire            way0_valid;
wire            way1_valid;
wire [19:0]     way0_tag;
wire [19:0]     way1_tag;
wire [127:0]    way0_rdata;
wire [127:0]    way1_rdata;

// tagv ram
TAGV_RAM tagv_way0(
    .addra(tagv_way0_addr),
    .clka(clk),
    .dina(tagv_way0_wdata),
    .douta(tagv_way0_rdata),
    .wea(tagv_way0_wen)
);
TAGV_RAM tagv_way1(
    .addra(tagv_way1_addr),
    .clka(clk),
    .dina(tagv_way1_wdata),
    .douta(tagv_way1_rdata),
    .wea(tagv_way1_wen)
);

// bank ram
BANK_RAM bank0_way0(
    .addra(bank0_way0_addr),
    .clka(clk),
    .dina(bank0_way0_wdata),
    .douta(bank0_way0_rdata),
    .wea(bank0_way0_wen)
);
BANK_RAM bank1_way0(
    .addra(bank1_way0_addr),
    .clka(clk),
    .dina(bank1_way0_wdata),
    .douta(bank1_way0_rdata),
    .wea(bank1_way0_wen)
);
BANK_RAM bank2_way0(
    .addra(bank2_way0_addr),
    .clka(clk),
    .dina(bank2_way0_wdata),
    .douta(bank2_way0_rdata),
    .wea(bank2_way0_wen)
);
BANK_RAM bank3_way0(
    .addra(bank3_way0_addr),
    .clka(clk),
    .dina(bank3_way0_wdata),
    .douta(bank3_way0_rdata),
    .wea(bank3_way0_wen)
);
BANK_RAM bank0_way1(
    .addra(bank0_way1_addr),
    .clka(clk),
    .dina(bank0_way1_wdata),
    .douta(bank0_way1_rdata),
    .wea(bank0_way1_wen)
);
BANK_RAM bank1_way1(
    .addra(bank1_way1_addr),
    .clka(clk),
    .dina(bank1_way1_wdata),
    .douta(bank1_way1_rdata),
    .wea(bank1_way1_wen)
);
BANK_RAM bank2_way1(
    .addra(bank2_way1_addr),
    .clka(clk),
    .dina(bank2_way1_wdata),
    .douta(bank2_way1_rdata),
    .wea(bank2_way1_wen)
);
BANK_RAM bank3_way1(
    .addra(bank3_way1_addr),
    .clka(clk),
    .dina(bank3_way1_wdata),
    .douta(bank3_way1_rdata),
    .wea(bank3_way1_wen)
);

// main fsm
always @(posedge clk) begin
    if (~resetn) begin
        main_state <= MAIN_IDLE;
    end
    else begin
        main_state <= main_next_state;
    end
end

always @(*) begin
    case (main_state)
        MAIN_IDLE: begin
            if (valid) begin
                main_next_state = MAIN_LOOKUP;
            end
            else begin
                main_next_state = MAIN_IDLE;
            end
        end
        MAIN_LOOKUP: begin
            if (cache_hit & ~valid) begin
                main_next_state = MAIN_IDLE;
            end
            else if (cache_hit & valid) begin
                main_next_state = MAIN_LOOKUP;
            end
            else begin                              // ~cache_hit
                main_next_state = MAIN_MISS;
            end
        end
        MAIN_MISS: begin
            if (wr_rdy) begin
                main_next_state = MAIN_REPLACE;
            end
            else begin
                main_next_state = MAIN_MISS;
            end
        end
        MAIN_REPLACE: begin
            if (rd_rdy) begin
                main_next_state = MAIN_REFILL;
            end
            else begin
                main_next_state = MAIN_REPLACE;
            end
        end
        MAIN_REFILL: begin
            if (ret_valid & ret_last) begin
                main_next_state = MAIN_IDLE;
            end
            else begin
                main_next_state = MAIN_REFILL;
            end
        end
        default:
            main_next_state <= MAIN_IDLE;
    endcase
end

// write buffer fsm
always @(posedge clk) begin
    if (~resetn) begin
        wr_state <= WR_IDLE;
    end
    else begin
        wr_state <= wr_next_state;
    end
end

wire hit_write;
assign hit_write = cache_hit & req_op_r;                
always @(*) begin
    case (wr_state)
        WR_IDLE: begin
            if (main_state[1] & hit_write) begin        // mainfsm is LOOKUP and Store hit Cache
                wr_next_state = WR_WRITE;
            end
            else begin
                wr_next_state = WR_IDLE;
            end
        end
        WR_WRITE: begin
            if (~hit_write) begin
                wr_next_state = WR_IDLE;
            end
            else begin
                wr_next_state = WR_WRITE;
            end
        end
        default:
            wr_next_state <= WR_IDLE;
    endcase
end

// request buffer
always @(posedge clk)
begin
    if(~resetn)
    begin
        req_index_r  <= 0;
        req_offset_r <= 0;
        req_op_r     <= 0;
        req_tag_r    <= 0;
        req_wdata_r  <= 0;
        req_wstrb_r  <= 0;
    end
    else if(main_state == MAIN_IDLE & main_next_state == MAIN_LOOKUP | main_state == MAIN_LOOKUP & main_next_state == MAIN_LOOKUP)
    begin
        req_index_r   <= index;
        req_offset_r  <= offset;
        req_op_r      <= op;
        req_tag_r     <= tag;
        req_wdata_r   <= wdata;
        req_wstrb_r   <= wstrb;
        replace_way_r <= pseudo_random_number[0];
    end
end

assign way0_valid = tagv_way0_rdata[0];
assign way1_valid = tagv_way1_rdata[0];
assign way0_tag   = tagv_way0_rdata[20:1];
assign way1_tag   = tagv_way1_rdata[20:1];

assign way0_hit  = way0_valid && (way0_tag == req_tag_r);
assign way1_hit  = way1_valid && (way1_tag == req_tag_r);
assign wr_way0_hit = way0_valid && (way0_tag == wr_tag_r);
assign wr_way1_hit = way1_valid && (way1_tag == wr_tag_r);
assign cache_hit = way0_hit || way1_hit;
assign hit_way   = way1_hit ? 1'b1 : 1'b0;

assign way0_rdata = {bank3_way0_rdata, bank2_way0_rdata, bank1_way0_rdata, bank0_way0_rdata};
assign way1_rdata = {bank3_way1_rdata, bank2_way1_rdata, bank1_way1_rdata, bank0_way1_rdata};
assign way0_load_word = way0_rdata[req_offset_r[3:2] * 32 +: 32];
assign way1_load_word = way1_rdata[req_offset_r[3:2] * 32 +: 32];
assign load_result = way0_hit ? way0_load_word : way1_load_word;

always @(posedge clk)
begin
    if(main_state == MAIN_LOOKUP & hit_write)
    begin
        wr_tag_r    <= req_tag_r;
        wr_way_r    <= hit_way;
        wr_bank_r   <= req_offset_r[3:2];
        wr_index_r  <= req_index_r;
        wr_wstrb_r  <= req_wstrb_r;
        wr_wdata_r  <= req_wdata_r;
        wr_offset_r <= req_offset_r;
    end
end

// bank selection
assign wr_bank0_hit = wr_offset_r[3:2] == 2'b00;
assign wr_bank1_hit = wr_offset_r[3:2] == 2'b01;
assign wr_bank2_hit = wr_offset_r[3:2] == 2'b10;
assign wr_bank3_hit = wr_offset_r[3:2] == 2'b11;

// write hit
assign replace_way  = replace_way_r;
assign replace_data = replace_way ? way1_rdata : way0_rdata;
assign replace_tag  = replace_way ? way1_tag   : way0_tag;
always @(posedge clk)
begin
    if(main_state == MAIN_LOOKUP && main_next_state == MAIN_MISS)
    begin
        replace_data_r <= replace_data;
        replace_tag_r  <= replace_tag;
    end
end

// miss buffer
always @(posedge clk) begin
    if (~resetn)
        ret_data_num <= 2'b00;
    else if (ret_last && ret_valid)
        ret_data_num <= 2'b00;
    else if (ret_valid)
        ret_data_num <= ret_data_num + 1'b1;
end

reg using_req_buffer;
always @(posedge clk) begin
    if (~resetn) begin
        using_req_buffer <= 1'b0;
    end
    else if (using_req_buffer && data_ok) begin
        using_req_buffer <= 1'b0;
    end
    else if (main_state == MAIN_IDLE && valid) begin
        using_req_buffer <= 1'b1;
    end
end

// dirty bit table
assign dirty_index = using_req_buffer ? req_index_r:
                     valid ? index: 8'b0;

always @(posedge clk) begin
    if (~resetn) begin
        dirty_way0 <= 256'b0;
        dirty_way1 <= 256'b0;
    end
    else if (main_state == MAIN_LOOKUP && req_op_r) begin
        if (way0_hit) begin
            dirty_way0[dirty_index] <= 1'b1;
        end
        else if (way1_hit) begin
            dirty_way1[dirty_index] <= 1'b1;
        end
    end
    else if (main_state == MAIN_REFILL) begin
        if (replace_way==0) begin
            dirty_way0[dirty_index] <= req_op_r;
        end
        else if (replace_way==1) begin
            dirty_way1[dirty_index] <= req_op_r;
        end
    end
end

wire is_dirty;
assign is_dirty = replace_way ? dirty_way1[dirty_index] : dirty_way0[dirty_index];

reg wr_req_r;

always @(posedge clk) begin
    if (~resetn) begin
        wr_req_r <= 1'b0;
    end
    else if (main_state == MAIN_MISS && is_dirty && ~wr_req_r) begin
        wr_req_r <= 1'b1;
    end
    else if (wr_rdy && wr_req_r) begin
        wr_req_r <= 1'b0;
    end
end

// axi interface
assign rd_req = main_state == MAIN_REPLACE;
assign rd_type = 3'b100;
assign rd_addr = {req_tag_r, req_index_r, 4'b0};

assign wr_req = wr_req_r;
assign wr_type = 3'b100;
assign wr_addr = {replace_tag_r, req_index_r, 4'b0};
assign wr_data = replace_data;
assign wr_wstrb = 4'b1111;

// LFSR
always @ (posedge clk) begin
   if (~resetn)
       pseudo_random_number <= {7'b1111111,16'hFFFF};
   else
       pseudo_random_number <= {pseudo_random_number[21:0], pseudo_random_number[22] ^ pseudo_random_number[0]};
end

// cpu interface
assign rdata =  main_state == MAIN_LOOKUP ? load_result :
                main_state == MAIN_REFILL & ret_valid ? req_wdata_r : 32'b0;

assign addr_ok =    main_state == MAIN_IDLE & main_next_state == MAIN_LOOKUP | 
                    main_state == MAIN_LOOKUP & main_next_state == MAIN_LOOKUP;

assign data_ok =    main_state == MAIN_LOOKUP & main_next_state == MAIN_IDLE |
                    main_state == MAIN_LOOKUP & main_next_state == MAIN_LOOKUP |
                    main_state == MAIN_REFILL & ret_valid & ret_data_num == req_offset_r[3:2];

// tagv ram and bank ram interface
assign tagv_way0_addr = wr_state == WR_WRITE ? wr_index_r :
                        main_state == MAIN_LOOKUP ? index: req_index_r;
assign tagv_way1_addr = tagv_way0_addr;

assign tagv_way0_wen = main_state == MAIN_REFILL && ~replace_way || wr_state == WR_WRITE && ~wr_way_r;
assign tagv_way1_wen = main_state == MAIN_REFILL && replace_way || wr_state == WR_WRITE && wr_way_r;

assign tagv_way0_wdata = wr_state == WR_WRITE ? {way0_tag,1'b1}: {req_tag_r,1'b1};
assign tagv_way1_wdata = wr_state == WR_WRITE ? {way1_tag,1'b1}: {req_tag_r,1'b1};

assign bank0_way0_addr = wr_state == WR_WRITE ? wr_index_r:
                         main_state == MAIN_LOOKUP ? index: req_index_r;
assign bank1_way0_addr = bank0_way0_addr;
assign bank2_way0_addr = bank0_way0_addr;
assign bank3_way0_addr = bank0_way0_addr;
assign bank0_way1_addr = bank0_way0_addr;
assign bank1_way1_addr = bank0_way0_addr;
assign bank2_way1_addr = bank0_way0_addr;
assign bank3_way1_addr = bank0_way0_addr;

assign bank0_way0_wen  = (wr_state == WR_WRITE && wr_way0_hit && wr_bank0_hit) ? wr_wstrb_r : 
                         (main_state == MAIN_REFILL && ret_data_num == 2'b00 && ret_valid && ~replace_way) ? 4'hf : 4'h0;
assign bank1_way0_wen  = (wr_state == WR_WRITE && wr_way0_hit && wr_bank1_hit) ? wr_wstrb_r : 
                         (main_state == MAIN_REFILL && ret_data_num == 2'b01 && ret_valid && ~replace_way) ? 4'hf : 4'h0;
assign bank2_way0_wen  = (wr_state == WR_WRITE && wr_way0_hit && wr_bank2_hit) ? wr_wstrb_r : 
                         (main_state == MAIN_REFILL && ret_data_num == 2'b10 && ret_valid && ~replace_way) ? 4'hf : 4'h0;
assign bank3_way0_wen  = (wr_state == WR_WRITE && wr_way0_hit && wr_bank3_hit) ? wr_wstrb_r : 
                         (main_state == MAIN_REFILL && ret_data_num == 2'b11 && ret_valid && ~replace_way) ? 4'hf : 4'h0;
assign bank0_way1_wen  = (wr_state == WR_WRITE && wr_way1_hit && wr_bank0_hit) ? wr_wstrb_r : 
                         (main_state == MAIN_REFILL && ret_data_num == 2'b00 && ret_valid && replace_way) ? 4'hf : 4'h0;
assign bank1_way1_wen  = (wr_state == WR_WRITE && wr_way1_hit && wr_bank1_hit) ? wr_wstrb_r : 
                         (main_state == MAIN_REFILL && ret_data_num == 2'b01 && ret_valid && replace_way) ? 4'hf : 4'h0;
assign bank2_way1_wen  = (wr_state == WR_WRITE && wr_way1_hit && wr_bank2_hit) ? wr_wstrb_r : 
                         (main_state == MAIN_REFILL && ret_data_num == 2'b10 && ret_valid && replace_way) ? 4'hf : 4'h0;
assign bank3_way1_wen  = (wr_state == WR_WRITE && wr_way1_hit && wr_bank3_hit) ? wr_wstrb_r : 
                         (main_state == MAIN_REFILL && ret_data_num == 2'b11 && ret_valid && replace_way) ? 4'hf : 4'h0;

wire [31:0] refill_data;
assign refill_data = req_wstrb_r == 4'b0000 ? ret_data:
                     req_wstrb_r == 4'b0001 ? {ret_data[31:8],req_wdata_r[7:0]}:
                     req_wstrb_r == 4'b0011 ? {ret_data[31:16],req_wdata_r[15:0]}:
                     req_wstrb_r == 4'b0111 ? {ret_data[31:24],req_wdata_r[23:0]}:
                     req_wstrb_r == 4'b1111 ? req_wdata_r:
                     req_wstrb_r == 4'b1110 ? {req_wdata_r[31:8],ret_data[7:0]}:
                     req_wstrb_r == 4'b1100 ? {req_wdata_r[31:16],ret_data[15:0]}:
                     req_wstrb_r == 4'b1000 ? {req_wdata_r[31:24],ret_data[23:0]}: 32'b0;

assign bank0_way0_wdata = wr_state == WR_WRITE && ~wr_way_r ? wr_wdata_r :
                          main_state == MAIN_REFILL ? (req_offset_r[3:2] == 2'b00) ? refill_data : ret_data : 32'b0;
assign bank1_way0_wdata = wr_state == WR_WRITE && ~wr_way_r ? wr_wdata_r :
                          main_state == MAIN_REFILL ? (req_offset_r[3:2] == 2'b01) ? refill_data : ret_data : 32'b0;
assign bank2_way0_wdata = wr_state == WR_WRITE && ~wr_way_r ? wr_wdata_r :
                          main_state == MAIN_REFILL ? (req_offset_r[3:2] == 2'b10) ? refill_data : ret_data : 32'b0;
assign bank3_way0_wdata = wr_state == WR_WRITE && ~wr_way_r ? wr_wdata_r :
                          main_state == MAIN_REFILL ? (req_offset_r[3:2] == 2'b11) ? refill_data : ret_data : 32'b0;
assign bank0_way1_wdata = wr_state == WR_WRITE && wr_way_r ? wr_wdata_r :
                          main_state == MAIN_REFILL ? (req_offset_r[3:2] == 2'b00) ? refill_data : ret_data : 32'b0;
assign bank1_way1_wdata = wr_state == WR_WRITE && wr_way_r ? wr_wdata_r :
                          main_state == MAIN_REFILL ? (req_offset_r[3:2] == 2'b01) ? refill_data : ret_data : 32'b0;
assign bank2_way1_wdata = wr_state == WR_WRITE && wr_way_r ? wr_wdata_r :
                          main_state == MAIN_REFILL ? (req_offset_r[3:2] == 2'b10) ? refill_data : ret_data : 32'b0;
assign bank3_way1_wdata = wr_state == WR_WRITE && wr_way_r ? wr_wdata_r :
                          main_state == MAIN_REFILL ? (req_offset_r[3:2] == 2'b11) ? refill_data : ret_data : 32'b0;
endmodule
