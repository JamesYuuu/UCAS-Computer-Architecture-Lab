module WB_stage(
    input               clk,
    input               reset,
    // allowin
    output              ws_allowin,
    // input from EXE stage
    input               ms_to_ws_valid,
    input   [167:0]     ms_to_ws_bus,
    // output for reg_file
    output  [38:0]      rf_bus,
    // trace debug interface
    output [31:0]       debug_wb_pc     ,
    output [ 3:0]       debug_wb_rf_we  ,
    output [ 4:0]       debug_wb_rf_wnum,
    output [31:0]       debug_wb_rf_wdata,
    // interrupt signal
    output              wb_ex,
    output [31:0]       csr_eentry
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
reg  [167:0] ms_to_ws_bus_r;

wire [33:0]  csr_data;
wire [4:0]   csr_op;
wire [13:0]  csr_num;
wire [14:0]  csr_code;
wire         inst_csrrd;
wire         inst_csrwr;
wire         inst_csrxchg;
wire         inst_ertn;
wire         inst_syscall;

wire [31:0]  rj_value;
wire [31:0]  rkd_value;

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
    else if (wb_ex) begin
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
assign {rj_value,rkd_value,csr_data,gr_we,dest,final_result,pc}=ms_to_ws_bus_r;
assign rf_bus={ws_valid,rf_we,rf_waddr,rf_wdata};

assign wb_ex = inst_syscall & ws_valid;

wire csr_re;
wire [31:0] csr_rvalue;
wire csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire wb_ecode;
wire wb_esubcode;
wire [31:0] wb_vaddr;
wire [31:0] csr_save0_data;
wire [31:0] csr_save1_data;
wire [31:0] csr_save2_data;
wire [31:0] csr_save3_data;
wire [31:0] coreid_in;
wire ertn_flush;
wire [7:0] hw_int_in;

assign csr_re = inst_csrrd;
assign csr_we = inst_csrwr | inst_csrxchg;
assign csr_wmask = 0;
assign csr_wvalue = 0;
assign wb_ecode = 0;
assign wb_esubcode = 0;
assign wb_vaddr = 0;
assign csr_save0_data = 0;
assign csr_save1_data = 0;
assign csr_save2_data = 0;
assign csr_save3_data = 0;
assign coreid_in = 0;
assign ertn_flush = inst_ertn;
assign hw_int_in = 0;

csr my_csr(
    .reset(reset),
    .clk(clk),
    .csr_re(csr_re),
    .csr_num(csr_num),
    .csr_rvalue(csr_rvalue),
    .csr_eentry(csr_eentry),
    .csr_we(csr_we),
    .csr_wmask(csr_wmask),
    .csr_wvalue(csr_wvalue),
    .wb_ecode(wb_ecode),
    .wb_esubcode(wb_esubcode),
    .wb_ex(wb_ex),
    .wb_pc(wb_pc),
    .wb_vaddr(wb_vaddr),
    .csr_save0_data(csr_save0_data),
    .csr_save1_data(csr_save1_data),
    .csr_save2_data(csr_save2_data),
    .csr_save3_data(csr_save3_data),
    .coreid_in(coreid_in),
    .ertn_flush(ertn_flush),
    .hw_int_in(hw_int_in)
);

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

endmodule