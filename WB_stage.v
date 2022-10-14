module WB_stage(
    input               clk,
    input               reset,
    // allowin
    output              ws_allowin,
    // input from EXE stage
    input               ms_to_ws_valid,
    input   [171:0]     ms_to_ws_bus,
    // output for reg_file
    output  [38:0]      rf_bus,
    // trace debug interface
    output [31:0]       debug_wb_pc     ,
    output [ 3:0]       debug_wb_rf_we  ,
    output [ 4:0]       debug_wb_rf_wnum,
    output [31:0]       debug_wb_rf_wdata,
    // interrupt signal
    output              wb_ex,
    output [31:0]       csr_eentry,
    output [31:0]       csr_era,
    output              wb_ertn,
    input  [31:0]       data_sram_addr_error
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
reg  [171:0] ms_to_ws_bus_r;

wire [33:0]  csr_data;
wire [4:0]   csr_op;
wire [13:0]  csr_num;
wire [13:0]  wb_csr_num;
wire [14:0]  csr_code;
wire         inst_csrrd;
wire         inst_csrwr;
wire         inst_csrxchg;
wire         inst_ertn;
wire         inst_syscall;

wire [3:0]   exception_op;
wire         adef_detected;
wire         inst_break;
wire         ine_detected;
wire         ale_detected;

// needed for csr operation
wire        csr_re;
wire [31:0] csr_rvalue;
wire        csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire [5:0]  wb_ecode;
wire [8:0]  wb_esubcode;
wire [31:0] wb_vaddr;
wire [31:0] csr_save0_data;
wire [31:0] csr_save1_data;
wire [31:0] csr_save2_data;
wire [31:0] csr_save3_data;
wire [31:0] coreid_in;
wire        ertn_flush;
wire [7:0]  hw_int_in;
wire        has_int;
wire        ipi_int_in;

wire [31:0]  rj_value;
wire [31:0]  rkd_value;

assign  {csr_op,csr_num,csr_code}=csr_data;
assign  {inst_csrrd,inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall}=csr_op;
assign  {adef_detected,inst_break,ine_detected,ale_detected}=exception_op;

assign rf_we    = gr_we && ws_valid;
assign rf_waddr = dest;
assign rf_wdata = inst_csrrd ? csr_rvalue : 
                  inst_csrwr ? csr_rvalue :
                  inst_csrxchg ? csr_rvalue :
                  final_result;

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (wb_ex | wb_ertn) begin
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
assign {exception_op,rj_value,rkd_value,csr_data,gr_we,dest,final_result,pc}=ms_to_ws_bus_r;
assign rf_bus={ws_valid,rf_we,rf_waddr,rf_wdata};

assign wb_ex = (inst_syscall | inst_break | adef_detected | ine_detected | ale_detected) & ws_valid;
assign wb_ertn = inst_ertn & ws_valid;

assign csr_re = inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn;
assign csr_we = inst_csrwr | inst_csrxchg;
assign csr_wmask =  inst_csrwr ? 32'hffffffff :
                    inst_csrxchg ? rj_value : 32'b0;
assign csr_wvalue = (inst_csrwr | inst_csrxchg) ? rkd_value : 32'b0;
assign wb_ecode = inst_syscall  ? 6'hb : 
                  inst_break    ? 6'hc :
                  adef_detected ? 6'h8 :
                  ine_detected  ? 6'hd :
                  ale_detected  ? 6'h9 :
                  6'h0;
assign wb_esubcode = 9'b0;
assign wb_vaddr =   adef_detected ? pc :
                    ale_detected  ? data_sram_addr_error : 32'b0;
assign csr_save0_data = 32'b0;
assign csr_save1_data = 32'b0;
assign csr_save2_data = 32'b0;
assign csr_save3_data = 32'b0;
assign coreid_in      = 32'b0;
assign ertn_flush     = inst_ertn;
assign hw_int_in      = 8'b0;
assign ipi_int_in     = 1'b0;

assign wb_csr_num = wb_ertn ? 14'h6 : csr_num;
assign csr_era = csr_rvalue;

csr my_csr(
    .reset(reset),
    .clk(clk),
    .csr_re(csr_re),
    .csr_num(wb_csr_num),
    .csr_rvalue(csr_rvalue),
    .csr_eentry(csr_eentry),
    .csr_we(csr_we),
    .csr_wmask(csr_wmask),
    .csr_wvalue(csr_wvalue),
    .wb_ecode(wb_ecode),
    .wb_esubcode(wb_esubcode),
    .wb_ex(wb_ex),
    .wb_pc(pc),
    .wb_vaddr(wb_vaddr),
    .csr_save0_data(csr_save0_data),
    .csr_save1_data(csr_save1_data),
    .csr_save2_data(csr_save2_data),
    .csr_save3_data(csr_save3_data),
    .coreid_in(coreid_in),
    .ertn_flush(ertn_flush),
    .hw_int_in(hw_int_in),
    .has_int(has_int)
);

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

endmodule