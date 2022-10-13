module WB_stage(
    input               clk,
    input               reset,
    // allowin
    output              ws_allowin,
    // input from EXE stage
    input               ms_to_ws_valid,
    input   [103:0]     ms_to_ws_bus,
    // output for reg_file
    output  [38:0]      rf_bus,
    // trace debug interface
    output [31:0]       debug_wb_pc     ,
    output [ 3:0]       debug_wb_rf_we  ,
    output [ 4:0]       debug_wb_rf_wnum,
    output [31:0]       debug_wb_rf_wdata,
    // interrupt signal
    output              wb_ex
);

wire        gr_we;
wire [31:0] final_result;
wire [31:0] pc;
wire [4: 0] dest;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

reg          ws_valid;
wire         ws_ready_go;
reg  [103:0] ms_to_ws_bus_r;

wire [33:0]  csr_data;
wire [4:0]   csr_op;
wire [13:0]  csr_num;
wire [14:0]  csr_code;
wire         inst_csrrd;
wire         inst_csrwr;
wire         inst_csrxchg;
wire         inst_ertn;
wire         inst_syscall;

assign  {csr_op,csr_num,csr_code}=csr_data;
assign  {inst_csrrd,inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall}=csr_op;

assign rf_we    = gr_we && ws_valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end
    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

//deal with input and output
assign {csr_data,gr_we,dest,final_result,pc}=ms_to_ws_bus_r;
assign rf_bus={ws_valid,rf_we,rf_waddr,rf_wdata};

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

endmodule