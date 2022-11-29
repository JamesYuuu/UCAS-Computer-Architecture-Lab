module WB_stage(
    input               clk,
    input               reset,
    // allowin
    output              ws_allowin,
    // input from EXE stage
    input               ms_to_ws_valid,
    input   [223:0]     ms_to_ws_bus,
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
    output [63:0]       stable_counter_value,
    output              has_int,
    // comunication with tlb
    input               r_e,
    input   [18:0]      r_vppn,
    input   [5:0]       r_ps,
    input   [9:0]       r_asid,
    input               r_g,
    input   [19:0]      r_ppn0,
    input   [1:0]       r_plv0,
    input   [1:0]       r_mat0,
    input               r_d0,
    input               r_v0,
    input   [19:0]      r_ppn1,
    input   [1:0]       r_plv1,
    input   [1:0]       r_mat1,
    input               r_d1,
    input               r_v1,
    output  [3:0]       r_index,
    output              we,
    output  [3:0]       w_index,
    output              w_e,
    output  [18:0]      w_vppn,
    output  [5:0]       w_ps,
    output  [9:0]       w_asid,
    output              w_g,
    output  [19:0]      w_ppn0,
    output  [1:0]       w_plv0,
    output  [1:0]       w_mat0,
    output              w_d0,
    output              w_v0,
    output  [19:0]      w_ppn1,
    output  [1:0]       w_plv1,
    output  [1:0]       w_mat1,
    output              w_d1,
    output              w_v1,
    input               s1_found,
    input   [3:0]       s1_index,
    // to stall the tlb_srch
    output              wb_write_asid_ehi,

    // to handle tlb inst in exe
    input               ex_inst_tlb_srch,
    output  [31:0]      csr_asid,
    output  [31:0]      csr_tlbehi,

    output              wb_refetch,
    output  [31:0]      refetch_pc,

    // to do address transilation
    output  [31:0]      csr_dmw0,
    output  [31:0]      csr_dmw1,
    output  [31:0]      csr_crmd
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
reg  [223:0] ms_to_ws_bus_r;

wire [31:0]  data_sram_addr_error;
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
wire         inst_rdcntid;
wire         ds_has_int;

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
wire [31:0] coreid_in;
wire        ertn_flush;
wire [7:0]  hw_int_in;
wire        ipi_int_in;

wire [31:0]  rj_value;
wire [31:0]  rkd_value;

wire [9:0]  tlb_bus;
wire inst_tlb_fill;
wire inst_tlb_wr;
wire inst_tlb_srch;
wire inst_tlb_rd;
wire inst_tlb_inv;
wire [4:0] op_tlb_inv;
wire [3:0] inst_tlb_op;

wire [5:0] tlb_exception;
wire  tlbr;
wire  pil;
wire  pis;
wire  pif;
wire  pme;
wire  ppi;

assign  {csr_op,csr_num,csr_code}=csr_data;
assign  {inst_csrrd,inst_csrwr,inst_csrxchg,inst_ertn,inst_syscall} = csr_op;
assign  {adef_detected,inst_break,ine_detected,ale_detected} = exception_op;
assign  {tlbr,pil,pis,pif,pme,ppi} = tlb_exception;

assign rf_we    = gr_we && ws_valid && ~(wb_ex) && ~(wb_refetch);
assign rf_waddr = dest;
assign rf_wdata = inst_csrrd ? csr_rvalue : 
                  inst_csrwr ? csr_rvalue :
                  inst_csrxchg ? csr_rvalue :
                  inst_rdcntid ? csr_rvalue :
                  final_result;

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
        ms_to_ws_bus_r <= 0;
    end
    else if (wb_ex | wb_ertn | wb_refetch) begin
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
wire mem_re;
assign {tlb_exception,refetch_needed, tlb_bus, mem_re,inst_rdcntid,data_sram_addr_error, ds_has_int,exception_op,rj_value,rkd_value,csr_data,gr_we,dest,final_result,pc}=ms_to_ws_bus_r;
assign rf_bus={ws_valid,rf_we,rf_waddr,rf_wdata};

assign {inst_tlb_fill, inst_tlb_wr, inst_tlb_srch, inst_tlb_rd, inst_tlb_inv, op_tlb_inv} = tlb_bus;

assign wb_ex = (inst_syscall | inst_break | adef_detected | ine_detected | ale_detected | ds_has_int | tlbr | pil | pis | pif | pme | ppi) & ws_valid;
assign wb_ertn = inst_ertn & ws_valid;

assign csr_re = inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn | inst_rdcntid;
assign csr_we = (inst_csrwr | inst_csrxchg) & ws_valid;
assign csr_wmask =  inst_csrwr ? 32'hffffffff :
                    inst_csrxchg ? rj_value : 32'b0;
assign csr_wvalue = (inst_csrwr | inst_csrxchg) ? rkd_value : 32'b0;
assign wb_ecode = inst_syscall  ? 6'hb : 
                  inst_break    ? 6'hc :
                  adef_detected ? 6'h8 :
                  ine_detected  ? 6'hd :
                  ale_detected  ? 6'h9 :
                  tlbr          ? 6'h3F :
                  pil           ? 6'h1:
                  pis           ? 6'h2:
                  pif           ? 6'h3:
                  pme           ? 6'h4:
                  ppi           ? 6'h7:
                  6'h0;
assign wb_esubcode = 9'b0;
assign wb_vaddr =   adef_detected ? pc :
                    ale_detected  ? data_sram_addr_error : 32'b0;
assign coreid_in      = 32'b0;
assign ertn_flush     = inst_ertn;
assign hw_int_in      = 8'b0;
assign ipi_int_in     = 1'b0;

assign wb_csr_num = wb_ertn ? 14'h6 : 
                    inst_rdcntid ? 14'h40 :
                    csr_num;
assign csr_era = csr_rvalue;

assign inst_tlb_op = {inst_tlb_fill, inst_tlb_wr, ex_inst_tlb_srch, inst_tlb_rd};

csr csr(
    // csr
    .reset                  (reset               ),
    .clk                    (clk                 ),
    .csr_re                 (csr_re              ),
    .csr_num                (wb_csr_num          ),
    .csr_rvalue             (csr_rvalue          ),
    .csr_eentry             (csr_eentry          ),
    .csr_we                 (csr_we              ),
    .csr_wmask              (csr_wmask           ),
    .csr_wvalue             (csr_wvalue          ),
    .wb_ecode               (wb_ecode            ),
    .wb_esubcode            (wb_esubcode         ),
    .wb_ex                  (wb_ex               ),
    .wb_pc                  (pc                  ),
    .wb_vaddr               (wb_vaddr            ),
    .coreid_in              (coreid_in           ),
    .ertn_flush             (ertn_flush          ),
    .hw_int_in              (hw_int_in           ),
    .has_int                (has_int             ),
    .ipi_int_in             (ipi_int_in          ),
    .stable_counter_value   (stable_counter_value),
    // tlb
    .inst_tlb_op            (inst_tlb_op         ),
    // write port
    .we                     (we             ),
    .w_index                (w_index        ),
    .w_e                    (w_e            ),
    .w_ps                   (w_ps           ),
    .w_vppn                 (w_vppn         ),
    .w_asid                 (w_asid         ),
    .w_g                    (w_g            ),
    .w_ppn0                 (w_ppn0         ),
    .w_plv0                 (w_plv0         ),
    .w_mat0                 (w_mat0         ),
    .w_d0                   (w_d0           ),
    .w_v0                   (w_v0           ),
    .w_ppn1                 (w_ppn1         ),
    .w_plv1                 (w_plv1         ),
    .w_mat1                 (w_mat1         ),
    .w_d1                   (w_d1           ),
    .w_v1                   (w_v1           ),
    // read port            
    .r_index                (r_index        ),
    .r_e                    (r_e            ),
    .r_vppn                 (r_vppn         ),
    .r_ps                   (r_ps           ),
    .r_asid                 (r_asid         ),
    .r_g                    (r_g            ),
    .r_ppn0                 (r_ppn0         ),
    .r_plv0                 (r_plv0         ),
    .r_mat0                 (r_mat0         ),
    .r_d0                   (r_d0           ),
    .r_v0                   (r_v0           ),
    .r_ppn1                 (r_ppn1         ),     
    .r_plv1                 (r_plv1         ),
    .r_mat1                 (r_mat1         ),
    .r_d1                   (r_d1           ),
    .r_v1                   (r_v1           ),
    .s1_found               (s1_found       ),
    .s1_index               (s1_index       ),
    .csr_asid               (csr_asid       ),
    .csr_tlbehi             (csr_tlbehi     ),
    .csr_dmw0               (csr_dmw0       ),
    .csr_dmw1               (csr_dmw1       ),
    .csr_crmd               (csr_crmd       )
);

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

assign wb_write_asid_ehi =  (inst_tlb_rd     | 
                            inst_csrwr      & (csr_num == 14'h18) |
                            inst_csrwr      & (csr_num == 14'h11) |
                            inst_csrxchg    & (csr_num == 14'h18) |
                            inst_csrxchg    & (csr_num == 14'h11)) & ws_valid;

assign wb_refetch = refetch_needed;
assign refetch_pc = pc;

endmodule