module preIF_stage(
    input           clk,
    input           reset,
    // allowin from ID stage
    input           fs_allowin,
    // branch bus
    input   [33:0]  br_bus,
    // output to IF stage
    output          to_fs_valid,
    output  [33:0]  to_fs_bus,
    // inst sram interface
    output          inst_sram_req,       // if there is a request
    output          inst_sram_wr,        // read or write
    output  [3:0]   inst_sram_wstrb,     // write strobes
    output  [1:0]   inst_sram_size,      // number of bytes  0:1 bytes 1:2bytes 2:4bytes
    output  [31:0]  inst_sram_addr,      // request addr
    output  [31:0]  inst_sram_wdata,     // write data
    input           inst_sram_addr_ok,   // if data and addr has been received
    // interrupt signal
    input           wb_ex,
    input           wb_ertn,
    input   [31:0]  csr_eentry,
    input   [31:0]  csr_era
);


// to detech adef
wire adef_detected;

// signals for pc
wire [31:0] seq_pc;
wire [31:0] nextpc;

// signals from branch
wire        br_taken;
wire [31:0] br_target;
wire        br_taken_cancel;
assign {br_taken_cancel,br_taken,br_target} = br_bus;

reg  [31:0] pre_fs_pc;

// pre-IF stage
assign seq_pc       =   pre_fs_pc + 3'h4;
    
assign nextpc       =   wb_ex       ? csr_eentry :
                        wb_ertn     ? csr_era   :
                        br_taken    ? br_target : seq_pc;

assign pre_fs_ready_go = inst_sram_req && inst_sram_addr_ok;
assign to_fs_valid = pre_fs_ready_go & ~reset;

assign adef_detected = nextpc[1:0] == 2'b00 ? 0 : 1;

// PC update
always @(posedge clk) begin
    if (reset) begin
        pre_fs_pc <= 32'h1BFFFFFC;  // make nextpc=0x1C000000;
    end
    else if (fs_allowin & to_fs_valid) begin
        pre_fs_pc <= nextpc;
    end
end

assign to_fs_bus = {br_taken_cancel,adef_detected,pre_fs_pc};
// interface with sram
assign inst_sram_req    = fs_allowin;
assign inst_sram_addr   = nextpc;
assign inst_sram_wr     = 1'b0;
assign inst_sram_wstrb  = 4'b0;
assign inst_sram_size   = 2'b10;
assign inst_sram_wdata  = 32'b0;

endmodule

